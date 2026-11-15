import 'platform_network_helper.dart';

/// Bancos principales de Nicaragua soportados por el analizador automático.
enum NicaraguaBank {
  bacCredomatic,
  banpro,
  lafise,
  ficohsa,
  bdf,
  avanz,
  otherBank,
}

extension NicaraguaBankX on NicaraguaBank {
  String get name {
    switch (this) {
      case NicaraguaBank.bacCredomatic:
        return 'BAC Credomatic';
      case NicaraguaBank.banpro:
        return 'Banpro Promerica';
      case NicaraguaBank.lafise:
        return 'Banco LAFISE';
      case NicaraguaBank.ficohsa:
        return 'Banco Ficohsa';
      case NicaraguaBank.bdf:
        return 'BDF';
      case NicaraguaBank.avanz:
        return 'Banco Avanz';
      case NicaraguaBank.otherBank:
        return 'Banco / Tarjeta';
    }
  }
}

/// Resultado de analizar un correo o notificación bancaria de Nicaragua.
class ParsedBankTransaction {
  final String uniqueSignature;
  final NicaraguaBank bank;
  final String merchant;
  final double originalAmount;
  final bool wasInDollars;
  final double exchangeRateUsed;
  final double amountInCordobas;
  final String? last4Digits;
  final DateTime detectedDate;
  final String rawSnippet;

  const ParsedBankTransaction({
    required this.uniqueSignature,
    required this.bank,
    required this.merchant,
    required this.originalAmount,
    required this.wasInDollars,
    required this.exchangeRateUsed,
    required this.amountInCordobas,
    required this.detectedDate,
    required this.rawSnippet,
    this.last4Digits,
  });

  String get cardTitle {
    if (last4Digits != null && last4Digits!.isNotEmpty) {
      return 'Tarjeta ${bank.name} (*$last4Digits)';
    }
    return 'Tarjeta ${bank.name}';
  }

  Map<String, dynamic> toJson() => {
        'uniqueSignature': uniqueSignature,
        'bank': bank.name,
        'merchant': merchant,
        'originalAmount': originalAmount,
        'wasInDollars': wasInDollars,
        'exchangeRateUsed': exchangeRateUsed,
        'amountInCordobas': amountInCordobas,
        'last4Digits': last4Digits,
        'detectedDate': detectedDate.toIso8601String(),
        'rawSnippet': rawSnippet,
      };
}

class GmailSyncResponse {
  final bool success;
  final String statusMessage;
  final List<ParsedBankTransaction> newTransactions;

  const GmailSyncResponse({
    required this.success,
    required this.statusMessage,
    required this.newTransactions,
  });
}

class NicaraguaBankGmailService {
  /// Tasa oficial de referencia en Nicaragua (editable por el usuario en la app).
  static const double defaultUsdToCordobaRate = 36.6243;

