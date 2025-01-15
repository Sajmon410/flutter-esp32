import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_esp32/main.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:custom_info_window/custom_info_window.dart';
import 'package:photo_manager/photo_manager.dart';

class MapScreen extends StatefulWidget {
  final List<PhotoInfo> photos;

  const MapScreen({Key? key, required this.photos}) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  gmaps.BitmapDescriptor markerIcon = gmaps.BitmapDescriptor.defaultMarker;

@override
  void initState() {
    super.initState();
    addCustomIcon();  // Pozivamo funkciju za dodavanje custom ikone
    _loadMarkers();
  }
void addCustomIcon() {
  gmaps.BitmapDescriptor.fromAssetImage(
    ImageConfiguration(devicePixelRatio: 2.5),
    "assets/gps.png",
  ).then((icon) {
    setState(() {
      markerIcon = icon;
    });
    print("Custom marker icon loaded successfully");
  }).catchError((e) {
    print("Error loading marker icon: $e");
  });
}

  late gmaps.GoogleMapController mapController;
  final gmaps.LatLng _initialPosition = const gmaps.LatLng(45.2517, 19.8369);
  Set<gmaps.Marker> _markers = {};
  final CustomInfoWindowController _customInfoWindowController =
      CustomInfoWindowController();

  

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
                  width: 200,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 6,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(12),
                        ),
                        child: Image.file(
                          imageFile,
                          width: 200,
                          height: 100,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          children: [
                            Center(
                              child: Text(
                                photo.imagePath,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            ElevatedButton(
                              onPressed: () {
                                _customInfoWindowController.hideInfoWindow!();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Info window closed'),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.deepPurple,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text('Close',
                              style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                gmaps.LatLng(photo.latitude, photo.longitude),
              );
            }
          },
          icon: markerIcon,  // Koristimo custom ikonu ovde
        ),
      );
    }
  }

  Future<File?> _getImageFile(String imagePath) async {
    final assetEntity = await AssetEntity.fromId(imagePath);
    return assetEntity?.file;
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
            initialCameraPosition: gmaps.CameraPosition(target: _initialPosition, zoom: 10),
            markers: _markers,
            onMapCreated: (controller) {
              mapController = controller;
              _customInfoWindowController.googleMapController = controller;
            },
          ),
          CustomInfoWindow(
            controller: _customInfoWindowController,
            height: 200,
            width: 200,
            offset: 50,
          ),
        ],
      ),
    );
  }
}