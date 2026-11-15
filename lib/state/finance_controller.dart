import 'package:flutter/foundation.dart';
import '../models/financial_models.dart';
import '../services/local_storage_service.dart';
import '../services/nicaragua_bank_gmail_service.dart';
import '../services/recalculation_engine.dart';

class FinanceController extends ChangeNotifier {
  String _activePeriodId = 'period_nov_2026';
  List<MonthlyPeriodRecord> _periods = [];
  List<ActivityLogEntry> _activityLogs = [];
  OnlineAdviceResult? _onlineAdvice;
  bool _isCheckingOnline = false;

  // Configuración de conexión a Bancos de Nicaragua vía Gmail
  String _gmailAddress = '';
  String _gmailAppPassword = '';
  double _usdToCordobaRate = NicaraguaBankGmailService.defaultUsdToCordobaRate;
  Set<String> _processedBankSignatures = {};
  bool _isSyncingGmail = false;
  String? _lastBankSyncMessage;

  FinanceController() {
    _initializeDefaultDemo();
    _loadPersistedData();
  }

  String get activePeriodId => _activePeriodId;
  List<MonthlyPeriodRecord> get periods => List.unmodifiable(_periods);
  List<ActivityLogEntry> get activityLogs => List.unmodifiable(_activityLogs);
  OnlineAdviceResult? get onlineAdvice => _onlineAdvice;
  bool get isCheckingOnline => _isCheckingOnline;

  String get gmailAddress => _gmailAddress;
  String get gmailAppPassword => _gmailAppPassword;
  double get usdToCordobaRate => _usdToCordobaRate;
  bool get isSyncingGmail => _isSyncingGmail;
  String? get lastBankSyncMessage => _lastBankSyncMessage;

  MonthlyPeriodRecord get activePeriod {
    return _periods.firstWhere(
      (p) => p.id == _activePeriodId,
      orElse: () => _periods.first,
    );
  }

  String get currentMonthLabel => activePeriod.monthLabel;
  AllocationStrategy get strategy => activePeriod.strategy;
  List<IncomeItem> get incomes => List.unmodifiable(activePeriod.incomes);
  List<ExpenseItem> get expenses => List.unmodifiable(activePeriod.expenses);

  List<IncomeItem> get fixedIncomes =>
      incomes.where((i) => !i.isExtraSaleOrBusiness).toList();

  List<IncomeItem> get extraSalesAndBusinessIncomes =>
      incomes.where((i) => i.isExtraSaleOrBusiness).toList();

  List<ExpenseItem> get twoQuincenaExpenses =>
      expenses.where((e) => e.collectsFromTwoQuincenas).toList();

  List<ExpenseItem> get singleQuincenaExpenses =>
      expenses.where((e) => !e.collectsFromTwoQuincenas).toList();

  MonthlyPlanSummary get summary => RecalculationEngine.buildSummary(
        incomes: incomes,
        expenses: expenses,
      );

  List<AdvisorInsight> get advisorInsights =>
      RecalculationEngine.generateInsights(
        summary: summary,
        expenses: expenses,
      );

  Future<void> _loadPersistedData() async {
    final persisted = await LocalStorageService.loadData();
    if (persisted != null && persisted.periods.isNotEmpty) {
      _periods = persisted.periods;
      _activePeriodId = persisted.activePeriodId;
      _activityLogs = persisted.activityLogs;
      _gmailAddress = persisted.gmailAddress;
      _gmailAppPassword = persisted.gmailAppPassword;
      _usdToCordobaRate = persisted.usdToCordobaRate;
      _processedBankSignatures = persisted.processedBankSignatures;
    } else {
      await _persistState();
    }
    notifyListeners();
    refreshOnlineAdvice();
  }

  Future<void> _persistState() async {
    await LocalStorageService.saveData(
      activePeriodId: _activePeriodId,
      periods: _periods,
      activityLogs: _activityLogs,
      gmailAddress: _gmailAddress,
      gmailAppPassword: _gmailAppPassword,
      usdToCordobaRate: _usdToCordobaRate,
      processedBankSignatures: _processedBankSignatures,
    );
  }

  // -------------------- SINCRONIZACIÓN BANCARIA GMAIL (NICARAGUA) --------------------

