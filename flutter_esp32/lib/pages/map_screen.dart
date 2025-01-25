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
    addCustomIcon();
    _loadMarkers();
  }

  void addCustomIcon() {
    gmaps.BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(devicePixelRatio: 1.0),
      "assets/gps.png",
    ).then((icon) {
      setState(() {
        markerIcon = icon;
        _loadMarkers();
      });
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
    setState(() {
      
   
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
                          height: 150,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.only(left: 0),
                        child: Column(
                          children: [
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 6.0),
                                child: Text(
                                  '${photo.timestamp.day}/${photo.timestamp.month}/${photo.timestamp.year}\n'
                                  '${photo.timestamp.hour}:${photo.timestamp.minute}:${photo.timestamp.second}',
                                  style: TextStyle(
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ),
                           const SizedBox(height: 4),
                            Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center, // Center the buttons horizontally
                                children: [
                                    Padding(
                                      padding: const EdgeInsets.only(right: 5.0),
                                        child: ElevatedButton(
                                          onPressed: () {
                                            _showDeleteConfirmation(photo);
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.redAccent,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                          ),
                                          child: const Text('Delete',
                                              style: TextStyle(color: Colors.white)),
                                        ),
                                      ),                                
                                  ElevatedButton(
                                    onPressed: () {
                                      _customInfoWindowController.hideInfoWindow!();
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
                    ],
                  ),
                ),
                gmaps.LatLng(photo.latitude, photo.longitude),
              );
            }
          },
          icon: markerIcon,
        ),
      );
    }
     });
  }
  

  Future<File?> _getImageFile(String imagePath) async {
    final assetEntity = await AssetEntity.fromId(imagePath);
    return assetEntity?.file;
  }

  void _showDeleteConfirmation(PhotoInfo photo) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: const Text('Are you sure you want to delete this photo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deletePhoto(photo);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _deletePhoto(PhotoInfo photo) {
    setState(() {
      _markers.removeWhere((marker) => marker.markerId.value == photo.imagePath);
      widget.photos.remove(photo);
    });
    deletePhotoFromDatabase(photo.imagePath);
    _customInfoWindowController.hideInfoWindow!();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Photo deleted successfully.')),
    );
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
            myLocationButtonEnabled: false,
            onMapCreated: (controller) {
              mapController = controller;
              _customInfoWindowController.googleMapController = controller;
            },
          ),
          CustomInfoWindow(
            controller: _customInfoWindowController,
            height: 250,
            width: 200,
            offset: 50,
          ),
        ],
      ),
    );
  }
}
