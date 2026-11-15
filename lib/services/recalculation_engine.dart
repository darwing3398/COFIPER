import 'dart:io';
import '../models/financial_models.dart';

class AdvisorInsight {
  final String title;
  final String message;
  final String? actionStep;
  final InsightSeverity severity;

  const AdvisorInsight({
    required this.title,
    required this.message,
    required this.severity,
    this.actionStep,
  });
}

enum InsightSeverity { positive, warning, critical, info }

class OnlineAdviceResult {
  final bool isOnline;
  final DateTime fetchedAt;
  final List<AdvisorInsight> tips;

  const OnlineAdviceResult({
    required this.isOnline,
    required this.fetchedAt,
    required this.tips,
  });
}

class RecalculationEngine {
  /// Rehace todos los cálculos de distribución de gastos entre la 1ra Quincena y la 2da Quincena.
  static List<ExpenseItem> recalculateExpenses({
    required List<IncomeItem> incomes,
    required List<ExpenseItem> expenses,
    required AllocationStrategy strategy,
    bool respectCollectedQ1 = true,
    bool resetManualOverrides = false,
  }) {
    final double q1Income =
        incomes.fold(0.0, (sum, item) => sum + item.q1Amount);
    final double q2Income =
        incomes.fold(0.0, (sum, item) => sum + item.q2Amount);
    final double totalIncome = q1Income + q2Income;

    final List<ExpenseItem> workingList = expenses.map((e) {
      if (resetManualOverrides && e.splitMode == SplitMode.customManual) {
        return e.copyWith(splitMode: SplitMode.twoQuincenasAuto);
      }
      return e;
    }).toList();

    double fixedQ1 = 0.0;
    double fixedQ2 = 0.0;
    double autoPoolTotal = 0.0;

    for (final exp in workingList) {
      if (exp.splitMode == SplitMode.onlyQ1) {
        fixedQ1 += exp.totalAmount;
      } else if (exp.splitMode == SplitMode.onlyQ2) {
        fixedQ2 += exp.totalAmount;
      } else if (exp.splitMode == SplitMode.customManual ||
          (respectCollectedQ1 && exp.q1Collected)) {
        final clampedQ1 = exp.q1Allocation.clamp(0.0, exp.totalAmount);
        fixedQ1 += clampedQ1;
        fixedQ2 += (exp.totalAmount - clampedQ1);
      } else if (exp.splitMode == SplitMode.twoQuincenasAuto) {
        autoPoolTotal += exp.totalAmount;
      }
    }

    double q1ShareRatio = 0.5;

    if (autoPoolTotal > 0) {
      switch (strategy) {
        case AllocationStrategy.equal5050:
          q1ShareRatio = 0.5;
          break;

        case AllocationStrategy.incomeProportional:
          q1ShareRatio = totalIncome > 0 ? (q1Income / totalIncome) : 0.5;
          break;

        case AllocationStrategy.liquidityBalance:
          final double remQ1 = q1Income - fixedQ1;
          final double remQ2 = q2Income - fixedQ2;
          final double targetAutoQ1 =
              ((autoPoolTotal + remQ1 - remQ2) / 2.0).clamp(0.0, autoPoolTotal);
          q1ShareRatio = targetAutoQ1 / autoPoolTotal;
          break;
      }
    }

    return workingList.map((exp) {
      switch (exp.splitMode) {
        case SplitMode.onlyQ1:
          return exp.copyWith(
            q1Allocation: exp.totalAmount,
            q2Allocation: 0.0,
          );

        case SplitMode.onlyQ2:
          return exp.copyWith(
            q1Allocation: 0.0,
            q2Allocation: exp.totalAmount,
          );

        case SplitMode.customManual:
          final double safeQ1 = exp.q1Allocation.clamp(0.0, exp.totalAmount);
          final double safeQ2 =
              (exp.totalAmount - safeQ1).clamp(0.0, exp.totalAmount);
          return exp.copyWith(
            q1Allocation: _roundCents(safeQ1),
            q2Allocation: _roundCents(safeQ2),
          );

        case SplitMode.twoQuincenasAuto:
          if (respectCollectedQ1 && exp.q1Collected) {
            final double safeQ1 = exp.q1Allocation.clamp(0.0, exp.totalAmount);
            return exp.copyWith(
              q1Allocation: _roundCents(safeQ1),
              q2Allocation: _roundCents(exp.totalAmount - safeQ1),
            );
          }
          final double q1Val = _roundCents(exp.totalAmount * q1ShareRatio);
          final double q2Val = _roundCents(exp.totalAmount - q1Val);
          return exp.copyWith(
            q1Allocation: q1Val,
            q2Allocation: q2Val,
          );
      }
    }).toList();
  }