  void saveGmailBankSettings({
    required String gmail,
    required String appPassword,
    required double exchangeRate,
  }) {
    _gmailAddress = gmail.trim();
    _gmailAppPassword = appPassword.trim();
    if (exchangeRate > 0) {
      _usdToCordobaRate = exchangeRate;
    }
    notifyListeners();
    _persistState();
  }

  /// Conecta con Gmail (IMAP TLS) para leer notificaciones de BAC, Banpro, LAFISE, Ficohsa, etc.
  Future<GmailSyncResponse> syncWithGmailBanks({
    String? emailOverride,
    String? passwordOverride,
    double? rateOverride,
  }) async {
    if (emailOverride != null || passwordOverride != null || rateOverride != null) {
      saveGmailBankSettings(
        gmail: emailOverride ?? _gmailAddress,
        appPassword: passwordOverride ?? _gmailAppPassword,
        exchangeRate: rateOverride ?? _usdToCordobaRate,
      );
    }

    _isSyncingGmail = true;
    _lastBankSyncMessage = 'Conectando con tu bandeja de Gmail...';
    notifyListeners();

    final response = await NicaraguaBankGmailService.syncFromGmailImap(
      gmailAddress: _gmailAddress,
      appPassword: _gmailAppPassword,
      alreadyProcessedSignatures: _processedBankSignatures,
      usdToCordobaRate: _usdToCordobaRate,
    );

    if (response.success && response.newTransactions.isNotEmpty) {
      for (final tx in response.newTransactions) {
        _applyDetectedBankTransaction(tx);
      }
      recalculateAll();
    }

    _isSyncingGmail = false;
    _lastBankSyncMessage = response.statusMessage;
    notifyListeners();
    await _persistState();
    return response;
  }

  /// Analiza al instante un correo o mensaje de alerta bancaria (BAC, Banpro, LAFISE, Ficohsa)
  /// y lo suma a la tarjeta correspondiente o lo registra en los gastos del mes.
  ParsedBankTransaction? processBankAlertText(String rawAlertText) {
    final parsed = NicaraguaBankGmailService.parseBankEmailOrAlert(
      rawText: rawAlertText,
      usdToCordobaRate: _usdToCordobaRate,
      externalId: 'manual_${DateTime.now().microsecondsSinceEpoch}',
    );
    if (parsed == null) {
      return null;
    }

    _applyDetectedBankTransaction(parsed);
    recalculateAll();
    return parsed;
  }

  void _applyDetectedBankTransaction(ParsedBankTransaction tx) {
    _processedBankSignatures.add(tx.uniqueSignature);
    final current = activePeriod;

    // Buscar si ya existe una tarjeta de crédito registrada para ese banco (o con esos 4 dígitos)
    final bankNameUpper = tx.bank.name.toUpperCase();
    final bankShortKeyword = bankNameUpper.split(' ').first;

    int existingIndex = -1;
    for (int i = 0; i < current.expenses.length; i++) {
      final exp = current.expenses[i];
      if (exp.category != ExpenseCategory.creditCard) continue;
      final titleUpper = exp.title.toUpperCase();
      if (tx.last4Digits != null && titleUpper.contains(tx.last4Digits!)) {
        existingIndex = i;
        break;
      }
      if (titleUpper.contains(bankShortKeyword)) {
        existingIndex = i;
        break;
      }
    }

    final currencyDetail = tx.wasInDollars
        ? 'Cobro original US\$ ${tx.originalAmount.toStringAsFixed(2)} (TC ${tx.exchangeRateUsed.toStringAsFixed(2)}) → ${formatCordobas(tx.amountInCordobas)}'
        : 'Cobro en Córdobas: ${formatCordobas(tx.amountInCordobas)}';

    if (existingIndex >= 0) {
      // Sumar el consumo al saldo de esa tarjeta de crédito existente
      final existingCard = current.expenses[existingIndex];
      final newTotal = existingCard.totalAmount + tx.amountInCordobas;
      final updatedNotes = existingCard.notes == null || existingCard.notes!.isEmpty
          ? 'Última compra: ${tx.merchant} (${formatCordobas(tx.amountInCordobas)})'
          : '${existingCard.notes} | + ${tx.merchant} (${formatCordobas(tx.amountInCordobas)})';

      final updatedCard = existingCard.copyWith(
        totalAmount: newTotal,
        notes: updatedNotes,
      );

      final nextList = [...current.expenses];
      nextList[existingIndex] = updatedCard;
      _updateActivePeriod(current.copyWith(expenses: nextList));

      _recordActivity(
        type: ActivityType.expenseUpdated,
        title: 'Compra Bancaria Sumada a ${existingCard.title}',
        detail: '${tx.merchant} • $currencyDetail',
        amount: tx.amountInCordobas,
      );
    } else {
      // Crear automáticamente la Tarjeta de Crédito para ese banco en modo 2 Quincenas
      final newCard = ExpenseItem(
        id: 'exp_bank_${DateTime.now().microsecondsSinceEpoch}',
        title: tx.cardTitle,
        category: ExpenseCategory.creditCard,
        totalAmount: tx.amountInCordobas,
        splitMode: SplitMode.twoQuincenasAuto,
        q1Allocation: tx.amountInCordobas / 2.0,
        q2Allocation: tx.amountInCordobas / 2.0,
        dueDay: 28,
        notes: 'Detectado de Gmail: ${tx.merchant} ($currencyDetail)',
      );

      _updateActivePeriod(
        current.copyWith(expenses: [newCard, ...current.expenses]),
      );

      _recordActivity(
        type: ActivityType.expenseAdded,
        title: 'Nueva Compra en ${tx.cardTitle}',
        detail: '${tx.merchant} • $currencyDetail',
        amount: tx.amountInCordobas,
      );
    }
  }

