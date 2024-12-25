import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(MyApp());
}

class CameraControl {
  final String baseHost = 'http://192.168.0.7'; // Zameniti sa stvarnim URL-om

  // Funkcija za slanje POST zahteva za promenu konfiguracije
  Future<void> updateConfig(String configId, dynamic value) async {
    final url = Uri.parse('$baseHost/update_config');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'config': configId,
        'value': value,
      }),
    );
    if (response.statusCode == 200) {
      print('Configuration updated: ${response.body}');
    } else {
      print('Failed to update configuration');
    }
  }

  // Funkcija za uzimanje slike (Get Still)
  Future<void> getStill() async {
    final url = Uri.parse('$baseHost/capture?_cb=${DateTime.now().millisecondsSinceEpoch}');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      print('Still image captured');
    } else {
      print('Failed to capture still image');
    }
  }

  // Funkcija za pokretanje stream-a
  Future<void> startStream() async {
    final url = Uri.parse('$baseHost/stream');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      print('Stream started');
    } else {
      print('Failed to start stream');
    }
  }

  // Funkcija za zaustavljanje stream-a
  Future<void> stopStream() async {
    final url = Uri.parse('$baseHost/stop_stream');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      print('Stream stopped');
    } else {
      print('Failed to stop stream');
    }
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
            // Dugme za uzimanje statične slike
            ElevatedButton(
              onPressed: () async {
                await cameraControl.getStill(); // Uzimanje statične slike
              },
              child: Text('Get Still'),
            ),
            // Dugme za pokretanje stream-a
            ElevatedButton(
              onPressed: () async {
                await cameraControl.startStream(); // Pokretanje stream-a
              },
              child: Text('Start Stream'),
            ),
            // Dugme za zaustavljanje stream-a
            ElevatedButton(
              onPressed: () async {
                await cameraControl.stopStream(); // Zaustavljanje stream-a
              },
              child: Text('Stop Stream'),
            ),
            // Dugme za promenu konfiguracije (AEC primer)
            ElevatedButton(
              onPressed: () async {
                await cameraControl.updateConfig('aec', true); // Primer promene konfiguracije
              },
              child: Text('Enable AEC'),
            ),
            // Dugme za kontrolu drugih funkcija (AWB, Exposure, itd.)
            ElevatedButton(
              onPressed: () async {
                await cameraControl.updateConfig('awb_gain', true); // Primer promene konfiguracije
              },
              child: Text('Enable AWB'),
            ),
            // Dugme za kontrolu detekcije lica
            ElevatedButton(
              onPressed: () async {
                await cameraControl.updateConfig('face_detect', true); // Aktivacija detekcije lica
              },
              child: Text('Enable Face Detect'),
            ),
          ],
        ),
      ),
    );
  }
}