  /// Calcula el resumen financiero completo de las 2 quincenas y valora si se está excediendo en gastos.
  static MonthlyPlanSummary buildSummary({
    required List<IncomeItem> incomes,
    required List<ExpenseItem> expenses,
  }) {
    final double q1Income =
        incomes.fold(0.0, (sum, item) => sum + item.q1Amount);
    final double q2Income =
        incomes.fold(0.0, (sum, item) => sum + item.q2Amount);

    final double q1ExtraIncome = incomes
        .where((i) => i.isExtraSaleOrBusiness)
        .fold(0.0, (sum, item) => sum + item.q1Amount);
    final double q2ExtraIncome = incomes
        .where((i) => i.isExtraSaleOrBusiness)
        .fold(0.0, (sum, item) => sum + item.q2Amount);

    double q1Expenses = 0.0;
    double q2Expenses = 0.0;
    double q1VaultTarget = 0.0;
    double vaultLockedNow = 0.0;
    double totalDebtPayments = 0.0;
    double totalEssentialExpenses = 0.0;
    double totalFlexibleAndAntExpenses = 0.0;

    for (final exp in expenses) {
      q1Expenses += exp.q1Allocation;
      q2Expenses += exp.q2Allocation;

      if (exp.collectsFromTwoQuincenas) {
        q1VaultTarget += exp.q1Allocation;
        if (exp.q1Collected && !exp.q2Collected) {
          vaultLockedNow += exp.q1Allocation;
        }
      }

      if (exp.category == ExpenseCategory.creditCard ||
          exp.category == ExpenseCategory.loan) {
        totalDebtPayments += exp.totalAmount;
      } else if (exp.category == ExpenseCategory.housing ||
          exp.category == ExpenseCategory.utilities ||
          exp.category == ExpenseCategory.food ||
          exp.category == ExpenseCategory.transport) {
        totalEssentialExpenses += exp.totalAmount;
      } else {
        totalFlexibleAndAntExpenses += exp.totalAmount;
      }
    }

    return MonthlyPlanSummary(
      q1Income: q1Income,
      q2Income: q2Income,
      q1ExtraIncome: q1ExtraIncome,
      q2ExtraIncome: q2ExtraIncome,
      q1Expenses: q1Expenses,
      q2Expenses: q2Expenses,
      q1VaultTarget: q1VaultTarget,
      vaultLockedNow: vaultLockedNow,
      totalDebtPayments: totalDebtPayments,
      totalEssentialExpenses: totalEssentialExpenses,
      totalFlexibleAndAntExpenses: totalFlexibleAndAntExpenses,
    );
  }

