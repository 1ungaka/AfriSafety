import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Round avatar with a member's initial, styled as in the design: teal for
/// you, ink or amber for others, outlined when their location is stale.
class MemberAvatar extends StatelessWidget {
  const MemberAvatar({
    super.key,
    required this.initial,
    required this.colorIndex,
    this.isMe = false,
    this.dimmed = false,
    this.size = 40,
  });

  final String initial;
  final int colorIndex;
  final bool isMe;
  final bool dimmed;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg) = isMe
        ? (AppColors.teal, Colors.white)
        : colorIndex.isEven
        ? (AppColors.amber, AppColors.ink)
        : (AppColors.ink, Colors.white);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: dimmed ? AppColors.surface : bg,
        border: Border.all(
          color: dimmed ? AppColors.amber : Colors.white,
          width: 3,
        ),
      ),
      child: Text(
        initial,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: size * 0.35,
          color: dimmed ? AppColors.ink : fg,
        ),
      ),
    );
  }
}
