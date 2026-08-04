import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/pulse_widgets.dart';
import '../../models/event.dart';
import '../../models/notice.dart';
import '../../providers/async_value.dart';
import '../../providers/auth_provider.dart';
import '../../providers/event_provider.dart';
import '../../providers/notice_provider.dart';
import '../../providers/site_provider.dart';
import '../events/event_details_screen.dart';
import '../events/event_list_screen.dart';
import '../events/widgets/event_card.dart';
import '../notices/notice_details_screen.dart';
import '../notices/notice_screen.dart';
import '../wallet/wallet_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _bannerIndex = 0;

  static const _banners = [
    'assets/pulse/header_image1.png',
    'assets/pulse/header_image2.png',
    'assets/pulse/header_image3.png',
  ];

  Future<void> _refresh() async {
    await Future.wait([
      context.read<EventProvider>().loadUpcoming(refresh: true),
      context.read<NoticeProvider>().load(refresh: true),
      context.read<AuthProvider>().refreshUser(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = context.watch<AuthProvider>().user;
    final site = context.watch<SiteProvider>().currentSite;
    final events = context.watch<EventProvider>().upcoming;
    final notices = context.watch<NoticeProvider>().notices;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Row(
                    children: [
                      SvgPicture.asset(
                        greetingAsset(),
                        height: 30,
                        width: 30,
                        placeholderBuilder: (_) => const SizedBox(width: 30, height: 30),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(greeting(), style: theme.textTheme.bodySmall),
                            Text(
                              user?.displayName.isNotEmpty == true
                                  ? user!.displayName
                                  : 'Welcome',
                              style: theme.textTheme.titleLarge,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      _IconAction(
                        icon: Icons.account_balance_wallet_outlined,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const WalletScreen()),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _IconAction(
                        icon: Icons.notifications_none_rounded,
                        badge: notices.data
                            ?.where((n) => n.isImportant)
                            .length,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const NoticeScreen()),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (site != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                    child: Row(
                      children: [
                        const Icon(Icons.place_rounded,
                            size: 15, color: AppColors.primary),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            site.name,
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              SliverToBoxAdapter(child: _buildBanner()),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: _WalletStrip(
                    balance: user?.walletBalance ?? 0,
                    points: user?.loyaltyPoints ?? 0,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const WalletScreen()),
                    ),
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                  child: SectionHeader(
                    title: 'Happening soon',
                    actionLabel: 'See all',
                    onAction: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const EventListScreen()),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(child: _buildEventRail(events)),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                  child: SectionHeader(
                    title: 'Notices',
                    actionLabel: 'See all',
                    onAction: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const NoticeScreen()),
                    ),
                  ),
                ),
              ),
              _buildNotices(notices.data),

              const SliverToBoxAdapter(child: SizedBox(height: 28)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBanner() => Padding(
        padding: const EdgeInsets.only(top: 18),
        child: Column(
          children: [
            CarouselSlider(
              options: CarouselOptions(
                height: 160,
                viewportFraction: 0.88,
                autoPlay: true,
                autoPlayInterval: const Duration(seconds: 5),
                enlargeCenterPage: true,
                enlargeFactor: 0.16,
                onPageChanged: (i, _) => setState(() => _bannerIndex = i),
              ),
              items: _banners
                  .map((asset) => ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.asset(
                          asset,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          errorBuilder: (_, __, ___) => Container(
                            color: AppColors.primary.withValues(alpha: 0.12),
                          ),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _banners.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  height: 6,
                  width: _bannerIndex == i ? 18 : 6,
                  decoration: BoxDecoration(
                    color: _bannerIndex == i
                        ? AppColors.primary
                        : Theme.of(context).colorScheme.outline,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ],
        ),
      );

  Widget _buildEventRail(AsyncValue<List<Event>> events) {
    if (events.isLoading && !events.hasData) {
      return SizedBox(
        height: 210,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: 3,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (_, __) => const ShimmerBox(height: 210, width: 220, radius: 14),
        ),
      );
    }

    final list = events.data ?? const <Event>[];
    if (list.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: EmptyState(
          title: 'Nothing scheduled yet',
          message: 'New events for your park will show up here.',
          icon: Icons.event_outlined,
        ),
      );
    }

    return SizedBox(
      height: 210,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) => EventMiniCard(
          event: list[i],
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => EventDetailsScreen(eventId: list[i].id),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotices(List<Notice>? notices) {
    if (notices == null) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: CardListSkeleton(count: 2, height: 82),
        ),
      );
    }
    if (notices.isEmpty) {
      return const SliverToBoxAdapter(
        child: EmptyState(
          title: 'No notices right now',
          message: 'Announcements from the estate team appear here.',
          icon: Icons.campaign_outlined,
        ),
      );
    }

    final top = notices.take(3).toList();
    return SliverList.separated(
      itemCount: top.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: _NoticeTile(notice: top[i]),
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({required this.icon, required this.onTap, this.badge});

  final IconData icon;
  final VoidCallback onTap;
  final int? badge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.colorScheme.outline),
            ),
            child: Icon(icon, size: 20, color: theme.colorScheme.onSurface),
          ),
          if (badge != null && badge! > 0)
            Positioned(
              top: -3,
              right: -3,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                constraints: const BoxConstraints(minWidth: 18),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: theme.scaffoldBackgroundColor, width: 1.5),
                ),
                child: Text(
                  '$badge',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _WalletStrip extends StatelessWidget {
  const _WalletStrip({
    required this.balance,
    required this.points,
    required this.onTap,
  });

  final double balance;
  final int points;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.primaryDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pulse wallet',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    money(balance),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            Container(width: 1, height: 40, color: Colors.white24),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'Privilege points',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.stars_rounded, size: 17, color: AppColors.accent),
                    const SizedBox(width: 5),
                    Text(
                      compactNumber(points),
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NoticeTile extends StatelessWidget {
  const _NoticeTile({required this.notice});

  final Notice notice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => NoticeDetailsScreen(notice: notice)),
      ),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.colorScheme.outline),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 38,
              width: 38,
              decoration: BoxDecoration(
                color: (notice.isImportant ? AppColors.danger : AppColors.primary)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                notice.isImportant
                    ? Icons.priority_high_rounded
                    : Icons.campaign_outlined,
                size: 19,
                color: notice.isImportant ? AppColors.danger : AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notice.title,
                    style: theme.textTheme.titleSmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      if (notice.category != null) ...[
                        Text(notice.category!, style: theme.textTheme.labelSmall),
                        Text(' · ', style: theme.textTheme.labelSmall),
                      ],
                      Text(relativeTime(notice.createdAt),
                          style: theme.textTheme.labelSmall),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 20, color: theme.colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
