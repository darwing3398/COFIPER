import 'package:flutter/material.dart';

/// Formateador oficial de moneda en Córdobas de Nicaragua (C$).
String formatCordobas(double amount, {bool showDecimals = true}) {
  final isNegative = amount < -0.005;
  final absVal = amount.abs();
  final fixed = absVal.toStringAsFixed(showDecimals ? 2 : 0);
  final parts = fixed.split('.');
  final intPart = parts[0];
  final decPart = parts.length > 1 ? '.${parts[1]}' : '';

  final buffer = StringBuffer();
  for (int i = 0; i < intPart.length; i++) {
    final posFromRight = intPart.length - i;
    buffer.write(intPart[i]);
    if (posFromRight > 1 && posFromRight % 3 == 1) {
      buffer.write(',');
    }
  }
  return '${isNegative ? "- " : ""}C\$ ${buffer.toString()}$decPart';
}

/// Tipo de origen del ingreso: Sueldo/Fijo vs Venta/Negocio Extra en la semana o quincena.
enum IncomeOrigin {
  fixedSalary,
  extraSaleOrBusiness,
}

extension IncomeOriginX on IncomeOrigin {
  String get label {
    switch (this) {
      case IncomeOrigin.fixedSalary:
        return 'Sueldo / Ingreso Fijo';
      case IncomeOrigin.extraSaleOrBusiness:
        return 'Venta / Negocio / Ingreso Extra';
    }
  }

  IconData get icon {
    switch (this) {
      case IncomeOrigin.fixedSalary:
        return Icons.payments_rounded;
      case IncomeOrigin.extraSaleOrBusiness:
        return Icons.storefront_rounded;
    }
  }

  Color get color {
    switch (this) {
      case IncomeOrigin.fixedSalary:
        return const Color(0xFF10B981);
      case IncomeOrigin.extraSaleOrBusiness:
        return const Color(0xFF0EA5E9);
    }
  }
}

/// Frecuencia o quincena en la que entra el ingreso.
enum IncomeFrequency {
  /// Se recibe el mismo monto en cada quincena (ej. C$ 12,000 en 1ra Quincena y C$ 12,000 en 2da Quincena).
  biweekly,

  /// Se recibe una vez al mes pero se divide mitad y mitad entre las 2 quincenas.
  monthlySplit,

  /// Entra en el trayecto de la 1ra Quincena (Días 1 al 15: ventas de la semana, negocios o pago Q1).
  onlyQ1,

  /// Entra en el trayecto de la 2da Quincena (Días 16 al 30: ventas de la semana, negocios o pago Q2).
  onlyQ2,
}

extension IncomeFrequencyX on IncomeFrequency {
  String get label {
    switch (this) {
      case IncomeFrequency.onlyQ1:
        return 'Para 1ra Quincena (Pago de Fin de Mes o Ventas → Cubre gastos del 1 al 15)';
      case IncomeFrequency.onlyQ2:
        return 'Para 2da Quincena (Pago del Día 15 o Ventas → Cubre gastos del 16 al 30)';
      case IncomeFrequency.monthlySplit:
        return 'Dividir mitad y mitad (50% en 1ra Quincena y 50% en 2da Quincena)';
      case IncomeFrequency.biweekly:
        return 'Repetir automáticamente este mismo monto en las 2 quincenas';
    }
  }

  String get shortLabel {
    switch (this) {
      case IncomeFrequency.onlyQ1:
        return '1ra Quincena (Pago Fin de Mes → Gastos 1-15)';
      case IncomeFrequency.onlyQ2:
        return '2da Quincena (Pago Día 15 → Gastos 16-30)';
      case IncomeFrequency.monthlySplit:
        return 'Dividido (50/50)';
      case IncomeFrequency.biweekly:
        return 'Ambas Quincenas';
    }
  }
}

/// Categorías de gastos con soporte especial para Tarjetas de Crédito y Préstamos.
enum ExpenseCategory {
  creditCard,
  loan,
  housing,
  utilities,
  food,
  transport,
  subscription,
  antExpense,
}

extension ExpenseCategoryX on ExpenseCategory {
  String get label {
    switch (this) {
      case ExpenseCategory.creditCard:
        return 'Tarjeta de Crédito';
      case ExpenseCategory.loan:
        return 'Préstamo / Cuota';
      case ExpenseCategory.housing:
        return 'Vivienda / Alquiler';
      case ExpenseCategory.utilities:
        return 'Servicios (Luz, Agua, Internet)';
      case ExpenseCategory.food:
        return 'Comida / Supermercado';
      case ExpenseCategory.transport:
        return 'Transporte / Combustible';
      case ExpenseCategory.subscription:
        return 'Suscripciones / Planes';
      case ExpenseCategory.antExpense:
        return 'Gastos Diarios / Hormiga / Antojos';
    }
  }

