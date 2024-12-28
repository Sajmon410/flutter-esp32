import 'dart:typed_data'; // Rad sa bajtovima
import 'dart:io'; // Provera konekcije
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:photo_manager/photo_manager.dart'; // Rad sa galerijom
import 'package:location/location.dart' as loc; // GPS lokacija
import 'package:image/image.dart' as img; // Rad sa slikama i EXIF metapodacima
import 'package:flutter_vlc_player/flutter_vlc_player.dart'; // VLC Player za stream
import 'package:exif/exif.dart'; // EXIF biblioteka za metapodatke

void main() {
  runApp(const MyApp());
}

// Glavna aplikacija
class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: CameraScreen(),
    );
  }
}

// Kamera kontrola (ESP32)
class CameraControl {
  final String baseHost = 'http://192.168.0.7'; // Port 81

  // Funkcija za uzimanje slike
  Future<Uint8List?> getStill() async {
    final url = Uri.parse('$baseHost/capture?_cb=${DateTime.now().millisecondsSinceEpoch}');
    print('Pokušaj povezivanja na URL: $url');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        print('Slika uspešno preuzeta!');
        return response.bodyBytes;
      } else {
        print('HTTP Greška: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Greška: $e'); // Detaljna greška
      return null;
    }
  }
}

// Ekran sa kamerom
class CameraScreen extends StatefulWidget {
  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  final CameraControl cameraControl = CameraControl();
  bool _isLoading = false;
  Uint8List? _imageBytes;
  bool _imageCaptured = false;
  bool _isStreaming = false;

  // VLC Player Controller
  late VlcPlayerController _vlcController;

  // Lokacija
  loc.Location location = loc.Location();

  @override
  void initState() {
    super.initState();

    // Provera konekcije
    testConnection();

    // Inicijalizacija VLC kontrolera
    _vlcController = VlcPlayerController.network(
      'http://192.168.0.7:81/stream', // Port 81 za stream
      hwAcc: HwAcc.disabled, // Hardversko ubrzanje
      autoPlay: false, // Ne startuje automatski
      options: VlcPlayerOptions(),
    );

    _vlcController.addListener(() {
      if (_vlcController.value.isInitialized) {
        print("VLC je uspešno inicijalizovan.");
      } else {
        print("VLC još uvek nije inicijalizovan!");
      }
    });
  }

  @override
  void dispose() {
    _vlcController.dispose(); // Oslobađa resurse
    super.dispose();
  }

  // Provera mrežne konekcije
  void testConnection() async {
    try {
      final result = await InternetAddress.lookup('192.168.0.7');
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        print('Uređaj je dostupan.');
      }
    } on SocketException catch (_) {
      print('Uređaj nije dostupan.');
    }
  }

  // Funkcija za proveru dozvola za GPS
  Future<bool> _checkPermissions() async {
    bool serviceEnabled;
    loc.PermissionStatus permissionGranted;

    // Proveri da li je GPS omogućen
    serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) {
        print('GPS nije omogućen!');
        return false;
      }
    }

    // Proveri dozvole
    permissionGranted = await location.hasPermission();
    if (permissionGranted == loc.PermissionStatus.denied) {
      permissionGranted = await location.requestPermission();
      if (permissionGranted != loc.PermissionStatus.granted) {
        print('GPS dozvola nije odobrena!');
        return false;
      }
    }

    print('Dozvola za GPS odobrena.');
    return true;
  }

  // Hvatanje slike
  Future<void> _captureStillImage() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final image = await cameraControl.getStill();
      if (image != null) {
        setState(() {
          _imageBytes = image;
          _imageCaptured = true;
        });
      } else {
        print('Greška pri preuzimanju slike.');
      }
    } catch (e) {
      print("Greška: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Čuvanje slike sa GPS lokacijom
  Future<void> _saveImageWithLocation(Uint8List imageBytes) async {
    try {
      print("Početak čuvanja slike...");

      // Provera dozvola
      bool permissionsOk = await _checkPermissions();
      if (!permissionsOk) return;

      // 1. Preuzimanje GPS lokacije
      final loc.LocationData locationData = await location.getLocation();
      final double latitude = locationData.latitude ?? 0.0;
      final double longitude = locationData.longitude ?? 0.0;

      print('GPS lokacija: $latitude, $longitude');

      // 2. Učitavanje slike
      final img.Image? originalImage = img.decodeImage(imageBytes);
      if (originalImage == null) {
        print('Greška pri učitavanju slike.');
        return;
      }

      // 3. Kodiranje slike
      final Uint8List encodedImage = Uint8List.fromList(img.encodeJpg(originalImage));

      // 4. Snimanje slike u galeriju
      final AssetEntity? result = await PhotoManager.editor.saveImage(
        encodedImage,
        filename: 'moja_slika_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      if (result != null) {
        print('Slika sa GPS lokacijom sačuvana!');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Slika sa lokacijom je sačuvana!')),
        );
      } else {
        print('Greška pri snimanju slike!');
      }
    } catch (e) {
      print('Greška tokom čuvanja slike: $e');
    }
  }

  // Start/stop stream funkcija
  void _startStopStream() async {
    setState(() {
      _isStreaming = !_isStreaming;
    });

    if (_isStreaming) {
      if (_vlcController.value.isInitialized) {
        _vlcController.play();
      } else {
        setState(() {
          _isStreaming = false;
        });
      }
    } else {
      _vlcController.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ESP32 Camera Control')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_imageBytes != null) Image.memory(_imageBytes!),
            if (_isLoading) const CircularProgressIndicator(),
            ElevatedButton(onPressed: _captureStillImage, child: const Text('Get Still')),
            if (_imageCaptured) ElevatedButton(
              onPressed: () => _saveImageWithLocation(_imageBytes!),
              child: const Text('Save Image'),
            ),
          ],
        ),
      ),
    );
  }
}