  /// Genera diagnósticos automáticos locales valorando si hay exceso de gastos.
  static List<AdvisorInsight> generateInsights({
    required MonthlyPlanSummary summary,
    required List<ExpenseItem> expenses,
  }) {
    final List<AdvisorInsight> insights = [];

    if (summary.hasMonthlyDeficit) {
      insights.add(
        AdvisorInsight(
          title: '🚨 Te estás excediendo en gastos este mes',
          message:
              'Tus gastos totales (${formatCordobas(summary.totalExpenses)}) superan tus ingresos (${formatCordobas(summary.totalIncome)}) por ${formatCordobas(summary.totalFreeCash.abs())}.',
          actionStep:
              'Acción inmediata: Recorta gastos diarios/hormiga o registra una venta/negocio extra de al menos ${formatCordobas(summary.totalFreeCash.abs())} para no endeudarte más.',
          severity: InsightSeverity.critical,
        ),
      );
    } else if (summary.hasQ1Deficit || summary.hasQ2Deficit) {
      final String tightQ = summary.hasQ1Deficit
          ? '1ra Quincena (Días 1-15)'
          : '2da Quincena (Días 16-30)';
      final double deficitAmt = summary.hasQ1Deficit
          ? summary.q1FreeCash.abs()
          : summary.q2FreeCash.abs();
      insights.add(
        AdvisorInsight(
          title: '⚠️ Desbalance en la $tightQ',
          message:
              'En el mes sí te alcanza el dinero, pero en la $tightQ te faltan ${formatCordobas(deficitAmt)} porque se te juntaron muchos pagos ahí.',
          actionStep:
              'Toca el botón "Rehacer Cálculos de mis 2 Quincenas" en Inicio para pasar parte de tus tarjetas/préstamos a la otra quincena.',
          severity: InsightSeverity.warning,
        ),
      );
    } else {
      insights.add(
        AdvisorInsight(
          title: '✅ Tus 2 Quincenas están bien balanceadas',
          message:
              'Te quedan libres ${formatCordobas(summary.q1FreeCash)} en la 1ra Quincena y ${formatCordobas(summary.q2FreeCash)} en la 2da Quincena después de apartar todas tus deudas y gastos.',
          actionStep:
              'Guarda al menos el 30% de ese dinero libre como fondo de emergencia.',
          severity: InsightSeverity.positive,
        ),
      );
    }

    // Valorar cada categoría donde se esté excediendo
    for (final catVal in summary.categoryValuations) {
      if (catVal.isExceeding) {
        insights.add(
          AdvisorInsight(
            title: 'Exceso en ${catVal.categoryGroupTitle}',
            message:
                'Estás destinando ${formatCordobas(catVal.currentAmount)} (${catVal.percentageOfIncome.toStringAsFixed(0)}% de tu ingreso), cuando el máximo recomendable es ${catVal.recommendedMaxPct.toStringAsFixed(0)}% (${formatCordobas(catVal.recommendedMaxAmount)}).',
            actionStep:
                'Te estás pasando por ${formatCordobas(catVal.excessAmount)} en este rubro.',
            severity: InsightSeverity.warning,
          ),
        );
      }
    }

    // Recordatorio de apartar el dinero de la 1ra Quincena
    if (summary.q1VaultTarget > 0) {
      insights.add(
        AdvisorInsight(
          title: 'Regla para Tarjetas y Préstamos en 1ra Quincena',
          message:
              'De tu 1ra Quincena debes recoger ${formatCordobas(summary.q1VaultTarget)} para pagar tus tarjetas y préstamos a fin de mes.',
          actionStep:
              'Apenas recibas la 1ra Quincena, separa esos ${formatCordobas(summary.q1VaultTarget)} en otra cuenta o sobre para no gastártelos antes del día de pago.',
          severity: InsightSeverity.info,
        ),
      );
    }

    return insights;
  }

  /// Verifica si hay acceso a Internet y genera consejos avanzados de mejora y balanceo
  /// adaptados a la situación actual en Córdobas (C$).
  static Future<OnlineAdviceResult> fetchOnlineImprovementTips({
    required MonthlyPlanSummary summary,
    required List<IncomeItem> incomes,
    required List<ExpenseItem> expenses,
  }) async {
    bool hasInternet = false;
    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      try {
        final result = await InternetAddress.lookup('one.one.one.one')
            .timeout(const Duration(seconds: 3));
        hasInternet = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      } catch (_) {
        hasInternet = false;
      }
    }

    final List<AdvisorInsight> dynamicTips = [];

    // Ordenar gastos de mayor a menor para dar recomendaciones con nombres reales
    final sortedExpenses = [...expenses]
      ..sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
    final biggestExpense =
        sortedExpenses.isNotEmpty ? sortedExpenses.first : null;

    final debtItems = expenses
        .where((e) =>
            e.category == ExpenseCategory.creditCard ||
            e.category == ExpenseCategory.loan)
        .toList()
      ..sort((a, b) => b.totalAmount.compareTo(a.totalAmount));

