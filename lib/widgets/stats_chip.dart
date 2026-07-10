import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../theme.dart';

/// Compact live-updating completion meter for the current board.
class StatsChip extends ConsumerWidget {
  const StatsChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(boardStatsProvider);
    if (stats.total == 0) return const SizedBox.shrink();

    final percent = (stats.percent * 100).round();
    return Tooltip(
      message: '${stats.done} of ${stats.total} cards completed',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: VaultColors.surfaceRaised,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: VaultColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 15,
              height: 15,
              child: CircularProgressIndicator(
                value: stats.percent,
                strokeWidth: 2.6,
                backgroundColor: VaultColors.border,
                color: percent == 100
                    ? const Color(0xFF66BB6A)
                    : VaultColors.accent,
              ),
            ),
            const SizedBox(width: 9),
            Text(
              '${stats.done}/${stats.total} done · $percent%',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: VaultColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
