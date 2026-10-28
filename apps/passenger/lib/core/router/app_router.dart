import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/phone_screen.dart';
import '../../features/auth/presentation/otp_screen.dart';
import '../../features/home/presentation/home_shell.dart';
import '../../features/city/presentation/city_map_screen.dart';
import '../../features/city/presentation/ride_tracking_screen.dart';
import '../../features/region/presentation/region_search_screen.dart';
import '../../features/region/presentation/trip_list_screen.dart';
import '../../features/region/presentation/trip_details_screen.dart';
import '../../features/region/presentation/booking_confirm_screen.dart';
import '../../features/history/presentation/history_screen.dart';
import '../../features/support/presentation/support_list_screen.dart';
import '../../features/support/presentation/new_case_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/profile/presentation/payment_methods_screen.dart';
import '../../features/onboarding/presentation/language_selection_screen.dart';
import '../api/api_client.dart';
import '../providers/locale_provider.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final localeNotifier = ref.read(localeProvider.notifier);
  final isFirstLaunch = localeNotifier.isFirstLaunch;

  return GoRouter(
    initialLocation: isFirstLaunch ? '/language' : '/auth/phone',
    redirect: (context, state) async {
      final token = await readAccessToken();
      final hasToken = token != null && token.isNotEmpty;
      final location = state.matchedLocation;
      final inAuth = location.startsWith('/auth') || location == '/language';
      if (!hasToken && !inAuth) return '/auth/phone';
      if (hasToken && location.startsWith('/auth')) return '/home';
      return null;
    },
    routes: [
      // Language selection (first launch)
      GoRoute(
        path: '/language',
        builder: (_, __) => const LanguageSelectionScreen(),
      ),
      // Auth flow
      GoRoute(
        path: '/auth/phone',
        builder: (_, __) => const PhoneScreen(),
      ),
      GoRoute(
        path: '/auth/otp',
        builder: (_, state) {
          final extra = state.extra;
          if (extra is Map) {
            return OtpScreen(
              phone: extra['phone'] as String,
              debugCode: extra['code'] as String?,
            );
          }
          return OtpScreen(phone: extra as String);
        },
      ),

      // Main shell with bottom nav
      ShellRoute(
        builder: (context, state, child) => HomeShell(child: child),
        routes: [
          GoRoute(
            path: '/home',
            builder: (_, __) => const CityMapScreen(),
          ),
          GoRoute(
            path: '/region',
            builder: (_, __) => const RegionSearchScreen(),
            routes: [
              GoRoute(
                path: 'trips',
                builder: (_, state) {
                  final args = state.extra as Map<String, String>;
                  return TripListScreen(
                    origin: args['origin'] ?? '',
                    destination: args['destination'] ?? '',
                  );
                },
              ),
              GoRoute(
                path: 'trips/:tripId',
                builder: (_, state) {
                  final tripId = state.pathParameters['tripId']!;
                  return TripDetailsScreen(tripId: tripId);
                },
              ),
              GoRoute(
                path: 'trips/:tripId/book',
                builder: (_, state) {
                  final tripId = state.pathParameters['tripId']!;
                  return BookingConfirmScreen(tripId: tripId);
                },
              ),
            ],
          ),
          GoRoute(
            path: '/history',
            builder: (_, __) => const HistoryScreen(),
          ),
          GoRoute(
            path: '/support',
            builder: (_, __) => const SupportListScreen(),
            routes: [
              GoRoute(
                path: 'new',
                builder: (_, state) {
                  final args = state.extra as Map<String, String>?;
                  return NewCaseScreen(
                    referenceType: args?['referenceType'],
                    referenceId: args?['referenceId'],
                  );
                },
              ),
            ],
          ),
          GoRoute(
            path: '/profile',
            builder: (_, __) => const ProfileScreen(),
            routes: [
              GoRoute(
                path: 'payment-methods',
                builder: (_, __) => const PaymentMethodsScreen(),
              ),
            ],
          ),
        ],
      ),

      // Ride tracking (full-screen, no bottom nav)
      GoRoute(
        path: '/rides/:rideId',
        builder: (_, state) {
          final rideId = state.pathParameters['rideId']!;
          return RideTrackingScreen(rideId: rideId);
        },
      ),
    ],
  );
});