  IconData get icon {
    switch (this) {
      case ExpenseCategory.creditCard:
        return Icons.credit_card_rounded;
      case ExpenseCategory.loan:
        return Icons.account_balance_rounded;
      case ExpenseCategory.housing:
        return Icons.home_work_rounded;
      case ExpenseCategory.utilities:
        return Icons.bolt_rounded;
      case ExpenseCategory.food:
        return Icons.shopping_cart_rounded;
      case ExpenseCategory.transport:
        return Icons.directions_car_rounded;
      case ExpenseCategory.subscription:
        return Icons.subscriptions_rounded;
      case ExpenseCategory.antExpense:
        return Icons.local_cafe_rounded;
    }
  }

  Color get color {
    switch (this) {
      case ExpenseCategory.creditCard:
        return const Color(0xFF6366F1); // Indigo
      case ExpenseCategory.loan:
        return const Color(0xFFEC4899); // Pink/Rose
      case ExpenseCategory.housing:
        return const Color(0xFF0EA5E9); // Sky Blue
      case ExpenseCategory.utilities:
        return const Color(0xFFF59E0B); // Amber
      case ExpenseCategory.food:
        return const Color(0xFF10B981); // Emerald
      case ExpenseCategory.transport:
        return const Color(0xFF8B5CF6); // Violet
      case ExpenseCategory.subscription:
        return const Color(0xFF14B8A6); // Teal
      case ExpenseCategory.antExpense:
        return const Color(0xFFEF4444); // Red
    }
  }

  /// Por defecto, Tarjetas de Crédito y Préstamos recolectan fondos de hasta 2 quincenas.
  bool get defaultsToTwoQuincenas =>
      this == ExpenseCategory.creditCard ||
      this == ExpenseCategory.loan ||
      this == ExpenseCategory.housing;
}

/// Cómo se reparte un gasto entre las 2 quincenas del mes.
enum SplitMode {
  /// Recoge dinero de las 2 quincenas (calculado automáticamente por el motor según estrategia).
  twoQuincenasAuto,

  /// Se paga completo en la Primera Quincena (Q1).
  onlyQ1,

  /// Se paga completo en la Segunda Quincena (Q2).
  onlyQ2,

  /// El usuario fijó manualmente cuánto apartar en la 1ra Quincena y el resto se recalcula en la 2da.
  customManual,
}

extension SplitModeX on SplitMode {
  String get label {
    switch (this) {
      case SplitMode.twoQuincenasAuto:
        return 'Recoger entre las 2 Quincenas';
      case SplitMode.onlyQ1:
        return 'Pagar todo en 1ra Quincena';
      case SplitMode.onlyQ2:
        return 'Pagar todo en 2da Quincena';
      case SplitMode.customManual:
        return '2 Quincenas (Ajustado por ti)';
    }
  }
}

/// Estrategia matemática para rehacer los cálculos de repartición quincenal.
enum AllocationStrategy {
  /// Equilibra las cargas de tarjetas/préstamos para que quede el mismo dinero libre en ambas quincenas.
  liquidityBalance,

  /// Divide cada gasto de 2 quincenas exactamente 50% en la 1ra y 50% en la 2da.
  equal5050,

  /// Reparte proporcionalmente al ingreso disponible en cada quincena.
  incomeProportional,
}

extension AllocationStrategyX on AllocationStrategy {
  String get title {
    switch (this) {
      case AllocationStrategy.liquidityBalance:
        return 'Dejar igual dinero libre (Recomendado)';
      case AllocationStrategy.equal5050:
        return 'Mitad y Mitad (50% / 50%)';
      case AllocationStrategy.incomeProportional:
        return 'Según ingreso de cada quincena';
    }
  }

  String get description {
    switch (this) {
      case AllocationStrategy.liquidityBalance:
        return 'Reparte tus tarjetas y préstamos de forma inteligente para que te quede la misma cantidad de dinero libre en ambas quincenas.';
      case AllocationStrategy.equal5050:
        return 'Divide cada tarjeta de crédito, préstamo y gasto de 2 quincenas en dos partes exactamente iguales.';
      case AllocationStrategy.incomeProportional:
        return 'Si en una quincena ganaste más por ventas o negocios extras, esa quincena absorbe una mayor parte de las deudas.';
    }
  }
}

class IncomeItem {
  final String id;
  final String title;
  final double amount;
  final IncomeFrequency frequency;
  final IncomeOrigin origin;
  final String? noteOrWeek;

