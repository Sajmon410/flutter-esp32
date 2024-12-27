import 'dart:typed_data'; // Za rad sa bajtovima
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:async'; // Za otkazivanje operacija
import 'package:geolocator/geolocator.dart'; // Za lokaciju
import 'package:photo_manager/photo_manager.dart'; // Za rad sa galerijom

// Dodati VLC Player
import 'package:flutter_vlc_player/flutter_vlc_player.dart';

void main() {
  runApp(MyApp());
}

class CameraControl {
  final String baseHost = 'http://192.168.0.7';

  // Funkcija za uzimanje slike (Get Still)
  Future<Uint8List?> getStill() async {
    final url = Uri.parse('$baseHost/capture?_cb=${DateTime.now().millisecondsSinceEpoch}');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      return response.bodyBytes;
    } else {
      print('Failed to capture still image');
      return null;
    }
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: CameraScreen(),
    );
  }
}

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
  bool _isVlcInitialized = false; // Flag za status inicijalizacije VLC kontrolera

  // VLC Controller za stream
  late VlcPlayerController _vlcController;

  @override
  void initState() {
    super.initState();

    // Kreiranje kontrolera sa URL-om za stream
    _vlcController = VlcPlayerController.network(
      'http://192.168.0.7:81/stream', // URL za live stream
      hwAcc: HwAcc.auto, // Hardversko ubrzanje
      autoPlay: false, // Ne automatski start stream-a
    );

    // Dodavanje kašnjenja za inicijalizaciju i proveru statusa
    Future.delayed(Duration(seconds: 5), () {
      if (_vlcController.value.isInitialized) {
        setState(() {
          _isVlcInitialized = true;
        });
        print("VLC je uspešno inicijalizovan!");
      } else {
        print("VLC nije inicijalizovan! Pokušajte ponovo.");
        // Ponovo pokušajte da inicijalizujete
        _initializeVlcController();
      }
    });

    // Listener za greške tokom inicijalizacije
    _vlcController.addListener(() {
      if (!_vlcController.value.isInitialized) {
        print("VLC nije inicijalizovan!");
        print("Greška: ${_vlcController.value.errorDescription}");
      } else {
        print("VLC kontroler je inicijalizovan.");
      }
    });
  }

  void _initializeVlcController() {
    print("Pokušavam ponovo da inicijalizujem VLC kontroler...");
    _vlcController = VlcPlayerController.network(
      'http://192.168.0.7:81/stream', // URL za live stream
      hwAcc: HwAcc.auto, // Hardversko ubrzanje
      autoPlay: false, // Ne automatski start stream-a
    );
    Future.delayed(Duration(seconds: 5), () {
      if (_vlcController.value.isInitialized) {
        setState(() {
          _isVlcInitialized = true;
        });
        print("VLC je uspešno inicijalizovan!");
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

  Future<void> executeWithLoading(Future<void> Function() action) async {
    setState(() {
      _isLoading = true;
    });

    try {
      await action();
    } catch (e) {
      print("Greška: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _captureStillImage() async {
    await executeWithLoading(() async {
      final image = await cameraControl.getStill();
      if (image != null) {
        setState(() {
          _imageBytes = image;
          _imageCaptured = true;
        });
      } else {
        print('Greška pri preuzimanju slike');
      }
    });
  }

  Future<void> _saveImage(Uint8List imageBytes) async {
    String filename = 'moja_slika_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final result = await PhotoManager.editor.saveImage(
      imageBytes,
      filename: filename,
    );

    if (result != null) {
      print('Slika uspešno sačuvana!');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Slika je sačuvana u galeriji!'),
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      print('Greška pri snimanju slike!');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('ESP32 Camera Control'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_imageBytes != null) ...[
              Image.memory(_imageBytes!),
              SizedBox(height: 20),
            ],

            if (_isLoading) ...[
              CircularProgressIndicator(),
              SizedBox(height: 20),
            ],

            ElevatedButton(
              onPressed: _captureStillImage,
              child: Text('Get Still'),
            ),

            if (_imageCaptured) ...[
              ElevatedButton(
                onPressed: () => _saveImage(_imageBytes!),
                child: Text('Save Image'),
              ),
            ],

            // Prikaz Live Stream-a
            if (_isVlcInitialized) ...[
              Container(
                height: 300,
                child: VlcPlayer(
                  controller: _vlcController,
                  aspectRatio: 16 / 9,
                  placeholder: Center(child: CircularProgressIndicator()),
                ),
              ),
            ],

            // Dugme za pokretanje stream-a
            ElevatedButton(
              onPressed: () {
                if (_vlcController.value.isInitialized) {
                  setState(() {
                    _isStreaming = !_isStreaming; // Menja status stream-a
                  });
                  if (_isStreaming) {
                    _vlcController.play();
                    print("Stream pokrenut");
                  } else {
                    _vlcController.stop();
                    print("Stream zaustavljen");
                  }
                } else {
                  print("VLC nije inicijalizovan. Molimo pokušajte ponovo.");
                }
              },
              child: Text(_isStreaming ? 'Stop Stream' : 'Start Stream'),
            ),
          ],
        ),
      ),
    );
  }
}