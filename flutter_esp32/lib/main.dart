import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_esp32/pages/map_picker_screen.dart';
import 'package:flutter_esp32/pages/map_screen.dart';
import 'package:http/http.dart' as http;
import 'package:photo_manager/photo_manager.dart';
// import 'package:location/location.dart' as loc;
import 'package:image/image.dart' as img;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:logger/logger.dart';
import 'package:web_socket_channel/io.dart';

final Logger logger = Logger();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
  final String wsUrl = 'ws://51.20.31.17:3000';

  Future<Uint8List?> getStill() async {
    // Optional HTTP endpoint for snapshot (if your Node.js server supports it)
    final url = Uri.parse('http://51.20.31.17:3000/capture?_cb=${DateTime.now().millisecondsSinceEpoch}');
    try {
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
      logger.d('HTTP Error: ${response.statusCode}');
      return null;
    } catch (e) {
      logger.e('Error: $e');
      return null;
    }
  }
}
class ESP32Camera {
  final String id;
  final String name;
  final String wsUrl;
  final double lat;
  final double lng;

  ESP32Camera({
    required this.id,
    required this.name,
    required this.wsUrl,
    required this.lat,
    required this.lng,
  });
}
// Model for photo data
class PhotoInfo {
  final double latitude;
  final double longitude;
  final String imagePath;
  final DateTime timestamp;

  PhotoInfo({
    required this.latitude,
    required this.longitude,
    required this.imagePath,
    required this.timestamp,
  });


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

// Database functions
Future<Database> initializeDatabase() async {
  final dbPath = await getDatabasesPath();
  return openDatabase(
    p.join(dbPath, 'photos.db'),
    onCreate: (db, version) {
      return db.execute(
          'CREATE TABLE photos(id INTEGER PRIMARY KEY, latitude REAL, longitude REAL, imagePath TEXT, timestamp TEXT)');
    },
    version: 1,
  );
}

Future<void> savePhotoToDatabase(PhotoInfo photo) async {
  final db = await initializeDatabase();
  await db.insert('photos', photo.toMap());
}

Future<void> deletePhotoFromDatabase(String imagePath) async {
  final db = await initializeDatabase();
  await db.delete('photos', where: 'imagePath = ?', whereArgs: [imagePath]);
}

Future<List<PhotoInfo>> loadPhotosFromDatabase() async {
  final db = await initializeDatabase();
  final maps = await db.query('photos');
  return List.generate(maps.length, (i) => PhotoInfo.fromMap(maps[i]));
}

Uint8List? safeDecode(Uint8List bytes) {
  try {
    img.decodeImage(bytes);
    return bytes;
  } catch (_) {
    return null;
  }
}

Future<void> deleteDatabaseFile() async {
  final dbPath = await getDatabasesPath();
  final path = p.join(dbPath, 'photos.db');
  final exists = await databaseFactory.databaseExists(path);
  if (exists) {
    await deleteDatabase(path);
    logger.d("Database deleted successfully: $path");
  } else {
    logger.d("Database doesn't exist: $path");
  }
}

// Camera Screen with WebSocket stream
class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class CameraPickerScreen extends StatelessWidget {
  final List<ESP32Camera> cameras;
  const CameraPickerScreen({super.key, required this.cameras});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Select Camera")),
      body: ListView.builder(
        itemCount: cameras.length,
        itemBuilder: (context, index) {
          final cam = cameras[index];
          return ListTile(
            title: Text(cam.name),
            subtitle: Text(cam.wsUrl),
            onTap: () {
              Navigator.pop(context, cam); // return the selected camera
            },
          );
        },
      ),
    );
  }
}
class _CameraScreenState extends State<CameraScreen> {
  final CameraControl cameraControl = CameraControl();
  // final loc.Location location = loc.Location();
  List<PhotoInfo> photos = [];

