import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/pulse_widgets.dart';
import '../../providers/theme_provider.dart';
import '../events/event_list_screen.dart';
import '../notices/notice_screen.dart';
import '../wallet/wallet_screen.dart';

/// The service grid. Modules that ship in a later phase route to a placeholder
/// that names what is coming rather than failing silently.
class DiscoverScreen extends StatelessWidget {
  const DiscoverScreen({super.key});

  static const _services = <_Service>[
    _Service('Events', 'assets/discover_services/events_icon_light.png',
        'assets/discover_services/events_icon_dark.png', Icons.event_rounded, _Target.events),
    _Service('Notices', 'assets/discover_services/notices_icon_light.png',
        'assets/discover_services/notices_icon_dark.png', Icons.campaign_rounded, _Target.notices),
    _Service('My Wallet', 'assets/my_wallet/add_balance_icon_light.png',
        'assets/my_wallet/add_balance_icon_dark.png',
        Icons.account_balance_wallet_rounded, _Target.wallet),
    _Service('Amenities', 'assets/discover_services/amenities_icon_light.png',
        'assets/discover_services/amenities_icon_dark.png', Icons.pool_rounded, _Target.soon),
    _Service('Documents', 'assets/discover_services/document_icon_light.png',
        'assets/discover_services/document_icon_dark.png', Icons.folder_rounded, _Target.soon),
    _Service('Food Court', 'assets/discover_services/food_court_icon_light.png',
        'assets/discover_services/food_court_icon_dark.png',
        Icons.restaurant_rounded, _Target.soon),
    _Service('Carpool', 'assets/discover_services/carpool_icon_light.png',
        'assets/discover_services/carpool_icon_dark.png',
        Icons.directions_car_rounded, _Target.soon),
    _Service('Curated Services', 'assets/discover_services/curated_services_icon_light.png',
        'assets/discover_services/curated_services_icon_dark.png',
        Icons.room_service_rounded, _Target.soon),
    _Service('Privilege', 'assets/discover_services/pulse_privilege_icon_light.png',
        'assets/discover_services/pulse_privilege_icon_dark.png',
        Icons.workspace_premium_rounded, _Target.soon),
    _Service('SOS Directory', 'assets/discover_services/sos_directory_icon_light.png',
        'assets/discover_services/sos_directory_icon_dark.png',
        Icons.emergency_rounded, _Target.soon),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = context.watch<ThemeProvider>().isDark(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Discover')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Text(
            'Everything your office park offers, in one grid.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 22),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 0.94,
            ),
            itemCount: _services.length,
            itemBuilder: (_, i) => _ServiceTile(
              service: _services[i],
              isDark: isDark,
            ),
          ),
        ],
      ),
    );
  }
}

enum _Target { events, notices, wallet, soon }

class _Service {
  const _Service(this.label, this.lightAsset, this.darkAsset, this.fallback, this.target);

  final String label;
  final String lightAsset;
  final String darkAsset;
  final IconData fallback;
  final _Target target;
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({required this.service, required this.isDark});

  final _Service service;
  final bool isDark;

  void _open(BuildContext context) {
    final route = switch (service.target) {
      _Target.events => MaterialPageRoute<void>(builder: (_) => const EventListScreen()),
      _Target.notices => MaterialPageRoute<void>(builder: (_) => const NoticeScreen()),
      _Target.wallet => MaterialPageRoute<void>(builder: (_) => const WalletScreen()),
      _Target.soon => null,
    };

    if (route == null) {
      showPulseSnack(context, '${service.label} arrives in the next release.');
      return;
    }
    Navigator.of(context).push(route);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tint = AppColors.tintFor(service.label);
    final comingSoon = service.target == _Target.soon;

    return InkWell(
      onTap: () => _open(context),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.outline),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 46,
              width: 46,
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(13),
              ),
              alignment: Alignment.center,
              child: Image.asset(
                isDark ? service.darkAsset : service.lightAsset,
                height: 24,
                width: 24,
                errorBuilder: (_, __, ___) =>
                    Icon(service.fallback, size: 22, color: tint),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              service.label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
            if (comingSoon) ...[
              const SizedBox(height: 3),
              Text(
                'Soon',
                style: theme.textTheme.labelSmall?.copyWith(fontSize: 9.5),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
