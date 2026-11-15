import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/platform_network_helper.dart';

class PinSecurityManager {
  static const String _pinStorageKey = 'cofiper_custom_pin_v2';
  static const String _recoveryEmailKey = 'cofiper_recovery_email_v2';
  static const String _gmailUserKey = 'cofiper_gmail_user_v1';
  static const String _gmailPassKey = 'cofiper_gmail_app_pass_v1';

  /// Devuelve `null` si el usuario aún no ha creado su PIN por primera vez.
  static Future<String?> getSavedPin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_pinStorageKey);
      if (saved != null && saved.length == 4) {
        return saved;
      }
    } catch (_) {}
    return null;
  }

  static Future<String> getSavedRecoveryEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_recoveryEmailKey) ?? '';
    } catch (_) {
      return '';
    }
  }

  static Future<void> savePinAndEmail({
    required String pin,
    required String recoveryEmail,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_pinStorageKey, pin.trim());
      if (recoveryEmail.trim().isNotEmpty) {
        await prefs.setString(
            _recoveryEmailKey, recoveryEmail.trim().toLowerCase());
      }
    } catch (_) {}
  }

  static Future<bool> trySendPinToEmail(String targetEmail) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentPin = prefs.getString(_pinStorageKey) ?? '';
      final senderGmail = prefs.getString(_gmailUserKey) ?? '';
      final senderPass = prefs.getString(_gmailPassKey) ?? '';
      if (currentPin.isEmpty) return false;

      return await sendRecoveryEmailViaSmtp(
        recipientEmail: targetEmail,
        currentPin: currentPin,
        senderGmail: senderGmail.isNotEmpty ? senderGmail : targetEmail,
        senderAppPassword: senderPass,
      );
    } catch (_) {
      return false;
    }
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
    final savedEmail = await PinSecurityManager.getSavedRecoveryEmail();
    final emailCtrl = TextEditingController(text: savedEmail);

    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.lock_reset_rounded, color: Color(0xFF059669)),
            SizedBox(width: 8),
            Expanded(child: Text('Cambiar PIN y Correo')),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Actualiza tu PIN de 4 dígitos o tu correo electrónico de recuperación:',
                style: TextStyle(fontSize: 12.5),
              ),
              const SizedBox(height: 12),
              if (savedPin != null) ...[
                TextField(
                  controller: currentPinCtrl,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 4,
                  decoration: const InputDecoration(
                    labelText: 'Tu PIN Actual (4 números)',
                    prefixIcon: Icon(Icons.lock_outline_rounded),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
              ],
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
              const SizedBox(height: 10),
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Correo para recuperar PIN',
                  hintText: 'tucorreo@gmail.com',
                  prefixIcon: Icon(Icons.email_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
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
              final nextEmail = emailCtrl.text.trim();

              if (savedPin != null && currentInput != savedPin) {
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

              if (nextEmail.isEmpty || !nextEmail.contains('@')) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text('Ingresa un correo electrónico válido.'),
                  ),
                );
                return;
              }

              await PinSecurityManager.savePinAndEmail(
                pin: nextInput,
                recoveryEmail: nextEmail,
              );
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      '¡PIN y correo de recuperación actualizados con éxito!'),
                ),
              );
            },
            child: const Text('Guardar Cambios'),
          ),
        ],
      ),
    );
  }

  @override
  State<PinLockGate> createState() => _PinLockGateState();
}

class _PinLockGateState extends State<PinLockGate> {
  bool _isLoading = true;
  bool _isUnlocked = false;

  /// Si `_expectedPin` es `null`, significa que es la primera vez que el usuario abre la app
  /// y debe crear su propio PIN de 4 dígitos + correo de recuperación.
  String? _expectedPin;
  String _recoveryEmail = '';
  String _enteredPin = '';
  String? _errorMessage;

