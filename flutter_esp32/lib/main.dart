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
import 'package:logger/logger.dart';

final Logger logger = Logger();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  //ovde se od komentarise funkcija za brisanje baze pri potrebi
  //await deleteDatabaseFile();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: CameraScreen(),
    );
  }
}

class CameraControl {
  final String baseHost = 'http://esp32.local';
  Future<Uint8List?> getStill() async {
    final url = Uri.parse('$baseHost/capture?_cb=${DateTime.now().millisecondsSinceEpoch}');
    try {
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        logger.d('HTTP Error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      logger.e('Error: $e');
      return null;
    }
  }
}

//model za cuvanje podataka o slici
class PhotoInfo {
  final double latitude;
  final double longitude;
  final String imagePath;
  final DateTime timestamp;

  PhotoInfo({required this.latitude, required this.longitude, required this.imagePath, required this.timestamp,});

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'imagePath': imagePath,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  static PhotoInfo fromMap(Map<String, dynamic> map) {
    return PhotoInfo(
      latitude: map['latitude'],
      longitude: map['longitude'],
      imagePath: map['imagePath'],
      timestamp: DateTime.parse(map['timestamp']),
    );
  }
}

//funkcije za rad sa bazom
Future<Database> initializeDatabase() async {
  final dbPath = await getDatabasesPath();
  return openDatabase(
    p.join(dbPath, 'photos.db'),
    onCreate: (db, version) {
      return db.execute(
        'CREATE TABLE photos(id INTEGER PRIMARY KEY, latitude REAL, longitude REAL, imagePath TEXT, timestamp TEXT)',
      );
    },
    version: 1,
  );
}

Future<void> deletePhotoFromDatabase(String imagePath) async{
  final db = await initializeDatabase();
  await db.delete(
    'photos',
    where: 'imagePath = ?',
    whereArgs : [imagePath],
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
Uint8List? safeDecode(Uint8List bytes) {
  try {
    img.decodeImage(bytes); // samo pokušava da dekodira
    return bytes; // vraća samo ako je dekodiranje uspelo
  } catch (_) {
    return null; // preskače loše frejmove
  }
}
//funkcija za brisanje cele baze
Future<void> deleteDatabaseFile()async{
  final dbPath = await getDatabasesPath();
  final path = p.join(dbPath, 'photos.db');

  final databaseExists = await databaseFactory.databaseExists(path);
  if (databaseExists){
    await deleteDatabase(path);
    logger.d("Data Base Deletet Succesfully: $path");
  }else{
    logger.d("Data Base doesn't exists: $path");
  }
}

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
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
        logger.e('Error with image.');
      }
    } catch (e) {
      logger.e("Error: $e");
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
      final AssetEntity result = await PhotoManager.editor.saveImage(
        encodedImage,
        filename: 'moja_slika_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      final newPhoto = PhotoInfo(
        latitude: latitude,
        longitude: longitude,
        imagePath: result.id,
        timestamp: DateTime.now(),
      );
      await savePhotoToDatabase(newPhoto);
      setState(() {
        photos.add(newPhoto);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo saved to Gallery and added to Map!')),
        );
      }
        } catch (e) {
      logger.e('Greška: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error while taking image.')),
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
            // prikaz MJPEG strima ili slike
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
                      error: (context, error, stackTrace) {
                        debugPrint("Stream error: $error");
                        return const SizedBox.shrink();
                      },
                    )
                  : _imageBytes != null && safeDecode(_imageBytes!) != null
                      ? Image.memory(_imageBytes!,gaplessPlayback: true,) //prikaz slike
                      : const Center(
                          child: Text(
                            'No content available.\n  Click Start Stream!',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
            ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                onPressed: () {
                setState(() {
                  _isStreaming = !_isStreaming; // prekidac za strim
                  _imageCaptured = false; // resetuje kada se strim prekine
                });
              },
              child: Text(_isStreaming ? 'Stop Stream' : 'Start Stream'),
            ),
            // prikaz indikatora ucitavanja ako je potrebno
            if (_isStreaming && _isLoading)
              const CircularProgressIndicator()
            else
              ElevatedButton(
                onPressed: _isStreaming ? _captureFromStream : null, // dugme vidljivo ali disabled ako strim nije aktivan
                child: const Text('Take Photo'),
              ),

            // dugme za cuvanje slike sa lokacijom (vidljivo ali disabled ako nema slike ili ako strim nije aktivan)
            ElevatedButton(
              onPressed: (_isStreaming && _imageCaptured) ? () => _saveImageWithLocation(_imageBytes!) : null, 
              child: const Text('Save Image'),
            ),

            // Dugme za otvaranje mape
            ElevatedButton(
              onPressed: () {
                 setState(() {
                _isStreaming = false; // prekidac za strim
                _imageCaptured = false; // resetuje kada se strim prekine
              });
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