  /// Consulta conectividad a internet y actualiza los consejos personalizados del Asesor IA.
  Future<void> refreshOnlineAdvice() async {
    _isCheckingOnline = true;
    notifyListeners();

    _onlineAdvice = await RecalculationEngine.fetchOnlineImprovementTips(
      summary: summary,
      incomes: incomes,
      expenses: expenses,
    );

    _isCheckingOnline = false;
    notifyListeners();
  }

  void _recordActivity({
    required ActivityType type,
    required String title,
    required String detail,
    double? amount,
  }) {
    final entry = ActivityLogEntry(
      id: 'log_${DateTime.now().microsecondsSinceEpoch}',
      timestamp: DateTime.now(),
      type: type,
      title: title,
      detail: detail,
      amount: amount,
      periodLabel: currentMonthLabel,
    );
    _activityLogs = [entry, ..._activityLogs];
    if (_activityLogs.length > 250) {
      _activityLogs = _activityLogs.sublist(0, 250);
    }
  }

  void _updateActivePeriod(MonthlyPeriodRecord updatedPeriod) {
    _periods = _periods
        .map((p) => p.id == updatedPeriod.id ? updatedPeriod : p)
        .toList();
  }

  // -------------------- GESTIÓN DE PERIODOS MENSUALES --------------------

  void switchActivePeriod(String periodId) {
    if (_periods.any((p) => p.id == periodId)) {
      _activePeriodId = periodId;
      notifyListeners();
      _persistState();
      refreshOnlineAdvice();
    }
  }

  void createNewMonthlyPeriod(
    String newMonthLabel, {
    bool cloneCurrentStructure = true,
  }) {
    final current = activePeriod;
    final newId = 'period_${DateTime.now().millisecondsSinceEpoch}';

    final clonedIncomes = cloneCurrentStructure
        ? current.incomes
            .where((inc) => !inc.isExtraSaleOrBusiness)
            .map((inc) => inc.copyWith(id: '${inc.id}_${newId.substring(7)}'))
            .toList()
        : <IncomeItem>[];

    final clonedExpenses = cloneCurrentStructure
        ? current.expenses
            .map(
              (exp) => exp.copyWith(
                id: '${exp.id}_${newId.substring(7)}',
                q1Collected: false,
                q2Collected: false,
              ),
            )
            .toList()
        : <ExpenseItem>[];

    final recalculatedExpenses = RecalculationEngine.recalculateExpenses(
      incomes: clonedIncomes,
      expenses: clonedExpenses,
      strategy: current.strategy,
      respectCollectedQ1: false,
    );

    final newPeriod = MonthlyPeriodRecord(
      id: newId,
      monthLabel: newMonthLabel.trim(),
      strategy: current.strategy,
      incomes: clonedIncomes,
      expenses: recalculatedExpenses,
      createdAt: DateTime.now(),
    );

    _periods = [newPeriod, ..._periods];
    _activePeriodId = newId;

    _recordActivity(
      type: ActivityType.periodCreated,
      title: 'Nuevo Mes Creado: ${newMonthLabel.trim()}',
      detail: cloneCurrentStructure
          ? 'Se copiaron tus ingresos fijos y gastos base al nuevo mes.'
          : 'Mes iniciado desde cero.',
    );

    notifyListeners();
    _persistState();
    refreshOnlineAdvice();
  }

