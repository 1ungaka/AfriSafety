import 'package:afrisafety/core/geo/grid.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('snaps to the 0.01° square containing the point', () {
    // Johannesburg CBD (southern, eastern hemisphere: floor goes "down").
    final c = GridCell.at(-26.2041, 28.0473);
    expect(c, const GridCell(-2621, 2804));
    expect(c.south, closeTo(-26.21, 1e-9));
    expect(c.north, closeTo(-26.20, 1e-9));
    expect(-26.2041, inInclusiveRange(c.south, c.north));
    expect(28.0473, inInclusiveRange(c.west, c.east));
  });

  test('points a few metres apart in the same square snap alike', () {
    expect(GridCell.at(-26.2041, 28.0473), GridCell.at(-26.2049, 28.0479));
  });

  test('neighbours are the 8 squares around', () {
    const me = GridCell(-2621, 2804);
    expect(me.isNear(const GridCell(-2620, 2805)), isTrue);
    expect(me.isNear(const GridCell(-2619, 2804)), isFalse);
  });

  test('time is reduced to a 4-hour block', () {
    expect(periodOfDay(DateTime(2026, 10, 8, 0, 30)), 0);
    expect(periodOfDay(DateTime(2026, 10, 8, 13, 59)), 3);
    expect(periodOfDay(DateTime(2026, 10, 8, 23, 59)), 5);
  });

  test('toString does not leak the square', () {
    expect(const GridCell(-2621, 2804).toString(), isNot(contains('2621')));
  });
}
