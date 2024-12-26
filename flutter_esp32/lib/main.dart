import 'dart:typed_data'; // Za rad sa bajtovima
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async'; // Za otkazivanje operacija
import 'package:geolocator/geolocator.dart'; // Za lokaciju
import 'package:image_gallery_saver/image_gallery_saver.dart'; // Za snimanje u galeriju

void main() {
  runApp(MyApp());
}

class CameraControl {
  final String baseHost = 'http://192.168.0.7'; // Zameniti sa stvarnim URL-om

  // Funkcija za uzimanje slike (Get Still)
  Future<Uint8List?> getStill() async {
    final url = Uri.parse('$baseHost/capture?_cb=${DateTime.now().millisecondsSinceEpoch}');
    final response = await http.get(url); // HTTP GET zahtev

    if (response.statusCode == 200) {
      return response.bodyBytes; // Vraća bajtove slike
    } else {
      print('Failed to capture still image');
      return null; // U slučaju greške vraća null
    }
  }

  // Funkcija za pokretanje stream-a
  Future<void> startStream() async {
    final url = Uri.parse('$baseHost:81/stream');  // Proveriti ispravan URL za stream
    final response = await http.get(url);

    if (response.statusCode == 200) {
      print('Stream started');
    } else {
      print('Failed to start stream');
      print('Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}');
    }
  }

  // Funkcija za zaustavljanje stream-a
  Future<void> stopStream() async {
    final url = Uri.parse('$baseHost:81/stop_stream'); // Proveriti URL za zaustavljanje stream-a
    final response = await http.get(url);

    if (response.statusCode == 200) {
      print('Stream stopped');
    } else {
      print('Failed to stop stream');
      print('Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}');
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
  bool _isLoading = false; // Indikator za učitavanje
  Uint8List? _imageBytes; // Promenljiva za čuvanje slike
  bool _imageCaptured = false; // Oznaka da li je slika preuzeta
  bool _isStreaming = false; // Oznaka da li je stream aktivan
  bool _isCanceling = false; // Oznaka da li se operacija otkazuje

  // Funkcija za izvršavanje operacija sa indikatorom učitavanja
  Future<void> executeWithLoading(Future<void> Function() action) async {
    setState(() {
      _isLoading = true; // Početak učitavanja
      _isCanceling = false; // Resetujemo status otkazivanja
    });

    try {
      await action(); // Izvršava akciju
    } catch (e) {
      if (_isCanceling) {
        print('Operacija je otkazana');
      } else {
        print("Greška: $e");
      }
    } finally {
      setState(() {
        _isLoading = false; // Kraj učitavanja
      });
    }
  }

  // Funkcija za preuzimanje slike
  Future<void> _captureStillImage() async {
    if (_isLoading || _isCanceling) return; // Ako je već u toku učitavanje ili operacija se otkazuje

    await executeWithLoading(() async {
      final image = await cameraControl.getStill();
      if (image != null) {
        setState(() {
          _imageBytes = image; // Čuva preuzetu sliku
          _imageCaptured = true; // Obeležava da je slika preuzeta
        });
      } else {
        print('Greška pri preuzimanju slike');
      }
    });
  }

  // Funkcija za snimanje slike u galeriju
  Future<void> _takePhoto() async {
    if (_imageBytes != null) {
      // Snimanje slike u galeriju
      final result = await ImageGallerySaver.saveImage(Uint8List.fromList(_imageBytes!));

      // Dohvatanje trenutne lokacije
      Position position = await _getCurrentLocation();

      if (result['isSuccess']) {
        print('Slika uspešno sačuvana!');
         ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Slika je uspešno sačuvana u galeriji!'),
            duration: Duration(seconds: 2),
          ),
        );
        // Sačuvaj informacije o lokaciji sa slikom (ako je potrebno)
        print('Lokacija: Latitude: ${position.latitude}, Longitude: ${position.longitude}');
      } else {
        print('Greška pri snimanju slike!');
      }
    }
  }

  // Funkcija za dobijanje trenutne lokacije
  Future<Position> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Provera da li je omogućena lokacija
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Lokacijske usluge nisu omogućene');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Dozvola za lokaciju je odbijena');
      }
    }

    // Dobijanje trenutne lokacije
    return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  }

  // Funkcija za pokretanje stream-a
  Future<void> _startStream() async {
    if (_isLoading || _isStreaming || _isCanceling) return; // Ako je već u toku učitavanje ili stream je aktivan

    await executeWithLoading(() async {
      await cameraControl.startStream();
      setState(() {
        _isStreaming = true; // Postavlja status stream-a na aktivan
      });
    });
  }

  // Funkcija za zaustavljanje stream-a i otkazivanje operacija
  Future<void> _stopStream() async {
    if (_isLoading || !_isStreaming || _isCanceling) return; // Ako nije aktivan stream ili je otkazivanje u toku

    setState(() {
      _isCanceling = true; // Postavlja status otkazivanja
      _isLoading = true; // Pokreće indikator učitavanja dok se zaustavlja stream
    });

    try {
      await cameraControl.stopStream(); // Zaustavljanje stream-a
      setState(() {
        _isStreaming = false; // Postavlja status stream-a na neaktivan
      });
    } catch (e) {
      print("Greška pri zaustavljanju stream-a: $e");
    } finally {
      setState(() {
        _isCanceling = false; // Završava otkazivanje
        _isLoading = false; // Kraj učitavanja
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
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
            // Prikaz slike ako postoji
            if (_imageBytes != null) ...[
              Image.memory(_imageBytes!), // Prikazivanje preuzete slike
              SizedBox(height: 20),
            ],

            // Prikazivanje indikatora učitavanja ako je _isLoading true
            if (_isLoading) ...[
              CircularProgressIndicator(), // Indikator učitavanja
              SizedBox(height: 20),
            ],

            // Dugme za preuzimanje slike
            ElevatedButton(
              onPressed: _captureStillImage, // Klik za preuzimanje slike
              child: Text('Get Still'),
            ),
            
            // Dugme za snimanje slike sa lokacijom
            if (_imageCaptured) ...[
              ElevatedButton(
                onPressed: _takePhoto, // Sačuvaj sliku u galeriji sa lokacijom
                child: Text('Take a Photo'),
              ),
            ],

            // Dugme za pokretanje stream-a, prikazuje se samo nakon što je slika preuzeta
            if (_imageCaptured && !_isStreaming) ...[
              ElevatedButton(
                onPressed: _startStream, // Pokretanje stream-a
                child: Text('Start Stream'),
              ),
            ],

            // Dugme za zaustavljanje stream-a, prikazuje se čak i kada se učitava
            if (_isStreaming || _isLoading) ...[
              ElevatedButton(
                onPressed: _stopStream, // Zaustavljanje stream-a
                child: Text('Stop Stream'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}