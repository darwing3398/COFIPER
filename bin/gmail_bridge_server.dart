import 'dart:convert';
import 'dart:io';
import 'package:cofiper/services/platform_network_io.dart';

Future<void> main(List<String> args) async {
  final port = int.tryParse(Platform.environment['PORT'] ?? '8787') ?? 8787;
  final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
  stdout.writeln('COFIPER Gmail Bridge escuchando en http://0.0.0.0:$port');

  await for (final HttpRequest request in server) {
    request.response.headers
      ..set('Access-Control-Allow-Origin', '*')
      ..set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
      ..set(
        'Access-Control-Allow-Headers',
        'Origin, Content-Type, Accept, Authorization, Bypass-Tunnel-Reminder',
      );

    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.noContent;
      await request.response.close();
      continue;
    }

    if (request.method == 'GET' && request.uri.path == '/health') {
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({'ok': true, 'service': 'cofiper-gmail-bridge'}));
      await request.response.close();
      continue;
    }

    if (request.method == 'POST' && request.uri.path == '/imap-sync') {
      try {
        final bodyStr = await utf8.decoder.bind(request).join();
        final payload = jsonDecode(bodyStr) as Map<String, dynamic>;
        final cleanEmail = (payload['email'] as String? ?? '').trim();
        final cleanPass =
            (payload['appPassword'] as String? ?? '').replaceAll(' ', '').trim();

        final result = await fetchGmailImapRawMessages(
          cleanEmail: cleanEmail,
          cleanPass: cleanPass,
        );

        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.json
          ..write(jsonEncode(result));
      } catch (e) {
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({
            'success': false,
            'statusMessage': 'Error procesando solicitud IMAP: $e',
            'blocks': <String>[],
          }));
      }
      await request.response.close();
      continue;
    }

    if (request.method == 'POST' && request.uri.path == '/smtp-recover') {
      try {
        final bodyStr = await utf8.decoder.bind(request).join();
        final payload = jsonDecode(bodyStr) as Map<String, dynamic>;
        final sent = await sendRecoveryEmailViaSmtp(
          recipientEmail: (payload['recipientEmail'] as String? ?? '').trim(),
          currentPin: (payload['currentPin'] as String? ?? '').trim(),
          senderGmail: (payload['senderGmail'] as String? ?? '').trim(),
          senderAppPassword: (payload['senderAppPassword'] as String? ?? '')
              .replaceAll(' ', '')
              .trim(),
        );
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({'sent': sent}));
      } catch (e) {
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({'sent': false, 'error': e.toString()}));
      }
      await request.response.close();
      continue;
    }

    request.response
      ..statusCode = HttpStatus.notFound
      ..write('Not Found');
    await request.response.close();
  }
}