  // -------------------- ESTRATEGIA Y RECÁLCULO --------------------

  void setStrategyAndRecalculate(
    AllocationStrategy newStrategy, {
    bool resetManualOverrides = false,
  }) {
    _updateActivePeriod(activePeriod.copyWith(strategy: newStrategy));
    recalculateAll(
      resetManualOverrides: resetManualOverrides,
      logRecalculation: true,
    );
  }

  void recalculateAll({
    bool respectCollectedQ1 = true,
    bool resetManualOverrides = false,
    bool logRecalculation = false,
  }) {
    final current = activePeriod;
    final updatedExpenses = RecalculationEngine.recalculateExpenses(
      incomes: current.incomes,
      expenses: current.expenses,
      strategy: current.strategy,
      respectCollectedQ1: respectCollectedQ1,
      resetManualOverrides: resetManualOverrides,
    );

    _updateActivePeriod(current.copyWith(expenses: updatedExpenses));

    if (logRecalculation) {
      final sum = summary;
      _recordActivity(
        type: ActivityType.recalculationRun,
        title: 'Cálculos Rehechos (${current.strategy.title})',
        detail:
            'Libre Q1: ${formatCordobas(sum.q1FreeCash)} | Libre Q2: ${formatCordobas(sum.q2FreeCash)}',
      );
    }

    notifyListeners();
    _persistState();
    refreshOnlineAdvice();
  }

  // -------------------- CRUD DE INGRESOS --------------------

  void addIncome({
    required String title,
    required double amount,
    required IncomeFrequency frequency,
    IncomeOrigin origin = IncomeOrigin.fixedSalary,
    String? noteOrWeek,
  }) {
    final newItem = IncomeItem(
      id: 'inc_${DateTime.now().microsecondsSinceEpoch}',
      title: title.trim(),
      amount: amount,
      frequency: frequency,
      origin: origin,
      noteOrWeek: noteOrWeek,
    );
    final current = activePeriod;
    _updateActivePeriod(
      current.copyWith(incomes: [...current.incomes, newItem]),
    );

    _recordActivity(
      type: ActivityType.incomeAdded,
      title: origin == IncomeOrigin.extraSaleOrBusiness
          ? 'Venta / Negocio Extra: ${newItem.title}'
          : 'Ingreso Fijo: ${newItem.title}',
      detail:
          '${frequency.shortLabel} (1ra Quincena: ${formatCordobas(newItem.q1Amount)} | 2da Quincena: ${formatCordobas(newItem.q2Amount)})',
      amount: newItem.monthlyTotal,
    );

    recalculateAll();
  }

  void updateIncome(IncomeItem updated) {
    final current = activePeriod;
    final nextIncomes = current.incomes
        .map((e) => e.id == updated.id ? updated : e)
        .toList();
    _updateActivePeriod(current.copyWith(incomes: nextIncomes));

    _recordActivity(
      type: ActivityType.incomeUpdated,
      title: 'Ingreso Editado: ${updated.title}',
      detail:
          'Total mes: ${formatCordobas(updated.monthlyTotal)} (${updated.frequency.shortLabel})',
      amount: updated.monthlyTotal,
    );

    recalculateAll();
  }

  void deleteIncome(String id) {
    final current = activePeriod;
    final target = current.incomes.where((e) => e.id == id).firstOrNull;
    final nextIncomes = current.incomes.where((e) => e.id != id).toList();
    _updateActivePeriod(current.copyWith(incomes: nextIncomes));

    if (target != null) {
      _recordActivity(
        type: ActivityType.recordDeleted,
        title: 'Ingreso Eliminado: ${target.title}',
        detail: 'Se restó ${formatCordobas(target.monthlyTotal)} del mes',
        amount: target.monthlyTotal,
      );
    }

    recalculateAll();
  }

  // -------------------- CRUD DE GASTOS --------------------