    if (summary.hasMonthlyDeficit ||
        summary.hasQ1Deficit ||
        summary.hasQ2Deficit ||
        summary.spentPercentage > 80) {
      // Situación delicada o ajustada: Plan de Rescate Inteligente
      final neededExtra = summary.hasMonthlyDeficit
          ? summary.totalFreeCash.abs()
          : (summary.totalIncome * 0.15);

      dynamicTips.add(
        AdvisorInsight(
          title: 'Plan de Rescate: Meta Semanal de Ventas / Ingreso Extra',
          message:
              'Para estabilizar tus quincenas sin tocar tarjetas de crédito, tu meta ideal de ingresos extras o ventas en el mes es de ${formatCordobas(neededExtra)} (aprox. ${formatCordobas(neededExtra / 4)} por semana).',
          actionStep:
              'Registra cada venta o trabajo extra en la pestaña "Ingresos" eligiendo la quincena en que entró para que la app reduzca automáticamente la presión sobre tu sueldo fijo.',
          severity: InsightSeverity.info,
        ),
      );

      if (debtItems.isNotEmpty) {
        final topDebt = debtItems.first;
        dynamicTips.add(
          AdvisorInsight(
            title: 'Estrategia contra Intereses Bancarios (${topDebt.title})',
            message:
                'Tu compromiso financiero más fuerte es "${topDebt.title}" con ${formatCordobas(topDebt.totalAmount)} al mes. En Nicaragua, pagar solo el mínimo de una tarjeta puede costarte más del 45% anual en intereses y cargos.',
            actionStep:
                'Recoge puntualmente ${formatCordobas(topDebt.q1Allocation)} en la 1ra Quincena y ${formatCordobas(topDebt.q2Allocation)} en la 2da Quincena para pagar de contado antes del día ${topDebt.dueDay ?? 28}.',
            severity: InsightSeverity.warning,
          ),
        );
      }

      if (biggestExpense != null) {
        dynamicTips.add(
          AdvisorInsight(
            title: 'Regla del 10% sobre tu Gasto Mayor (${biggestExpense.title})',
            message:
                'Tu gasto número 1 del mes es "${biggestExpense.title}" (${formatCordobas(biggestExpense.totalAmount)}). Si logras reducir un 10% entre este rubro y tus gastos diarios, liberarás ${formatCordobas(summary.totalExpenses * 0.10)} cada mes.',
            actionStep:
                'Usa ese ahorro de ${formatCordobas(summary.totalExpenses * 0.10)} para abonar a capital de tu deuda más pequeña (Método Bola de Nieve).',
            severity: InsightSeverity.positive,
          ),
        );
      }
    } else {
      // Situación positiva: Consejos de crecimiento y blindaje quincenal
      dynamicTips.add(
        AdvisorInsight(
          title: 'Multiplicación con tus Ganancias / Ingresos Libres',
          message:
              'Tienes un excedente mensual saludable de ${formatCordobas(summary.totalFreeCash)}. No lo dejes mezclado con el dinero de gastos diarios.',
          actionStep:
              'Destina ${formatCordobas(summary.totalFreeCash * 0.50)} a capital de trabajo (para invertir en más ventas/negocio) y ${formatCordobas(summary.totalFreeCash * 0.50)} a un ahorro intocable.',
          severity: InsightSeverity.positive,
        ),
      );
    }

    if (summary.totalExtraIncome > 0) {
      dynamicTips.add(
        AdvisorInsight(
          title: 'Buen Impulso por Ventas / Negocios Extras',
          message:
              'Este mes has sumado ${formatCordobas(summary.totalExtraIncome)} por ventas o negocios extras (Q1: ${formatCordobas(summary.q1ExtraIncome)} | Q2: ${formatCordobas(summary.q2ExtraIncome)}).',
          actionStep:
              'Consejo Senior: Separa siempre el costo de reposición de tu mercadería antes de usar la ganancia para gastos personales.',
          severity: InsightSeverity.positive,
        ),
      );
    }

    return OnlineAdviceResult(
      isOnline: hasInternet,
      fetchedAt: DateTime.now(),
      tips: dynamicTips,
    );
  }

  static double _roundCents(double value) {
    return (value * 100).roundToDouble() / 100.0;
  }
}
