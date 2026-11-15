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

class _CofiperAppState extends State<CofiperApp> {
  late final FinanceController _controller;

  @override
  void initState() {
    super.initState();
    _controller = FinanceController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shell = HomeShell(controller: _controller);
    return MaterialApp(
      title: 'COFIPER - Control Quincenal',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
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
