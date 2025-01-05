import 'dart:typed_data'; // Rad sa bajtovima
import 'package:flutter/material.dart';
import 'package:flutter_esp32/pages/map_screen.dart';
import 'package:http/http.dart' as http;
import 'package:photo_manager/photo_manager.dart'; // Galerija
import 'package:location/location.dart' as loc; // GPS lokacija
import 'package:image/image.dart' as img; // Rad sa slikama
import 'package:flutter_mjpeg/flutter_mjpeg.dart'; // MJPEG paket

void main() {
  runApp(const MyApp());
}

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

// Kamera kontrola
class CameraControl {
  final String baseHost = 'http://192.168.0.21'; // IP adresa ESP32

  // Hvatanje slike
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

class CameraScreen extends StatefulWidget {
  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  final CameraControl cameraControl = CameraControl();

  // Stanja
  bool _isLoading = false; // Indikator učitavanja
  bool _isStreaming = false; // Da li je stream aktivan
  Uint8List? _imageBytes; // Hvatanje slike
  bool _imageCaptured = false;

  loc.Location location = loc.Location(); // GPS lokacija

  @override
  void initState() {
    super.initState();
  }

  // Hvatanje slike sa strima
  Future<void> _captureFromStream() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final image = await cameraControl.getStill(); // Hvata frejm
      if (image != null) {
        setState(() {
          _imageBytes = image;
          _imageCaptured = true;
          _isLoading = false;
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
      // Proveri dozvole
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

      // Snimanje slike
      final Uint8List encodedImage = Uint8List.fromList(img.encodeJpg(originalImage));

      final AssetEntity? result = await PhotoManager.editor.saveImage(
        encodedImage,
        filename: 'slika_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      if (result != null) {
        print('Slika sa GPS lokacijom sačuvana!');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Slika sačuvana!')),
        );
      } else {
        print('Greška pri snimanju slike!');
      }
    } catch (e) {
      print('Greška: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ESP32 Camera Control'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Prikaz MJPEG strima ili slike
            Container(
              width: 320,
              height: 242,
              decoration: BoxDecoration(
                color: Colors.black,
                border: Border.all(
                  color: Colors.deepPurple,
                  width: 3.0,
                ),
                borderRadius: BorderRadius.circular(5.0),
              ),
              child: _isStreaming
                  ? Mjpeg(
                      stream: '${cameraControl.baseHost}:81/stream', // Strim
                      isLive: true,
                    )
                  : _imageBytes != null
                      ? Image.memory(_imageBytes!) // Prikaz slike
                      : const Center(
                          child: Text(
                            'No content available.',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
            ),

            const SizedBox(height: 20), // Razmak

            // Dugme za start streama
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isStreaming = !_isStreaming; // Prekidač za strim
                });
              },
              child: Text(_isStreaming ? 'Stop Stream' : 'Start Stream'),
            ),

            // Dugme za hvatanje frejma sa strima
            ElevatedButton(
              onPressed: _captureFromStream,
              child: const Text('Take Photo'),
            ),

            // Dugme za čuvanje slike sa lokacijom
            if (_imageCaptured)
              ElevatedButton(
                onPressed: () => _saveImageWithLocation(_imageBytes!),
                child: const Text('Save Image'),
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