  // Controladores para la pantalla de creación inicial de PIN (Primera vez)
  final _firstPinCtrl = TextEditingController();
  final _confirmPinCtrl = TextEditingController();
  final _setupEmailCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPinState();
  }

  @override
  void dispose() {
    _firstPinCtrl.dispose();
    _confirmPinCtrl.dispose();
    _setupEmailCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPinState() async {
    final pin = await PinSecurityManager.getSavedPin();
    final email = await PinSecurityManager.getSavedRecoveryEmail();
    if (mounted) {
      setState(() {
        _expectedPin = pin;
        _recoveryEmail = email;
        _isLoading = false;
      });
    }
  }

  void _lockNow() {
    _loadPinState();
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

  Future<void> _handleFirstTimeSetup() async {
    final pin1 = _firstPinCtrl.text.trim();
    final pin2 = _confirmPinCtrl.text.trim();
    final email = _setupEmailCtrl.text.trim().toLowerCase();

    if (pin1.length != 4 || int.tryParse(pin1) == null) {
      setState(() {
        _errorMessage = 'Tu PIN debe ser de exactamente 4 números.';
      });
      return;
    }

    if (pin1 != pin2) {
      setState(() {
        _errorMessage = 'Los dos PIN ingresados no coinciden.';
      });
      return;
    }

    if (email.isEmpty || !email.contains('@')) {
      setState(() {
        _errorMessage =
            'Ingresa tu correo electrónico para poder recuperar el PIN si se te olvida.';
      });
      return;
    }

    await PinSecurityManager.savePinAndEmail(
      pin: pin1,
      recoveryEmail: email,
    );

    if (!mounted) return;
    setState(() {
      _expectedPin = pin1;
      _recoveryEmail = email;
      _isUnlocked = true;
      _errorMessage = null;
    });
  }

  Future<void> _showForgotPinDialog() async {
    final verifyEmailCtrl = TextEditingController();
    final resetPinCtrl = TextEditingController();
    bool emailVerified = false;
    bool sendingEmail = false;
    String? feedbackText;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.mark_email_read_rounded, color: Color(0xFF0EA5E9)),
                SizedBox(width: 8),
                Expanded(child: Text('Recuperar PIN por Correo')),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    !emailVerified
                        ? 'Ingresa el correo electrónico que registraste cuando creaste tu PIN en COFIPER:'
                        : '¡Correo verificado! Ahora puedes crear tu nuevo PIN de 4 dígitos:',
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  if (!emailVerified)
                    TextField(
                      controller: verifyEmailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Tu correo registrado',
                        hintText: 'ejemplo@gmail.com',
                        prefixIcon: Icon(Icons.email_outlined),
                        border: OutlineInputBorder(),
                      ),
                    )
                  else
                    TextField(
                      controller: resetPinCtrl,
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      maxLength: 4,
                      decoration: const InputDecoration(
                        labelText: 'Escribe tu Nuevo PIN (4 dígitos)',
                        prefixIcon: Icon(Icons.key_rounded),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  if (feedbackText != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      feedbackText!,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: emailVerified
                            ? const Color(0xFF059669)
                            : Colors.redAccent,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              if (!emailVerified)
                FilledButton.icon(
                  icon: sendingEmail
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.verified_user_rounded),
                  label: const Text('Verificar Correo'),
                  onPressed: sendingEmail
                      ? null
                      : () async {
                          final typed =
                              verifyEmailCtrl.text.trim().toLowerCase();
                          if (typed.isEmpty || !typed.contains('@')) {
                            setDialogState(() {
                              feedbackText = 'Escribe un correo válido.';
                            });
                            return;
                          }

                          if (_recoveryEmail.isNotEmpty &&
                              typed != _recoveryEmail.toLowerCase()) {
                            setDialogState(() {
                              feedbackText =
                                  'Ese correo no coincide con el correo registrado en este dispositivo.';
                            });
                            return;
                          }

                          setDialogState(() => sendingEmail = true);
                          final sentBySmtp =
                              await PinSecurityManager.trySendPinToEmail(typed);
                          setDialogState(() {
                            sendingEmail = false;
                            emailVerified = true;
                            feedbackText = sentBySmtp
                                ? 'Se envió un correo a $typed con tu PIN y además puedes restablecerlo aquí mismo:'
                                : 'Identidad confirmada con $typed. Ingresa tu nuevo PIN de 4 dígitos abajo:';
                          });
                        },
                )
              else
                FilledButton.icon(
                  icon: const Icon(Icons.check_circle_outline_rounded),
                  label: const Text('Guardar Nuevo PIN y Entrar'),
                  onPressed: () async {
                    final newPin = resetPinCtrl.text.trim();
                    if (newPin.length != 4 || int.tryParse(newPin) == null) {
                      setDialogState(() {
                        feedbackText =
                            'El nuevo PIN debe tener exactamente 4 números.';
                      });
                      return;
                    }

                    await PinSecurityManager.savePinAndEmail(
                      pin: newPin,
                      recoveryEmail: _recoveryEmail.isNotEmpty
                          ? _recoveryEmail
                          : verifyEmailCtrl.text.trim().toLowerCase(),
                    );

                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    setState(() {
                      _expectedPin = newPin;
                      _isUnlocked = true;
                      _errorMessage = null;
                    });
                  },
                ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0B172A),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF10B981)),
        ),
      );
    }

    if (_isUnlocked) {
      return widget.child;
    }

    // Si es la primera vez que abre la app, mostrar pantalla de creación de PIN a su gusto
    if (_expectedPin == null) {
      return _buildFirstTimeCreatePinScreen();
    }

    return _buildUnlockKeypadScreen();
  }

  Widget _buildFirstTimeCreatePinScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFF0B172A),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: const Color(0xFF10B981).withValues(alpha: 0.4),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF059669), Color(0xFF0EA5E9)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Center(
                        child: Text(
                          'C\$',
                          style: TextStyle(
                            color: Color(0xFFFDE68A),
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Bienvenido a COFIPER',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Crea tu propio código PIN de 4 dígitos para proteger tus finanzas y registra tu correo por si algún día necesitas recuperarlo:',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 12.5),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: _firstPinCtrl,
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      maxLength: 4,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Crea tu PIN (4 números)',
                        labelStyle: TextStyle(color: Colors.white70),
                        prefixIcon:
                            Icon(Icons.lock_outline_rounded, color: Colors.white70),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white24),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFF34D399)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _confirmPinCtrl,
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      maxLength: 4,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Repite tu PIN de 4 números',
                        labelStyle: TextStyle(color: Colors.white70),
                        prefixIcon:
                            Icon(Icons.check_circle_outline_rounded, color: Colors.white70),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white24),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFF34D399)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _setupEmailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Tu correo para recuperar el PIN',
                        hintText: 'tucorreo@gmail.com',
                        hintStyle: TextStyle(color: Colors.white38),
                        labelStyle: TextStyle(color: Colors.white70),
                        prefixIcon:
                            Icon(Icons.email_outlined, color: Colors.white70),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white24),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFF34D399)),
                        ),
                      ),
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFFFCA5A5),
                          fontWeight: FontWeight.bold,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF059669),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: _handleFirstTimeSetup,
                        icon: const Icon(Icons.shield_rounded),
                        label: const Text(
                          'Guardar mi PIN y Entrar',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUnlockKeypadScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFF0B172A),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 76,
                  height: 76,
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
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'COFIPER · Acceso Seguro',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Ingresa tu PIN personal de 4 dígitos',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 22),

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

                const SizedBox(height: 24),

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

                const SizedBox(height: 18),
                TextButton.icon(
                  onPressed: _showForgotPinDialog,
                  icon: const Icon(
                    Icons.help_outline_rounded,
                    color: Color(0xFF38BDF8),
                    size: 18,
                  ),
                  label: const Text(
                    '¿Olvidaste tu PIN? Recupéralo con tu correo',
                    style: TextStyle(
                      color: Color(0xFF38BDF8),
                      fontWeight: FontWeight.w600,
                    ),
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
