import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/models.dart';

class InvitePreview {
  const InvitePreview({
    required this.circleName,
    required this.inviterName,
    required this.memberCount,
  });

  final String circleName;
  final String inviterName;
  final int memberCount;
}

/// Thrown for business errors the server reports by message.
class CircleException implements Exception {
  const CircleException(this.code);

  /// e.g. `rate_limited`, `consent_required`, `not_a_member`.
  final String code;

  @override
  String toString() => 'CircleException($code)';
}

abstract interface class CirclesRepository {
  Future<List<Circle>> myCircles();
  Future<List<CircleMember>> members(String circleId);

  /// Viewers this user has limited to SOS only, per Circle.
  Future<Set<String>> mySosOnlyViewers(String circleId);

  /// Sharers who limited this user to SOS only (honest status).
  Future<Set<String>> sharersLimitingMe(String circleId);

  Future<String> createCircle(String name);
  Future<String> createInvite(String circleId);

  /// Null for a wrong or expired code.
  Future<InvitePreview?> previewInvite(String code);

  /// Returns the Circle id, or null for a wrong or expired code.
  Future<String?> acceptInvite(String code);
  Future<void> leave(String circleId);
  Future<void> setPaused({String? circleId, required bool paused});
  Future<void> setShareLevel(String circleId, String viewerId, ShareLevel l);

  /// Fires whenever membership, pause state or share levels change in any
  /// of this user's Circles.
  Stream<void> changes();
}

class SupabaseCirclesRepository implements CirclesRepository {
  SupabaseCirclesRepository(this._db);

  final SupabaseClient _db;

  String get _uid => _db.auth.currentUser!.id;

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on PostgrestException catch (e) {
      const known = {
        'rate_limited',
        'consent_required',
        'not_a_member',
        'invalid_viewer',
        'invalid_level',
      };
      if (known.contains(e.message)) throw CircleException(e.message);
      rethrow;
    }
  }

  @override
  Future<List<Circle>> myCircles() async {
    final rows = await _db
        .from('circles')
        .select('id, name, owner_id')
        .order('created_at');
    return [
      for (final r in rows)
        Circle(
          id: r['id'] as String,
          name: r['name'] as String,
          ownerId: r['owner_id'] as String,
        ),
    ];
  }

  @override
  Future<List<CircleMember>> members(String circleId) async {
    final rows = await _db
        .from('circle_members')
        .select('user_id, role, sharing_paused, joined_at')
        .eq('circle_id', circleId)
        .order('joined_at');
    final ids = [for (final r in rows) r['user_id'] as String];
    final profiles = ids.isEmpty
        ? const <Map<String, dynamic>>[]
        : await _db
              .from('profiles')
              .select('id, display_name')
              .inFilter('id', ids);
    final names = {
      for (final p in profiles) p['id'] as String: p['display_name'] as String,
    };
    return [
      for (final r in rows)
        CircleMember(
          circleId: circleId,
          userId: r['user_id'] as String,
          displayName: names[r['user_id']] ?? '',
          role: r['role'] == 'owner' ? MemberRole.owner : MemberRole.member,
          sharingPaused: r['sharing_paused'] as bool,
          joinedAt: DateTime.parse(r['joined_at'] as String),
        ),
    ];
  }

  @override
  Future<Set<String>> mySosOnlyViewers(String circleId) async {
    final rows = await _db
        .from('share_levels')
        .select('viewer_id')
        .eq('circle_id', circleId)
        .eq('sharer_id', _uid)
        .eq('level', ShareLevel.sosOnly.wire);
    return {for (final r in rows) r['viewer_id'] as String};
  }

  @override
  Future<Set<String>> sharersLimitingMe(String circleId) async {
    final rows = await _db
        .from('share_levels')
        .select('sharer_id')
        .eq('circle_id', circleId)
        .eq('viewer_id', _uid)
        .eq('level', ShareLevel.sosOnly.wire);
    return {for (final r in rows) r['sharer_id'] as String};
  }

  @override
  Future<String> createCircle(String name) => _guard(
    () async =>
        await _db.rpc<String>('create_circle', params: {'p_name': name.trim()}),
  );

  @override
  Future<String> createInvite(String circleId) => _guard(
    () async =>
        await _db.rpc<String>('create_invite', params: {'p_circle': circleId}),
  );

  @override
  Future<InvitePreview?> previewInvite(String code) => _guard(() async {
    final rows = await _db.rpc<List<dynamic>>(
      'preview_invite',
      params: {'p_code': code},
    );
    if (rows.isEmpty) return null;
    final r = rows.first as Map<String, dynamic>;
    return InvitePreview(
      circleName: r['circle_name'] as String,
      inviterName: r['inviter_name'] as String,
      memberCount: r['member_count'] as int,
    );
  });

  @override
  Future<String?> acceptInvite(String code) => _guard(
    () async =>
        await _db.rpc<String?>('accept_invite', params: {'p_code': code}),
  );

  @override
  Future<void> leave(String circleId) => _guard(
    () => _db.rpc<void>('leave_circle', params: {'p_circle': circleId}),
  );

  @override
  Future<void> setPaused({String? circleId, required bool paused}) => _guard(
    () => _db.rpc<void>(
      'set_sharing_paused',
      params: {'p_circle': circleId, 'p_paused': paused},
    ),
  );

  @override
  Future<void> setShareLevel(String circleId, String viewerId, ShareLevel l) =>
      _guard(
        () => _db.rpc<void>(
          'set_share_level',
          params: {
            'p_circle': circleId,
            'p_viewer': viewerId,
            'p_level': l.wire,
          },
        ),
      );

  @override
  Stream<void> changes() {
    late final RealtimeChannel channel;
    late final StreamController<void> controller;
    controller = StreamController<void>.broadcast(
      onCancel: () async {
        await _db.removeChannel(channel);
        await controller.close();
      },
    );
    void emit(PostgresChangePayload _) => controller.add(null);
    channel =
        _db.channel(
            'circle-changes-$_uid-${DateTime.now().microsecondsSinceEpoch}',
          )
          ..onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'circle_members',
            callback: emit,
          )
          ..onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'share_levels',
            callback: emit,
          )
          ..onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'sender_key_envelopes',
            callback: emit,
          )
          ..subscribe();
    return controller.stream;
  }
}
