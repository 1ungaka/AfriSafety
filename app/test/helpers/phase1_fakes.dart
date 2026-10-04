import 'dart:async';
import 'dart:typed_data';

import 'package:afrisafety/core/crypto/location_codec.dart';
import 'package:afrisafety/features/circles/domain/circles_controller.dart';
import 'package:afrisafety/features/onboarding/data/profile_repository.dart';
import 'package:afrisafety/features/panic/data/alerts_repository.dart';
import 'package:afrisafety/features/sharing/data/location_source.dart';
import 'package:afrisafety/features/sharing/domain/location_policy.dart';

class FakeAlertsRepository implements AlertsRepository {
  /// Number of insert calls that should fail before succeeding.
  int failuresBeforeSuccess = 0;
  final List<String> inserted = [];
  final List<List<String>> dispatched = [];
  final List<String> resolved = [];
  List<AlertReceipt> receiptRows = [];
  // ignore: close_sinks (lives for the duration of a test)
  final _receiptChanges = StreamController<void>.broadcast();
  // ignore: close_sinks (lives for the duration of a test)
  final _alertChanges = StreamController<void>.broadcast();
  List<EncryptedAlert> active = [];

  void emitReceiptChange() => _receiptChanges.add(null);

  @override
  Future<void> insert({
    required String id,
    required String incidentId,
    required String circleId,
    required String deviceId,
    required int keyVersion,
    required Uint8List ciphertext,
  }) async {
    if (failuresBeforeSuccess > 0) {
      failuresBeforeSuccess--;
      throw StateError('offline');
    }
    inserted.add(circleId);
  }

  @override
  Future<void> dispatch(List<String> alertIds) async =>
      dispatched.add(alertIds);

  @override
  Future<List<EncryptedAlert>> activeAlertsForMe() async => active;

  @override
  Future<List<AlertReceipt>> receipts(List<String> alertIds) async =>
      receiptRows;

  @override
  Future<void> acknowledge(String alertId, {required bool seen}) async {}

  @override
  Future<void> resolveIncident(String incidentId) async =>
      resolved.add(incidentId);

  @override
  Stream<void> alertChanges() => _alertChanges.stream;

  @override
  Stream<void> receiptChanges() => _receiptChanges.stream;
}

class FakeLocationSource implements LocationSource {
  FakeLocationSource({this.fix, this.level = LocationPermissionLevel.always});

  LocationFix? fix;
  LocationPermissionLevel level;
  // ignore: close_sinks (lives for the duration of a test)
  final controller = StreamController<LocationFix>.broadcast();

  @override
  Future<LocationPermissionLevel> permission() async => level;

  @override
  Future<LocationPermissionLevel> requestWhileInUse() async => level;

  @override
  Future<LocationPermissionLevel> requestAlways() async => level;

  @override
  Future<bool> requestNotifications() async => true;

  @override
  Stream<LocationFix> watch(TrackingSpec spec, SharingNotificationText text) =>
      controller.stream;

  @override
  Future<LocationFix?> current({required Duration timeout}) async => fix;

  @override
  Future<int?> batteryPercent() async => 80;
}

class FakeCirclesController extends CirclesController {
  FakeCirclesController(this.initial);

  final CirclesState initial;

  @override
  Future<CirclesState> build() async => initial;
}

class FakeProfileRepository implements ProfileRepository {
  FakeProfileRepository({this.current = const OnboardingStatusEmpty()});

  OnboardingStatus current;
  final Set<ConsentType> recorded = {};
  String? savedName;

  @override
  Future<OnboardingStatus> status() async => current;

  @override
  Future<void> recordConsents(Set<ConsentType> consents) async =>
      recorded.addAll(consents);

  @override
  Future<void> saveDisplayName(String name) async => savedName = name;
}
