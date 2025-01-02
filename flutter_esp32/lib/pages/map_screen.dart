import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';

void main() => runApp(const MapScreen());

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late GoogleMapController mapController;
  late LocationData _currentLocation;
  final Location _location = Location();

  // Beograd koordinata
  final LatLng _center = const LatLng(44.7866, 20.4489);

  // Funkcija za čitanje GPS lokacije
  Future<void> _getCurrentLocation() async {
    try {
      final LocationData currentLocation = await _location.getLocation();
      setState(() {
        _currentLocation = currentLocation;
      });

      // Pomeranje kamere na trenutnu lokaciju
      mapController.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(currentLocation.latitude!, currentLocation.longitude!),
          14.0,
        ),
      );
    } catch (e) {
      print('Error getting location: $e');
    }
  }

  // OnMapCreated funkcija
  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
    _getCurrentLocation(); // Pozivanje GPS lokacije čim se mapa kreira
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
       debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Google Map'),
          backgroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () {
              Navigator.of(context).pop(); // Dodavanje back dugmeta
            },
          ),
        ),
        body: GoogleMap(
          onMapCreated: _onMapCreated,
          initialCameraPosition: CameraPosition(
            target: _center, // Početna pozicija Beograd
            zoom: 10.0,
          ),
          myLocationEnabled: true, // Omogućava prikaz trenutne lokacije korisnika
          myLocationButtonEnabled: true, // Omogućava dugme za pretragu trenutne lokacije
        ),
      ),
    );
  }
}