import 'dart:typed_data'; // Rad sa bajtovima
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:photo_manager/photo_manager.dart'; // Rad sa galerijom
import 'package:flutter_vlc_player/flutter_vlc_player.dart'; // VLC Player
import 'dart:io'; // Provera konekcije

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

    // Dodajemo osluškivanje stanja inicijalizacije
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

  // Funkcija za proveru mrežne konekcije
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

  // Funkcija za hvatanje slike
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

  // Funkcija za čuvanje slike
  Future<void> _saveImage(Uint8List imageBytes) async {
    String filename = 'moja_slika_${DateTime.now().millisecondsSinceEpoch}.jpg';

    final result = await PhotoManager.editor.saveImage(imageBytes, filename: filename);
    if (result != null) {
      print('Slika uspešno sačuvana!');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Slika je sačuvana u galeriji!'), duration: Duration(seconds: 2)),
      );
    } else {
      print('Greška pri snimanju slike!');
    }
  }

  // Start/stop stream funkcija
  void _startStopStream() async {
    setState(() {
      _isStreaming = !_isStreaming; // Menja status stream-a
    });

    if (_isStreaming) {
      print('Status inicijalizacije: ${_vlcController.value.isInitialized}');
      print('Trenutni status kontrole: ${_vlcController.value}'); 
      if (_vlcController.value.isInitialized) {
        _vlcController.play(); // Pokreće stream
      } else {
        print('VLC još uvek nije inicijalizovan. Pokušaj ponovo.');
        setState(() {
          _isStreaming = false; // Vraća status
        });
      }
    } else {
      _vlcController.stop(); // Zaustavlja stream
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ESP32 Camera Control'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Prikaz slike
            if (_imageBytes != null) ...[
              Image.memory(_imageBytes!),
              const SizedBox(height: 20),
            ],

            // Prikaz učitavanja
            if (_isLoading) ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
            ],

            // Dugme za hvatanje slike
            ElevatedButton(
              onPressed: _captureStillImage,
              child: const Text('Get Still'),
            ),

            // Dugme za čuvanje slike
            if (_imageCaptured) ...[
              ElevatedButton(
                onPressed: () => _saveImage(_imageBytes!),
                child: const Text('Save Image'),
              ),
            ],

            // Prikaz Live Stream-a
            if (_isStreaming) ...[
              Container(
                height: 300,
                child: VlcPlayer(
                  controller: _vlcController,
                  aspectRatio: 16 / 9,
                  placeholder: const Center(child: CircularProgressIndicator()),
                ),
              ),
            ],

            // Dugme za start/stop stream-a
            ElevatedButton(
              onPressed: _startStopStream,
              child: Text(_isStreaming ? 'Stop Stream' : 'Start Stream'),
            ),
          ],
        ),
      ),
    );
  }
}