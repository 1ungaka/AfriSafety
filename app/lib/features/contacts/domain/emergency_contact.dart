/// Someone without the app who should get an SOS text. Stored only in this
/// phone's encrypted vault; the server never sees these numbers.
class EmergencyContact {
  const EmergencyContact({
    required this.id,
    required this.name,
    required this.phone,
    required this.consentedAt,
  });

  final String id;
  final String name;

  /// E.164, e.g. +27821234567.
  final String phone;

  /// When the user confirmed this person agreed to receive emergency texts
  /// (POPIA: their number is their personal information).
  final DateTime consentedAt;

  static const maxContacts = 5;

  Map<String, Object> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'consent': consentedAt.toUtc().toIso8601String(),
  };

  static EmergencyContact fromJson(Map<String, dynamic> j) => EmergencyContact(
    id: j['id'] as String,
    name: j['name'] as String,
    phone: j['phone'] as String,
    consentedAt: DateTime.parse(j['consent'] as String),
  );

  @override
  String toString() => 'EmergencyContact($id, redacted)';
}

/// Normalises a phone number to E.164, treating local numbers as South
/// African (`082 123 4567` → `+27821234567`). Returns null if it doesn't
/// look like a phone number.
String? normalisePhone(String input) {
  var s = input.replaceAll(RegExp(r'[\s\-().]'), '');
  if (s.startsWith('00')) s = '+${s.substring(2)}';
  if (s.startsWith('0')) s = '+27${s.substring(1)}';
  if (!RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(s)) return null;
  // South African numbers have 9 digits after +27.
  if (s.startsWith('+27') && s.length != 12) return null;
  return s;
}
