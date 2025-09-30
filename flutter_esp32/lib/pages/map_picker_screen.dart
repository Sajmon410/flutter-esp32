// map_picker_screen.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapPickerScreen extends StatefulWidget {
  const MapPickerScreen({super.key});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  GoogleMapController? mapController;

  // Example ESP32 cameras with unique IDs and locations
  final List<Map<String, dynamic>> esp32Cameras = [
    {"id": "cam1", "name": "ESP32 Cam 1", "lat": 44.8176, "lng": 20.4569},
    {"id": "cam2", "name": "ESP32 Cam 2", "lat": 44.8200, "lng": 20.4600},
    {"id": "cam3", "name": "ESP32 Cam 3", "lat": 44.8150, "lng": 20.4500},
  ];

  Set<Marker> getMarkers() {
    return esp32Cameras.map((cam) {
      return Marker(
        markerId: MarkerId(cam["id"]),
        position: LatLng(cam["lat"], cam["lng"]),
        infoWindow: InfoWindow(
          title: cam["name"],
          onTap: () {
            // Return selected camera back to previous screen
            Navigator.pop(context, cam);
          },
        ),
      );
    }).toSet();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Pick Camera on Map"),
      ),
      body: GoogleMap(
        onMapCreated: (controller) {
          mapController = controller;
        },
        initialCameraPosition: const CameraPosition(
          target: LatLng(44.8176, 20.4569), // default location
          zoom: 14,
        ),
        markers: getMarkers(),
      ),
    );
  }
}