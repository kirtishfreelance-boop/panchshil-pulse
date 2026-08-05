import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/pulse_widgets.dart';
import '../../models/amenity.dart';
import '../../providers/amenity_provider.dart';
import 'facility_detail_screen.dart';
import 'my_bookings_screen.dart';

/// Browse bookable facilities, filtered by type.
class AmenitiesScreen extends StatefulWidget {
  const AmenitiesScreen({super.key});

  @override
  State<AmenitiesScreen> createState() => _AmenitiesScreenState();
}

class _AmenitiesScreenState extends State<AmenitiesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<AmenityProvider>();
      provider
        ..loadCategories()
        ..loadFacilities();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AmenityProvider>();
    final categories = provider.categories.data ?? const <FacilityCategory>[];
    final state = provider.facilities;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Amenities'),
        actions: [
          IconButton(
            tooltip: 'My bookings',
            icon: const Icon(Icons.event_available_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MyBookingsScreen()),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          if (categories.isNotEmpty)
            SizedBox(
              height: 54,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                children: [
                  _Chip(
                    label: 'All',
                    selected: provider.activeCategoryId == null,
                    onTap: () => provider.loadFacilities(),
                  ),
                  ...categories.map(
                    (c) => _Chip(
                      label: '${c.name} (${c.facilityCount})',
                      selected: provider.activeCategoryId == c.id,
                      onTap: () => provider.loadFacilities(categoryId: c.id),
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
                    child: CardListSkeleton(count: 3, height: 210),
                  );
                }
                if (state.hasError && !state.hasData) {
                  return ErrorView(
                    message: state.error!,
                    onRetry: () => provider.loadFacilities(
                      categoryId: provider.activeCategoryId,
                    ),
                  );
                }

                final facilities = state.data ?? const <Facility>[];
                if (facilities.isEmpty) {
                  return const EmptyState(
                    title: 'Nothing bookable here yet',
                    message: 'Amenities added by the estate team will show up here.',
                    icon: Icons.meeting_room_outlined,
                  );
                }

                return RefreshIndicator(
                  onRefresh: () => provider.loadFacilities(
                    categoryId: provider.activeCategoryId,
                  ),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                    itemCount: facilities.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemBuilder: (_, i) => _FacilityCard(facility: facilities[i]),
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

class _FacilityCard extends StatelessWidget {
  const _FacilityCard({required this.facility});

  final Facility facility;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => FacilityDetailScreen(facility: facility)),
      ),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.outline),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                PulseImage(url: facility.coverImage, height: 140, width: double.infinity),
                if (facility.categoryName != null)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface.withValues(alpha: 0.94),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        facility.categoryName!,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(facility.name, style: theme.textTheme.titleMedium),
                  if (facility.location != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.place_outlined,
                            size: 14, color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            facility.location!,
                            style: theme.textTheme.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.schedule_rounded,
                          size: 14, color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 5),
                      Text(
                        '${facility.opensLabel} – ${facility.closesLabel} · ${facility.slotMinutes} min slots',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        facility.isFree ? 'Free' : money(facility.pricePerSlot),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: facility.isFree ? AppColors.success : null,
                        ),
                      ),
                      if (!facility.isFree)
                        Text(' per slot', style: theme.textTheme.bodySmall),
                      const Spacer(),
                      if (facility.capacity > 0)
                        PulseChip(
                          label: 'Seats ${facility.capacity}',
                          icon: Icons.groups_rounded,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
