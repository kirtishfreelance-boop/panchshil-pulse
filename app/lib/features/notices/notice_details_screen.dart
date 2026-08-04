import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/pulse_widgets.dart';
import '../../models/notice.dart';

class NoticeDetailsScreen extends StatelessWidget {
  const NoticeDetailsScreen({super.key, required this.notice});

  final Notice notice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = notice.isImportant ? AppColors.danger : AppColors.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notice'),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share_rounded),
            onPressed: () => Share.share(
              '${notice.title}\n\n${notice.body ?? ''}\n\n— Panchshil Pulse',
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          if (notice.coverImage != null) ...[
            PulseImage(url: notice.coverImage, height: 190, radius: 16),
            const SizedBox(height: 20),
          ],
          Row(
            children: [
              if (notice.category != null)
                PulseChip(label: notice.category!, color: accent),
              if (notice.isImportant) ...[
                const SizedBox(width: 8),
                const PulseChip(
                  label: 'Important',
                  color: AppColors.danger,
                  icon: Icons.priority_high_rounded,
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Text(notice.title, style: theme.textTheme.headlineMedium),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.schedule_rounded,
                  size: 14, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 5),
              Text(
                notice.createdAt != null
                    ? '${dayMonthYear(notice.createdAt!)} · ${relativeTime(notice.createdAt)}'
                    : '',
                style: theme.textTheme.labelSmall,
              ),
            ],
          ),
          const SizedBox(height: 22),
          if (notice.body != null)
            Text(
              notice.body!,
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.65),
            ),
          if (notice.expiresAt != null) ...[
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.event_busy_rounded,
                      size: 18, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Valid until ${dayMonthYear(notice.expiresAt!)}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
