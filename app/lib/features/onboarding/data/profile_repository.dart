import 'package:supabase_flutter/supabase_flutter.dart';

/// Consents recorded in `public.consents` (POPIA s11).
enum ConsentType { termsPrivacy, locationSharing, age18Plus }

extension ConsentTypeWire on ConsentType {
  String get wire => switch (this) {
    ConsentType.termsPrivacy => 'terms_privacy',
    ConsentType.locationSharing => 'location_sharing',
    ConsentType.age18Plus => 'age_18_plus',
  };
}

/// Bump when docs/privacy-policy.md changes in a way users must re-accept.
const currentPolicyVersion = '1';

class OnboardingStatus {
  const OnboardingStatus({required this.displayName, required this.consents});

  final String? displayName;
  final Set<ConsentType> consents;

  bool get hasProfile => displayName != null;
  bool get hasRequiredConsents => consents.containsAll(ConsentType.values);
  bool get isComplete => hasProfile && hasRequiredConsents;
}

/// Placeholder status before the real one has loaded.
class OnboardingStatusEmpty extends OnboardingStatus {
  const OnboardingStatusEmpty() : super(displayName: null, consents: const {});
}

abstract interface class ProfileRepository {
  Future<OnboardingStatus> status();
  Future<void> saveDisplayName(String name);
  Future<void> recordConsents(Set<ConsentType> consents);
}

class SupabaseProfileRepository implements ProfileRepository {
  SupabaseProfileRepository(this._db);

  final SupabaseClient _db;

  String get _uid => _db.auth.currentUser!.id;

  @override
  Future<OnboardingStatus> status() async {
    final profile = await _db
        .from('profiles')
        .select('display_name')
        .eq('id', _uid)
        .maybeSingle();
    final consents = await _db
        .from('consents')
        .select('consent_type')
        .eq('user_id', _uid)
        .isFilter('revoked_at', null);
    final granted = {for (final c in consents) c['consent_type'] as String};
    return OnboardingStatus(
      displayName: profile?['display_name'] as String?,
      consents: {
        for (final type in ConsentType.values)
          if (granted.contains(type.wire)) type,
      },
    );
  }

  @override
  Future<void> saveDisplayName(String name) async {
    // Insert or update explicitly: an upsert would also try to UPDATE the
    // id column, and only display_name is updatable.
    final updated = await _db
        .from('profiles')
        .update({'display_name': name.trim()})
        .eq('id', _uid)
        .select('id');
    if (updated.isEmpty) {
      await _db.from('profiles').insert({
        'id': _uid,
        'display_name': name.trim(),
      });
    }
  }

  @override
  Future<void> recordConsents(Set<ConsentType> consents) async {
    if (consents.isEmpty) return;
    await _db.from('consents').insert([
      for (final c in consents)
        {'consent_type': c.wire, 'policy_version': currentPolicyVersion},
    ]);
  }
}
