import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/financial_models.dart';
import '../services/recalculation_engine.dart';
import '../state/finance_controller.dart';
import '../widgets/bank_gmail_sync_modal.dart';
import '../widgets/entry_modals.dart';
import 'pin_lock_screen.dart';

class HomeShell extends StatefulWidget {
  final FinanceController controller;

  const HomeShell({
    super.key,
    required this.controller,
  });

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final pages = [
          _SimpleHomeTab(
            controller: widget.controller,
            onGoToExpenses: () => setState(() => _selectedIndex = 1),
            onGoToAdvisor: () => setState(() => _selectedIndex = 3),
          ),
          _ExpensesAndSplitTab(controller: widget.controller),
          _IncomesAndSalesTab(controller: widget.controller),
          _SmartAdvisorAndHistoryTab(controller: widget.controller),
        ];

        return Scaffold(
          appBar: AppBar(
            title: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _showPeriodSelectorDialog(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'COFIPER · Control en Córdobas (C\$)',
                      style:
                          TextStyle(fontWeight: FontWeight.w800, fontSize: 16.5),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.calendar_month_rounded, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          'Mes: ${widget.controller.currentMonthLabel} (Cambiar ▾)',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              IconButton(
                tooltip: 'Conectar Bancos / Leer Gmail',
                icon: const Icon(Icons.mark_email_read_rounded),
                onPressed: () =>
                    showBankGmailSyncModal(context, widget.controller),
              ),
              IconButton(
                tooltip: 'Rehacer cálculos de las 2 quincenas',
                icon: const Icon(Icons.auto_fix_high_rounded),
                onPressed: () {
                  widget.controller.recalculateAll(
                    respectCollectedQ1: false,
                    resetManualOverrides: true,
                    logRecalculation: true,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      behavior: SnackBarBehavior.floating,
                      content: Text(
                        '¡Cálculos de las 2 quincenas actualizados! (${widget.controller.strategy.title})',
                      ),
                    ),
                  );
                },
              ),
              PopupMenuButton<String>(
                tooltip: 'Opciones',
                onSelected: (value) {
                  if (value == 'change_pin') {
                    PinLockGate.showChangePinDialog(context);
                  } else if (value == 'lock_now') {
                    PinLockGate.lockApp(context);
                  } else if (value == 'new_month') {
                    _showNewMonthDialog(context);
                  } else if (value == 'copy_report') {
                    final report = widget.controller.generateTextReport();
                    Clipboard.setData(ClipboardData(text: report));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content:
                            Text('Resumen en Córdobas copiado al portapapeles.'),
                      ),
                    );
                  } else if (value == 'demo') {
                    widget.controller.loadDemoScenario();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content:
                            Text('Ejemplo en Córdobas (C\$) restaurado.'),
                      ),
                    );
                  } else if (value == 'clear') {
                    widget.controller.clearAllData();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            'Mes en blanco. Ya puedes meter tus propios ingresos y gastos en C\$.'),
                      ),
                    );
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'change_pin',
                    child: ListTile(
                      leading: Icon(Icons.key_rounded, color: Color(0xFF059669)),
                      title: Text('Cambiar mi PIN de Seguridad'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'lock_now',
                    child: ListTile(
                      leading: Icon(Icons.lock_rounded),
                      title: Text('Bloquear App Ahora'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'new_month',
                    child: ListTile(
                      leading: Icon(Icons.calendar_month_rounded),
                      title: Text('Iniciar Nuevo Mes'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'copy_report',
                    child: ListTile(
                      leading: Icon(Icons.copy_all_rounded),
                      title: Text('Copiar Resumen para WhatsApp / Notas'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'demo',
                    child: ListTile(
                      leading: Icon(Icons.restore_rounded),
                      title: Text('Ver Ejemplo en Córdobas (C\$)'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'clear',
                    child: ListTile(
                      leading: Icon(Icons.delete_sweep_rounded,
                          color: Colors.redAccent),
                      title: Text('Poner Todo en Cero (Empezar Limpio)'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: IndexedStack(
            index: _selectedIndex,
            children: pages,
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (idx) {
              setState(() => _selectedIndex = idx);
              if (idx == 3) {
                widget.controller.refreshOnlineAdvice();
              }
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: 'Inicio',
              ),
              NavigationDestination(
                icon: Icon(Icons.credit_card_outlined),
                selectedIcon: Icon(Icons.credit_card_rounded),
                label: 'Mis Gastos',
              ),
              NavigationDestination(
                icon: Icon(Icons.storefront_outlined),
                selectedIcon: Icon(Icons.storefront_rounded),
                label: 'Ingresos/Ventas',
              ),
              NavigationDestination(
                icon: Icon(Icons.psychology_outlined),
                selectedIcon: Icon(Icons.psychology_rounded),
                label: 'Asesor IA',
              ),
            ],
          ),
        );
      },
    );
  }

  void _showPeriodSelectorDialog(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Mis Meses Guardados',
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showNewMonthDialog(context);
                    },
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Nuevo Mes'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: widget.controller.periods.map((period) {
                    final isSelected =
                        period.id == widget.controller.activePeriodId;
                    final periodSum = RecalculationEngine.buildSummary(
                      incomes: period.incomes,
                      expenses: period.expenses,
                    );
                    return ListTile(
                      leading: Icon(
                        isSelected
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_off_rounded,
                        color: isSelected
                            ? Theme.of(ctx).colorScheme.primary
                            : null,
                      ),
                      title: Text(
                        period.monthLabel,
                        style: TextStyle(
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(
                        'Ingresos: ${formatCordobas(periodSum.totalIncome, showDecimals: false)} • Gastos: ${formatCordobas(periodSum.totalExpenses, showDecimals: false)}',
                      ),
                      onTap: () {
                        widget.controller.switchActivePeriod(period.id);
                        Navigator.pop(ctx);
                      },
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showNewMonthDialog(BuildContext context) {
    final monthCtrl = TextEditingController(text: 'Diciembre 2026');
    bool cloneBase = true;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Iniciar Nuevo Mes'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: monthCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre del Mes',
                  hintText: 'Ej. Diciembre 2026, Enero 2027...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: cloneBase,
                title: const Text('Copiar mi sueldo fijo y gastos actuales'),
                subtitle: const Text(
                  'Pasa tus tarjetas, préstamos y sueldo al nuevo mes con las casillas de pago listas para empezar.',
                ),
                onChanged: (v) {
                  if (v != null) setDialogState(() => cloneBase = v);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (monthCtrl.text.trim().isEmpty) return;
                widget.controller.createNewMonthlyPeriod(
                  monthCtrl.text.trim(),
                  cloneCurrentStructure: cloneBase,
                );
                Navigator.pop(ctx);
              },
              child: const Text('Crear Mes'),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// PESTAÑA 1: INICIO CLARO (SEMÁFORO DE EXCESO + MIS 2 QUINCENAS + RECÁLCULO)
// ============================================================================

class _SimpleHomeTab extends StatelessWidget {
  final FinanceController controller;
  final VoidCallback onGoToExpenses;
  final VoidCallback onGoToAdvisor;

  const _SimpleHomeTab({
    required this.controller,
    required this.onGoToExpenses,
    required this.onGoToAdvisor,
  });

  Color _statusColor(SpendingStatusLevel status) {
    switch (status) {
      case SpendingStatusLevel.healthy:
        return const Color(0xFF10B981);
      case SpendingStatusLevel.warningHigh:
        return const Color(0xFFF59E0B);
      case SpendingStatusLevel.exceedingLimit:
        return const Color(0xFFF97316);
      case SpendingStatusLevel.deficitCritical:
        return const Color(0xFFEF4444);
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = controller.summary;
    final statusColor = _statusColor(summary.spendingStatus);
    final spentRatio = (summary.spentPercentage / 100.0).clamp(0.0, 1.0);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        // 1. Semáforo Principal: ¿Me estoy excediendo en gastos?
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Etiqueta de valoración automática
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor.withValues(alpha: 0.6)),
                ),
                child: Row(
                  children: [
                    Icon(
                      summary.hasMonthlyDeficit
                          ? Icons.warning_amber_rounded
                          : Icons.analytics_rounded,
                      color: statusColor,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        summary.spendingStatusHeadline,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'DINERO TOTAL QUE TE QUEDA LIBRE EN EL MES:',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                formatCordobas(summary.totalFreeCash),
                style: TextStyle(
                  color: summary.hasMonthlyDeficit
                      ? const Color(0xFFFCA5A5)
                      : Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              // Barra de porcentaje de ingresos consumido por gastos
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: spentRatio,
                  minHeight: 9,
                  backgroundColor: Colors.white12,
                  valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Ingresos: ${formatCordobas(summary.totalIncome, showDecimals: false)}',
                    style: const TextStyle(
                      color: Color(0xFF6EE7B7),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Gastos: ${formatCordobas(summary.totalExpenses, showDecimals: false)}',
                    style: const TextStyle(
                      color: Color(0xFFFCA5A5),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              if (summary.totalExtraIncome > 0) ...[
                const SizedBox(height: 6),
                Text(
                  '✨ Incluye ${formatCordobas(summary.totalExtraIncome, showDecimals: false)} de tus ventas / negocios extras',
                  style: const TextStyle(
                    color: Color(0xFF38BDF8),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 14),

        // 2. Tres Botones Directos para Registrar sin perderse
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () => showIncomeFormModal(
                  context,
                  controller,
                  defaultToExtraSale: true,
                ),
                icon: const Icon(Icons.storefront_rounded, size: 18),
                label: const Text(
                  '+ Venta / Extra',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () => showIncomeFormModal(
                  context,
                  controller,
                  defaultToExtraSale: false,
                ),
                icon: const Icon(Icons.payments_rounded, size: 18),
                label: const Text(
                  '+ Sueldo',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () => showExpenseFormModal(context, controller),
                icon: const Icon(Icons.add_card_rounded, size: 18),
                label: const Text(
                  '+ Gasto/Deuda',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => showBankGmailSyncModal(context, controller),
            icon: const Icon(Icons.mark_email_read_rounded,
                color: Color(0xFF4F46E5)),
            label: const Text(
              'Sincronizar Tarjetas desde Gmail (BAC • Banpro • LAFISE • Ficohsa)',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
          ),
        ),

        const SizedBox(height: 18),

        // 3. Tus 2 Quincenas Explicadas Claramente
        Text(
          'Cómo quedan tus 2 Quincenas del Mes',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'Aquí ves cuánto dinero entra en cada quincena, cuánto debes apartar para tus gastos/tarjetas y cuánto te queda libre:',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 10),

        _ClearQuincenaCard(
          quincenaTitle: 'Primera Quincena (Días 1 al 15)',
          incomeAmount: summary.q1Income,
          extraSalesAmount: summary.q1ExtraIncome,
          expensesAmount: summary.q1Expenses,
          freeAmount: summary.q1FreeCash,
          adviceFooter: summary.q1VaultTarget > 0
              ? '📌 Importante: De esta 1ra Quincena debes guardar ${formatCordobas(summary.q1VaultTarget)} para juntarlo con la 2da Quincena y pagar tus tarjetas/préstamos.'
              : 'Todos los pagos de esta quincena están cubiertos.',
          accentColor: const Color(0xFF2563EB),
        ),

        const SizedBox(height: 12),

        _ClearQuincenaCard(
          quincenaTitle: 'Segunda Quincena (Días 16 al 30)',
          incomeAmount: summary.q2Income,
          extraSalesAmount: summary.q2ExtraIncome,
          expensesAmount: summary.q2Expenses,
          freeAmount: summary.q2FreeCash,
          adviceFooter:
              '📌 Une lo que guardaste en la 1ra Quincena + los ${formatCordobas(summary.q2Expenses)} de esta 2da Quincena para cancelar tus tarjetas y préstamos.',
          accentColor: const Color(0xFF7C3AED),
        ),

        const SizedBox(height: 16),

        // 4. Tarjeta Clara para "Rehacer Cálculos"
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.calculate_rounded,
                        color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '¿Cómo quieres repartir tus gastos en las 2 quincenas?',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...AllocationStrategy.values.map((strat) {
                  final selected = controller.strategy == strat;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        controller.setStrategyAndRecalculate(
                          strat,
                          resetManualOverrides: true,
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: selected
                              ? Theme.of(context)
                                  .colorScheme
                                  .primaryContainer
                                  .withValues(alpha: 0.5)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              selected
                                  ? Icons.radio_button_checked_rounded
                                  : Icons.radio_button_off_rounded,
                              size: 20,
                              color: selected
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.grey,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    strat.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                  Text(
                                    strat.description,
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Rehacer Cálculos Ahora'),
                        onPressed: () {
                          controller.recalculateAll(
                            respectCollectedQ1: false,
                            resetManualOverrides: true,
                            logRecalculation: true,
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              behavior: SnackBarBehavior.floating,
                              content: Text(
                                  '¡Listo! Se recalcularon los montos de cada gasto para ambas quincenas.'),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: onGoToExpenses,
                      child: const Text('Ver Gastos →'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ClearQuincenaCard extends StatelessWidget {
  final String quincenaTitle;
  final double incomeAmount;
  final double extraSalesAmount;
  final double expensesAmount;
  final double freeAmount;
  final String adviceFooter;
  final Color accentColor;

  const _ClearQuincenaCard({
    required this.quincenaTitle,
    required this.incomeAmount,
    required this.extraSalesAmount,
    required this.expensesAmount,
    required this.freeAmount,
    required this.adviceFooter,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final isNegative = freeAmount < -0.01;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isNegative
              ? Colors.redAccent
              : accentColor.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: accentColor.withValues(alpha: 0.15),
                foregroundColor: accentColor,
                child: const Icon(Icons.event_available_rounded, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  quincenaTitle,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Dinero que entra:', style: TextStyle(fontSize: 13.5)),
              Text(
                formatCordobas(incomeAmount),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF059669),
                ),
              ),
            ],
          ),
          if (extraSalesAmount > 0)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '  (Incluye ${formatCordobas(extraSalesAmount)} de ventas/negocios extras)',
                style: const TextStyle(fontSize: 11.5, color: Color(0xFF0284C7)),
              ),
            ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('A repartir en gastos/deudas:',
                  style: TextStyle(fontSize: 13.5)),
              Text(
                '- ${formatCordobas(expensesAmount)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFDC2626),
                ),
              ),
            ],
          ),
          const Divider(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isNegative ? '⚠️ Te faltan:' : 'Te quedan libres:',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                formatCordobas(freeAmount),
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  color:
                      isNegative ? Colors.redAccent : const Color(0xFF059669),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              adviceFooter,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// PESTAÑA 2: MIS GASTOS Y DEUDAS (CUÁNTO PONER EN CADA QUINCENA)
// ============================================================================

class _ExpensesAndSplitTab extends StatelessWidget {
  final FinanceController controller;

  const _ExpensesAndSplitTab({required this.controller});

  @override
  Widget build(BuildContext context) {
    final summary = controller.summary;
    final twoQList = controller.twoQuincenaExpenses;
    final singleQList = controller.singleQuincenaExpenses;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        // Resumen fijo arriba de cuánto queda libre en cada quincena
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _LiveCashChip(
                label: 'Libre 1ra Quincena',
                amount: summary.q1FreeCash,
              ),
              Container(width: 1, height: 32, color: Colors.white24),
              _LiveCashChip(
                label: 'Libre 2da Quincena',
                amount: summary.q2FreeCash,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () => showExpenseFormModal(context, controller),
                icon: const Icon(Icons.add_card_rounded),
                label: const Text('+ Nuevo Gasto'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: () => showBankGmailSyncModal(context, controller),
                icon: const Icon(Icons.mark_email_read_rounded),
                label: const Text('Leer Bancos (Gmail)'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        Text(
          'Gastos que recogen dinero de las 2 Quincenas',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'Tarjetas de crédito, préstamos y gastos grandes: mueve la barra si en una quincena necesitas poner menos y pasar el resto a la otra.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 10),

        if (twoQList.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No tienes gastos de 2 quincenas registrados aún.'),
            ),
          ),

        ...twoQList.map(
          (exp) => _InteractiveSplitExpenseCard(
            expense: exp,
            controller: controller,
          ),
        ),

        if (singleQList.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text(
            'Gastos de 1 Sola Quincena',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          ...singleQList.map(
            (exp) => Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: exp.category.color.withValues(alpha: 0.15),
                  foregroundColor: exp.category.color,
                  child: Icon(exp.category.icon),
                ),
                title: Text(
                  exp.title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('${exp.category.label} • ${exp.splitMode.label}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      formatCordobas(exp.totalAmount),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded,
                          color: Colors.redAccent),
                      onPressed: () => controller.deleteExpense(exp.id),
                    ),
                  ],
                ),
                onTap: () => showExpenseFormModal(
                  context,
                  controller,
                  existing: exp,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _LiveCashChip extends StatelessWidget {
  final String label;
  final double amount;

  const _LiveCashChip({required this.label, required this.amount});

  @override
  Widget build(BuildContext context) {
    final isNeg = amount < -0.01;
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 11.5),
        ),
        const SizedBox(height: 2),
        Text(
          formatCordobas(amount),
          style: TextStyle(
            color: isNeg ? Colors.redAccent.shade100 : const Color(0xFF6EE7B7),
            fontWeight: FontWeight.bold,
            fontSize: 15.5,
          ),
        ),
      ],
    );
  }
}

class _InteractiveSplitExpenseCard extends StatelessWidget {
  final ExpenseItem expense;
  final FinanceController controller;

  const _InteractiveSplitExpenseCard({
    required this.expense,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final q1Pct = expense.totalAmount > 0
        ? ((expense.q1Allocation / expense.totalAmount) * 100).round()
        : 50;
    final q2Pct = 100 - q1Pct;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: expense.category.color.withValues(alpha: 0.4),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor:
                      expense.category.color.withValues(alpha: 0.15),
                  foregroundColor: expense.category.color,
                  child: Icon(expense.category.icon),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        expense.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15.5,
                        ),
                      ),
                      Text(
                        [
                          expense.category.label,
                          if (expense.cutoffDay != null)
                            'Corte: Día ${expense.cutoffDay}',
                          if (expense.dueDay != null)
                            'Pago: Día ${expense.dueDay}',
                        ].join(' • '),
                        style: TextStyle(
                          fontSize: 12,
                          color: expense.category.color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatCordobas(expense.totalAmount),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const Text(
                      'Total del mes',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Cajas de 1ra Quincena y 2da Quincena
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '1ra Quincena ($q1Pct%)',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          formatCordobas(expense.q1Allocation),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: () => controller.toggleQuincenaCollected(
                            expense.id,
                            isQ1: true,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                expense.q1Collected
                                    ? Icons.check_box_rounded
                                    : Icons.check_box_outline_blank_rounded,
                                size: 18,
                                color: expense.q1Collected
                                    ? const Color(0xFF10B981)
                                    : Colors.grey,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  expense.q1Collected
                                      ? 'Ya aparté'
                                      : 'Marcar apartado',
                                  style: const TextStyle(fontSize: 11.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(Icons.add_rounded, color: Colors.grey, size: 18),
                ),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '2da Quincena ($q2Pct%)',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF7C3AED),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          formatCordobas(expense.q2Allocation),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: () => controller.toggleQuincenaCollected(
                            expense.id,
                            isQ1: false,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                expense.q2Collected
                                    ? Icons.check_box_rounded
                                    : Icons.check_box_outline_blank_rounded,
                                size: 18,
                                color: expense.q2Collected
                                    ? const Color(0xFF10B981)
                                    : Colors.grey,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  expense.q2Collected
                                      ? 'Ya pagué'
                                      : 'Marcar pagado',
                                  style: const TextStyle(fontSize: 11.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 6),
            Slider(
              value: expense.q1Allocation.clamp(0.0, expense.totalAmount),
              min: 0.0,
              max: expense.totalAmount > 0 ? expense.totalAmount : 1.0,
              divisions: 20,
              label:
                  '1ra: ${formatCordobas(expense.q1Allocation, showDecimals: false)} / 2da: ${formatCordobas(expense.q2Allocation, showDecimals: false)}',
              onChanged: (newVal) {
                controller.updateManualSplitForExpense(expense.id, newVal);
              },
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  expense.splitMode == SplitMode.customManual
                      ? 'Ajustado manualmente por ti'
                      : 'Reparto automático activo',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                Row(
                  children: [
                    if (expense.splitMode == SplitMode.customManual)
                      TextButton(
                        onPressed: () =>
                            controller.resetExpenseToAutoSplit(expense.id),
                        child: const Text('Volver a Auto'),
                      ),
                    IconButton(
                      tooltip: 'Editar gasto',
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      onPressed: () => showExpenseFormModal(
                        context,
                        controller,
                        existing: expense,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Eliminar gasto',
                      icon: const Icon(Icons.delete_outline_rounded,
                          size: 18, color: Colors.redAccent),
                      onPressed: () => controller.deleteExpense(expense.id),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// PESTAÑA 3: MIS INGRESOS FIJOS Y VENTAS / NEGOCIOS EXTRAS
// ============================================================================

class _IncomesAndSalesTab extends StatelessWidget {
  final FinanceController controller;

  const _IncomesAndSalesTab({required this.controller});

  @override
  Widget build(BuildContext context) {
    final extraSales = controller.extraSalesAndBusinessIncomes;
    final fixedList = controller.fixedIncomes;
    final summary = controller.summary;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        // Botones claros para registrar Venta/Negocio o Sueldo Fijo
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () => showIncomeFormModal(
                  context,
                  controller,
                  defaultToExtraSale: true,
                ),
                icon: const Icon(Icons.storefront_rounded),
                label: const Text('+ Venta / Negocio Extra'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () => showIncomeFormModal(
                  context,
                  controller,
                  defaultToExtraSale: false,
                ),
                icon: const Icon(Icons.payments_rounded),
                label: const Text('+ Sueldo Fijo'),
              ),
            ),
          ],
        ),

        const SizedBox(height: 18),

        // Sección 1: Ventas, Negocios e Ingresos Extras en la Semana o Quincena
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Ventas y Negocios Extras (${formatCordobas(summary.totalExtraIncome, showDecimals: false)})',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Registra aquí cualquier venta, negocio o ingreso extra que hagas en la semana o durante la quincena:',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),

        if (extraSales.isEmpty)
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Aún no has registrado ventas o negocios extras en este mes. Toca "+ Venta / Negocio Extra" cuando te entre un dinero adicional.',
              ),
            ),
          ),

        ...extraSales.map(
          (inc) => Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE0F2FE),
                foregroundColor: Color(0xFF0284C7),
                child: Icon(Icons.storefront_rounded),
              ),
              title: Text(
                inc.title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                [
                  inc.frequency.shortLabel,
                  if (inc.noteOrWeek != null) inc.noteOrWeek!,
                ].join(' • '),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    formatCordobas(inc.monthlyTotal),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0284C7),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded,
                        color: Colors.redAccent),
                    onPressed: () => controller.deleteIncome(inc.id),
                  ),
                ],
              ),
              onTap: () => showIncomeFormModal(
                context,
                controller,
                existing: inc,
              ),
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Sección 2: Sueldo e Ingresos Fijos
        Text(
          'Sueldo e Ingresos Fijos (Quincenal o Mensual)',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        if (fixedList.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No has registrado ingresos fijos aún.'),
            ),
          ),
        ...fixedList.map(
          (inc) => Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFD1FAE5),
                foregroundColor: Color(0xFF047857),
                child: Icon(Icons.payments_rounded),
              ),
              title: Text(
                inc.title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                '${inc.frequency.shortLabel} → 1ra: ${formatCordobas(inc.q1Amount, showDecimals: false)} | 2da: ${formatCordobas(inc.q2Amount, showDecimals: false)}',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${formatCordobas(inc.monthlyTotal, showDecimals: false)}/mes',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF047857),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded,
                        color: Colors.redAccent),
                    onPressed: () => controller.deleteIncome(inc.id),
                  ),
                ],
              ),
              onTap: () => showIncomeFormModal(
                context,
                controller,
                existing: inc,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// PESTAÑA 4: ASESOR IA CON INTERNET + VALORACIÓN DE EXCESO + BITÁCORA
// ============================================================================

class _SmartAdvisorAndHistoryTab extends StatefulWidget {
  final FinanceController controller;

  const _SmartAdvisorAndHistoryTab({required this.controller});

  @override
  State<_SmartAdvisorAndHistoryTab> createState() =>
      _SmartAdvisorAndHistoryTabState();
}

class _SmartAdvisorAndHistoryTabState
    extends State<_SmartAdvisorAndHistoryTab> {
  double _simulatedNewDebt = 2000.0;

  String _formatDateTime(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$d/$m/${dt.year} $h:$min';
  }

  @override
  Widget build(BuildContext context) {
    final summary = widget.controller.summary;
    final localInsights = widget.controller.advisorInsights;
    final onlineResult = widget.controller.onlineAdvice;
    final isChecking = widget.controller.isCheckingOnline;

    final simPerQuincena = _simulatedNewDebt / 2.0;
    final newQ1Free = summary.q1FreeCash - simPerQuincena;
    final newQ2Free = summary.q2FreeCash - simPerQuincena;
    final canAfford = newQ1Free >= 0 && newQ2Free >= 0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        // 1. Valoración de Datos: ¿Me estoy excediendo en gastos?
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.speed_rounded, color: Color(0xFF4F46E5)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Evaluación: ¿Me estoy excediendo en gastos?',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'La app compara tus gastos en Córdobas contra los límites saludables recomendados para tu nivel de ingreso:',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 14),
                ...summary.categoryValuations.map((val) {
                  final ratio = val.recommendedMaxPct > 0
                      ? (val.percentageOfIncome / val.recommendedMaxPct)
                          .clamp(0.0, 1.0)
                      : 0.0;
                  final barColor = val.isExceeding
                      ? const Color(0xFFEF4444)
                      : const Color(0xFF10B981);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                val.categoryGroupTitle,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Text(
                              '${formatCordobas(val.currentAmount, showDecimals: false)} (${val.percentageOfIncome.toStringAsFixed(0)}%)',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: barColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: ratio,
                            minHeight: 8,
                            backgroundColor: Colors.grey.withValues(alpha: 0.2),
                            valueColor: AlwaysStoppedAnimation<Color>(barColor),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          val.isExceeding
                              ? '⚠️ Te excedes por ${formatCordobas(val.excessAmount, showDecimals: false)} (Máximo saludable: ${formatCordobas(val.recommendedMaxAmount, showDecimals: false)})'
                              : '✅ Dentro del límite saludable (Máx: ${formatCordobas(val.recommendedMaxAmount, showDecimals: false)})',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: val.isExceeding
                                ? const Color(0xFFDC2626)
                                : const Color(0xFF047857),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // 2. Consejos de Mejora en Línea (Asesor IA con Internet)
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: (onlineResult?.isOnline ?? false)
                ? const Color(0xFF0EA5E9).withValues(alpha: 0.1)
                : Colors.amber.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: (onlineResult?.isOnline ?? false)
                  ? const Color(0xFF0EA5E9).withValues(alpha: 0.4)
                  : Colors.amber.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            children: [
              Icon(
                (onlineResult?.isOnline ?? false)
                    ? Icons.wifi_rounded
                    : Icons.wifi_off_rounded,
                color: (onlineResult?.isOnline ?? false)
                    ? const Color(0xFF0284C7)
                    : Colors.amber.shade800,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (onlineResult?.isOnline ?? false)
                          ? 'Conectado a Internet · Consejos IA Activos'
                          : 'Modo Local · Conéctate para actualizar tips en línea',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const Text(
                      'Analiza tus ingresos, ventas extras y deudas para darte un plan de mejora.',
                      style: TextStyle(fontSize: 11.5),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Actualizar consejos con internet',
                onPressed: isChecking
                    ? null
                    : () => widget.controller.refreshOnlineAdvice(),
                icon: isChecking
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        ...localInsights.map((item) => _InsightCard(insight: item)),
        if (onlineResult != null)
          ...onlineResult.tips.map((item) => _InsightCard(insight: item)),

        const SizedBox(height: 16),

        // 3. Simulador en Córdobas (C$)
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.science_rounded, color: Color(0xFF6366F1)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Simulador: ¿Me alcanza para un nuevo gasto?',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Prueba cuánto te quedaría en cada quincena si adquieres una nueva deuda o gasto mensual en Córdobas:',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                Text(
                  'Nuevo gasto mensual: ${formatCordobas(_simulatedNewDebt, showDecimals: false)} (${formatCordobas(simPerQuincena, showDecimals: false)} por quincena)',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Slider(
                  value: _simulatedNewDebt,
                  min: 500,
                  max: 15000,
                  divisions: 29,
                  label: formatCordobas(_simulatedNewDebt, showDecimals: false),
                  onChanged: (v) => setState(() => _simulatedNewDebt = v),
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: canAfford
                        ? const Color(0xFF10B981).withValues(alpha: 0.1)
                        : Colors.redAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        canAfford
                            ? '✅ Sí te alcanza en ambas quincenas'
                            : '🚨 No recomendable: Te dejaría en negativo',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: canAfford
                              ? const Color(0xFF047857)
                              : Colors.redAccent,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '• Te quedaría en 1ra Quincena: ${formatCordobas(newQ1Free)}\n'
                        '• Te quedaría en 2da Quincena: ${formatCordobas(newQ2Free)}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),

        // 4. Bitácora Histórica de Movimientos Guardados
        Text(
          'Bitácora de Movimientos Guardados (${widget.controller.activityLogs.length})',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        ...widget.controller.activityLogs.take(25).map(
              (entry) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: entry.type.color.withValues(alpha: 0.15),
                    foregroundColor: entry.type.color,
                    child: Icon(entry.type.icon, size: 16),
                  ),
                  title: Text(
                    entry.title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${entry.detail} • ${_formatDateTime(entry.timestamp)}',
                  ),
                  trailing: entry.amount != null
                      ? Text(
                          formatCordobas(entry.amount!, showDecimals: false),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: entry.type.color,
                          ),
                        )
                      : null,
                ),
              ),
            ),
      ],
    );
  }
}

class _InsightCard extends StatelessWidget {
  final AdvisorInsight insight;

  const _InsightCard({required this.insight});

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;
    switch (insight.severity) {
      case InsightSeverity.positive:
        color = const Color(0xFF10B981);
        icon = Icons.verified_rounded;
        break;
      case InsightSeverity.warning:
        color = const Color(0xFFF59E0B);
        icon = Icons.warning_amber_rounded;
        break;
      case InsightSeverity.critical:
        color = const Color(0xFFEF4444);
        icon = Icons.error_outline_rounded;
        break;
      case InsightSeverity.info:
        color = const Color(0xFF0284C7);
        icon = Icons.lightbulb_outline_rounded;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  insight.title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  insight.message,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (insight.actionStep != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    '💡 ${insight.actionStep!}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