  void addExpense({
    required String title,
    required ExpenseCategory category,
    required double totalAmount,
    required SplitMode splitMode,
    double? customQ1Amount,
    int? dueDay,
    int? cutoffDay,
    String? notes,
  }) {
    double q1 = 0.0;
    double q2 = 0.0;

    if (splitMode == SplitMode.onlyQ1) {
      q1 = totalAmount;
    } else if (splitMode == SplitMode.onlyQ2) {
      q2 = totalAmount;
    } else if (splitMode == SplitMode.customManual && customQ1Amount != null) {
      q1 = customQ1Amount.clamp(0.0, totalAmount);
      q2 = totalAmount - q1;
    } else {
      q1 = totalAmount / 2.0;
      q2 = totalAmount / 2.0;
    }

    final newExpense = ExpenseItem(
      id: 'exp_${DateTime.now().microsecondsSinceEpoch}',
      title: title.trim(),
      category: category,
      totalAmount: totalAmount,
      splitMode: splitMode,
      q1Allocation: q1,
      q2Allocation: q2,
      dueDay: dueDay,
      cutoffDay: cutoffDay,
      notes: notes,
    );

    final current = activePeriod;
    _updateActivePeriod(
      current.copyWith(expenses: [...current.expenses, newExpense]),
    );

    _recordActivity(
      type: ActivityType.expenseAdded,
      title: 'Gasto Registrado: ${newExpense.title}',
      detail: '${category.label} • ${splitMode.label}',
      amount: totalAmount,
    );

    recalculateAll();
  }

  void updateExpense(ExpenseItem updated) {
    final current = activePeriod;
    final nextExpenses = current.expenses
        .map((e) => e.id == updated.id ? updated : e)
        .toList();
    _updateActivePeriod(current.copyWith(expenses: nextExpenses));

    _recordActivity(
      type: ActivityType.expenseUpdated,
      title: 'Gasto Editado: ${updated.title}',
      detail:
          '${updated.category.label} • Total: ${formatCordobas(updated.totalAmount)}',
      amount: updated.totalAmount,
    );

    recalculateAll();
  }

  void deleteExpense(String id) {
    final current = activePeriod;
    final target = current.expenses.where((e) => e.id == id).firstOrNull;
    final nextExpenses = current.expenses.where((e) => e.id != id).toList();
    _updateActivePeriod(current.copyWith(expenses: nextExpenses));

    if (target != null) {
      _recordActivity(
        type: ActivityType.recordDeleted,
        title: 'Gasto Eliminado: ${target.title}',
        detail: target.category.label,
        amount: target.totalAmount,
      );
    }

    recalculateAll();
  }

  void updateManualSplitForExpense(String expenseId, double newQ1Amount) {
    final current = activePeriod;
    ExpenseItem? modifiedItem;

    final nextExpenses = current.expenses.map((exp) {
      if (exp.id != expenseId) return exp;
      final clampedQ1 =
          ((newQ1Amount.clamp(0.0, exp.totalAmount)) * 100).roundToDouble() /
              100.0;
      final clampedQ2 =
          ((exp.totalAmount - clampedQ1) * 100).roundToDouble() / 100.0;
      modifiedItem = exp.copyWith(
        splitMode: SplitMode.customManual,
        q1Allocation: clampedQ1,
        q2Allocation: clampedQ2,
      );
      return modifiedItem!;
    }).toList();

    _updateActivePeriod(current.copyWith(expenses: nextExpenses));

    if (modifiedItem != null) {
      _recordActivity(
        type: ActivityType.manualSplitAdjusted,
        title: 'Ajuste de Quincenas: ${modifiedItem!.title}',
        detail:
            '1ra Quincena: ${formatCordobas(modifiedItem!.q1Allocation)} → 2da Quincena: ${formatCordobas(modifiedItem!.q2Allocation)}',
        amount: modifiedItem!.totalAmount,
      );
    }

    notifyListeners();
    _persistState();
    refreshOnlineAdvice();
  }

  void resetExpenseToAutoSplit(String expenseId) {
    final current = activePeriod;
    final nextExpenses = current.expenses.map((exp) {
      if (exp.id != expenseId) return exp;
      return exp.copyWith(splitMode: SplitMode.twoQuincenasAuto);
    }).toList();
    _updateActivePeriod(current.copyWith(expenses: nextExpenses));
    recalculateAll(logRecalculation: true);
  }

