/// A 0.01° grid square (about 1.1 km north–south, ~1 km east–west in
/// South Africa). Community reports are snapped to one on the phone, so the
/// server never receives a precise location.
class GridCell {
  const GridCell(this.lat, this.lon);

  factory GridCell.at(double latitude, double longitude) => GridCell(
    (latitude * 100).floor().clamp(-9000, 8999),
    (longitude * 100).floor().clamp(-18000, 17999),
  );

  final int lat;
  final int lon;

  double get south => lat / 100;
  double get west => lon / 100;
  double get north => (lat + 1) / 100;
  double get east => (lon + 1) / 100;

  /// This square and the 8 around it.
  bool isNear(GridCell other) =>
      (other.lat - lat).abs() <= 1 && (other.lon - lon).abs() <= 1;

  @override
  bool operator ==(Object other) =>
      other is GridCell && other.lat == lat && other.lon == lon;

  @override
  int get hashCode => Object.hash(lat, lon);

  @override
  String toString() => 'GridCell(redacted)';
}

/// The 4-hour block of the day (0–5) used instead of an exact time.
int periodOfDay(DateTime local) => local.hour ~/ 4;
