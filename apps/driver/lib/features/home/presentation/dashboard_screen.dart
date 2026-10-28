import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_service.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/qadam_ui.dart';

final _profileProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  return ref.read(driverApiProvider).getProfile();
});

final _offersProvider = FutureProvider<List<dynamic>>((ref) async {
  return ref.read(driverApiProvider).getOffers();
});

final _activeRideProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  return ref.read(driverApiProvider).getActiveRide();
});

final _walletProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  return ref.read(driverApiProvider).getWalletBalance();
});

final _onlineProvider = StateProvider<bool>((ref) => false);

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  Timer? _heartbeatTimer;
  Timer? _offersTimer;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    // New offers must appear without a manual refresh.
    _offersTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (!mounted) return;
      ref.invalidate(_offersProvider);
      ref.invalidate(_activeRideProvider);
      ref.invalidate(_walletProvider);
    });
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    _offersTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await ref.read(driverApiProvider).getProfile();
      final status = profile['online_status'];
      final online = status == 'online' || status == 'busy';
      ref.read(_onlineProvider.notifier).state = online;
      if (online) _startHeartbeat();
    } catch (e) {
      debugPrint('PROFILE LOAD ERROR: $e');
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _sendLocation();
    _heartbeatTimer =
        Timer.periodic(const Duration(seconds: 15), (_) => _sendLocation());
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  /// Dispatch only considers drivers with a known location, so the driver
  /// must report its position while online.
  Future<void> _sendLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      await ref
          .read(driverApiProvider)
          .updateLocation(pos.latitude, pos.longitude);
    } catch (e) {
      debugPrint('LOCATION HEARTBEAT ERROR: $e');
    }
  }

  Future<void> _toggleOnline(bool newVal) async {
    try {
      final api = ref.read(driverApiProvider);
      final result = await api.setOnline(newVal);
      final online = result['online_status'] == 'online';
      ref.read(_onlineProvider.notifier).state = online;
      if (online) {
        _startHeartbeat();
        ref.invalidate(_offersProvider);
      } else {
        _stopHeartbeat();
      }
    } catch (e) {
      HapticFeedback.mediumImpact();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final offersAsync = ref.watch(_offersProvider);
    final activeRideAsync = ref.watch(_activeRideProvider);
    final isOnline = ref.watch(_onlineProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(_profileProvider);
            ref.invalidate(_offersProvider);
            ref.invalidate(_activeRideProvider);
            ref.invalidate(_walletProvider);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Row(
                children: [
                  const QadamWordmark(size: 20, subtitle: 'DRIVER'),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => context.go('/profile'),
                    child: const QadamAvatar(size: 44),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _OnlineCard(isOnline: isOnline, onToggle: _toggleOnline),
              const SizedBox(height: 14),
              _EarningsCard(),
              activeRideAsync.maybeWhen(
                data: (ride) => ride == null
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.only(top: 20),
                        child: _ActiveRideCard(
                          ride: ride,
                          onTap: () =>
                              context.push('/dashboard/ride/${ride['id']}'),
                        ),
                      ),
                orElse: () => const SizedBox.shrink(),
              ),
              const SizedBox(height: 24),
              QadamSectionLabel(
                l10n.incomingOrders,
                trailing: offersAsync.maybeWhen(
                  data: (offers) => offers.isEmpty
                      ? const SizedBox.shrink()
                      : QadamTag(
                          label: '${offers.length}',
                          color: AppTheme.primary,
                        ),
                  orElse: () => const SizedBox.shrink(),
                ),
              ),
              const SizedBox(height: 12),
              offersAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    ),
                  ),
                ),
                error: (e, _) => Text(
                  '${l10n.loadError}: $e',
                  style: const TextStyle(color: AppTheme.error),
                ),
                data: (offers) {
                  if (offers.isEmpty) {
                    return _EmptyOffers(isOnline: isOnline);
                  }
                  return Column(
                    children: offers
                        .map(
                          (o) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _OfferCard(
                              offer: o as Map<String, dynamic>,
                              onTap: () => context.push(
                                '/dashboard/offer/${o['ride_order_id']}',
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnlineCard extends StatelessWidget {
  const _OnlineCard({required this.isOnline, required this.onToggle});
  final bool isOnline;
  final Future<void> Function(bool) onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return QadamGradientCard(
      gradient: isOnline
          ? AppTheme.brandGradient
          : const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF2A3350), AppTheme.ink],
            ),
      padding: const EdgeInsets.fromLTRB(22, 20, 18, 20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isOnline
                            ? const Color(0xFF8BFFE4)
                            : Colors.white.withOpacity(0.45),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isOnline
                          ? l10n.youAreOnline
                          : l10n.youAreOffline,
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  isOnline ? l10n.receivingOrders : l10n.tapToStart,
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    color: Colors.white.withOpacity(0.78),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Transform.scale(
            scale: 1.15,
            child: Switch(
              value: isOnline,
              onChanged: onToggle,
              activeColor: AppTheme.primary,
              activeTrackColor: Colors.white,
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: Colors.white.withOpacity(0.25),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveRideCard extends StatelessWidget {
  const _ActiveRideCard({required this.ride, required this.onTap});

  final Map<String, dynamic> ride;
  final VoidCallback onTap;

  String _statusLabel(String? status) {
    switch (status) {
      case 'assigned':
        return 'Едьте к пассажиру';
      case 'driver_arriving':
        return 'В пути к пассажиру';
      case 'driver_arrived':
        return 'Вы на месте';
      case 'in_progress':
        return 'Поездка идёт';
      default:
        return 'Текущая поездка';
    }
  }

  @override
  Widget build(BuildContext context) {
    return QadamCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      borderColor: AppTheme.primary.withOpacity(0.35),
      child: Row(
        children: [
          const QadamIconBadge(icon: Icons.local_taxi_rounded, size: 46),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _statusLabel(ride['status'] as String?),
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  ride['dropoff_address']?.toString() ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppTheme.textSecondary,
          ),
        ],
      ),
    );
  }
}

class _EarningsCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final walletAsync = ref.watch(_walletProvider);

    return QadamGradientCard(
      gradient: AppTheme.sunGradient,
      padding: const EdgeInsets.fromLTRB(22, 20, 18, 20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.account_balance_wallet_rounded,
                      size: 16,
                      color: AppTheme.ink.withOpacity(0.65),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      l10n.walletBalance,
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                        color: AppTheme.ink.withOpacity(0.65),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  walletAsync.maybeWhen(
                    data: (wallet) => '${wallet['balance']} ${l10n.som}',
                    orElse: () => '— ${l10n.som}',
                  ),
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 30,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                    color: AppTheme.ink,
                  ),
                ),
              ],
            ),
          ),
          Material(
            color: Colors.white.withOpacity(0.6),
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => GoRouter.of(context).go('/wallet'),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Text(
                      l10n.details,
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.ink,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      size: 15,
                      color: AppTheme.ink,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({required this.offer, required this.onTap});
  final Map<String, dynamic> offer;
  final VoidCallback onTap;

  String _addr(dynamic v) => (v as String? ?? '').trim().isEmpty ? '—' : v as String;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final net = offer['net_estimate'];
    final eta = offer['eta_min'];
    final price = offer['quoted_price'];
    final pickup = _addr(offer['pickup_address']);
    final dropoff = _addr(offer['dropoff_address']);

    return QadamCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  gradient: AppTheme.brandGradient,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.local_taxi_rounded,
                  color: Colors.white,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.newOrder,
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    if (eta != null)
                      Text(
                        '${l10n.toPassenger}: ~$eta мин',
                        style: const TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              if (net != null)
                QadamTag(
                  label: '$net ${l10n.som}',
                  color: AppTheme.earningsGreen,
                  background: AppTheme.mint,
                ),
              if (price != null && net == null)
                QadamTag(
                  label: '$price ${l10n.som}',
                  color: AppTheme.primary,
                  background: AppTheme.lavender,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: const BoxDecoration(
                      gradient: AppTheme.brandGradient,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Container(width: 2, height: 18, color: AppTheme.divider),
                  Container(
                    width: 9,
                    height: 9,
                    decoration: const BoxDecoration(
                      color: AppTheme.ink,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pickup,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dropoff,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyOffers extends StatelessWidget {
  const _EmptyOffers({required this.isOnline});
  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return QadamCard(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      child: Column(
        children: [
          QadamIconBadge(
            icon: isOnline
                ? Icons.radar_rounded
                : Icons.power_settings_new_rounded,
            color: isOnline ? AppTheme.primary : AppTheme.textSecondary,
            size: 60,
          ),
          const SizedBox(height: 16),
          Text(
            isOnline ? l10n.waitingOrders : l10n.enableOnline,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.4,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
