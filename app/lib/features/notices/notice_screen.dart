import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/pulse_widgets.dart';
import '../../models/notice.dart';
import '../../providers/notice_provider.dart';
import 'notice_details_screen.dart';

class NoticeScreen extends StatefulWidget {
  const NoticeScreen({super.key});

  @override
  State<NoticeScreen> createState() => _NoticeScreenState();
}

class _NoticeScreenState extends State<NoticeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<NoticeProvider>().load(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NoticeProvider>();
    final state = provider.notices;

    return Scaffold(
      appBar: AppBar(title: const Text('Notices')),
      body: Column(
        children: [
          if (provider.categories.isNotEmpty)
            SizedBox(
              height: 54,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                children: [
                  _Chip(
                    label: 'All',
                    selected: provider.activeCategory == null,
                    onTap: () => provider.load(),
                  ),
                  ...provider.categories.map(
                    (c) => _Chip(
                      label: c,
                      selected: provider.activeCategory == c,
                      onTap: () => provider.load(category: c),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: Builder(
              builder: (_) {
                if (state.isLoading && !state.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(20),
                    child: CardListSkeleton(count: 4, height: 96),
                  );
                }
                if (state.hasError && !state.hasData) {
                  return ErrorView(
                    message: state.error!,
                    onRetry: () => provider.load(refresh: true),
                  );
                }
                final notices = state.data ?? const <Notice>[];
                if (notices.isEmpty) {
                  return const EmptyState(
                    title: 'No notices',
                    message: 'Announcements from the estate team appear here.',
                    icon: Icons.campaign_outlined,
                  );
                }
                return RefreshIndicator(
                  onRefresh: () => provider.load(
                    category: provider.activeCategory,
                    refresh: true,
                  ),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                    itemCount: notices.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _NoticeCard(notice: notices[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          showCheckmark: false,
          labelStyle: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
            color: selected ? Colors.white : Theme.of(context).colorScheme.onSurface,
          ),
          onSelected: (_) => onTap(),
        ),
      );
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({required this.notice});

  final Notice notice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = notice.isImportant ? AppColors.danger : AppColors.primary;

    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => NoticeDetailsScreen(notice: notice)),
      ),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.outline),
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(width: 4, color: accent),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (notice.category != null)
                            PulseChip(label: notice.category!, color: accent),
                          const Spacer(),
                          Text(
                            relativeTime(notice.createdAt),
                            style: theme.textTheme.labelSmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        notice.title,
                        style: theme.textTheme.titleMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (notice.body != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          notice.body!,
                          style: theme.textTheme.bodySmall,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