  bool _isStreaming = false;
  bool _imageCaptured = false;
  bool _isLoading = false;
  Uint8List? _currentFrame;
  Uint8List? _imageBytes; // <-- new variable to hold the captured image


final List<ESP32Camera> cameras = [
  ESP32Camera(id: 'cam1', name: 'ESP32 - Living Room', wsUrl: 'ws://51.20.31.17:3000', lat: 44.8176, lng: 20.4569),
  ESP32Camera(id: 'cam2', name: 'ESP32 - Backyard', wsUrl: 'ws://192.168.1.102:3000', lat: 44.8200, lng: 20.4600),
  ESP32Camera(id: 'cam3', name: 'ESP32 - Garage', wsUrl: 'ws://192.168.1.103:3000', lat: 44.8150, lng: 20.4500),
];
  ESP32Camera? _selectedCamera;

  late IOWebSocketChannel channel;

  @override
  void initState() {
    super.initState();
    _initializePhotos();
  }

  Future<void> _initializePhotos() async {
    final loadedPhotos = await loadPhotosFromDatabase();
    setState(() => photos = loadedPhotos);
  }

  void _startStream() {
   if (_selectedCamera == null) return;
  channel = IOWebSocketChannel.connect(_selectedCamera!.wsUrl);

    channel.stream.listen((message) {
      if (message is Uint8List) {
        setState(() {
          _currentFrame = message;
          _imageBytes = message;  // <-- now _imageBytes is updated
          _imageCaptured = true;
        });
      }
    }, onError: (error) {
      logger.e("WebSocket error: $error");
    }, onDone: () {
      logger.d("WebSocket closed");
      if (_isStreaming) {
        // Try to reconnect automatically
        Future.delayed(const Duration(seconds: 1), _startStream);
      }
    });
  }

  void _stopStream() {
    _isStreaming = false;
    channel.sink.close();
    setState(() => _currentFrame = null);
  }

  Future<void> _captureFrame() async {
    if (_currentFrame != null) {
      setState(() => _imageCaptured = true);
    } else {
      logger.e('No frame to capture!');
    }
  }

  Future<void> _saveImageAtCamera(Uint8List imageBytes, double latitude, double longitude) async {
  try {
    final img.Image? originalImage = img.decodeImage(imageBytes);
    if (originalImage == null) throw Exception('Error decoding image');

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
    logger.e('Error: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error while saving image.')),
      );
    }
  }
}

  @override
  void dispose() {
    if (_isStreaming) channel.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ESP32 Camera Control', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.deepPurple,
      ),
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
             const SizedBox(height: 20),
              Padding(
              padding: const EdgeInsets.only(bottom: 20.0),
              child: ElevatedButton(
                onPressed: () async {
                  final selectedCam = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MapPickerScreen(),
                    ),
                  );

                  if (selectedCam != null && selectedCam is ESP32Camera) {
                    setState(() {
                      _selectedCamera = selectedCam;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Selected: ${selectedCam.name}')),
                    );
                  }
                },
                child: const Text("Choose Camera"),
              ),
              ),
            Container(
              width: 320,
              height: 242,
              decoration: BoxDecoration(
                color: Colors.black,
                border: Border.all(color: Colors.deepPurple, width: 3),
                borderRadius: BorderRadius.circular(5),
              ),
              child: _currentFrame != null
                  ? Image.memory(
                      _currentFrame!,
                      gaplessPlayback: true,
                      width: 320,
                      height: 242,
                      fit: BoxFit.cover,
                    )
                  : const Center(
                      child: Text(
                        ' No content available.\nSelect the camera and\n   Click Start Stream!',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isStreaming = !_isStreaming;
                  _imageCaptured = false;
                  if (_isStreaming) {
                    _startStream();
                  } else {
                    _stopStream();
                  }
                });
              },
              child: Text(_isStreaming ? 'Stop Stream' : 'Start Stream'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _isStreaming && _currentFrame != null
                  ? () {
                      setState(() {
                        _imageCaptured = true; // mark current frame as captured
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Frame captured!')),
                      );
                    }
                  : null,
              child: const Text('Take Photo'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _imageCaptured && _selectedCamera != null
                  ? () => _saveImageAtCamera(
                        _currentFrame!,
                        _selectedCamera!.lat,
                        _selectedCamera!.lng,
                      )
                  : null,
              child: const Text('Save Image'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isStreaming = false;
                  _imageCaptured = false;
                  _stopStream();
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
    );
  }
}