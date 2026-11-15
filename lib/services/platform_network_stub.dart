Future<bool> checkDeviceInternetConnection() async {
  // En versión Web App (PWA) el navegador gestiona la conexión directamente.
  return true;
}

Future<Map<String, dynamic>> fetchGmailImapRawMessages({
  required String cleanEmail,
  required String cleanPass,
}) async {
  return {
    'success': false,
    'statusMessage':
        'En la versión Web App de iPhone (Safari), por seguridad del navegador copia el texto del correo de tu banco en la sección #2 de abajo ("Pegar Correo de Gmail o SMS del Banco") para sumarlo al instante.',
    'blocks': <String>[],
  };
}
