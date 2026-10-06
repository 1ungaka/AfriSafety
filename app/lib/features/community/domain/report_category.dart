import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

enum ReportCategory {
  suspicious('suspicious', Icons.visibility_outlined),
  theft('theft', Icons.backpack_outlined),
  robbery('robbery', Icons.report_outlined),
  assault('assault', Icons.personal_injury_outlined),
  harassment('harassment', Icons.record_voice_over_outlined),
  vandalism('vandalism', Icons.broken_image_outlined);

  const ReportCategory(this.wire, this.icon);

  final String wire;
  final IconData icon;

  static ReportCategory? fromWire(String wire) =>
      values.where((c) => c.wire == wire).firstOrNull;

  String label(AppLocalizations l10n) => switch (this) {
    ReportCategory.suspicious => l10n.categorySuspicious,
    ReportCategory.theft => l10n.categoryTheft,
    ReportCategory.robbery => l10n.categoryRobbery,
    ReportCategory.assault => l10n.categoryAssault,
    ReportCategory.harassment => l10n.categoryHarassment,
    ReportCategory.vandalism => l10n.categoryVandalism,
  };
}

/// "When did it happen?" choices, turned into a date and 4-hour block.
enum ReportWhen { justNow, earlierToday, yesterday }
