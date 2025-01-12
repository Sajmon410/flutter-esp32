import 'package:flutter/material.dart';
import 'package:flutter_esp32/main.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:location/location.dart'; // Paket za rad sa GPS lokacijom

class MapScreen extends StatefulWidget {
  final List<PhotoInfo> photos;

  const MapScreen({Key? key, required this.photos}) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late GoogleMapController mapController;
final LatLng _initialPosition = const LatLng(45.2517, 19.8369);// Beograd
  Set<Marker> _markers = {};

  // Za trenutnu lokaciju
  final Location _location = Location(); // Za dobijanje GPS lokacije
  bool _isLocationSet = false; // Da li je trenutna lokacija postavljena

  @override
  void initState() {
    super.initState();
    _loadMarkers();
    _getCurrentLocation(); // Dohvati trenutnu lokaciju
  }

  // Funkcija za preuzimanje trenutne GPS lokacije
  Future<void> _getCurrentLocation() async {
    try {
      final LocationData currentLocation = await _location.getLocation();
      setState(() {
        _isLocationSet = true;
      });

      // Pomeranje kamere na trenutnu lokaciju
      mapController.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(currentLocation.latitude!, currentLocation.longitude!),
          14.0, // Zoom nivo
        ),
      );
    } catch (e) {
      print('Greška pri preuzimanju lokacije: $e');
    }
  }

  void _loadMarkers() {
    for (var photo in widget.photos) {
      _markers.add(
        Marker(
          markerId: MarkerId(photo.imagePath),
          position: LatLng(photo.latitude, photo.longitude),
          infoWindow: InfoWindow(
            title: 'Slika',
            snippet: 'Kliknite za pregled',
            onTap: () {
              _showImageDialog(photo.imagePath);
            },
          ),
        ),
      );
    }
  }

  void _showImageDialog(String imagePath) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Image.asset(imagePath), // Prikazuje sliku
          actions: [
            TextButton(
              child: const Text('Zatvori'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Photo Location',
        style: TextStyle(color: Colors.white),),
        backgroundColor: Colors.deepPurple,
      ),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: _initialPosition,
          zoom: 10,
        ),
        markers: _markers,
        onMapCreated: (GoogleMapController controller) {
          mapController = controller;
        },
        myLocationEnabled: true, // Omogućava prikaz trenutne lokacije korisnika
        myLocationButtonEnabled: false, // Onemogućava default dugme za lokaciju
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Poziva funkciju za preuzimanje trenutne lokacije
          _getCurrentLocation();
        },
        backgroundColor: Colors.deepPurple,
        child: const Icon(Icons.location_searching, color: Colors.white),
      ),
    );
  }
}