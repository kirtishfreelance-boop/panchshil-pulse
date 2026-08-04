import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/pulse_widgets.dart';
import '../../models/site.dart';
import '../../providers/auth_provider.dart';
import '../../providers/site_provider.dart';
import '../shell/home_shell.dart';
import 'registration_screen.dart';

/// Shown to a new number before registration, and reachable later from Profile
/// to switch between the parks a user has access to.
class SelectOfficeParkScreen extends StatefulWidget {
  const SelectOfficeParkScreen({super.key, this.isSwitching = false});

  /// When true the user is already signed in and is changing their active site.
  final bool isSwitching;

  @override
  State<SelectOfficeParkScreen> createState() => _SelectOfficeParkScreenState();
}

class _SelectOfficeParkScreenState extends State<SelectOfficeParkScreen> {
  int? _selectedId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final sites = context.read<SiteProvider>();
      if (widget.isSwitching) {
        sites.loadAllowedSites().then((_) {
          if (mounted) setState(() => _selectedId = sites.currentSiteId);
        });
      } else {
        sites.loadPublicSites();
      }
    });
  }

  Future<void> _continue() async {
    final siteId = _selectedId;
    if (siteId == null) return;

    if (!widget.isSwitching) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => RegistrationScreen(siteId: siteId),
      ));
      return;
    }

    setState(() => _saving = true);
    try {
      await context.read<AuthProvider>().switchSite(siteId);
      if (!mounted) return;
      context.read<SiteProvider>().setCurrentSite(siteId);
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeShell()),
        (route) => false,
      );
    } catch (e) {
      if (mounted) showPulseSnack(context, '$e', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<SiteProvider>();
    final state = provider.sites;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isSwitching ? 'Switch office park' : ''),
        leading: widget.isSwitching || Navigator.of(context).canPop()
            ? const BackButton()
            : null,
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Where are you based?', style: theme.textTheme.headlineLarge),
                  const SizedBox(height: 8),
                  Text(
                    'Pick your office park. Events, notices and amenities are scoped to it.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
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
                      padding: EdgeInsets.symmetric(horizontal: 24),
                      child: CardListSkeleton(count: 4, height: 84),
                    );
                  }
                  if (state.hasError && !state.hasData) {
                    return ErrorView(
                      message: state.error!,
                      onRetry: () => widget.isSwitching
                          ? provider.loadAllowedSites()
                          : provider.loadPublicSites(),
                    );
                  }
                  final sites = state.data ?? const <Site>[];
                  if (sites.isEmpty) {
                    return const EmptyState(
                      title: 'No office parks available',
                      message: 'Contact your estate helpdesk to get access.',
                      icon: Icons.location_city_outlined,
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: sites.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _SiteTile(
                      site: sites[i],
                      selected: sites[i].id == _selectedId,
                      onTap: () => setState(() => _selectedId = sites[i].id),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: FilledButton(
                onPressed: _selectedId == null || _saving ? null : _continue,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : Text(widget.isSwitching ? 'Switch site' : 'Continue'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SiteTile extends StatelessWidget {
  const _SiteTile({required this.site, required this.selected, required this.onTap});

  final Site site;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.primary : theme.colorScheme.outline,
            width: selected ? 1.8 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              height: 44,
              width: 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.apartment_rounded, color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(site.name, style: theme.textTheme.titleMedium),
                  if (site.address != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      site.address!,
                      style: theme.textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: selected ? AppColors.primary : theme.colorScheme.outline,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
