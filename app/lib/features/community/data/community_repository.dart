import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/geo/grid.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../onboarding/data/profile_repository.dart';
import '../domain/report_category.dart';

class CellReport {
  const CellReport({
    required this.cell,
    required this.category,
    required this.reporters,
  });

  final GridCell cell;
  final ReportCategory category;

  /// Different people who reported this (always 3 or more).
  final int reporters;
}

class QueueItem {
  const QueueItem({
    required this.cell,
    required this.category,
    required this.reporters,
    required this.flags,
    required this.status,
  });

  final GridCell cell;
  final ReportCategory category;
  final int reporters;
  final int flags;

  /// null (undecided), 'kept' or 'hidden'.
  final String? status;
}

class CommunityException implements Exception {
  const CommunityException(this.code);

  final String code;
}

abstract interface class CommunityRepository {
  Future<bool> hasConsent();
  Future<void> giveConsent();
  Future<void> withdrawConsent();
  Future<void> submit({
    required ReportCategory category,
    required GridCell cell,
    required DateTime occurredOn,
    required int period,
  });

  /// k-anonymous aggregates around [center] (±[radius] squares).
  Future<List<CellReport>> cellsAround(GridCell center, {int radius = 40});
  Future<void> flag(GridCell cell, ReportCategory category);
  Future<bool> isModerator();
  Future<List<QueueItem>> moderationQueue();
  Future<void> moderate(
    GridCell cell,
    ReportCategory category, {
    required bool keep,
  });
}

class SupabaseCommunityRepository implements CommunityRepository {
  SupabaseCommunityRepository(this._db);

  final SupabaseClient _db;

  static Never _rethrow(PostgrestException e) =>
      throw CommunityException(e.message);

  @override
  Future<bool> hasConsent() async {
    final rows = await _db
        .from('consents')
        .select('id')
        .eq('consent_type', 'community')
        .isFilter('revoked_at', null)
        .limit(1);
    return rows.isNotEmpty;
  }

  @override
  Future<void> giveConsent() async {
    await _db.from('consents').insert({
      'consent_type': 'community',
      'policy_version': currentPolicyVersion,
    });
  }

  @override
  Future<void> withdrawConsent() async {
    await _db.rpc<void>('revoke_consent', params: {'p_type': 'community'});
  }

  @override
  Future<void> submit({
    required ReportCategory category,
    required GridCell cell,
    required DateTime occurredOn,
    required int period,
  }) async {
    try {
      await _db.rpc<void>(
        'submit_report',
        params: {
          'p_category': category.wire,
          'p_cell_lat': cell.lat,
          'p_cell_lon': cell.lon,
          'p_occurred_on':
              '${occurredOn.year.toString().padLeft(4, '0')}-'
              '${occurredOn.month.toString().padLeft(2, '0')}-'
              '${occurredOn.day.toString().padLeft(2, '0')}',
          'p_period': period,
        },
      );
    } on PostgrestException catch (e) {
      _rethrow(e);
    }
  }

  @override
  Future<List<CellReport>> cellsAround(
    GridCell center, {
    int radius = 40,
  }) async {
    final rows = await _db.rpc<List<dynamic>>(
      'community_cells',
      params: {
        'p_min_lat': center.lat - radius,
        'p_max_lat': center.lat + radius,
        'p_min_lon': center.lon - radius,
        'p_max_lon': center.lon + radius,
      },
    );
    return [
      for (final r in rows.cast<Map<String, dynamic>>())
        if (ReportCategory.fromWire(r['category'] as String) case final c?)
          CellReport(
            cell: GridCell(r['cell_lat'] as int, r['cell_lon'] as int),
            category: c,
            reporters: r['reporters'] as int,
          ),
    ];
  }

  @override
  Future<void> flag(GridCell cell, ReportCategory category) async {
    try {
      await _db.rpc<void>(
        'flag_cell',
        params: {
          'p_cell_lat': cell.lat,
          'p_cell_lon': cell.lon,
          'p_category': category.wire,
        },
      );
    } on PostgrestException catch (e) {
      _rethrow(e);
    }
  }

  @override
  Future<bool> isModerator() async =>
      await _db.rpc<bool>('is_moderator') == true;

  @override
  Future<List<QueueItem>> moderationQueue() async {
    final rows = await _db.rpc<List<dynamic>>('moderation_queue');
    return [
      for (final r in rows.cast<Map<String, dynamic>>())
        if (ReportCategory.fromWire(r['category'] as String) case final c?)
          QueueItem(
            cell: GridCell(r['cell_lat'] as int, r['cell_lon'] as int),
            category: c,
            reporters: r['reporters'] as int? ?? 0,
            flags: r['flags'] as int? ?? 0,
            status: r['status'] as String?,
          ),
    ];
  }

  @override
  Future<void> moderate(
    GridCell cell,
    ReportCategory category, {
    required bool keep,
  }) async {
    await _db.rpc<void>(
      'moderate_cell',
      params: {
        'p_cell_lat': cell.lat,
        'p_cell_lon': cell.lon,
        'p_category': category.wire,
        'p_keep': keep,
      },
    );
  }
}

final communityRepositoryProvider = Provider<CommunityRepository>(
  (ref) => SupabaseCommunityRepository(ref.watch(supabaseProvider)),
);