  void toggleQuincenaCollected(String expenseId, {required bool isQ1}) {
    final current = activePeriod;
    ExpenseItem? toggledItem;

    final nextExpenses = current.expenses.map((exp) {
      if (exp.id != expenseId) return exp;
      toggledItem = isQ1
          ? exp.copyWith(q1Collected: !exp.q1Collected)
          : exp.copyWith(q2Collected: !exp.q2Collected);
      return toggledItem!;
    }).toList();

    _updateActivePeriod(current.copyWith(expenses: nextExpenses));

    if (toggledItem != null) {
      if (isQ1) {
        _recordActivity(
          type: ActivityType.vaultQ1Toggled,
          title: toggledItem!.q1Collected
              ? 'Ya aparté 1ra Quincena: ${toggledItem!.title}'
              : 'Pendiente 1ra Quincena: ${toggledItem!.title}',
          detail: toggledItem!.q1Collected
              ? 'Apartado: ${formatCordobas(toggledItem!.q1Allocation)}'
              : 'Se desmarcó el apartado de la 1ra Quincena.',
          amount: toggledItem!.q1Allocation,
        );
      } else {
        _recordActivity(
          type: ActivityType.paymentQ2Toggled,
          title: toggledItem!.q2Collected
              ? 'Ya pagué 2da Quincena: ${toggledItem!.title}'
              : 'Pendiente 2da Quincena: ${toggledItem!.title}',
          detail: toggledItem!.q2Collected
              ? 'Liquidado: ${formatCordobas(toggledItem!.q2Allocation)}'
              : 'Se desmarcó el pago de la 2da Quincena.',
          amount: toggledItem!.q2Allocation,
        );
      }
    }

    notifyListeners();
    _persistState();
  }

  void clearAllData() {
    final current = activePeriod;
    _updateActivePeriod(
      current.copyWith(incomes: [], expenses: []),
    );
    _recordActivity(
      type: ActivityType.recordDeleted,
      title: 'Presupuesto en Blanco (${current.monthLabel})',
      detail: 'Se limpiaron los registros del mes para empezar de cero.',
    );
    notifyListeners();
    _persistState();
    refreshOnlineAdvice();
  }

  void loadDemoScenario() {
    _initializeDefaultDemo();
    _persistState();
    notifyListeners();
    refreshOnlineAdvice();
  }

