/// A saved place ("Home", "Campus"). Stored only in this phone's encrypted
/// vault: other members learn about it only through arrive/leave events
/// that the owner's phone sends.
class Place {
  const Place({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
  });

  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final double radiusMeters;

  static const radiusChoices = [100.0, 200.0, 500.0];
  static const maxNameLength = 40;

  Map<String, Object> toJson() => {
    'id': id,
    'name': name,
    'lat': latitude,
    'lon': longitude,
    'r': radiusMeters,
  };

  static Place fromJson(Map<String, dynamic> j) => Place(
    id: j['id'] as String,
    name: j['name'] as String,
    latitude: (j['lat'] as num).toDouble(),
    longitude: (j['lon'] as num).toDouble(),
    radiusMeters: (j['r'] as num).toDouble(),
  );

  @override
  String toString() => 'Place($id, redacted)';
}
