import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/local_vault.dart';
import '../domain/emergency_contact.dart';

class ContactsRepository {
  ContactsRepository(this._vault);

  static const _file = 'contacts';
  final LocalVault _vault;

  Future<List<EmergencyContact>> load() async {
    final raw = await _vault.readJson(_file);
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item is Map<String, dynamic>) EmergencyContact.fromJson(item),
    ];
  }

  Future<void> save(List<EmergencyContact> contacts) =>
      _vault.writeJson(_file, [for (final c in contacts) c.toJson()]);
}

final contactsRepositoryProvider = Provider<ContactsRepository>(
  (ref) => ContactsRepository(ref.watch(localVaultProvider)),
);
