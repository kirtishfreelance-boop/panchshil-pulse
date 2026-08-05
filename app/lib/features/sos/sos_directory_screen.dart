import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/pulse_widgets.dart';
import '../../models/document.dart';
import '../../providers/amenity_provider.dart';

/// Emergency and estate contacts, one tap to dial. Urgent entries are pinned
/// to the top and styled to be findable without reading.
class SosDirectoryScreen extends StatefulWidget {
  const SosDirectoryScreen({super.key});

  @override
  State<SosDirectoryScreen> createState() => _SosDirectoryScreenState();
}

class _SosDirectoryScreenState extends State<SosDirectoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<AmenityProvider>().loadContacts(),
    );
  }

  Future<void> _call(SosContact contact) async {
    final uri = Uri(scheme: 'tel', path: contact.phone);
    if (!await launchUrl(uri)) {
      if (mounted) {
        showPulseSnack(context, 'Could not start the call.', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<AmenityProvider>();
    final state = provider.contacts;

    return Scaffold(
      appBar: AppBar(title: const Text('SOS directory')),
      body: Builder(
        builder: (_) {
          if (state.isLoading && !state.hasData) {
            return const Padding(
              padding: EdgeInsets.all(20),
              child: CardListSkeleton(count: 5, height: 72),
            );
          }
          if (state.hasError && !state.hasData) {
            return ErrorView(message: state.error!, onRetry: provider.loadContacts);
          }

          final contacts = state.data ?? const <SosContact>[];
          if (contacts.isEmpty) {
            return const EmptyState(
              title: 'No contacts listed',
              message: 'The estate team has not published a directory yet.',
              icon: Icons.contact_phone_outlined,
            );
          }

          final urgent = contacts.where((c) => c.isUrgent).toList();
          final rest = contacts.where((c) => !c.isUrgent).toList();

          // Group the non-urgent entries by their category.
          final grouped = <String, List<SosContact>>{};
          for (final c in rest) {
            (grouped[c.category] ??= []).add(c);
          }

          return RefreshIndicator(
            onRefresh: provider.loadContacts,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              children: [
                if (urgent.isNotEmpty) ...[
                  Row(
                    children: [
                      const Icon(Icons.emergency_rounded, size: 18, color: AppColors.danger),
                      const SizedBox(width: 8),
                      Text(
                        'Emergency',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: AppColors.danger,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...urgent.map((c) => _ContactCard(
                        contact: c,
                        urgent: true,
                        onCall: () => _call(c),
                      )),
                  const SizedBox(height: 24),
                ],
                ...grouped.entries.expand((entry) => [
                      Text(entry.key, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 12),
                      ...entry.value.map((c) => _ContactCard(
                            contact: c,
                            onCall: () => _call(c),
                          )),
                      const SizedBox(height: 20),
                    ]),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({
    required this.contact,
    required this.onCall,
    this.urgent = false,
  });

  final SosContact contact;
  final VoidCallback onCall;
  final bool urgent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tint = urgent ? AppColors.danger : AppColors.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onCall,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: urgent
                ? AppColors.danger.withValues(alpha: 0.07)
                : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: urgent
                  ? AppColors.danger.withValues(alpha: 0.35)
                  : theme.colorScheme.outline,
            ),
          ),
          child: Row(
            children: [
              Container(
                height: 46,
                width: 46,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.call_rounded, size: 21, color: tint),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contact.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontSize: urgent ? 16 : 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      contact.role == null
                          ? contact.phone
                          : '${contact.role} · ${contact.phone}',
                      style: theme.textTheme.labelSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: tint,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Call',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
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