  /// Costo del producto / capital invertido cuando es una Venta o Negocio Extra (en C$).
  /// La ganancia neta libre para gastar es `amount - investmentCost`.
  final double investmentCost;

  const IncomeItem({
    required this.id,
    required this.title,
    required this.amount,
    required this.frequency,
    this.origin = IncomeOrigin.fixedSalary,
    this.noteOrWeek,
    this.investmentCost = 0.0,
  });

  bool get isExtraSaleOrBusiness =>
      origin == IncomeOrigin.extraSaleOrBusiness;

  /// Ganancia Neta libre para gastar después de separar el capital invertido.
  double get netAmount =>
      investmentCost > 0 ? (amount - investmentCost).clamp(0.0, amount) : amount;

  /// Monto neto disponible que entra en la 1ra Quincena.
  double get q1Amount {
    switch (frequency) {
      case IncomeFrequency.biweekly:
        return netAmount;
      case IncomeFrequency.monthlySplit:
        return netAmount / 2.0;
      case IncomeFrequency.onlyQ1:
        return netAmount;
      case IncomeFrequency.onlyQ2:
        return 0.0;
    }
  }

  /// Monto neto disponible que entra en la 2da Quincena.
  double get q2Amount {
    switch (frequency) {
      case IncomeFrequency.biweekly:
        return netAmount;
      case IncomeFrequency.monthlySplit:
        return netAmount / 2.0;
      case IncomeFrequency.onlyQ1:
        return 0.0;
      case IncomeFrequency.onlyQ2:
        return netAmount;
    }
  }

  /// Total mensual neto que representa este ingreso para tus gastos.
  double get monthlyTotal => q1Amount + q2Amount;

  /// Monto bruto total vendido antes de restar la inversión.
  double get grossMonthlyTotal =>
      frequency == IncomeFrequency.biweekly ? amount * 2.0 : amount;

  /// Capital a reponer / costo de inversión del mes.
  double get monthlyInvestmentCost =>
      frequency == IncomeFrequency.biweekly
          ? investmentCost * 2.0
          : investmentCost;

