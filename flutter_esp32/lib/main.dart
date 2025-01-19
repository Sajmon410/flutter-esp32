import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_esp32/pages/map_screen.dart';
import 'package:http/http.dart' as http;
import 'package:photo_manager/photo_manager.dart';
import 'package:location/location.dart' as loc;
import 'package:image/image.dart' as img;
import 'package:flutter_mjpeg/flutter_mjpeg.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
  final String baseHost = 'http://192.168.0.11';

  Future<Uint8List?> getStill() async {
    final url = Uri.parse('$baseHost/capture?_cb=${DateTime.now().millisecondsSinceEpoch}');
    try {
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        print('HTTP Error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error: $e');
      return null;
    }
  }
}

// Model za čuvanje podataka o slici
class PhotoInfo {
  final double latitude;
  final double longitude;
  final String imagePath;

  PhotoInfo({required this.latitude, required this.longitude, required this.imagePath});

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'imagePath': imagePath,
    };
  }

  static PhotoInfo fromMap(Map<String, dynamic> map) {
    return PhotoInfo(
      latitude: map['latitude'],
      longitude: map['longitude'],
      imagePath: map['imagePath'],
    );
  }
}

// Funkcije za rad sa bazom
Future<Database> initializeDatabase() async {
  final dbPath = await getDatabasesPath();
  return openDatabase(
    p.join(dbPath, 'photos.db'),
    onCreate: (db, version) {
      return db.execute(
        'CREATE TABLE photos(id INTEGER PRIMARY KEY, latitude REAL, longitude REAL, imagePath TEXT)',
      );
    },
    version: 1,
  );
}

Future<void> savePhotoToDatabase(PhotoInfo photo) async {
  final db = await initializeDatabase();
  await db.insert('photos', photo.toMap());
}

Future<List<PhotoInfo>> loadPhotosFromDatabase() async {
  final db = await initializeDatabase();
  final maps = await db.query('photos');
  return List.generate(maps.length, (i) {
    return PhotoInfo.fromMap(maps[i]);
  });
}

class CameraScreen extends StatefulWidget {
  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  final CameraControl cameraControl = CameraControl();

  bool _isLoading = false;
  bool _isStreaming = false;
  Uint8List? _imageBytes;
  bool _imageCaptured = false;

  loc.Location location = loc.Location();
  List<PhotoInfo> photos = [];

  @override
  void initState() {
    super.initState();
    _initializePhotos();
  }

  Future<void> _initializePhotos() async {
    final loadedPhotos = await loadPhotosFromDatabase();
    setState(() {
      photos = loadedPhotos;
    });
  }

  Future<void> _captureFromStream() async {
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
        print('Error with image.');
      }
    } catch (e) {
      print("Error: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveImageWithLocation(Uint8List imageBytes) async {
    try {
      final permission = await loc.Location().requestPermission();
      if (permission != loc.PermissionStatus.granted) {
        throw Exception('GPS permissions are not allowed.');
      }

      final loc.LocationData locationData = await location.getLocation();
      final double latitude = locationData.latitude ?? 0.0;
      final double longitude = locationData.longitude ?? 0.0;

      final img.Image? originalImage = img.decodeImage(imageBytes);
      if (originalImage == null) {
        throw Exception('Error while image loading.');
      }

      final Uint8List encodedImage = Uint8List.fromList(img.encodeJpg(originalImage));
      final AssetEntity? result = await PhotoManager.editor.saveImage(
        encodedImage,
        filename: 'moja_slika_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      if (result != null) {
        final newPhoto = PhotoInfo(
          latitude: latitude,
          longitude: longitude,
          imagePath: result.id,
        );
        await savePhotoToDatabase(newPhoto);
        setState(() {
          photos.add(newPhoto);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Photo saved to gallery!')),
          );
        }
      } else {
        throw Exception('Error while downloading image!');
      }
    } catch (e) {
      print('Greška: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error while taking')),
        );
      }
    }
  }

   @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ESP32 Camera Control', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.deepPurple,
      ),
      backgroundColor: Colors.black,
      body: Container(
        color:  Colors.black,
      
      child: Center(
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
                      timeout: const Duration(seconds: 10), // Timeout
                      error: (context, error, stackTrace) =>
                          Text('Stream Error: $error'),
                    )
                  : _imageBytes != null
                      ? Image.memory(_imageBytes!) // Prikaz slike
                      : const Center(
                          child: Text(
                            'No content available.\n  Click Start Stream!',
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
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _captureFromStream,
                    child: const Text('Take Photo'),
                  ),

            // Dugme za čuvanje slike sa lokacijom
            if (_imageCaptured)
              ElevatedButton(
                onPressed: () => _saveImageWithLocation(_imageBytes!),
                child: const Text('Save Image'),
              ),

            // Dugme za otvaranje mape
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MapScreen(photos: photos),
                  ),
                );
              },
              child: const Text('Open Map'),
            ),
          ],
        ),
      ),
    ));
  }
}