import 'dart:async'; // Tajmeri
import 'package:flutter/material.dart'; // Osnovni UI elementi
import 'package:google_maps_flutter/google_maps_flutter.dart'; // Google mape
import 'package:location/location.dart'; // GPS lokacija

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MapScreen(),
    );
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late GoogleMapController mapController; // Kontroler za mapu
  final Location _location = Location(); // GPS lokacija
  bool _isLocationSet = false; // Status postavljanja lokacije

  // Početna koordinata - Beograd
  final LatLng _initialPosition = const LatLng(44.7866, 20.4489);

  // Funkcija za preuzimanje trenutne GPS lokacije
  Future<void> _getCurrentLocation() async {
    try {
      // Dohvati trenutnu lokaciju
      final LocationData currentLocation = await _location.getLocation();

      // Postavi kameru na trenutnu lokaciju
      mapController.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(currentLocation.latitude!, currentLocation.longitude!),
          14.0,
        ),
      );

      // Obeleži da je lokacija postavljena
      setState(() {
        _isLocationSet = true;
      });
    } catch (e) {
      print('Greška pri preuzimanju lokacije: $e');
    }
  }

  // Funkcija koja se poziva kada se mapa kreira
  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;

    // Postavi kameru na početnu poziciju nakon kreiranja
    WidgetsBinding.instance.addPostFrameCallback((_) {
      mapController.animateCamera(
        CameraUpdate.newLatLngZoom(
          _initialPosition,
          14.0,
        ),
      );
    });

    // Pozovi funkciju za preuzimanje trenutne lokacije
    _getCurrentLocation();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Google Map',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.deepPurple,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.of(context).pop(); // Dugme za povratak
          },
        ),
      ),
      body: GoogleMap(
        key: const ValueKey('google_map'), // Ključ za prepoznavanje widgeta
        onMapCreated: _onMapCreated,
        initialCameraPosition: CameraPosition(
          target: _initialPosition, // Početna pozicija Beograd
          zoom: 10.0, // Početno zumiranje
        ),
        myLocationEnabled: true, // Prikaz trenutne lokacije korisnika
        zoomControlsEnabled: true, // Kontrole za zumiranje
        zoomGesturesEnabled: true, // Zumiranje prstima
        mapType: MapType.normal, // Normalna mapa

        // Uklonjena opcija za default dugme
        myLocationButtonEnabled: false,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Ručno osvežavanje GPS lokacije
          _getCurrentLocation();
        },
        backgroundColor: Colors.deepPurple,
        child: const Icon(Icons.location_searching, color: Colors.white),
      ),
    );
  }
}