import 'dart:convert';
import 'dart:io';

Future<bool> checkDeviceInternetConnection() async {
  if (Platform.environment.containsKey('FLUTTER_TEST')) {
    return false;
  }
  try {
    final result = await InternetAddress.lookup('one.one.one.one')
        .timeout(const Duration(seconds: 3));
    return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
  } catch (_) {
    return false;
  }
}

Future<Map<String, dynamic>> fetchGmailImapRawMessages({
  required String cleanEmail,
  required String cleanPass,
}) async {
  SecureSocket? socket;
  try {
    socket = await SecureSocket.connect(
      'imap.gmail.com',
      993,
      timeout: const Duration(seconds: 10),
    );

    final responseBuffer = StringBuffer();
    _ImapWaiter waiter = _ImapWaiter();

    socket.listen(
      (data) {
        final chunk = utf8.decode(data, allowMalformed: true);
        responseBuffer.write(chunk);
        waiter.checkCompletion(responseBuffer.toString());
      },
      onError: (Object err) {
        waiter.completeWithError(err.toString());
      },
      onDone: () {
        waiter.completeIfPending(responseBuffer.toString());
      },
    );

    await waiter.waitForTag('* OK');

    responseBuffer.clear();
    waiter = _ImapWaiter();
    socket.write('A01 LOGIN "$cleanEmail" "$cleanPass"\r\n');
    final loginResp = await waiter.waitForTag('A01 ');
    if (!loginResp.contains('A01 OK')) {
      await socket.close();
      return {
        'success': false,
        'statusMessage':
            'Google rechazó el acceso. Asegúrate de usar una "Contraseña de aplicación" de 16 letras de tu cuenta Google (no tu clave normal).',
        'blocks': <String>[],
      };
    }

    responseBuffer.clear();
    waiter = _ImapWaiter();
    socket.write('A02 EXAMINE INBOX\r\n');
    final examineResp = await waiter.waitForTag('A02 ');

    final existsMatch =
        RegExp(r'\*\s+([0-9]+)\s+EXISTS').firstMatch(examineResp);
    final totalMessages =
        existsMatch != null ? (int.tryParse(existsMatch.group(1)!) ?? 0) : 0;

    if (totalMessages == 0) {
      socket.write('A99 LOGOUT\r\n');
      await socket.close();
      return {
        'success': true,
        'statusMessage': 'Tu bandeja de entrada está vacía.',
        'blocks': <String>[],
      };
    }

    final startSeq = (totalMessages - 29).clamp(1, totalMessages);
    responseBuffer.clear();
    waiter = _ImapWaiter();
    socket.write(
      'A03 FETCH $startSeq:$totalMessages (UID BODY.PEEK[HEADER.FIELDS (FROM SUBJECT DATE)] BODY.PEEK[TEXT])\r\n',
    );
    final fetchRaw = await waiter.waitForTag('A03 ');

    socket.write('A99 LOGOUT\r\n');
    await socket.close();

    final blocks = fetchRaw.split(RegExp(r'\*\s+[0-9]+\s+FETCH'));
    return {
      'success': true,
      'statusMessage': 'OK',
      'blocks': blocks,
    };
  } catch (e) {
    try {
      await socket?.close();
    } catch (_) {}
    return {
      'success': false,
      'statusMessage':
          'No se pudo conectar con Gmail ($e). Verifica tu conexión a internet.',
      'blocks': <String>[],
    };
  }
}

class _ImapWaiter {
  String _targetTag = '';
  bool _done = false;
  String _lastBuffer = '';

  Future<String> waitForTag(String tag) async {
    _targetTag = tag;
    _done = false;
    final deadline = DateTime.now().add(const Duration(seconds: 10));

    while (!_done && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 80));
    }
    return _lastBuffer;
  }

  void checkCompletion(String currentBuffer) {
    _lastBuffer = currentBuffer;
    if (_targetTag.isNotEmpty && currentBuffer.contains(_targetTag)) {
      _done = true;
    }
  }

  void completeWithError(String err) {
    _lastBuffer = err;
    _done = true;
  }

  void completeIfPending(String currentBuffer) {
    _lastBuffer = currentBuffer;
    _done = true;
  }
}
