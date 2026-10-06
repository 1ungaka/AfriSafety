import 'dart:convert';

import 'package:afrisafety/core/crypto/payload_cipher.dart';
import 'package:afrisafety/core/storage/local_vault.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sodium/sodium.dart';

import '../../helpers/fakes.dart';

void main() {
  late Sodium sodium;
  late InMemorySecretStore secrets;
  late InMemoryVaultFiles files;

  setUpAll(() async => sodium = await SodiumInit.init());

  setUp(() {
    secrets = InMemorySecretStore();
    files = InMemoryVaultFiles();
  });

  LocalVault vault() => LocalVault(
    sodium: sodium,
    cipher: PayloadCipher(sodium),
    secrets: secrets,
    files: files,
  );

  test('round-trips JSON and survives a restart (new instance)', () async {
    await vault().writeJson('places', [
      {'name': 'Home', 'lat': -26.2},
    ]);
    expect(await vault().readJson('places'), [
      {'name': 'Home', 'lat': -26.2},
    ]);
  });

  test('stores ciphertext only', () async {
    await vault().writeJson('places', {'name': 'Home'});
    final raw = files.files['places']!;
    expect(latin1.decode(raw).contains('Home'), isFalse);
  });

  test('a file swapped under another name is rejected', () async {
    final v = vault();
    await v.writeJson('contacts', {'n': 1});
    files.files['places'] = files.files['contacts']!;
    expect(await v.readJson('places'), isNull);
  });

  test('missing file reads as null', () async {
    expect(await vault().readJson('history'), isNull);
  });

  test('wipe deletes files and the key', () async {
    final v = vault();
    await v.writeJson('places', [1]);
    await v.wipe();
    expect(files.files, isEmpty);
    expect(await secrets.read('local_vault_key_v1'), isNull);
    expect(await v.readJson('places'), isNull);
  });
}
