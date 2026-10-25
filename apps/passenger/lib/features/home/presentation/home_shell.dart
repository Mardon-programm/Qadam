import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.child});
  final Widget child;

  static const _tabs = [
    _TabItem(icon: Icons.map_outlined, activeIcon: Icons.map, label: 'Такси', path: '/home'),
    _TabItem(icon: Icons.directions_bus_outlined, activeIcon: Icons.directions_bus, label: 'Межгород', path: '/region'),
    _TabItem(icon: Icons.history_outlined, activeIcon: Icons.history, label: 'История', path: '/history'),
    _TabItem(icon: Icons.headset_mic_outlined, activeIcon: Icons.headset_mic, label: 'Поддержка', path: '/support'),
    _TabItem(icon: Icons.person_outline, activeIcon: Icons.person, label: 'Профиль', path: '/profile'),
  ];

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    for (var i = 0; i < _tabs.length; i++) {
      if (location.startsWith(_tabs[i].path)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final current = _currentIndex(context);
    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: current,
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

class _TabItem {
  const _TabItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.path,
  });
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String path;
}
