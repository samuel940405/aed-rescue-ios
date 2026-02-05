class AedPoint {
  final int? id;
  final String name;
  final String address;
  final String floor;
  final String landmarks; // JSON string
  final double lat;
  final double lng;
  double? distance; // Runtime calculation

  AedPoint({
    this.id,
    required this.name,
    required this.address,
    required this.floor,
    required this.landmarks,
    required this.lat,
    required this.lng,
    this.distance,
  });

  factory AedPoint.fromMap(Map<String, dynamic> map) {
    return AedPoint(
      id: map['id'],
      name: map['name'] ?? 'Unknown AED',
      address: map['address'] ?? '',
      floor: map['floor'] ?? '1F',
      landmarks: map['landmarks'] ?? '[]',
      lat: map['lat'] ?? 0.0,
      lng: map['lng'] ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'floor': floor,
      'landmarks': landmarks,
      'lat': lat,
      'lng': lng,
    };
  }
}
