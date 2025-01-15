class PhotoInfo {
  final double latitude;
  final double longitude;
  final String imagePath;

  PhotoInfo({
    required this.latitude,
    required this.longitude,
    required this.imagePath,
  });

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'imagePath': imagePath,
    };
  }

  static PhotoInfo fromMap(Map<String, dynamic> map) {
    return PhotoInfo(
      latitude: map['latitude'],
      longitude: map['longitude'],
      imagePath: map['imagePath'],
    );
  }
}