import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/crypto/location_codec.dart';
import '../../../core/theme/app_colors.dart';
import '../domain/location_policy.dart';

/// Text for the persistent "sharing" notification (localised by the UI).
class SharingNotificationText {
  const SharingNotificationText({required this.title, required this.body});

  final String title;
  final String body;
}

enum LocationPermissionLevel {
  denied,
  whileInUse,
  always;

  bool get canTrack => this != denied;
}

/// Everything platform-specific about location, behind one interface so
/// the sharing logic is testable and the plugin can be swapped (D2).
abstract interface class LocationSource {
  Future<LocationPermissionLevel> permission();
  Future<LocationPermissionLevel> requestWhileInUse();

  /// Android 10+: opens the "Allow all the time" choice. Must only be
  /// called after the in-app explanation (Play policy).
  Future<LocationPermissionLevel> requestAlways();
  Future<bool> requestNotifications();

  /// Starts the location stream. On Android this runs inside a foreground
  /// service whose notification stays visible for as long as the stream
  /// is listened to: sharing is never silent.
  Stream<LocationFix> watch(TrackingSpec spec, SharingNotificationText text);

  /// A single fix (e.g. for a panic alert), or null within [timeout].
  Future<LocationFix?> current({required Duration timeout});

  Future<int?> batteryPercent();
}

class GeolocatorLocationSource implements LocationSource {
  GeolocatorLocationSource({Battery? battery})
    : _battery = battery ?? Battery();

  final Battery _battery;

  @override
  Future<LocationPermissionLevel> permission() async =>
      _map(await Geolocator.checkPermission());

  @override
  Future<LocationPermissionLevel> requestWhileInUse() async =>
      _map(await Geolocator.requestPermission());

  @override
  Future<LocationPermissionLevel> requestAlways() async {
    await Permission.locationAlways.request();
    return permission();
  }

  @override
  Future<bool> requestNotifications() async =>
      (await Permission.notification.request()).isGranted;

  @override
  Stream<LocationFix> watch(TrackingSpec spec, SharingNotificationText text) {
    final settings = defaultTargetPlatform == TargetPlatform.android
        ? AndroidSettings(
            accuracy: _accuracy(spec.accuracy),
            distanceFilter: spec.distanceFilterMeters,
            intervalDuration: spec.interval,
            foregroundNotificationConfig: ForegroundNotificationConfig(
              notificationTitle: text.title,
              notificationText: text.body,
              notificationChannelName: text.title,
              notificationIcon: const AndroidResource(
                name: 'ic_stat_afrisafety',
              ),
              setOngoing: true,
              color: AppColors.teal,
            ),
          )
        : LocationSettings(
            accuracy: _accuracy(spec.accuracy),
            distanceFilter: spec.distanceFilterMeters,
          );
    return Geolocator.getPositionStream(locationSettings: settings).map(_fix);
  }

  @override
  Future<LocationFix?> current({required Duration timeout}) async {
    try {
      final p = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: timeout,
        ),
      );
      return _fix(p);
    } on Exception {
      final last = await Geolocator.getLastKnownPosition();
      return last == null ? null : _fix(last);
    }
  }

  @override
  Future<int?> batteryPercent() async {
    try {
      return await _battery.batteryLevel;
    } on Exception {
      return null;
    }
  }

  static LocationFix _fix(Position p) => LocationFix(
    latitude: p.latitude,
    longitude: p.longitude,
    accuracyMeters: p.accuracy,
    recordedAt: p.timestamp.toUtc(),
    speedMetersPerSecond: p.speed >= 0 ? p.speed : null,
    isMocked: p.isMocked,
  );

  static LocationAccuracy _accuracy(TrackingAccuracy a) => switch (a) {
    TrackingAccuracy.high => LocationAccuracy.high,
    TrackingAccuracy.balanced => LocationAccuracy.medium,
    TrackingAccuracy.low => LocationAccuracy.low,
  };

  static LocationPermissionLevel _map(LocationPermission p) => switch (p) {
    LocationPermission.always => LocationPermissionLevel.always,
    LocationPermission.whileInUse => LocationPermissionLevel.whileInUse,
    _ => LocationPermissionLevel.denied,
  };
}
