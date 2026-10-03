import 'package:afrisafety/core/crypto/secret_store.dart';
import 'package:afrisafety/core/emergency/dialer.dart';

class InMemorySecretStore implements SecretStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}

class FakeDialer implements Dialer {
  FakeDialer({this.succeed = true});

  final bool succeed;
  final List<String> dialled = [];

  @override
  Future<bool> dial(String number) async {
    dialled.add(number);
    return succeed;
  }
}
