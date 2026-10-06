import 'package:afrisafety/features/contacts/domain/emergency_contact.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('South African local numbers become +27', () {
    expect(normalisePhone('082 123 4567'), '+27821234567');
    expect(normalisePhone('(082) 123-4567'), '+27821234567');
    expect(normalisePhone('0027821234567'), '+27821234567');
    expect(normalisePhone('+27 82 123 4567'), '+27821234567');
  });

  test('foreign numbers are kept', () {
    expect(normalisePhone('+44 7700 900123'), '+447700900123');
  });

  test('invalid input is rejected', () {
    expect(normalisePhone(''), isNull);
    expect(normalisePhone('12345'), isNull);
    expect(normalisePhone('082 123 456'), isNull, reason: 'too short for SA');
    expect(normalisePhone('+27 82 123 45678'), isNull);
    expect(normalisePhone('call me'), isNull);
  });
}
