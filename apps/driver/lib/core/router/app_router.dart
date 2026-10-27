import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../api/api_service.dart';
import '../providers/locale_provider.dart';
import '../../features/auth/presentation/phone_screen.dart';
import '../../features/auth/presentation/otp_screen.dart';
import '../../features/home/presentation/home_shell.dart';
import '../../features/home/presentation/dashboard_screen.dart';
import '../../features/map/presentation/map_screen.dart';
import '../../features/offers/presentation/offer_screen.dart';
import '../../features/rides/presentation/active_ride_screen.dart';
import '../../features/region/presentation/my_trips_screen.dart';
import '../../features/region/presentation/create_trip_screen.dart';
import '../../features/wallet/presentation/wallet_screen.dart';
import '../../features/documents/presentation/documents_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/earnings/presentation/earnings_screen.dart';
import '../../features/vehicles/presentation/vehicle_manage_screen.dart';
import '../../features/onboarding/presentation/language_selection_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final localeNotifier = ref.read(localeProvider.notifier);
  final isFirstLaunch = localeNotifier.isFirstLaunch;

  return GoRouter(
    initialLocation: isFirstLaunch ? '/language' : '/auth/phone',
    routes: [
      // Language selection (first launch)
      GoRoute(
        path: '/language',
        builder: (_, __) => const LanguageSelectionScreen(),
      ),
      GoRoute(
        path: '/auth/phone',
        builder: (_, __) => const PhoneScreen(),
      ),
      GoRoute(
        path: '/auth/otp',
        builder: (_, state) => OtpScreen(phone: state.extra as String),
      ),
      ShellRoute(
        builder: (_, __, child) => HomeShell(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (_, __) => const DashboardScreen(),
            routes: [
              GoRoute(
                path: 'offer/:rideId',
                builder: (_, state) =>
                    OfferScreen(rideId: state.pathParameters['rideId']!),
              ),
              GoRoute(
                path: 'ride/:rideId',
                builder: (_, state) =>
                    ActiveRideScreen(rideId: state.pathParameters['rideId']!),
              ),
            ],
          ),
          GoRoute(
            path: '/map',
            builder: (_, __) => const MapScreen(),
          ),
          GoRoute(
            path: '/trips',
            builder: (_, __) => const MyTripsScreen(),
            routes: [
              GoRoute(
                path: 'new',
                builder: (_, __) => const CreateTripScreen(),
              ),
            ],
          ),
          GoRoute(
            path: '/wallet',
            builder: (_, __) => const WalletScreen(),
          ),
          GoRoute(
            path: '/earnings',
            builder: (_, __) => const EarningsScreen(),
          ),
          GoRoute(
            path: '/vehicles',
            builder: (_, __) => const VehicleManageScreen(),
          ),
          GoRoute(
            path: '/documents',
            builder: (_, __) => const DocumentsScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (_, __) => const ProfileScreen(),
          ),
        ],
      ),
    ],
  );
});
