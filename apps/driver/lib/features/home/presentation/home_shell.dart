import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.child});
  final Widget child;

  static const _tabs = [
    (icon: Icons.map_outlined, activeIcon: Icons.map, label: 'Карта', path: '/map'),
    (icon: Icons.directions_bus_outlined, activeIcon: Icons.directions_bus, label: 'Рейсы', path: '/trips'),
    (icon: Icons.account_balance_wallet_outlined, activeIcon: Icons.account_balance_wallet, label: 'Кошелёк', path: '/wallet'),
    (icon: Icons.description_outlined, activeIcon: Icons.description, label: 'Документы', path: '/documents'),
    (icon: Icons.person_outline, activeIcon: Icons.person, label: 'Профиль', path: '/profile'),
  ];

  int _idx(BuildContext ctx) {
    final loc = GoRouterState.of(ctx).matchedLocation;
    for (var i = 0; i < _tabs.length; i++) {
      if (loc.startsWith(_tabs[i].path)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final cur = _idx(context);
    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: cur,
        onTap: (i) => context.go(_tabs[i].path),
        items: _tabs
            .map((t) => BottomNavigationBarItem(
                  icon: Icon(t.icon),
                  activeIcon: Icon(t.activeIcon),
                  label: t.label,
                ))
            .toList(),
      ),
    );
  }
}
