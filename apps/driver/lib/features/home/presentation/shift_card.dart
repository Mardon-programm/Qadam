import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/qadam_ui.dart';

class ShiftCard extends StatefulWidget {
  const ShiftCard({super.key});

  @override
  State<ShiftCard> createState() => _ShiftCardState();
}

class _ShiftCardState extends State<ShiftCard> {
  static const _startKey = 'qadam_shift_start_v1';
  static const _activeKey = 'qadam_shift_active_v1';

  bool _active = false;
  DateTime? _start;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _active) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _active = prefs.getBool(_activeKey) ?? false;
      final ms = prefs.getInt(_startKey);
      if (ms != null) _start = DateTime.fromMillisecondsSinceEpoch(ms);
    });
  }

  Future<void> _toggle() async {
    final prefs = await SharedPreferences.getInstance();
    if (_active) {
      await prefs.setBool(_activeKey, false);
      await prefs.remove(_startKey);
      setState(() {
        _active = false;
        _start = null;
      });
    } else {
      final now = DateTime.now();
      await prefs.setBool(_activeKey, true);
      await prefs.setInt(_startKey, now.millisecondsSinceEpoch);
      setState(() {
        _active = true;
        _start = now;
      });
    }
  }

  String _duration() {
    if (_start == null) return '00:00:00';
    final d = DateTime.now().difference(_start!);
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return QadamCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      radius: 22,
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: _active ? AppTheme.brandGradient : const LinearGradient(
                colors: [Color(0xFFCBD5F5), Color(0xFFE8ECF4)],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.timer_rounded,
              color: _active ? Colors.white : AppTheme.textSecondary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _active ? 'Смена в работе' : 'Смена не начата',
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  _active ? 'Время в онлайн: ${_duration()}' : 'Нажмите, чтобы засечь время смены',
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
          TextButton(
            onPressed: _toggle,
            child: Text(
              _active ? 'Завершить' : 'Начать смену',
              style: const TextStyle(
                fontFamily: 'Manrope',
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