  void _initializeDefaultDemo() {
    const defaultIncomes = [
      IncomeItem(
        id: 'inc_1',
        title: 'Salario Quincenal',
        amount: 12000.00,
        frequency: IncomeFrequency.biweekly,
        origin: IncomeOrigin.fixedSalary,
      ),
      IncomeItem(
        id: 'inc_2',
        title: 'Venta de Mercadería / Negocio Propio',
        amount: 2500.00,
        frequency: IncomeFrequency.onlyQ1,
        origin: IncomeOrigin.extraSaleOrBusiness,
        noteOrWeek: 'Semana 1 (Entró en 1ra Quincena)',
      ),
    ];

    const initialExpenses = [
      ExpenseItem(
        id: 'exp_tc_1',
        title: 'Tarjeta BAC Credomatic (*4512)',
        category: ExpenseCategory.creditCard,
        totalAmount: 5800.00,
        splitMode: SplitMode.twoQuincenasAuto,
        q1Allocation: 2900.00,
        q2Allocation: 2900.00,
        q1Collected: true,
        q2Collected: false,
        cutoffDay: 12,
        dueDay: 28,
        notes: 'Recoger en las 2 quincenas para pagar de contado el día 28',
      ),
      ExpenseItem(
        id: 'exp_loan_1',
        title: 'Cuota de Préstamo Banpro',
        category: ExpenseCategory.loan,
        totalAmount: 4200.00,
        splitMode: SplitMode.twoQuincenasAuto,
        q1Allocation: 2100.00,
        q2Allocation: 2100.00,
        q1Collected: true,
        q2Collected: false,
        dueDay: 30,
        notes: 'Se recoge mitad en 1ra quincena y mitad en 2da quincena',
      ),
      ExpenseItem(
        id: 'exp_rent',
        title: 'Alquiler / Casa',
        category: ExpenseCategory.housing,
        totalAmount: 5000.00,
        splitMode: SplitMode.twoQuincenasAuto,
        q1Allocation: 2500.00,
        q2Allocation: 2500.00,
        q1Collected: false,
        q2Collected: false,
        dueDay: 30,
      ),
      ExpenseItem(
        id: 'exp_util_1',
        title: 'Internet y Plan Celular',
        category: ExpenseCategory.utilities,
        totalAmount: 1450.00,
        splitMode: SplitMode.onlyQ1,
        q1Allocation: 1450.00,
        q2Allocation: 0.00,
        q1Collected: true,
        dueDay: 14,
      ),
      ExpenseItem(
        id: 'exp_util_2',
        title: 'Luz (Disnorte/Dissur) y Agua (Enacal)',
        category: ExpenseCategory.utilities,
        totalAmount: 1850.00,
        splitMode: SplitMode.onlyQ2,
        q1Allocation: 0.00,
        q2Allocation: 1850.00,
        dueDay: 26,
      ),
      ExpenseItem(
        id: 'exp_food',
        title: 'Comida y Supermercado del Mes',
        category: ExpenseCategory.food,
        totalAmount: 5200.00,
        splitMode: SplitMode.twoQuincenasAuto,
        q1Allocation: 2600.00,
        q2Allocation: 2600.00,
      ),
      ExpenseItem(
        id: 'exp_ant',
        title: 'Salidas, Comida Rápida y Gastos Diarios',
        category: ExpenseCategory.antExpense,
        totalAmount: 1600.00,
        splitMode: SplitMode.twoQuincenasAuto,
        q1Allocation: 800.00,
        q2Allocation: 800.00,
        notes: 'Tope máximo para no descontrolarse',
      ),
    ];

    final balancedExpenses = RecalculationEngine.recalculateExpenses(
      incomes: defaultIncomes,
      expenses: initialExpenses,
      strategy: AllocationStrategy.liquidityBalance,
      respectCollectedQ1: false,
    );

    final demoPeriod = MonthlyPeriodRecord(
      id: 'period_nov_2026',
      monthLabel: 'Noviembre 2026',
      strategy: AllocationStrategy.liquidityBalance,
      incomes: defaultIncomes,
      expenses: balancedExpenses,
      createdAt: DateTime.now(),
    );

    _periods = [demoPeriod];
    _activePeriodId = demoPeriod.id;
    _activityLogs = [
      ActivityLogEntry(
        id: 'log_init_2',
        timestamp: DateTime.now(),
        type: ActivityType.incomeAdded,
        title: 'Venta / Negocio Extra: Venta de Mercadería',
        detail: '1ra Quincena (Días 1-15) • Semana 1',
        amount: 2500.00,
        periodLabel: 'Noviembre 2026',
      ),
      ActivityLogEntry(
        id: 'log_init_1',
        timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
        type: ActivityType.periodCreated,
        title: 'Presupuesto en Córdobas (C\$) Iniciado',
        detail: 'Cálculos de 1ra y 2da Quincena listos.',
        periodLabel: 'Noviembre 2026',
      ),
    ];
  }

  String generateTextReport() {
    final s = summary;
    final buffer = StringBuffer();
    buffer.writeln('=== CONTROL QUINCENAL COFIPER ($currentMonthLabel) ===');
    buffer.writeln('Estado: ${s.spendingStatusHeadline}');
    buffer.writeln('');
    buffer.writeln('1. MIS 2 QUINCENAS EN CÓRDOBAS (C\$):');
    buffer.writeln(
        '• 1ra Quincena (Días 1-15): Ingreso ${formatCordobas(s.q1Income)} | Gastos ${formatCordobas(s.q1Expenses)} | ME QUEDA LIBRE: ${formatCordobas(s.q1FreeCash)}');
    buffer.writeln(
        '• 2da Quincena (Días 16-30): Ingreso ${formatCordobas(s.q2Income)} | Gastos ${formatCordobas(s.q2Expenses)} | ME QUEDA LIBRE: ${formatCordobas(s.q2FreeCash)}');
    if (s.totalExtraIncome > 0) {
      buffer.writeln(
          '• Total Ventas / Negocios Extras del mes: ${formatCordobas(s.totalExtraIncome)}');
    }
    buffer.writeln('');
    buffer.writeln('2. CUÁNTO PONER EN CADA QUINCENA POR GASTO:');
    for (final exp in expenses) {
      final statusQ1 = exp.q1Collected ? '[Ya aparté]' : '[Falta]';
      final statusQ2 = exp.q2Collected ? '[Ya pagué]' : '[Falta]';
      buffer.writeln(
          '- ${exp.title} (${formatCordobas(exp.totalAmount)}): 1ra Quincena ${formatCordobas(exp.q1Allocation)} $statusQ1 | 2da Quincena ${formatCordobas(exp.q2Allocation)} $statusQ2');
    }
    return buffer.toString();
  }
}
