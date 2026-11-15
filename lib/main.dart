import 'package:flutter/material.dart';
import 'screens/home_shell.dart';
import 'screens/pin_lock_screen.dart';
import 'state/finance_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CofiperApp());
}

class CofiperApp extends StatefulWidget {
  final bool enablePinGate;

  const CofiperApp({
    super.key,
    this.enablePinGate = true,
  });

  @override
  State<CofiperApp> createState() => _CofiperAppState();
}

class _CofiperAppState extends State<CofiperApp> with WidgetsBindingObserver {
  late final FinanceController _controller;

  /// `null` = Automático según la hora del día (6:00 AM - 5:59 PM Claro, 6:00 PM - 5:59 AM Oscuro)
  ThemeMode? _manualThemeOverride;
  late ThemeMode _effectiveThemeMode;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = FinanceController();
    _effectiveThemeMode = _resolveDayNightTheme();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  /// Detecta automáticamente si es de día (06:00 a 17:59 -> Modo Claro)
  /// o si es de noche (18:00 a 05:59 -> Modo Oscuro).
  ThemeMode _resolveDayNightTheme() {
    if (_manualThemeOverride != null) {
      return _manualThemeOverride!;
    }
    final hour = DateTime.now().hour;
    final isDayTime = hour >= 6 && hour < 18;
    return isDayTime ? ThemeMode.light : ThemeMode.dark;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final updated = _resolveDayNightTheme();
      if (updated != _effectiveThemeMode && mounted) {
        setState(() {
          _effectiveThemeMode = updated;
        });
      }
    }
  }

  void _cycleThemeMode() {
    setState(() {
      if (_manualThemeOverride == null) {
        // Alternar al opuesto del actual para probar o forzar
        _manualThemeOverride = _effectiveThemeMode == ThemeMode.light
            ? ThemeMode.dark
            : ThemeMode.light;
      } else {
        // Volver a detección automática por hora (Día / Noche)
        _manualThemeOverride = null;
      }
      _effectiveThemeMode = _resolveDayNightTheme();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkActive = _effectiveThemeMode == ThemeMode.dark;
    final isAutoDayNight = _manualThemeOverride == null;

    final shell = HomeShell(
      controller: _controller,
      isDarkMode: isDarkActive,
      isAutoDayNight: isAutoDayNight,
      onToggleDayNight: _cycleThemeMode,
    );

    return MaterialApp(
      title: 'COFIPER - Control Quincenal',
      debugShowCheckedModeBanner: false,
      themeMode: _effectiveThemeMode,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F766E),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF14B8A6),
          brightness: Brightness.dark,
        ),
      ),
      home: widget.enablePinGate ? PinLockGate(child: shell) : shell,
    );
  }
}
