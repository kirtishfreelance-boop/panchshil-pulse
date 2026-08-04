import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/pulse_widgets.dart';
import '../../providers/auth_provider.dart';
import '../../providers/site_provider.dart';
import '../../providers/theme_provider.dart';
import '../auth/select_office_park_screen.dart';
import '../events/event_list_screen.dart';
import '../wallet/wallet_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _openWhatsApp(BuildContext context) async {
    final uri = Uri.parse('https://wa.me/${AppConfig.supportWhatsApp}');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        showPulseSnack(context, 'Could not open WhatsApp.', isError: true);
      }
    }
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You will need your mobile number and an OTP to sign back in.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await context.read<AuthProvider>().signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final site = context.watch<SiteProvider>().currentSite;
    final user = auth.user;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: theme.colorScheme.outline),
            ),
            child: Row(
              children: [
                PulseAvatar(
                  imageUrl: user?.profileImage,
                  initials: user?.initials ?? 'P',
                  size: 62,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.displayName.isNotEmpty == true
                            ? user!.displayName
                            : 'Your profile',
                        style: theme.textTheme.titleLarge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      if (user?.designation != null || user?.companyName != null)
                        Text(
                          [user?.designation, user?.companyName]
                              .whereType<String>()
                              .join(' · '),
                          style: theme.textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      const SizedBox(height: 4),
                      Text(
                        '${user?.countryCode ?? '+91'} ${user?.mobile ?? ''}',
                        style: theme.textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Wallet',
                  value: money(user?.walletBalance ?? 0),
                  icon: Icons.account_balance_wallet_rounded,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const WalletScreen()),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  label: 'Privilege points',
                  value: compactNumber(user?.loyaltyPoints ?? 0),
                  icon: Icons.stars_rounded,
                  tint: AppColors.accent,
                ),
              ),
            ],
          ),

          const SizedBox(height: 28),
          Text('Account', style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          _Group(children: [
            _Row(
              icon: Icons.apartment_rounded,
              title: 'Office park',
              subtitle: site?.name ?? 'Not selected',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const SelectOfficeParkScreen(isSwitching: true),
                ),
              ),
            ),
            _Row(
              icon: Icons.confirmation_number_outlined,
              title: 'My events',
              subtitle: 'Registrations and passes',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const EventListScreen()),
              ),
            ),
            _Row(
              icon: Icons.account_balance_wallet_outlined,
              title: 'My wallet',
              subtitle: 'Balance and transactions',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const WalletScreen()),
              ),
            ),
          ]),

          const SizedBox(height: 24),
          Text('Preferences', style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          _Group(children: [
            _Row(
              icon: Icons.dark_mode_outlined,
              title: 'Appearance',
              subtitle: switch (themeProvider.mode) {
                ThemeMode.light => 'Light',
                ThemeMode.dark => 'Dark',
                ThemeMode.system => 'Match device',
              },
              trailing: Switch(
                value: themeProvider.isDark(context),
                onChanged: (_) => themeProvider.toggle(context),
              ),
            ),
          ]),

          const SizedBox(height: 24),
          Text('Support', style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          _Group(children: [
            _Row(
              icon: Icons.chat_bubble_outline_rounded,
              title: 'WhatsApp the helpdesk',
              subtitle: AppConfig.supportWhatsApp,
              onTap: () => _openWhatsApp(context),
            ),
            _Row(
              icon: Icons.mail_outline_rounded,
              title: 'Email us',
              subtitle: AppConfig.supportEmail,
              onTap: () => launchUrl(Uri.parse('mailto:${AppConfig.supportEmail}')),
            ),
            _Row(
              icon: Icons.share_outlined,
              title: 'Share the app',
              subtitle: 'Invite a colleague to Pulse',
              onTap: () => Share.share(
                'Panchshil Pulse keeps our office park in one place — events, '
                'amenities and notices. Ask the estate team for access.',
              ),
            ),
          ]),

          const SizedBox(height: 28),
          OutlinedButton.icon(
            onPressed: () => _confirmSignOut(context),
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text('Sign out'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.danger,
              side: const BorderSide(color: AppColors.danger, width: 1.4),
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              '${AppConfig.appName} · v1.0.0',
              style: theme.textTheme.labelSmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    this.tint = AppColors.primary,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color tint;
  final VoidCallback? onTap;

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
          border: Border.all(color: theme.colorScheme.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: tint),
            const SizedBox(height: 12),
            Text(value, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 2),
            Text(label, style: theme.textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1)
              const Padding(
                padding: EdgeInsets.only(left: 62),
                child: Divider(height: 1),
              ),
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 21, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.labelSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            trailing ??
                (onTap != null
                    ? Icon(Icons.chevron_right_rounded,
                        size: 20, color: theme.colorScheme.onSurfaceVariant)
                    : const SizedBox.shrink()),
          ],
        ),
      ),
    );
  }
}
