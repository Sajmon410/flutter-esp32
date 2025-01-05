import 'dart:typed_data'; // Rad sa bajtovima
import 'dart:io'; // Provera konekcije
import 'package:flutter/material.dart';
import 'package:flutter_esp32/pages/map_screen.dart';
import 'package:http/http.dart' as http;
import 'package:photo_manager/photo_manager.dart'; // Rad sa galerijom
import 'package:location/location.dart' as loc; // GPS lokacija
import 'package:image/image.dart' as img; // Rad sa slikama// EXIF biblioteka za metapodatke
import 'package:flutter_mjpeg/flutter_mjpeg.dart'; // MJPEG paket

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
  final String baseHost = 'http://192.168.0.21'; // Port 81

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

  // Lokacija
  loc.Location location = loc.Location();

  @override
  void initState() {
    super.initState();

    // Provera konekcije
    testConnection();
  }

  // Provera mrežne konekcije
  void testConnection() async {
    try {
      final result = await InternetAddress.lookup('http://192.168.0.21');
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        print('Uređaj je dostupan.');
      }
    } on SocketException catch (_) {
      print('Uređaj nije dostupan.');
    }
  }

  // Provera GPS dozvola
  Future<bool> _checkPermissions() async {
    bool serviceEnabled;
    loc.PermissionStatus permissionGranted;

    // Proveri GPS servis
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
    if (!permissionsOk) {
      print("Dozvole nisu odobrene, neće se sačuvati slika.");
      return;
    }

    // GPS lokacija
    final loc.LocationData locationData = await location.getLocation();
    final double latitude = locationData.latitude ?? 0.0;
    final double longitude = locationData.longitude ?? 0.0;

    print('GPS lokacija: $latitude, $longitude');

    // Učitavanje slike
    final img.Image? originalImage = img.decodeImage(imageBytes);
    if (originalImage == null) {
      print('Greška pri učitavanju slike.');
      return;
    }

    // Kodiranje slike
    final Uint8List encodedImage = Uint8List.fromList(img.encodeJpg(originalImage));

    // Snimanje slike u galeriju
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Greška pri snimanju slike!')),
      );
    }
  } catch (e) {
    print('Greška tokom čuvanja slike: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Greška pri čuvanju slike!')),
    );
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ESP32 Camera Control',
        style:TextStyle(color: Colors.white)),
        
        backgroundColor: Colors.deepPurple
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Okvir (pravougaonik) koji je uvek prisutan
            Container(
              width: 320, // Širina okvira
              height: 242, // Visina okvira
              decoration: BoxDecoration(
                color: Colors.black, // Boja pozadine
                border: Border.all(
                  color: Colors.deepPurple, // Boja ivica
                  width: 3.0, // Debljina ivica
                ),
                borderRadius: BorderRadius.circular(5.0), 
              // Zaobljeni uglovi
              ),
              child: Center(
                child: _isLoading
                    ? const CircularProgressIndicator() // Prikaz indikatora učitavanja
                    : (_imageBytes != null
                        ? Image.memory(_imageBytes!) // Prikaz slike
                        : const Text('No content available.',
                        style: TextStyle(color: Colors.white))), // Tekst ako nema slike
              ),  
            ),
            const SizedBox(height: 20), // Razmak ispod okvira

            // Dugme za hvatanje slike
            ElevatedButton(
              onPressed: _captureStillImage,
              child: const Text('Get Still'),
            ),

            // Dugme za čuvanje slike sa GPS lokacijom
            if (_imageCaptured)
              ElevatedButton(
                onPressed: () => _saveImageWithLocation(_imageBytes!),
                child: const Text('Save Image'),
              ),

            // Dugme za pokretanje MJPEG strima
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => StreamScreen(),
                  ),
                );
              },
              child: const Text('Start Stream'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MapScreen(),
                  ),
                );
              },
              child: const Text('Open Map'),
            ),
          ],
        ),
      ),
    );
  }
}

class StreamScreen extends StatelessWidget {
  const StreamScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ESP32 Stream'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Mjpeg(
            stream: 'http://192.168.0.21:81/stream',
            isLive: true,
          ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Back'),
            ),
          ],
        ),
      ),
    );
  }
}