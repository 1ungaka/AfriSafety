import 'package:afrisafety/features/circles/presentation/join_circle_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String format(String input) => InviteCodeFormatter()
      .formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: input))
      .text;

  test('groups as XXXXX-XXXXX while typing', () {
    expect(format('k7q2m'), 'K7Q2M');
    expect(format('k7q2m9'), 'K7Q2M-9');
    expect(format('k7q2m9xw4p'), 'K7Q2M-9XW4P');
  });

  test('normalises look-alike characters like the server (Crockford)', () {
    expect(format('OIL'), '011');
    expect(InviteCodeFormatter.normalise('k7q2m 9xw4p'), 'K7Q2M9XW4P');
  });

  test('caps the length at 10 characters', () {
    expect(format('ABCDEFGHJKMNP'), 'ABCDE-FGHJK');
  });
}
