import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/contacts_controller.dart';
import '../domain/emergency_contact.dart';

/// SMS emergency contacts: people without the app who get the SOS text.
class ContactsScreen extends ConsumerWidget {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final contacts = ref.watch(contactsControllerProvider).value ?? const [];
    final full = contacts.length >= EmergencyContact.maxContacts;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.contactsTitle)),
      floatingActionButton: full
          ? null
          : FloatingActionButton.extended(
              icon: const Icon(Icons.person_add_alt_1),
              label: Text(l10n.contactsAdd),
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => const _AddContactSheet(),
              ),
            ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
        children: [
          Text(l10n.contactsIntro, style: text.bodyLarge),
          const SizedBox(height: 8),
          Text(
            l10n.contactsPrivacy,
            style: text.bodyMedium?.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 16),
          Card(
            child: contacts.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(l10n.contactsEmpty),
                  )
                : Column(
                    children: [
                      for (final c in contacts)
                        ListTile(
                          leading: const Icon(Icons.sms_outlined),
                          title: Text(c.name),
                          subtitle: Text(c.phone),
                          trailing: IconButton(
                            tooltip: l10n.contactsDelete(c.name),
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => ref
                                .read(contactsControllerProvider.notifier)
                                .remove(c.id),
                          ),
                        ),
                    ],
                  ),
          ),
          if (full) ...[const SizedBox(height: 12), Text(l10n.contactsLimit)],
        ],
      ),
    );
  }
}

class _AddContactSheet extends ConsumerStatefulWidget {
  const _AddContactSheet();

  @override
  ConsumerState<_AddContactSheet> createState() => _AddContactSheetState();
}

class _AddContactSheetState extends ConsumerState<_AddContactSheet> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  bool _consent = false;
  bool _invalidPhone = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (normalisePhone(_phone.text) == null) {
      setState(() => _invalidPhone = true);
      return;
    }
    final ok = await ref
        .read(contactsControllerProvider.notifier)
        .add(name: _name.text, phone: _phone.text);
    if (ok && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ready = _name.text.trim().isNotEmpty && _phone.text.trim().isNotEmpty;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.contactsAdd,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              maxLength: 40,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: l10n.contactsName,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9+ \-()]')),
              ],
              decoration: InputDecoration(
                labelText: l10n.contactsPhone,
                hintText: '082 123 4567',
                errorText: _invalidPhone ? l10n.contactsPhoneInvalid : null,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() => _invalidPhone = false),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _consent,
              onChanged: (v) => setState(() => _consent = v ?? false),
              title: Text(l10n.contactsConsent),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: ready && _consent ? _save : null,
              child: Text(l10n.contactsSave),
            ),
          ],
        ),
      ),
    );
  }
}
