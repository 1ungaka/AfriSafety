import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../data/contacts_repository.dart';
import 'emergency_contact.dart';

final contactsControllerProvider =
    AsyncNotifierProvider<ContactsController, List<EmergencyContact>>(
      ContactsController.new,
    );

class ContactsController extends AsyncNotifier<List<EmergencyContact>> {
  @override
  Future<List<EmergencyContact>> build() =>
      ref.read(contactsRepositoryProvider).load();

  /// Adds a contact. The caller must have shown and confirmed the consent
  /// statement; returns false if the number is invalid or the list is full.
  Future<bool> add({required String name, required String phone}) async {
    final normalised = normalisePhone(phone);
    final current = await future;
    if (normalised == null ||
        name.trim().isEmpty ||
        current.length >= EmergencyContact.maxContacts) {
      return false;
    }
    final next = [
      ...current.where((c) => c.phone != normalised),
      EmergencyContact(
        id: const Uuid().v4(),
        name: name.trim(),
        phone: normalised,
        consentedAt: DateTime.now().toUtc(),
      ),
    ];
    await ref.read(contactsRepositoryProvider).save(next);
    state = AsyncData(next);
    return true;
  }

  Future<void> remove(String id) async {
    final next = [...await future]..removeWhere((c) => c.id == id);
    await ref.read(contactsRepositoryProvider).save(next);
    state = AsyncData(next);
  }
}
