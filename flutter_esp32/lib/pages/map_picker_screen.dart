// map_picker_screen.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../main.dart'; // for ESP32Camera class

class MapPickerScreen extends StatelessWidget {
  const MapPickerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<ESP32Camera> cameras = [
    ESP32Camera(id: 'cam1', name: 'ESP32 - Living Room', wsUrl: 'ws://:3000', lat: 44.8176, lng: 20.4569),
    ESP32Camera(id: 'cam2', name: 'ESP32 - Backyard', wsUrl: 'ws://192.168.1.102:3000', lat: 44.8200, lng: 20.4600),
    ESP32Camera(id: 'cam3', name: 'ESP32 - Garage', wsUrl: 'ws://192.168.1.103:3000', lat: 44.8150, lng: 20.4500),
  ];

    return Scaffold(
      appBar: AppBar(title: const Text("Pick Camera")),
      body: GoogleMap(
        initialCameraPosition: const CameraPosition(
          target: LatLng(44.8176, 20.4569),
          zoom: 14,
        ),
        markers: cameras.map((cam) {
          return Marker(
            markerId: MarkerId(cam.id),
            position: LatLng(
              44.8176 + (cameras.indexOf(cam) * 0.002), // fake coords for testing
              20.4569 + (cameras.indexOf(cam) * 0.002),
            ),
            infoWindow: InfoWindow(
              title: cam.name,
              onTap: () {
                Navigator.pop(context, cam);
              },
            ),
          );
        }).toSet(),
      ),
    );
  }
}