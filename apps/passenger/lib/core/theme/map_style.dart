import 'package:flutter/material.dart';

class QadamMapStyle {
  const QadamMapStyle._();

  static const String tileUrl =
      'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}@2x.png';
  static const List<String> subdomains = ['a', 'b', 'c', 'd'];

  static const Color routeColor = Color(0xFF2F5BFF);
  static const Color routeBorder = Colors.white;
  static const Color driverRouteColor = Color(0xFFFFB020);
  static const Color pickupColor = Color(0xFF2F5BFF);
  static const Color dropoffColor = Color(0xFF0B1226);
  static const Color driverColor = Color(0xFF2F5BFF);
}
