import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:panchshil_pulse/core/network/api_exception.dart';
import 'package:panchshil_pulse/core/theme/app_colors.dart';
import 'package:panchshil_pulse/core/theme/app_theme.dart';
import 'package:panchshil_pulse/core/utils/formatters.dart';
import 'package:panchshil_pulse/models/event.dart';
import 'package:panchshil_pulse/models/user.dart';
import 'package:panchshil_pulse/providers/async_value.dart';

void main() {
  group('AppUser', () {
    test('builds initials from a full name', () {
      const user = AppUser(id: 1, mobile: '9999999999', fullName: 'Aarav Mehta');
      expect(user.initials, 'AM');
    });

    test('falls back to first and last name when full_name is absent', () {
      const user = AppUser(
        id: 1,
        mobile: '9999999999',
        firstname: 'Ishita',
        lastname: 'Rao',
      );
      expect(user.displayName, 'Ishita Rao');
      expect(user.initials, 'IR');
    });

    test('handles a single-word name without crashing', () {
      const user = AppUser(id: 1, mobile: '9999999999', fullName: 'Prakash');
      expect(user.initials, 'P');
    });
  });

  group('Event', () {
    Map<String, dynamic> payload({
      bool past = false,
      int? seatsLeft = 10,
      Map<String, dynamic>? registration,
    }) =>
        {
          'id': 4,
          'title': 'Design Thinking Masterclass',
          'starts_at': '2026-08-16T10:00:00.000Z',
          'ends_at': '2026-08-16T16:00:00.000Z',
          'is_paid': true,
          'amount': 1500,
          'capacity': 40,
          'seats_taken': 0,
          'seats_left': seatsLeft,
          'is_past': past,
          'registration': registration,
        };

    test('parses the API payload', () {
      final event = Event.fromJson(payload());
      expect(event.id, 4);
      expect(event.isPaid, isTrue);
      expect(event.amount, 1500);
      expect(event.canRegister, isTrue);
    });

    test('is not registerable once sold out', () {
      final event = Event.fromJson(payload(seatsLeft: 0));
      expect(event.isSoldOut, isTrue);
      expect(event.canRegister, isFalse);
    });

    test('is not registerable after it has ended', () {
      final event = Event.fromJson(payload(past: true));
      expect(event.canRegister, isFalse);
    });

    test('surfaces an existing registration', () {
      final event = Event.fromJson(payload(registration: {
        'id': 9,
        'guests': 1,
        'amount_paid': 3000,
        'payment_status': 'paid',
        'ticket_code': 'PLS-4-1-3P6Q4N',
        'attended': false,
      }));
      expect(event.isRegistered, isTrue);
      expect(event.registration!.ticketCode, 'PLS-4-1-3P6Q4N');
      expect(event.canRegister, isFalse);
    });

    test('tolerates a malformed timestamp', () {
      final event = Event.fromJson({'id': 1, 'title': 'X', 'starts_at': 'nonsense'});
      expect(event.startsAt, isA<DateTime>());
    });
  });

  group('formatters', () {
    test('formats rupees in the Indian numbering system', () {
      expect(money(3000), '₹3,000');
      expect(money(150000), '₹1,50,000');
    });

    test('collapses a same-day event into one time range', () {
      final start = DateTime(2026, 8, 16, 10);
      final end = DateTime(2026, 8, 16, 16);
      expect(eventWhen(start, end), '16 Aug, 10:00 AM – 4:00 PM');
    });

    test('spells out both dates when an event spans days', () {
      final start = DateTime(2026, 8, 16, 22);
      final end = DateTime(2026, 8, 17, 2);
      expect(eventWhen(start, end), contains('17 Aug'));
    });

    test('reports a past event as ended', () {
      expect(countdown(DateTime.now().subtract(const Duration(days: 1))), 'Ended');
    });
  });

  group('AsyncValue', () {
    test('keeps previous data while refreshing', () {
      const loaded = AsyncValue.data([1, 2, 3]);
      final refreshing = loaded.toLoading();
      expect(refreshing.isLoading, isTrue);
      expect(refreshing.data, [1, 2, 3]);
    });

    test('reports an error without data', () {
      const failed = AsyncValue<List<int>>.error('offline');
      expect(failed.hasError, isTrue);
      expect(failed.hasData, isFalse);
    });
  });

  group('ApiException', () {
    test('flags the status codes the UI branches on', () {
      const unauthorized = ApiException('nope', statusCode: 401);
      const payment = ApiException('nope', statusCode: 402);
      const conflict = ApiException('nope', statusCode: 409);
      expect(unauthorized.isUnauthorized, isTrue);
      expect(payment.isPaymentRequired, isTrue);
      expect(conflict.isConflict, isTrue);
    });
  });

  group('theme', () {
    test('builds both themes on the brand palette', () {
      expect(AppTheme.light.colorScheme.primary, AppColors.primary);
      expect(AppTheme.dark.colorScheme.primary, AppColors.primary);
      expect(AppTheme.dark.brightness, Brightness.dark);
    });

    test('gives the same seed the same category tint', () {
      expect(AppColors.tintFor('Wellness'), AppColors.tintFor('Wellness'));
    });
  });
}
