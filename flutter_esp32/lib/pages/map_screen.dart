import 'dart:io'; // Rad sa fajlovima
import 'package:flutter/material.dart';
import 'package:flutter_esp32/main.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:custom_info_window/custom_info_window.dart';
import 'package:photo_manager/photo_manager.dart'; // Rad sa galerijom

class MapScreen extends StatefulWidget {
  final List<PhotoInfo> photos;

  const MapScreen({Key? key, required this.photos}) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late gmaps.GoogleMapController mapController;
  final gmaps.LatLng _initialPosition = const gmaps.LatLng(45.2517, 19.8369);
  Set<gmaps.Marker> _markers = {};

  // CustomInfoWindowController za prikaz prilagođenih info prozora
  final CustomInfoWindowController _customInfoWindowController =
      CustomInfoWindowController();

  @override
  void initState() {
    super.initState();
    _loadMarkers();
  }

  // Učitavanje markera
  void _loadMarkers() {
    for (var photo in widget.photos) {
      _markers.add(
        gmaps.Marker(
          markerId: gmaps.MarkerId(photo.imagePath),
          position: gmaps.LatLng(photo.latitude, photo.longitude),
          onTap: () async {
            final imageFile = await _getImageFile(photo.imagePath);
            if (imageFile != null) {
              _customInfoWindowController.addInfoWindow!(
                Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(8),
                        ),
                        child: Image.file(
                          imageFile,
                          width: 150,
                          height: 100,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          'Lokacija slike',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                gmaps.LatLng(photo.latitude, photo.longitude),
              );
            }
          },
        ),
      );
    }
  }

  // Preuzimanje fajla sa slike koristeći njen ID iz galerije
  Future<File?> _getImageFile(String imagePath) async {
    try {
      final assetEntity = await AssetEntity.fromId(imagePath);
      if (assetEntity != null) {
        final file = await assetEntity.file;
        return file;
      }
    } catch (e) {
      print('Greška pri učitavanju slike: $e');
    }
    return null;
  }

  @override
  void dispose() {
    _customInfoWindowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Photo Location', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.deepPurple,
      ),
      body: Stack(
        children: [
          gmaps.GoogleMap(
            initialCameraPosition: gmaps.CameraPosition(
              target: _initialPosition,
              zoom: 10,
            ),
            markers: _markers,
            onMapCreated: (gmaps.GoogleMapController controller) {
              mapController = controller;
              _customInfoWindowController.googleMapController = controller;
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
          ),
          CustomInfoWindow(
            controller: _customInfoWindowController,
            height: 150,
            width: 150,
            offset: 50,
          ),
        ],
      ),
    );
  }
}