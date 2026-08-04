import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/community_provider.dart';
import '../../providers/event_provider.dart';
import '../../providers/notice_provider.dart';
import '../../providers/site_provider.dart';
import '../community/community_main_screen.dart';
import '../discover/discover_screen.dart';
import '../home/home_screen.dart';
import '../profile/profile_screen.dart';
import '../pulse/pulse_screen.dart';

/// The five-tab shell: Home · Pulse · Community · Discover · Profile.
///
/// Each tab keeps its own navigation stack so switching tabs never loses a
/// half-finished flow.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late int _index = widget.initialTab;

  final _navigatorKeys = List.generate(5, (_) => GlobalKey<NavigatorState>());

  static const _tabs = <_TabSpec>[
    _TabSpec('Home', 'assets/home_screen/selected_home_icon.png',
        'assets/home_screen/unselected_home_icon.png', Icons.home_rounded),
    _TabSpec('Pulse', 'assets/home_screen/selected_pulse_icon.png',
        'assets/home_screen/unselected_pulse_icon.png', Icons.graphic_eq_rounded),
    _TabSpec('Community', 'assets/home_screen/selected_community_icon.png',
        'assets/home_screen/unselected_community_icon.png', Icons.groups_rounded),
    _TabSpec('Discover', 'assets/home_screen/selected_discover_icon.png',
        'assets/home_screen/unselected_discover_icon.png', Icons.explore_rounded),
    _TabSpec('Profile', 'assets/home_screen/selected_profile_icon.png',
        'assets/home_screen/unseleted_profile_icon.png', Icons.person_rounded),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _warmUp());
  }

  /// Fetch what the first two tabs need up front so switching feels instant.
  void _warmUp() {
    context.read<SiteProvider>()
      ..loadAllowedSites()
      ..loadServices();
    context.read<EventProvider>()
      ..loadUpcoming()
      ..loadCategories();
    context.read<NoticeProvider>().load();
    context.read<CommunityProvider>().loadAll();
  }

  void _onTap(int index) {
    if (index == _index) {
      // Tapping the active tab pops it back to its root.
      _navigatorKeys[index].currentState?.popUntil((r) => r.isFirst);
      return;
    }
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // A signed-out session (expired token) unwinds the shell.
    final signedIn = context.select<AuthProvider, bool>((a) => a.isSignedIn);
    if (!signedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
      });
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final navigator = _navigatorKeys[_index].currentState;
        if (navigator?.canPop() ?? false) {
          navigator!.pop();
        } else if (_index != 0) {
          setState(() => _index = 0);
        }
      },
      child: Scaffold(
        body: IndexedStack(
          index: _index,
          children: [
            _TabNavigator(navigatorKey: _navigatorKeys[0], child: const HomeScreen()),
            _TabNavigator(navigatorKey: _navigatorKeys[1], child: const PulseScreen()),
            _TabNavigator(
                navigatorKey: _navigatorKeys[2], child: const CommunityMainScreen()),
            _TabNavigator(navigatorKey: _navigatorKeys[3], child: const DiscoverScreen()),
            _TabNavigator(navigatorKey: _navigatorKeys[4], child: const ProfileScreen()),
          ],
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(top: BorderSide(color: theme.colorScheme.outline)),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 62,
              child: Row(
                children: List.generate(
                  _tabs.length,
                  (i) => Expanded(
                    child: _TabButton(
                      spec: _tabs[i],
                      selected: _index == i,
                      onTap: () => _onTap(i),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabSpec {
  const _TabSpec(this.label, this.selectedAsset, this.unselectedAsset, this.fallbackIcon);

  final String label;
  final String selectedAsset;
  final String unselectedAsset;
  final IconData fallbackIcon;
}

class _TabButton extends StatelessWidget {
  const _TabButton({required this.spec, required this.selected, required this.onTap});

  final _TabSpec spec;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = selected
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;

    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            selected ? spec.selectedAsset : spec.unselectedAsset,
            height: 22,
            width: 22,
            color: selected ? null : color,
            // The bundled PNGs are the source of truth; icons cover any gaps.
            errorBuilder: (_, __, ___) => Icon(spec.fallbackIcon, size: 22, color: color),
          ),
          const SizedBox(height: 5),
          Text(
            spec.label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _TabNavigator extends StatelessWidget {
  const _TabNavigator({required this.navigatorKey, required this.child});

  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  @override
  Widget build(BuildContext context) => Navigator(
        key: navigatorKey,
        onGenerateRoute: (settings) =>
            MaterialPageRoute(settings: settings, builder: (_) => child),
      );
}
