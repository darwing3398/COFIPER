import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/financial_models.dart';
import 'nicaragua_bank_gmail_service.dart';

class PersistedAppData {
  final String activePeriodId;
  final List<MonthlyPeriodRecord> periods;
  final List<ActivityLogEntry> activityLogs;
  final String gmailAddress;
  final String gmailAppPassword;
  final double usdToCordobaRate;
  final Set<String> processedBankSignatures;

  const PersistedAppData({
    required this.activePeriodId,
    required this.periods,
    required this.activityLogs,
    required this.gmailAddress,
    required this.gmailAppPassword,
    required this.usdToCordobaRate,
    required this.processedBankSignatures,
  });
}

class LocalStorageService {
  static const String _periodsKey = 'cofiper_periods_ni_v2';
  static const String _activePeriodKey = 'cofiper_active_period_ni_v2';
  static const String _logsKey = 'cofiper_activity_logs_ni_v2';
  static const String _gmailUserKey = 'cofiper_gmail_user_v1';
  static const String _gmailPassKey = 'cofiper_gmail_app_pass_v1';
  static const String _exchangeRateKey = 'cofiper_usd_rate_v1';
  static const String _bankSigsKey = 'cofiper_bank_sigs_v1';

  /// Carga todos los periodos mensuales, credenciales de sincronización bancaria y bitácora.
  static Future<PersistedAppData?> loadData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final periodsRaw = prefs.getString(_periodsKey);
      if (periodsRaw == null || periodsRaw.isEmpty) {
        return null;
      }

      final List<dynamic> decodedPeriods =
          jsonDecode(periodsRaw) as List<dynamic>;
      final periods = decodedPeriods
          .map((e) => MonthlyPeriodRecord.fromJson(e as Map<String, dynamic>))
          .toList();

      if (periods.isEmpty) return null;

      final activeId = prefs.getString(_activePeriodKey) ?? periods.first.id;

      final logsRaw = prefs.getString(_logsKey);
      List<ActivityLogEntry> logs = [];
      if (logsRaw != null && logsRaw.isNotEmpty) {
        final List<dynamic> decodedLogs = jsonDecode(logsRaw) as List<dynamic>;
        logs = decodedLogs
            .map((e) => ActivityLogEntry.fromJson(e as Map<String, dynamic>))
            .toList();
      }

      final gmailUser = prefs.getString(_gmailUserKey) ?? '';
      final gmailPass = prefs.getString(_gmailPassKey) ?? '';
      final usdRate = prefs.getDouble(_exchangeRateKey) ??
          NicaraguaBankGmailService.defaultUsdToCordobaRate;
      final sigsList = prefs.getStringList(_bankSigsKey) ?? <String>[];

      return PersistedAppData(
        activePeriodId: activeId,
        periods: periods,
        activityLogs: logs,
        gmailAddress: gmailUser,
        gmailAppPassword: gmailPass,
        usdToCordobaRate: usdRate,
        processedBankSignatures: sigsList.toSet(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Guarda de forma persistente todos los periodos mensuales, el mes activo, credenciales Gmail y bitácora.
  static Future<void> saveData({
    required String activePeriodId,
    required List<MonthlyPeriodRecord> periods,
    required List<ActivityLogEntry> activityLogs,
    required String gmailAddress,
    required String gmailAppPassword,
    required double usdToCordobaRate,
    required Set<String> processedBankSignatures,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_activePeriodKey, activePeriodId);
      await prefs.setString(
        _periodsKey,
        jsonEncode(periods.map((e) => e.toJson()).toList()),
      );
      await prefs.setString(
        _logsKey,
        jsonEncode(activityLogs.map((e) => e.toJson()).toList()),
      );
      await prefs.setString(_gmailUserKey, gmailAddress);
      await prefs.setString(_gmailPassKey, gmailAppPassword);
      await prefs.setDouble(_exchangeRateKey, usdToCordobaRate);
      await prefs.setStringList(
          _bankSigsKey, processedBankSignatures.toList());
    } catch (_) {
      // En entornos de test sin plugin inicializado se ignora silenciosamente.
    }
  }
}
