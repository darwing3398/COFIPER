import 'dart:convert';
import 'dart:js_interop';
import 'package:shared_preferences/shared_preferences.dart';

@JS('cofiperFetchJson')
external JSPromise<JSString> _cofiperFetchJson(JSString url);

Future<bool> checkDeviceInternetConnection() async {
  return true;
}

Future<Map<String, dynamic>> fetchGmailImapRawMessages({
  required String cleanEmail,
  required String cleanPass,
}) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final savedScriptUrl =
        (prefs.getString('cofiper_google_script_url_v1') ?? '').trim();

    // Permitir que el usuario pegue el link de script.google.com tanto en el campo dedicado
    // como en el campo de clave si empieza por http
    final effectiveUrl = cleanPass.startsWith('http')
        ? cleanPass
        : savedScriptUrl;

    if (effectiveUrl.isEmpty || !effectiveUrl.contains('script.google.com')) {
      return {
        'success': false,
        'statusMessage':
            'Para que Safari en iPhone lea tu Gmail automáticamente sin cables ni computadora, toca abajo el botón "Configurar Puente Google en Safari (1 vez)" y pega tu enlace de script.google.com.',
        'blocks': <String>[],
      };
    }

    final separator = effectiveUrl.contains('?') ? '&' : '?';
    final requestUrl =
        '$effectiveUrl${separator}action=sync&email=${Uri.encodeComponent(cleanEmail)}&t=${DateTime.now().millisecondsSinceEpoch}';

    final jsResponse = await _cofiperFetchJson(requestUrl.toJS).toDart;
    final rawJson = jsResponse.toDart;

    final decoded = jsonDecode(rawJson) as Map<String, dynamic>;
    final ok = decoded['success'] as bool? ?? false;
    final statusMsg = decoded['statusMessage'] as String? ?? 'OK';
    final rawBlocks = (decoded['blocks'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList();

    return {
      'success': ok,
      'statusMessage': statusMsg,
      'blocks': rawBlocks,
    };
  } catch (e) {
    return {
      'success': false,
      'statusMessage':
          'No se pudo conectar al Puente de Google en Safari ($e). Verifica que al implementar en script.google.com hayas elegido "Quién tiene acceso: Cualquier persona".',
      'blocks': <String>[],
    };
  }
}

Future<bool> sendRecoveryEmailViaSmtp({
  required String recipientEmail,
  required String currentPin,
  required String senderGmail,
  required String senderAppPassword,
}) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final savedScriptUrl =
        (prefs.getString('cofiper_google_script_url_v1') ?? '').trim();
    final effectiveUrl = senderAppPassword.startsWith('http')
        ? senderAppPassword
        : savedScriptUrl;

    if (effectiveUrl.isEmpty || !effectiveUrl.contains('script.google.com')) {
      return false;
    }

    final separator = effectiveUrl.contains('?') ? '&' : '?';
    final requestUrl =
        '$effectiveUrl${separator}action=recover&to=${Uri.encodeComponent(recipientEmail)}&pin=${Uri.encodeComponent(currentPin)}';

    final jsResponse = await _cofiperFetchJson(requestUrl.toJS).toDart;
    final decoded = jsonDecode(jsResponse.toDart) as Map<String, dynamic>;
    return decoded['sent'] == true;
  } catch (_) {
    return false;
  }
}
