import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_esp32/main.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:custom_info_window/custom_info_window.dart';
import 'package:photo_manager/photo_manager.dart';

class MapScreen extends StatefulWidget {
  final List<PhotoInfo> photos;
  const MapScreen({super.key, required this.photos});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  gmaps.BitmapDescriptor markerIcon = gmaps.BitmapDescriptor.defaultMarker;

  late gmaps.GoogleMapController mapController;
  final Set<gmaps.Marker> _markers = {};
  final CustomInfoWindowController _customInfoWindowController =
      CustomInfoWindowController();

  Map<String, List<PhotoInfo>> photosByLocation = {};
  Map<String, int> currentPhotoIndex = {}; // Track which photo is displayed per location

  @override
  void initState() {
    super.initState();
    _groupPhotosByLocation();
    addCustomIcon();
  }

  void _groupPhotosByLocation() {
    photosByLocation.clear();
    for (var photo in widget.photos) {
      final key = '${photo.latitude},${photo.longitude}';
      if (!photosByLocation.containsKey(key)) {
        photosByLocation[key] = [];
      }
      photosByLocation[key]!.add(photo);
    }

    // Sort each list so latest photo is first
    photosByLocation.forEach((key, photos) {
      photos.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      currentPhotoIndex[key] = 0;
    });
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
      logger.e("Error loading marker icon: $e");
    });
  }

  Future<File?> _getImageFile(String imagePath) async {
    final assetEntity = await AssetEntity.fromId(imagePath);
    final file = await assetEntity?.file;

    if (file == null || !(await file.exists()) || (await file.length()) == 0) {
      logger.e("Invalid image file: $imagePath");
      return null;
    }
    return file;
  }

  void _loadMarkers() {
    setState(() {
      _markers.clear();

      photosByLocation.forEach((key, photosAtLocation) {
        final latestPhoto = photosAtLocation[currentPhotoIndex[key]!];

        _markers.add(
          gmaps.Marker(
            markerId: gmaps.MarkerId(key),
            position: gmaps.LatLng(latestPhoto.latitude, latestPhoto.longitude),
            onTap: () => _showInfoWindowForLocation(key),
            icon: markerIcon,
          ),
        );
      });
    });
  }

  void _showInfoWindowForLocation(String key) async {
    final photosAtLocation = photosByLocation[key]!;
    int index = currentPhotoIndex[key]!;

    final imageFile = await _getImageFile(photosAtLocation[index].imagePath);

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
            // Image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: imageFile != null
                  ? Image.file(
                      imageFile,
                      width: 200,
                      height: 150,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.broken_image, size: 50, color: Colors.grey),
                    )
                  : const Icon(Icons.broken_image, size: 50, color: Colors.grey),
            ),

            // Timestamp
            const SizedBox(height: 6),

          // Timestamp with arrows
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Left arrow
              IconButton(
                icon: const Icon(Icons.arrow_left),
                onPressed: () {
                  setState(() {
                    currentPhotoIndex[key] =
                        (currentPhotoIndex[key]! - 1 + photosAtLocation.length) %
                            photosAtLocation.length;
                  });
                  _showInfoWindowForLocation(key);
                },
              ),

              // Timestamp
              Expanded(
                child: Text(
                  '${photosAtLocation[index].timestamp.day}/${photosAtLocation[index].timestamp.month}/${photosAtLocation[index].timestamp.year}\n'
                  '${photosAtLocation[index].timestamp.hour}:${photosAtLocation[index].timestamp.minute}:${photosAtLocation[index].timestamp.second}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15),
                ),
              ),

              // Right arrow
              IconButton(
                icon: const Icon(Icons.arrow_right),
                onPressed: () {
                  setState(() {
                    currentPhotoIndex[key] =
                        (currentPhotoIndex[key]! + 1) % photosAtLocation.length;
                  });
                  _showInfoWindowForLocation(key);
                },
              ),
            ],
          ),

          const SizedBox(height: 6),

          // Delete + Close buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Delete
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: ElevatedButton(
                  onPressed: () => _showDeleteConfirmation(photosAtLocation[index]),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Delete',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),

              // Close
              ElevatedButton(
                onPressed: () => _customInfoWindowController.hideInfoWindow!(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Close',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
        ],
      ),
    ),
    gmaps.LatLng(photosAtLocation[index].latitude, photosAtLocation[index].longitude),
  );
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
      widget.photos.remove(photo);
      _groupPhotosByLocation();
      _loadMarkers();
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
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          gmaps.GoogleMap(
            initialCameraPosition: gmaps.CameraPosition(
              target: widget.photos.isNotEmpty
                  ? gmaps.LatLng(widget.photos.first.latitude, widget.photos.first.longitude)
                  : const gmaps.LatLng(45.2517, 19.8369),
              zoom: 10,
            ),
            markers: _markers,
            myLocationButtonEnabled: false,
            onMapCreated: (controller) {
              mapController = controller;
              _customInfoWindowController.googleMapController = controller;
            },
          ),
          CustomInfoWindow(
            controller: _customInfoWindowController,
            height: 268,
            width: 200,
            offset: 50,
          ),
        ],
      ),
    );
  }
}