  /// Analiza el texto de un correo de Gmail o SMS de BAC, Banpro, LAFISE, Ficohsa, BDF o Avanz
  /// y extrae banco, monto (convirtiendo USD a C$ si aplica), comercio y últimos 4 dígitos.
  static ParsedBankTransaction? parseBankEmailOrAlert({
    required String rawText,
    double usdToCordobaRate = defaultUsdToCordobaRate,
    String? externalId,
  }) {
    final cleaned = rawText
        .replaceAll('\r\n', ' ')
        .replaceAll('\n', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (cleaned.isEmpty) return null;

    final upper = cleaned.toUpperCase();

    // 1. Detectar el banco de Nicaragua
    NicaraguaBank bank = NicaraguaBank.otherBank;
    if (upper.contains('BAC') || upper.contains('CREDOMATIC')) {
      bank = NicaraguaBank.bacCredomatic;
    } else if (upper.contains('BANPRO') || upper.contains('PROMERICA')) {
      bank = NicaraguaBank.banpro;
    } else if (upper.contains('LAFISE') || upper.contains('BANCENTRO')) {
      bank = NicaraguaBank.lafise;
    } else if (upper.contains('FICOHSA')) {
      bank = NicaraguaBank.ficohsa;
    } else if (upper.contains('BDF')) {
      bank = NicaraguaBank.bdf;
    } else if (upper.contains('AVANZ')) {
      bank = NicaraguaBank.avanz;
    }

    // 2. Detectar moneda y monto (C$, COR, NIO vs US$, USD, $)
    bool isDollars = false;
    double? extractedAmount;

    final cordobaRegex = RegExp(
      r'(?:C\$|NIO|COR|CORDOBAS?)\s*([0-9]{1,3}(?:,[0-9]{3})*(?:\.[0-9]{1,2})?|[0-9]+(?:\.[0-9]{1,2})?)',
      caseSensitive: false,
    );

    final dollarRegex = RegExp(
      r'(?:US\$|USD|\$)\s*([0-9]{1,3}(?:,[0-9]{3})*(?:\.[0-9]{1,2})?|[0-9]+(?:\.[0-9]{1,2})?)',
      caseSensitive: false,
    );

    final cordobaMatch = cordobaRegex.firstMatch(cleaned);
    if (cordobaMatch != null) {
      final rawNum = cordobaMatch.group(1)!.replaceAll(',', '');
      extractedAmount = double.tryParse(rawNum);
      isDollars = false;
    } else {
      final dollarMatch = dollarRegex.firstMatch(cleaned);
      if (dollarMatch != null) {
        final rawNum = dollarMatch.group(1)!.replaceAll(',', '');
        extractedAmount = double.tryParse(rawNum);
        isDollars = true;
      }
    }

    if (extractedAmount == null || extractedAmount <= 0) {
      return null;
    }

    // 3. Extraer últimos 4 dígitos de la tarjeta
    String? last4;
    final cardDigitsRegex = RegExp(
      r'(?:\*{1,4}|XXXX|terminaci[oó]n\s+|finalizada\s+en\s+|tarjeta\s+(?:no\.?\s*)?)([0-9]{4})\b',
      caseSensitive: false,
    );
    final digitsMatch = cardDigitsRegex.firstMatch(cleaned);
    if (digitsMatch != null) {
      last4 = digitsMatch.group(1);
    }

    // 4. Extraer comercio / establecimiento
    String merchant = 'Comercio / Compra con Tarjeta';
    final merchantPatterns = [
      RegExp(
        r'(?:comercio|establecimiento|negocio|lugar)\s*[:\-]?\s*([A-Za-z0-9ÁÉÍÓÚÑáéíóúñ\s\.\-&]{3,35}?)(?=\s+(?:por|monto|fecha|ciudad|tarjeta|con|el\s+d[ií]a|$|\.))',
        caseSensitive: false,
      ),
      RegExp(
        r'\ben\s+([A-Z0-9][A-Za-z0-9ÁÉÍÓÚÑáéíóúñ\s\.\-&]{2,30}?)(?=\s+(?:por|con\s+tu|con\s+la|con\s+tarjeta|el\s+d[ií]a|fecha|autorizaci[oó]n|$|\.))',
      ),
    ];

    for (final pattern in merchantPatterns) {
      final m = pattern.firstMatch(cleaned);
      if (m != null && m.group(1) != null) {
        final candidate = m.group(1)!.trim();
        if (candidate.length >= 3 &&
            !candidate.toUpperCase().contains('SU TARJETA') &&
            !candidate.toUpperCase().contains('LINEA')) {
          merchant = candidate;
          break;
        }
      }
    }

    final amountCordobas = isDollars
        ? ((extractedAmount * usdToCordobaRate * 100).roundToDouble() / 100.0)
        : extractedAmount;

    final signature = externalId ??
        '${bank.name}_${extractedAmount.toStringAsFixed(2)}_${merchant.toUpperCase()}_${last4 ?? "0000"}';

    return ParsedBankTransaction(
      uniqueSignature: signature,
      bank: bank,
      merchant: merchant,
      originalAmount: extractedAmount,
      wasInDollars: isDollars,
      exchangeRateUsed: usdToCordobaRate,
      amountInCordobas: amountCordobas,
      last4Digits: last4,
      detectedDate: DateTime.now(),
      rawSnippet:
          cleaned.length > 140 ? '${cleaned.substring(0, 140)}...' : cleaned,
    );
  }

  /// Sincroniza con Gmail usando la implementación nativa (o indica el modo en Web PWA).
  static Future<GmailSyncResponse> syncFromGmailImap({
    required String gmailAddress,
    required String appPassword,
    required Set<String> alreadyProcessedSignatures,
    double usdToCordobaRate = defaultUsdToCordobaRate,
  }) async {
    final cleanEmail = gmailAddress.trim();
    final cleanPass = appPassword.replaceAll(' ', '').trim();

    if (cleanEmail.isEmpty || !cleanEmail.contains('@')) {
      return const GmailSyncResponse(
        success: false,
        statusMessage: 'Ingresa una dirección de correo @gmail.com válida.',
        newTransactions: [],
      );
    }

    if (cleanPass.length < 8) {
      return const GmailSyncResponse(
        success: false,
        statusMessage:
            'Ingresa tu Contraseña de Aplicación de Google (16 letras).',
        newTransactions: [],
      );
    }

    final rawResult = await fetchGmailImapRawMessages(
      cleanEmail: cleanEmail,
      cleanPass: cleanPass,
    );

    final bool ok = rawResult['success'] as bool? ?? false;
    final String msg = rawResult['statusMessage'] as String? ?? '';
    final List<String> messageBlocks =
        (rawResult['blocks'] as List<dynamic>? ?? []).cast<String>();

    if (!ok) {
      return GmailSyncResponse(
        success: false,
        statusMessage: msg,
        newTransactions: const [],
      );
    }

    final List<ParsedBankTransaction> detected = [];

    for (final block in messageBlocks) {
      if (block.trim().isEmpty) continue;
      final upperBlock = block.toUpperCase();

      final looksLikeBankAlert = upperBlock.contains('BAC') ||
          upperBlock.contains('CREDOMATIC') ||
          upperBlock.contains('BANPRO') ||
          upperBlock.contains('PROMERICA') ||
          upperBlock.contains('LAFISE') ||
          upperBlock.contains('FICOHSA') ||
          upperBlock.contains('AVANZ') ||
          upperBlock.contains('BDF');

      final hasTransactionKeyword = upperBlock.contains('COMPRA') ||
          upperBlock.contains('CONSUMO') ||
          upperBlock.contains('TRANSACCI') ||
          upperBlock.contains('APROBADA') ||
          upperBlock.contains('NOTIFICACI') ||
          upperBlock.contains('ALERTA');

      if (!looksLikeBankAlert || !hasTransactionKeyword) {
        continue;
      }

      final uidMatch = RegExp(r'UID\s+([0-9]+)').firstMatch(block);
      final uid = uidMatch?.group(1);
      final decodedText = _cleanEmailBody(block);

      final parsed = parseBankEmailOrAlert(
        rawText: decodedText,
        usdToCordobaRate: usdToCordobaRate,
        externalId: uid != null ? 'gmail_uid_$uid' : null,
      );

      if (parsed != null &&
          !alreadyProcessedSignatures.contains(parsed.uniqueSignature)) {
        detected.add(parsed);
      }
    }

    if (detected.isEmpty) {
      return const GmailSyncResponse(
        success: true,
        statusMessage:
            'Conexión exitosa con tu Gmail. No se encontraron compras bancarias nuevas sin registrar en tus últimos correos.',
        newTransactions: [],
      );
    }

    return GmailSyncResponse(
      success: true,
      statusMessage:
          '¡Conexión exitosa! Se detectaron ${detected.length} compra(s) de tus bancos en Gmail y se actualizaron tus quincenas.',
      newTransactions: detected,
    );
  }

  static String _cleanEmailBody(String rawMime) {
    String working = rawMime
        .replaceAll('=\r\n', '')
        .replaceAll('=\n', '')
        .replaceAll('=3D', '=')
        .replaceAll('=20', ' ')
        .replaceAll('=C3=B3', 'ó')
        .replaceAll('=C3=A1', 'á')
        .replaceAll('=C3=A9', 'é')
        .replaceAll('=C3=AD', 'í')
        .replaceAll('=C3=BA', 'ú')
        .replaceAll('=C3=B1', 'ñ');

    working = working.replaceAll(RegExp(r'<[^>]*>'), ' ');
    working = working.replaceAll('&nbsp;', ' ').replaceAll('&amp;', '&');
    return working;
  }
}
