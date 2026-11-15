import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PinSecurityManager {
  static const String _pinStorageKey = 'cofiper_security_pin_v1';
  static const String defaultPin = '1234';

  static Future<String> getSavedPin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_pinStorageKey);
      if (saved != null && saved.length == 4) {
        return saved;
      }
    } catch (_) {}
    return defaultPin;
  }

  static Future<void> saveNewPin(String newPin) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_pinStorageKey, newPin);
    } catch (_) {}
  }
}

class PinLockGate extends StatefulWidget {
  final Widget child;

  const PinLockGate({
    super.key,
    required this.child,
  });

  static void lockApp(BuildContext context) {
    final state = context.findAncestorStateOfType<_PinLockGateState>();
    state?._lockNow();
  }

  static Future<void> showChangePinDialog(BuildContext context) async {
    final currentPinCtrl = TextEditingController();
    final newPinCtrl = TextEditingController();
    final savedPin = await PinSecurityManager.getSavedPin();

    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.lock_reset_rounded, color: Color(0xFF059669)),
            SizedBox(width: 8),
            Expanded(child: Text('Cambiar PIN de Seguridad')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Ingresa tu PIN actual de 4 dígitos y el nuevo PIN con el que deseas proteger tu app COFIPER:',
              style: TextStyle(fontSize: 12.5),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: currentPinCtrl,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 4,
              decoration: const InputDecoration(
                labelText: 'PIN Actual (Por defecto: 1234)',
                prefixIcon: Icon(Icons.lock_outline_rounded),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: newPinCtrl,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 4,
              decoration: const InputDecoration(
                labelText: 'Nuevo PIN (4 números)',
                prefixIcon: Icon(Icons.key_rounded),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              final currentInput = currentPinCtrl.text.trim();
              final nextInput = newPinCtrl.text.trim();

              if (currentInput != savedPin) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text('El PIN actual ingresado no es correcto.'),
                  ),
                );
                return;
              }

              if (nextInput.length != 4 || int.tryParse(nextInput) == null) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content:
                        Text('El nuevo PIN debe tener exactamente 4 números.'),
                  ),
                );
                return;
              }

              await PinSecurityManager.saveNewPin(nextInput);
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      '¡PIN de seguridad actualizado y guardado en tu teléfono!'),
                ),
              );
            },
            child: const Text('Guardar Nuevo PIN'),
          ),
        ],
      ),
    );
  }

  @override
  State<PinLockGate> createState() => _PinLockGateState();
}

class _PinLockGateState extends State<PinLockGate> {
  bool _isUnlocked = false;
  String _expectedPin = PinSecurityManager.defaultPin;
  String _enteredPin = '';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPin();
  }

  Future<void> _loadPin() async {
    final pin = await PinSecurityManager.getSavedPin();
    if (mounted) {
      setState(() {
        _expectedPin = pin;
      });
    }
  }

  void _lockNow() {
    _loadPin();
    setState(() {
      _isUnlocked = false;
      _enteredPin = '';
      _errorMessage = null;
    });
  }

  void _onDigitPressed(String digit) {
    if (_enteredPin.length >= 4) return;

    setState(() {
      _enteredPin += digit;
      _errorMessage = null;
    });

    if (_enteredPin.length == 4) {
      if (_enteredPin == _expectedPin) {
        setState(() {
          _isUnlocked = true;
          _enteredPin = '';
          _errorMessage = null;
        });
      } else {
        setState(() {
          _enteredPin = '';
          _errorMessage = 'PIN incorrecto. Inténtalo de nuevo.';
        });
      }
    }
  }

  void _onBackspace() {
    if (_enteredPin.isEmpty) return;
    setState(() {
      _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isUnlocked) {
      return widget.child;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0B172A),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icono de escudo financiero COFIPER
                Container(
                  width: 78,
                  height: 78,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF059669), Color(0xFF0EA5E9)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF10B981).withValues(alpha: 0.35),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      'C\$',
                      style: TextStyle(
                        color: Color(0xFFFDE68A),
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'COFIPER · Acceso Seguro',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _expectedPin == PinSecurityManager.defaultPin
                      ? 'Ingresa tu PIN de 4 dígitos (PIN inicial: 1234)'
                      : 'Ingresa tu PIN personal de 4 dígitos para continuar',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 24),

                // Indicadores de los 4 dígitos
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (index) {
                    final filled = index < _enteredPin.length;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: filled
                            ? const Color(0xFF34D399)
                            : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: filled
                              ? const Color(0xFF34D399)
                              : Colors.white38,
                          width: 2,
                        ),
                      ),
                    );
                  }),
                ),

                if (_errorMessage != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(
                      color: Color(0xFFFCA5A5),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],

                const SizedBox(height: 28),

                // Teclado numérico bancario
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 290),
                  child: Column(
                    children: [
                      _buildKeyRow(['1', '2', '3']),
                      const SizedBox(height: 14),
                      _buildKeyRow(['4', '5', '6']),
                      const SizedBox(height: 14),
                      _buildKeyRow(['7', '8', '9']),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          const SizedBox(width: 68, height: 68),
                          _PinKeyButton(
                            label: '0',
                            onTap: () => _onDigitPressed('0'),
                          ),
                          SizedBox(
                            width: 68,
                            height: 68,
                            child: IconButton(
                              onPressed: _onBackspace,
                              icon: const Icon(
                                Icons.backspace_outlined,
                                color: Colors.white70,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKeyRow(List<String> digits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: digits
          .map(
            (d) => _PinKeyButton(
              label: d,
              onTap: () => _onDigitPressed(d),
            ),
          )
          .toList(),
    );
  }
}

class _PinKeyButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PinKeyButton({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 68,
      height: 68,
      child: Material(
        color: Colors.white.withValues(alpha: 0.08),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