  IncomeItem copyWith({
    String? id,
    String? title,
    double? amount,
    IncomeFrequency? frequency,
    IncomeOrigin? origin,
    String? noteOrWeek,
    double? investmentCost,
  }) {
    return IncomeItem(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      frequency: frequency ?? this.frequency,
      origin: origin ?? this.origin,
      noteOrWeek: noteOrWeek ?? this.noteOrWeek,
      investmentCost: investmentCost ?? this.investmentCost,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'amount': amount,
        'frequency': frequency.name,
        'origin': origin.name,
        'noteOrWeek': noteOrWeek,
        'investmentCost': investmentCost,
      };

  factory IncomeItem.fromJson(Map<String, dynamic> json) {
    return IncomeItem(
      id: json['id'] as String,
      title: json['title'] as String,
      amount: (json['amount'] as num).toDouble(),
      frequency: IncomeFrequency.values.firstWhere(
        (e) => e.name == json['frequency'],
        orElse: () => IncomeFrequency.biweekly,
      ),
      origin: IncomeOrigin.values.firstWhere(
        (e) => e.name == json['origin'],
        orElse: () => IncomeOrigin.fixedSalary,
      ),
      noteOrWeek: json['noteOrWeek'] as String?,
      investmentCost: (json['investmentCost'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class ExpenseItem {
  final String id;
  final String title;
  final ExpenseCategory category;
  final double totalAmount;
  final SplitMode splitMode;

  /// Cuánto dinero se debe recoger/pagar en la 1ra Quincena.
  final double q1Allocation;

  /// Cuánto dinero se debe recoger/pagar en la 2da Quincena.
  final double q2Allocation;

  /// Indica si la parte de la 1ra Quincena ya fue apartada o pagada.
  final bool q1Collected;

  /// Indica si la parte de la 2da Quincena ya fue completada o pagada.
  final bool q2Collected;

  /// Día límite de pago del mes (1-31), útil para tarjetas de crédito y préstamos.
  final int? dueDay;

  /// Día de corte (opcional, para tarjetas de crédito).
  final int? cutoffDay;

  /// Fecha exacta de límite de pago seleccionada desde el calendario.
  final DateTime? dueDate;

  /// Fecha exacta de corte seleccionada desde el calendario.
  final DateTime? cutoffDate;

  final String? notes;

  const ExpenseItem({
    required this.id,
    required this.title,
    required this.category,
    required this.totalAmount,
    required this.splitMode,
    required this.q1Allocation,
    required this.q2Allocation,
    this.q1Collected = false,
    this.q2Collected = false,
    this.dueDay,
    this.cutoffDay,
    this.dueDate,
    this.cutoffDate,
    this.notes,
  });

  static String formatCalendarDate(DateTime d) {
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    return '$day/$month/${d.year}';
  }

  String? get formattedCutoffDate {
    if (cutoffDate != null) return formatCalendarDate(cutoffDate!);
    if (cutoffDay != null) return 'Día $cutoffDay';
    return null;
  }

  String? get formattedDueDate {
    if (dueDate != null) return formatCalendarDate(dueDate!);
    if (dueDay != null) return 'Día $dueDay';
    return null;
  }

  bool get collectsFromTwoQuincenas =>
      splitMode == SplitMode.twoQuincenasAuto ||
      splitMode == SplitMode.customManual;

  double get collectedTotal =>
      (q1Collected ? q1Allocation : 0.0) + (q2Collected ? q2Allocation : 0.0);

  double get remainingToCollect =>
      (totalAmount - collectedTotal).clamp(0.0, totalAmount);

  double get progress =>
      totalAmount <= 0 ? 1.0 : (collectedTotal / totalAmount).clamp(0.0, 1.0);

  bool get isFullyPaid =>
      (q1Allocation <= 0.01 || q1Collected) &&
      (q2Allocation <= 0.01 || q2Collected);

  /// Días restantes para la fecha límite de pago en el mes actual (negativo si ya pasó).
  int? daysUntilDue(int currentDay) {
    if (dueDate != null) {
      final today = DateTime(
          DateTime.now().year, DateTime.now().month, DateTime.now().day);
      final target = DateTime(dueDate!.year, dueDate!.month, dueDate!.day);
      return target.difference(today).inDays;
    }
    return dueDay != null ? (dueDay! - currentDay) : null;
  }

  /// Días restantes para la fecha de corte de la tarjeta.
  int? daysUntilCutoff(int currentDay) {
    if (cutoffDate != null) {
      final today = DateTime(
          DateTime.now().year, DateTime.now().month, DateTime.now().day);
      final target =
          DateTime(cutoffDate!.year, cutoffDate!.month, cutoffDate!.day);
      return target.difference(today).inDays;
    }
    return cutoffDay != null ? (cutoffDay! - currentDay) : null;
  }

  /// Devuelve un aviso claro de corte o fecha límite de pago si el gasto aún no está pagado al 100%.
  String? buildPaymentAlertMessage(int currentDay) {
    if (isFullyPaid) return null;
    if (dueDay == null &&
        cutoffDay == null &&
        dueDate == null &&
        cutoffDate == null) {
      return null;
    }

    final diffDue = daysUntilDue(currentDay);
    final dueLabel = formattedDueDate ?? '';
    final cutLabel = formattedCutoffDate;

    if (diffDue != null) {
      if (diffDue < 0) {
        return '🚨 ¡Vencida! Fecha límite fue $dueLabel (Pendiente: ${formatCordobas(remainingToCollect)})';
      } else if (diffDue == 0) {
        return '🚨 ¡Vence HOY ($dueLabel)! Pagar ${formatCordobas(remainingToCollect)} para evitar mora';
      } else if (diffDue <= 5) {
        return '⚠️ Faltan $diffDue día(s) para fecha límite ($dueLabel • Pendiente: ${formatCordobas(remainingToCollect)})';
      } else {
        return '📅 Pago límite: $dueLabel (en $diffDue días)${cutLabel != null ? " • Corte: $cutLabel" : ""}';
      }
    }

    final diffCut = daysUntilCutoff(currentDay);
    if (diffCut != null && cutLabel != null) {
      if (diffCut >= 0 && diffCut <= 5) {
        return '✂️ Tu tarjeta corta en $diffCut día(s) ($cutLabel)';
      }
      return '✂️ Fecha de corte: $cutLabel';
    }
    return null;
  }

  ExpenseItem copyWith({
    String? id,
    String? title,
    ExpenseCategory? category,
    double? totalAmount,
    SplitMode? splitMode,
    double? q1Allocation,
    double? q2Allocation,
    bool? q1Collected,
    bool? q2Collected,
    int? dueDay,
    int? cutoffDay,
    DateTime? dueDate,
    DateTime? cutoffDate,
    String? notes,
  }) {
    return ExpenseItem(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      totalAmount: totalAmount ?? this.totalAmount,
      splitMode: splitMode ?? this.splitMode,
      q1Allocation: q1Allocation ?? this.q1Allocation,
      q2Allocation: q2Allocation ?? this.q2Allocation,
      q1Collected: q1Collected ?? this.q1Collected,
      q2Collected: q2Collected ?? this.q2Collected,
      dueDay: dueDay ?? this.dueDay,
      cutoffDay: cutoffDay ?? this.cutoffDay,
      dueDate: dueDate ?? this.dueDate,
      cutoffDate: cutoffDate ?? this.cutoffDate,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'category': category.name,
        'totalAmount': totalAmount,
        'splitMode': splitMode.name,
        'q1Allocation': q1Allocation,
        'q2Allocation': q2Allocation,
        'q1Collected': q1Collected,
        'q2Collected': q2Collected,
        'dueDay': dueDay,
        'cutoffDay': cutoffDay,
        'dueDate': dueDate?.toIso8601String(),
        'cutoffDate': cutoffDate?.toIso8601String(),
        'notes': notes,
      };

  factory ExpenseItem.fromJson(Map<String, dynamic> json) {
    final parsedDueDate =
        DateTime.tryParse(json['dueDate'] as String? ?? '');
    final parsedCutoffDate =
        DateTime.tryParse(json['cutoffDate'] as String? ?? '');
    return ExpenseItem(
      id: json['id'] as String,
      title: json['title'] as String,
      category: ExpenseCategory.values.firstWhere(
        (e) => e.name == json['category'],
        orElse: () => ExpenseCategory.utilities,
      ),
      totalAmount: (json['totalAmount'] as num).toDouble(),
      splitMode: SplitMode.values.firstWhere(
        (e) => e.name == json['splitMode'],
        orElse: () => SplitMode.twoQuincenasAuto,
      ),
      q1Allocation: (json['q1Allocation'] as num).toDouble(),
      q2Allocation: (json['q2Allocation'] as num).toDouble(),
      q1Collected: json['q1Collected'] as bool? ?? false,
      q2Collected: json['q2Collected'] as bool? ?? false,
      dueDay: (json['dueDay'] as int?) ?? parsedDueDate?.day,
      cutoffDay: (json['cutoffDay'] as int?) ?? parsedCutoffDate?.day,
      dueDate: parsedDueDate,
      cutoffDate: parsedCutoffDate,
      notes: json['notes'] as String?,
    );
  }
}

/// Tipo de acción registrada en la bitácora de auditoría.
enum ActivityType {
  incomeAdded,
  incomeUpdated,
  expenseAdded,
  expenseUpdated,
  vaultQ1Toggled,
  paymentQ2Toggled,
  recalculationRun,
  manualSplitAdjusted,
  periodCreated,
  recordDeleted,
}

extension ActivityTypeX on ActivityType {
  String get label {
    switch (this) {
      case ActivityType.incomeAdded:
        return 'Ingreso Registrado';
      case ActivityType.incomeUpdated:
        return 'Ingreso Actualizado';
      case ActivityType.expenseAdded:
        return 'Gasto / Deuda Registrado';
      case ActivityType.expenseUpdated:
        return 'Gasto / Deuda Editado';
      case ActivityType.vaultQ1Toggled:
        return 'Apartado 1ra Quincena';
      case ActivityType.paymentQ2Toggled:
        return 'Pago 2da Quincena';
      case ActivityType.recalculationRun:
        return 'Recálculo Quincenal';
      case ActivityType.manualSplitAdjusted:
        return 'Ajuste Manual Q1/Q2';
      case ActivityType.periodCreated:
        return 'Cambio / Creación de Mes';
      case ActivityType.recordDeleted:
        return 'Registro Eliminado';
    }
  }

  IconData get icon {
    switch (this) {
      case ActivityType.incomeAdded:
      case ActivityType.incomeUpdated:
        return Icons.payments_rounded;
      case ActivityType.expenseAdded:
      case ActivityType.expenseUpdated:
        return Icons.receipt_long_rounded;
      case ActivityType.vaultQ1Toggled:
        return Icons.lock_clock_rounded;
      case ActivityType.paymentQ2Toggled:
        return Icons.task_alt_rounded;
      case ActivityType.recalculationRun:
        return Icons.calculate_rounded;
      case ActivityType.manualSplitAdjusted:
        return Icons.tune_rounded;
      case ActivityType.periodCreated:
        return Icons.calendar_month_rounded;
      case ActivityType.recordDeleted:
        return Icons.delete_sweep_rounded;
    }
  }

  Color get color {
    switch (this) {
      case ActivityType.incomeAdded:
      case ActivityType.incomeUpdated:
        return const Color(0xFF10B981);
      case ActivityType.expenseAdded:
      case ActivityType.expenseUpdated:
        return const Color(0xFF6366F1);
      case ActivityType.vaultQ1Toggled:
        return const Color(0xFF3B82F6);
      case ActivityType.paymentQ2Toggled:
        return const Color(0xFF059669);
      case ActivityType.recalculationRun:
        return const Color(0xFFF59E0B);
      case ActivityType.manualSplitAdjusted:
        return const Color(0xFF8B5CF6);
      case ActivityType.periodCreated:
        return const Color(0xFF0EA5E9);
      case ActivityType.recordDeleted:
        return const Color(0xFFEF4444);
    }
  }
}

class ActivityLogEntry {
  final String id;
  final DateTime timestamp;
  final ActivityType type;
  final String title;
  final String detail;
  final double? amount;
  final String periodLabel;

  const ActivityLogEntry({
    required this.id,
    required this.timestamp,
    required this.type,
    required this.title,
    required this.detail,
    required this.periodLabel,
    this.amount,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'type': type.name,
        'title': title,
        'detail': detail,
        'amount': amount,
        'periodLabel': periodLabel,
      };

  factory ActivityLogEntry.fromJson(Map<String, dynamic> json) {
    return ActivityLogEntry(
      id: json['id'] as String,
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.now(),
      type: ActivityType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => ActivityType.recalculationRun,
      ),
      title: json['title'] as String? ?? '',
      detail: json['detail'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble(),
      periodLabel: json['periodLabel'] as String? ?? '',
    );
  }
}

class MonthlyPeriodRecord {
  final String id;
  final String monthLabel;
  final AllocationStrategy strategy;
  final List<IncomeItem> incomes;
  final List<ExpenseItem> expenses;
  final DateTime createdAt;

  const MonthlyPeriodRecord({
    required this.id,
    required this.monthLabel,
    required this.strategy,
    required this.incomes,
    required this.expenses,
    required this.createdAt,
  });

  MonthlyPeriodRecord copyWith({
    String? id,
    String? monthLabel,
    AllocationStrategy? strategy,
    List<IncomeItem>? incomes,
    List<ExpenseItem>? expenses,
    DateTime? createdAt,
  }) {
    return MonthlyPeriodRecord(
      id: id ?? this.id,
      monthLabel: monthLabel ?? this.monthLabel,
      strategy: strategy ?? this.strategy,
      incomes: incomes ?? this.incomes,
      expenses: expenses ?? this.expenses,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'monthLabel': monthLabel,
        'strategy': strategy.name,
        'incomes': incomes.map((e) => e.toJson()).toList(),
        'expenses': expenses.map((e) => e.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory MonthlyPeriodRecord.fromJson(Map<String, dynamic> json) {
    return MonthlyPeriodRecord(
      id: json['id'] as String,
      monthLabel: json['monthLabel'] as String,
      strategy: AllocationStrategy.values.firstWhere(
        (e) => e.name == json['strategy'],
        orElse: () => AllocationStrategy.liquidityBalance,
      ),
      incomes: (json['incomes'] as List<dynamic>? ?? [])
          .map((e) => IncomeItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      expenses: (json['expenses'] as List<dynamic>? ?? [])
          .map((e) => ExpenseItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

/// Estado global de valoración de gastos (para indicar claramente si se está excediendo).
enum SpendingStatusLevel {
  healthy,
  warningHigh,
  exceedingLimit,
  deficitCritical,
}

class CategoryValuationItem {
  final String categoryGroupTitle;
  final double currentAmount;
  final double recommendedMaxAmount;
  final double percentageOfIncome;
  final double recommendedMaxPct;

  const CategoryValuationItem({
    required this.categoryGroupTitle,
    required this.currentAmount,
    required this.recommendedMaxAmount,
    required this.percentageOfIncome,
    required this.recommendedMaxPct,
  });

  bool get isExceeding => currentAmount > recommendedMaxAmount && recommendedMaxAmount > 0;
  double get excessAmount =>
      (currentAmount - recommendedMaxAmount).clamp(0.0, double.infinity);
}

/// Resumen detallado de una quincena individual (Q1 o Q2) y valoración del mes.
class MonthlyPlanSummary {
  final double q1Income;
  final double q2Income;
  final double q1ExtraIncome;
  final double q2ExtraIncome;
  final double q1Expenses;
  final double q2Expenses;

  /// Dinero que se recoge en la 1ra Quincena para gastos de 2 quincenas (Tarjetas, Préstamos, etc.)
  final double q1VaultTarget;

  /// Dinero ya apartado en la 1ra Quincena.
  final double vaultLockedNow;

  /// Total de deudas (Tarjetas de Crédito + Préstamos).
  final double totalDebtPayments;

  /// Total de gastos básicos/fijos (Vivienda, Servicios, Comida, Transporte).
  final double totalEssentialExpenses;

  /// Total de gastos hormiga/variables/suscripciones.
  final double totalFlexibleAndAntExpenses;

  const MonthlyPlanSummary({
    required this.q1Income,
    required this.q2Income,
    required this.q1ExtraIncome,
    required this.q2ExtraIncome,
    required this.q1Expenses,
    required this.q2Expenses,
    required this.q1VaultTarget,
    required this.vaultLockedNow,
    required this.totalDebtPayments,
    required this.totalEssentialExpenses,
    required this.totalFlexibleAndAntExpenses,
  });

  double get totalIncome => q1Income + q2Income;
  double get totalExtraIncome => q1ExtraIncome + q2ExtraIncome;
  double get totalExpenses => q1Expenses + q2Expenses;

  double get q1FreeCash => q1Income - q1Expenses;
  double get q2FreeCash => q2Income - q2Expenses;
  double get totalFreeCash => totalIncome - totalExpenses;

  /// Porcentaje del ingreso total que se va en gastos (0 a 100+).
  double get spentPercentage =>
      totalIncome <= 0 ? 0.0 : (totalExpenses / totalIncome) * 100.0;

  /// Ratio de endeudamiento sobre el ingreso mensual total (0.0 a 1.0+).
  double get debtRatio =>
      totalIncome <= 0 ? 0.0 : (totalDebtPayments / totalIncome);

  bool get hasQ1Deficit => q1FreeCash < -0.01;
  bool get hasQ2Deficit => q2FreeCash < -0.01;
  bool get hasMonthlyDeficit => totalFreeCash < -0.01;

  /// Determina si el usuario se está excediendo en gastos.
  SpendingStatusLevel get spendingStatus {
    if (hasMonthlyDeficit) {
      return SpendingStatusLevel.deficitCritical;
    }
    if (hasQ1Deficit || hasQ2Deficit || spentPercentage > 90) {
      return SpendingStatusLevel.exceedingLimit;
    }
    if (spentPercentage > 80 || debtRatio > 0.35) {
      return SpendingStatusLevel.warningHigh;
    }
    return SpendingStatusLevel.healthy;
  }

  String get spendingStatusHeadline {
    switch (spendingStatus) {
      case SpendingStatusLevel.deficitCritical:
        return '🚨 ¡Te estás excediendo! Gastas ${formatCordobas(totalFreeCash.abs())} más de lo que ganas';
      case SpendingStatusLevel.exceedingLimit:
        if (hasQ1Deficit) {
          return '⚠️ Te excedes en la 1ra Quincena por ${formatCordobas(q1FreeCash.abs())}';
        }
        if (hasQ2Deficit) {
          return '⚠️ Te excedes en la 2da Quincena por ${formatCordobas(q2FreeCash.abs())}';
        }
        return '⚠️ Estás al límite: Comprometes el ${spentPercentage.toStringAsFixed(0)}% de tu ingreso';
      case SpendingStatusLevel.warningHigh:
        return '👀 Precaución: Tus gastos o deudas están altos (${spentPercentage.toStringAsFixed(0)}% de tu ingreso)';
      case SpendingStatusLevel.healthy:
        return '✅ Gastos bajo control:Usas el ${spentPercentage.toStringAsFixed(0)}% de tus ingresos';
    }
  }

  /// Evalúa cada grupo de gastos para decirle al usuario exactamente en qué rubro se está excediendo.
  List<CategoryValuationItem> get categoryValuations {
    final inc = totalIncome > 0 ? totalIncome : 1.0;
    return [
      CategoryValuationItem(
        categoryGroupTitle: 'Tarjetas de Crédito y Préstamos',
        currentAmount: totalDebtPayments,
        recommendedMaxAmount: totalIncome * 0.35, // Máximo saludable: 35%
        percentageOfIncome: (totalDebtPayments / inc) * 100.0,
        recommendedMaxPct: 35.0,
      ),
      CategoryValuationItem(
        categoryGroupTitle: 'Gastos Básicos (Casa, Servicios, Comida)',
        currentAmount: totalEssentialExpenses,
        recommendedMaxAmount: totalIncome * 0.50, // Máximo saludable: 50%
        percentageOfIncome: (totalEssentialExpenses / inc) * 100.0,
        recommendedMaxPct: 50.0,
      ),
      CategoryValuationItem(
        categoryGroupTitle: 'Gastos Diarios / Hormiga y Suscripciones',
        currentAmount: totalFlexibleAndAntExpenses,
        recommendedMaxAmount: totalIncome * 0.10, // Máximo saludable: 10%
        percentageOfIncome: (totalFlexibleAndAntExpenses / inc) * 100.0,
        recommendedMaxPct: 10.0,
      ),
    ];
  }
}

/// Meta de Ahorro / "Alcancía por Quincena" (en Córdobas C$).
class SavingsGoalItem {
  final String id;
  final String title;
  final double targetAmount;
  final double savedAmount;
  final double quincenaGoalAmount;

  const SavingsGoalItem({
    required this.id,
    required this.title,
    required this.targetAmount,
    required this.savedAmount,
    required this.quincenaGoalAmount,
  });

  double get remainingAmount =>
      (targetAmount - savedAmount).clamp(0.0, targetAmount);

  double get progress =>
      targetAmount <= 0 ? 1.0 : (savedAmount / targetAmount).clamp(0.0, 1.0);

  bool get isCompleted => savedAmount >= targetAmount && targetAmount > 0;

  int get estimatedQuincenasLeft {
    if (isCompleted || quincenaGoalAmount <= 0) return 0;
    return (remainingAmount / quincenaGoalAmount).ceil();
  }

  SavingsGoalItem copyWith({
    String? id,
    String? title,
    double? targetAmount,
    double? savedAmount,
    double? quincenaGoalAmount,
  }) {
    return SavingsGoalItem(
      id: id ?? this.id,
      title: title ?? this.title,
      targetAmount: targetAmount ?? this.targetAmount,
      savedAmount: savedAmount ?? this.savedAmount,
      quincenaGoalAmount: quincenaGoalAmount ?? this.quincenaGoalAmount,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'targetAmount': targetAmount,
        'savedAmount': savedAmount,
        'quincenaGoalAmount': quincenaGoalAmount,
      };

  factory SavingsGoalItem.fromJson(Map<String, dynamic> json) {
    return SavingsGoalItem(
      id: json['id'] as String,
      title: json['title'] as String,
      targetAmount: (json['targetAmount'] as num).toDouble(),
      savedAmount: (json['savedAmount'] as num).toDouble(),
      quincenaGoalAmount: (json['quincenaGoalAmount'] as num).toDouble(),
    );
  }
}

/// Desglose oficial de Planilla / Salario Neto en Nicaragua (Ley 822 DGI + INSS 7% + Aguinaldo).
class NicaraguaPayrollBreakdown {
  final double grossMonthly;
  final double inssMonthly;
  final double irMonthly;
  final double netMonthly;
  final double netQuincenal;
  final double aguinaldoAccumulated;
  final int workedMonths;

  const NicaraguaPayrollBreakdown({
    required this.grossMonthly,
    required this.inssMonthly,
    required this.irMonthly,
    required this.netMonthly,
    required this.netQuincenal,
    required this.aguinaldoAccumulated,
    required this.workedMonths,
  });
}

class NicaraguaSalaryTaxCalculator {
  /// Calcula INSS Laboral (7%), IR progresivo de la DGI Nicaragua y Aguinaldo proporcional.
  static NicaraguaPayrollBreakdown calculate({
    required double grossMonthlySalary,
    int workedMonthsForAguinaldo = 12,
  }) {
    final gross = grossMonthlySalary.clamp(0.0, double.infinity);
    // 1. INSS Laboral en Nicaragua: 7%
    final inss = gross * 0.07;
    final taxableMonthly = gross - inss;
    final annualTaxable = taxableMonthly * 12.0;

    // 2. Tabla Progresiva Oficial de IR Rentas del Trabajo (DGI Nicaragua - C$)
    double annualIr = 0.0;
    if (annualTaxable <= 100000.0) {
      annualIr = 0.0;
    } else if (annualTaxable <= 200000.0) {
      annualIr = (annualTaxable - 100000.0) * 0.15;
    } else if (annualTaxable <= 350000.0) {
      annualIr = 15000.0 + (annualTaxable - 200000.0) * 0.20;
    } else if (annualTaxable <= 500000.0) {
      annualIr = 45000.0 + (annualTaxable - 350000.0) * 0.25;
    } else {
      annualIr = 82500.0 + (annualTaxable - 500000.0) * 0.30;
    }

    final irMonthly = annualIr / 12.0;
    final netMonthly = (gross - inss - irMonthly).clamp(0.0, gross);
    final netQuincenal = netMonthly / 2.0;

    final clampedMonths = workedMonthsForAguinaldo.clamp(1, 12);
    // En Nicaragua el Aguinaldo (13vo mes) es libre de deducciones de INSS e IR
    final aguinaldo = (gross / 12.0) * clampedMonths;

    return NicaraguaPayrollBreakdown(
      grossMonthly: gross,
      inssMonthly: inss,
      irMonthly: irMonthly,
      netMonthly: netMonthly,
      netQuincenal: netQuincenal,
      aguinaldoAccumulated: aguinaldo,
      workedMonths: clampedMonths,
    );
  }
}
