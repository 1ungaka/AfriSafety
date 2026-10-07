import 'package:afrisafety/core/widgets/map_attribution.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('detects MapTiler tiles by host', () {
    expect(
      MapAttribution.usesMapTiler(
        'https://api.maptiler.com/maps/streets-v2/256/{z}/{x}/{y}.png?key=k',
      ),
      isTrue,
    );
    expect(
      MapAttribution.usesMapTiler(
        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      ),
      isFalse,
    );
    // A look-alike host must not count (the credit follows the real source).
    expect(
      MapAttribution.usesMapTiler(
        'https://maptiler.com.example.org/{z}/{x}/{y}',
      ),
      isFalse,
    );
    expect(MapAttribution.usesMapTiler(''), isFalse);
  });
}
