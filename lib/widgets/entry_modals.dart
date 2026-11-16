import 'package:flutter/material.dart';
import '../models/financial_models.dart';
import '../state/finance_controller.dart';

Future<void> showIncomeFormModal(
  BuildContext context,
  FinanceController controller, {
  IncomeItem? existing,
  bool defaultToExtraSale = false,
}) async {
  final titleCtrl = TextEditingController(text: existing?.title ?? '');
  final amountCtrl = TextEditingController(
    text: existing != null ? existing.amount.toStringAsFixed(2) : '',
  );
  final investmentCostCtrl = TextEditingController(
    text: (existing != null && existing.investmentCost > 0)
        ? existing.investmentCost.toStringAsFixed(2)
        : '',
  );
  final noteOrWeekCtrl =
      TextEditingController(text: existing?.noteOrWeek ?? '');

  IncomeOrigin selectedOrigin = existing?.origin ??
      (defaultToExtraSale
          ? IncomeOrigin.extraSaleOrBusiness
          : IncomeOrigin.fixedSalary);

  IncomeFrequency selectedFrequency =
      existing?.frequency ?? IncomeFrequency.onlyQ1;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setModalState) {
          final parsedAmount =
              double.tryParse(amountCtrl.text.replaceAll(',', '.')) ?? 0.0;
          final isExtra = selectedOrigin == IncomeOrigin.extraSaleOrBusiness;
          final parsedCost = isExtra
              ? (double.tryParse(
                      investmentCostCtrl.text.replaceAll(',', '.')) ??
                  0.0)
              : 0.0;
          final previewItem = IncomeItem(
            id: 'preview',
            title: 'Preview',
            amount: parsedAmount,
            frequency: selectedFrequency,
            origin: selectedOrigin,
            investmentCost: parsedCost,
          );

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(selectedOrigin.icon, color: selectedOrigin.color),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          existing == null
                              ? (isExtra
                                  ? 'Registrar Venta o Ingreso Extra'
                                  : 'Registrar Sueldo / Ingreso Fijo')
                              : 'Editar Ingreso',
                          style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Selector de Tipo: Sueldo Fijo vs Venta / Negocio Extra
                  SegmentedButton<IncomeOrigin>(
                    segments: const [
                      ButtonSegment(
                        value: IncomeOrigin.fixedSalary,
                        icon: Icon(Icons.payments_rounded),
                        label: Text('Sueldo Fijo'),
                      ),
                      ButtonSegment(
                        value: IncomeOrigin.extraSaleOrBusiness,
                        icon: Icon(Icons.storefront_rounded),
                        label: Text('Venta / Negocio Extra'),
                      ),
                    ],
                    selected: {selectedOrigin},
                    onSelectionChanged: (vals) {
                      final next = vals.first;
                      setModalState(() {
                        selectedOrigin = next;
                        if (existing == null) {
                          selectedFrequency = IncomeFrequency.onlyQ1;
                        }
                      });
                    },
                  ),

                  const SizedBox(height: 14),
                  TextField(
                    controller: titleCtrl,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: isExtra
                          ? '¿De qué fue la venta o negocio?'
                          : 'Nombre de tu ingreso fijo',
                      hintText: isExtra
                          ? 'Ej. Venta de mercadería, encargo, trabajo extra...'
                          : 'Ej. Salario Quincenal, Pago Mensual...',
                      prefixIcon: Icon(selectedOrigin.icon),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setModalState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Monto en Córdobas (C\$)',
                      hintText: 'Ej. 12000 o 2500',
                      prefixText: 'C\$ ',
                      prefixIcon: Icon(Icons.payments_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (isExtra) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: investmentCostCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setModalState(() {}),
                      decoration: const InputDecoration(
                        labelText:
                            'Costo / Capital invertido del producto (Opcional C\$)',
                        hintText:
                            'Ej. 1500 (Se separa tu capital de la ganancia neta)',
                        prefixText: 'C\$ ',
                        prefixIcon: Icon(Icons.inventory_2_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (parsedCost > 0 && parsedAmount > 0) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0EA5E9).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '📦 Capital a reponer: ${formatCordobas(parsedCost)}  •  ✨ Ganancia Neta Libre: ${formatCordobas(previewItem.netAmount)}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0284C7),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: noteOrWeekCtrl,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Semana o día en que se hizo (Opcional)',
                        hintText: 'Ej. Semana 1, Fin de semana, Miércoles...',
                        prefixIcon: Icon(Icons.event_note_rounded),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    isExtra
                        ? '¿En qué quincena entró este dinero?'
                        : '¿Qué quincena de gastos vas a cubrir con este pago?',
                    style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 6),
                  RadioGroup<IncomeFrequency>(
                    groupValue: selectedFrequency,
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() => selectedFrequency = val);
                      }
                    },
                    child: Column(
                      children: (isExtra
                              ? [
                                  IncomeFrequency.onlyQ1,
                                  IncomeFrequency.onlyQ2,
                                  IncomeFrequency.monthlySplit,
                                ]
                              : [
                                  IncomeFrequency.onlyQ1,
                                  IncomeFrequency.onlyQ2,
                                  IncomeFrequency.monthlySplit,
                                  IncomeFrequency.biweekly,
                                ])
                          .map((freq) {
                        return RadioListTile<IncomeFrequency>(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: Text(freq.label),
                          value: freq,
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: selectedOrigin.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selectedOrigin.color.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _MiniPreviewStat(
                          label: '1ra Quincena',
                          value: formatCordobas(previewItem.q1Amount,
                              showDecimals: false),
                        ),
                        _MiniPreviewStat(
                          label: '2da Quincena',
                          value: formatCordobas(previewItem.q2Amount,
                              showDecimals: false),
                        ),
                        _MiniPreviewStat(
                          label: 'Total al Mes',
                          value: formatCordobas(previewItem.monthlyTotal,
                              showDecimals: false),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.check_circle_outline_rounded),
                      label: Text(existing == null
                          ? 'Guardar Ingreso y Recalcular'
                          : 'Actualizar y Recalcular'),
                      onPressed: () {
                        final title = titleCtrl.text.trim();
                        final amount = double.tryParse(
                                amountCtrl.text.replaceAll(',', '.')) ??
                            0.0;
                        if (title.isEmpty || amount <= 0) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Por favor escribe el concepto y un monto en Córdobas mayor a 0.'),
                            ),
                          );
                          return;
                        }
                        final note = noteOrWeekCtrl.text.trim().isEmpty
                            ? null
                            : noteOrWeekCtrl.text.trim();
                        final costVal = isExtra
                            ? (double.tryParse(investmentCostCtrl.text
                                    .replaceAll(',', '.')) ??
                                0.0)
                            : 0.0;

                        if (existing == null) {
                          controller.addIncome(
                            title: title,
                            amount: amount,
                            frequency: selectedFrequency,
                            origin: selectedOrigin,
                            noteOrWeek: note,
                            investmentCost: costVal,
                          );
                        } else {
                          controller.updateIncome(
                            existing.copyWith(
                              title: title,
                              amount: amount,
                              frequency: selectedFrequency,
                              origin: selectedOrigin,
                              noteOrWeek: note,
                              investmentCost: costVal,
                            ),
                          );
                        }
                        Navigator.pop(ctx);
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

Future<void> showExpenseFormModal(
  BuildContext context,
  FinanceController controller, {
  ExpenseItem? existing,
}) async {
  final titleCtrl = TextEditingController(text: existing?.title ?? '');
  final amountCtrl = TextEditingController(
    text: existing != null ? existing.totalAmount.toStringAsFixed(2) : '',
  );
  final notesCtrl = TextEditingController(text: existing?.notes ?? '');

  final now = DateTime.now();
  DateTime? selectedCutoffDate = existing?.cutoffDate ??
      (existing?.cutoffDay != null
          ? DateTime(now.year, now.month, existing!.cutoffDay!.clamp(1, 28))
          : null);
  DateTime? selectedDueDate = existing?.dueDate ??
      (existing?.dueDay != null
          ? DateTime(now.year, now.month, existing!.dueDay!.clamp(1, 28))
          : null);

  ExpenseCategory selectedCategory =
      existing?.category ?? ExpenseCategory.creditCard;
  SplitMode selectedSplitMode =
      existing?.splitMode ?? SplitMode.twoQuincenasAuto;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setModalState) {
          final isDebtOrCard =
              selectedCategory == ExpenseCategory.creditCard ||
                  selectedCategory == ExpenseCategory.loan;

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(selectedCategory.icon,
                          color: selectedCategory.color),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          existing == null
                              ? 'Registrar Gasto o Deuda'
                              : 'Editar Gasto o Deuda',
                          style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<ExpenseCategory>(
                    initialValue: selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Tipo de gasto',
                      border: OutlineInputBorder(),
                    ),
                    items: ExpenseCategory.values.map((cat) {
                      return DropdownMenuItem(
                        value: cat,
                        child: Row(
                          children: [
                            Icon(cat.icon, color: cat.color, size: 20),
                            const SizedBox(width: 10),
                            Text(cat.label),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() {
                          selectedCategory = val;
                          if (existing == null) {
                            selectedSplitMode = val.defaultsToTwoQuincenas
                                ? SplitMode.twoQuincenasAuto
                                : SplitMode.onlyQ1;
                          }
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleCtrl,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Nombre del Gasto / Tarjeta / Préstamo',
                      hintText:
                          'Ej. Tarjeta BAC, Préstamo Banpro, Luz, Comida...',
                      prefixIcon: Icon(Icons.receipt_long_rounded),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Monto Total en Córdobas (C\$)',
                      hintText: 'Ej. 4500',
                      prefixText: 'C\$ ',
                      prefixIcon: Icon(Icons.payments_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '¿De qué quincena vas a sacar este dinero?',
                    style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 6),
                  RadioGroup<SplitMode>(
                    groupValue: selectedSplitMode == SplitMode.customManual
                        ? SplitMode.twoQuincenasAuto
                        : selectedSplitMode,
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() => selectedSplitMode = val);
                      }
                    },
                    child: Column(
                      children: [
                        SplitMode.twoQuincenasAuto,
                        SplitMode.onlyQ1,
                        SplitMode.onlyQ2,
                      ].map((mode) {
                        return RadioListTile<SplitMode>(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: Text(mode.label),
                          subtitle: mode == SplitMode.twoQuincenasAuto
                              ? const Text(
                                  'Recoge una parte en la 1ra Quincena y el resto en la 2da Quincena (ideal para tarjetas y préstamos).')
                              : null,
                          value: mode,
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isDebtOrCard
                        ? 'Fechas de Corte y Límite de Pago (Calendario):'
                        : 'Fecha en que se hizo este pago (Solo registro, sin vencimiento):',
                    style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 8),
                  if (selectedCategory == ExpenseCategory.creditCard) ...[
                    _CalendarDateSelectorTile(
                      label: 'Fecha de Corte de la Tarjeta',
                      selectedDate: selectedCutoffDate,
                      icon: Icons.content_cut_rounded,
                      accentColor: const Color(0xFF0284C7),
                      onPickDate: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: selectedCutoffDate ?? DateTime.now(),
                          firstDate: DateTime(DateTime.now().year - 1, 1, 1),
                          lastDate: DateTime(DateTime.now().year + 5, 12, 31),
                          helpText: 'SELECCIONA LA FECHA DE CORTE',
                          cancelText: 'Cancelar',
                          confirmText: 'Aceptar',
                        );
                        if (picked != null) {
                          setModalState(() => selectedCutoffDate = picked);
                        }
                      },
                      onClear: selectedCutoffDate == null
                          ? null
                          : () =>
                              setModalState(() => selectedCutoffDate = null),
                    ),
                    const SizedBox(height: 8),
                  ],
                  _CalendarDateSelectorTile(
                    label: isDebtOrCard
                        ? 'Fecha Límite de Pago (Sin Intereses / Mora)'
                        : 'Fecha en que se realizó el pago (Registro)',
                    selectedDate: selectedDueDate,
                    icon: Icons.event_available_rounded,
                    accentColor: const Color(0xFF059669),
                    onPickDate: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: selectedDueDate ?? DateTime.now(),
                        firstDate: DateTime(DateTime.now().year - 1, 1, 1),
                        lastDate: DateTime(DateTime.now().year + 5, 12, 31),
                        helpText: isDebtOrCard
                            ? 'SELECCIONA LA FECHA LÍMITE DE PAGO'
                            : 'SELECCIONA LA FECHA EN QUE SE HIZO EL PAGO',
                        cancelText: 'Cancelar',
                        confirmText: 'Aceptar',
                      );
                      if (picked != null) {
                        setModalState(() => selectedDueDate = picked);
                      }
                    },
                    onClear: selectedDueDate == null
                        ? null
                        : () => setModalState(() => selectedDueDate = null),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nota o recordatorio (Opcional)',
                      hintText: 'Ej. Cuota 4 de 12, pagar de contado...',
                      prefixIcon: Icon(Icons.notes_rounded),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.calculate_rounded),
                      label: Text(existing == null
                          ? 'Agregar Gasto y Rehacer Cálculos'
                          : 'Guardar Cambios y Recalcular'),
                      onPressed: () {
                        final title = titleCtrl.text.trim();
                        final amount = double.tryParse(
                                amountCtrl.text.replaceAll(',', '.')) ??
                            0.0;
                        if (title.isEmpty || amount <= 0) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Por favor ingresa un nombre y un monto en Córdobas mayor a 0.'),
                            ),
                          );
                          return;
                        }
                        final notes = notesCtrl.text.trim().isEmpty
                            ? null
                            : notesCtrl.text.trim();

                        if (existing == null) {
                          controller.addExpense(
                            title: title,
                            category: selectedCategory,
                            totalAmount: amount,
                            splitMode: selectedSplitMode,
                            dueDay: selectedDueDate?.day,
                            cutoffDay: selectedCutoffDate?.day,
                            dueDate: selectedDueDate,
                            cutoffDate: selectedCutoffDate,
                            notes: notes,
                          );
                        } else {
                          controller.updateExpense(
                            existing.copyWith(
                              title: title,
                              category: selectedCategory,
                              totalAmount: amount,
                              splitMode: selectedSplitMode,
                              dueDay: selectedDueDate?.day,
                              cutoffDay: selectedCutoffDate?.day,
                              dueDate: selectedDueDate,
                              cutoffDate: selectedCutoffDate,
                              notes: notes,
                            ),
                          );
                        }
                        Navigator.pop(ctx);
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

class _MiniPreviewStat extends StatelessWidget {
  final String label;
  final String value;

  const _MiniPreviewStat({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF047857),
              ),
        ),
      ],
    );
  }
}

/// Modal para crear una nueva Meta de Ahorro ("Alcancía por Quincena").
Future<void> showSavingsGoalModal(
  BuildContext context,
  FinanceController controller,
) async {
  final titleCtrl = TextEditingController();
  final targetCtrl = TextEditingController();
  final quincenaGoalCtrl = TextEditingController();
  final initialSavedCtrl = TextEditingController(text: '0');

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Color(0xFF059669),
                    foregroundColor: Colors.white,
                    child: Icon(Icons.savings_rounded),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Nueva Meta de Ahorro (Alcancía)',
                      style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: titleCtrl,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: '¿Para qué estás ahorrando?',
                  hintText: 'Ej. Fondo de Emergencia, Mercadería, Prima...',
                  prefixIcon: Icon(Icons.flag_rounded),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: targetCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Meta Total en Córdobas (C\$)',
                  hintText: 'Ej. 15000',
                  prefixText: 'C\$ ',
                  prefixIcon: Icon(Icons.track_changes_rounded),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: quincenaGoalCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: '¿Cuánto quieres apartar en cada Quincena? (C\$)',
                  hintText: 'Ej. 1000',
                  prefixText: 'C\$ ',
                  prefixIcon: Icon(Icons.event_repeat_rounded),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: initialSavedCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: '¿Cuánto tienes ahorrado ya? (Opcional C\$)',
                  prefixText: 'C\$ ',
                  prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.add_task_rounded),
                  label: const Text('Crear Alcancía por Quincena'),
                  onPressed: () {
                    final title = titleCtrl.text.trim();
                    final target = double.tryParse(
                            targetCtrl.text.replaceAll(',', '.')) ??
                        0.0;
                    final perQ = double.tryParse(
                            quincenaGoalCtrl.text.replaceAll(',', '.')) ??
                        0.0;
                    final initSaved = double.tryParse(
                            initialSavedCtrl.text.replaceAll(',', '.')) ??
                        0.0;

                    if (title.isEmpty || target <= 0) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Ingresa un nombre y una meta mayor a C\$ 0.'),
                        ),
                      );
                      return;
                    }

                    controller.addSavingsGoal(
                      title: title,
                      targetAmount: target,
                      quincenaGoalAmount: perQ > 0 ? perQ : (target / 10.0),
                      initialSavedAmount: initSaved,
                    );
                    Navigator.pop(ctx);
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Modal interactivo: Calculadora Oficial de Salario Neto de Nicaragua (INSS 7% + IR DGI + Aguinaldo).
Future<void> showNicaraguaSalaryCalculatorModal(
  BuildContext context,
  FinanceController controller,
) async {
  final grossSalaryCtrl = TextEditingController(text: '26000');
  int workedMonths = 12;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setModalState) {
          final gross =
              double.tryParse(grossSalaryCtrl.text.replaceAll(',', '.')) ?? 0.0;
          final breakdown = NicaraguaSalaryTaxCalculator.calculate(
            grossMonthlySalary: gross,
            workedMonthsForAguinaldo: workedMonths,
          );

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: Color(0xFF0284C7),
                        foregroundColor: Colors.white,
                        child: Icon(Icons.calculate_rounded),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Calculadora Salarial Nicaragua 🇳🇮',
                              style: Theme.of(ctx)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const Text(
                              'Tabla Oficial INSS Laboral (7%) • IR DGI • Aguinaldo',
                              style:
                                  TextStyle(fontSize: 11.5, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: grossSalaryCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setModalState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Tu Salario Bruto Mensual en Córdobas (C\$)',
                      hintText: 'Ej. 25000',
                      prefixText: 'C\$ ',
                      prefixIcon: Icon(Icons.payments_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Meses trabajados para Aguinaldo:',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '$workedMonths mes(es)',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0284C7),
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: workedMonths.toDouble(),
                    min: 1,
                    max: 12,
                    divisions: 11,
                    label: '$workedMonths meses',
                    onChanged: (v) =>
                        setModalState(() => workedMonths = v.round()),
                  ),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        _PayrollRow(
                          label: 'Salario Bruto Mensual:',
                          value: formatCordobas(breakdown.grossMonthly),
                          valueColor: Colors.white,
                        ),
                        const SizedBox(height: 6),
                        _PayrollRow(
                          label: '(-) Deducción INSS Laboral (7%):',
                          value: '- ${formatCordobas(breakdown.inssMonthly)}',
                          valueColor: const Color(0xFFFCA5A5),
                        ),
                        const SizedBox(height: 6),
                        _PayrollRow(
                          label: '(-) Retención IR DGI Mensual:',
                          value: '- ${formatCordobas(breakdown.irMonthly)}',
                          valueColor: const Color(0xFFFCA5A5),
                        ),
                        const Divider(color: Colors.white24, height: 18),
                        _PayrollRow(
                          label: 'SALARIO NETO MENSUAL:',
                          value: formatCordobas(breakdown.netMonthly),
                          valueColor: const Color(0xFF6EE7B7),
                          isBold: true,
                        ),
                        const SizedBox(height: 6),
                        _PayrollRow(
                          label: '👉 TE DEPOSITAN CADA QUINCENA:',
                          value: formatCordobas(breakdown.netQuincenal),
                          valueColor: const Color(0xFFFDE68A),
                          isBold: true,
                        ),
                        const Divider(color: Colors.white24, height: 18),
                        _PayrollRow(
                          label:
                              '🎁 Aguinaldo Acumulado ($workedMonths meses):',
                          value: formatCordobas(breakdown.aguinaldoAccumulated),
                          valueColor: const Color(0xFF38BDF8),
                          isBold: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF059669),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: const Icon(Icons.looks_one_rounded, size: 18),
                          label: const Text(
                            'Meter en 1ra Quincena\n(Pago Fin de Mes)',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 11.5, fontWeight: FontWeight.bold),
                          ),
                          onPressed: breakdown.netQuincenal <= 0
                              ? null
                              : () {
                                  controller.addIncome(
                                    title:
                                        'Pago Fin de Mes Neto (Para Gastos 1-15)',
                                    amount: (breakdown.netQuincenal * 100)
                                            .roundToDouble() /
                                        100.0,
                                    frequency: IncomeFrequency.onlyQ1,
                                    origin: IncomeOrigin.fixedSalary,
                                  );
                                  Navigator.pop(ctx);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      behavior: SnackBarBehavior.floating,
                                      content: Text(
                                        'Se registró ${formatCordobas(breakdown.netQuincenal)} en tu 1ra Quincena (Gastos del 1 al 15).',
                                      ),
                                    ),
                                  );
                                },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF7C3AED),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: const Icon(Icons.looks_two_rounded, size: 18),
                          label: const Text(
                            'Meter en 2da Quincena\n(Pago del Día 15)',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 11.5, fontWeight: FontWeight.bold),
                          ),
                          onPressed: breakdown.netQuincenal <= 0
                              ? null
                              : () {
                                  controller.addIncome(
                                    title:
                                        'Pago Día 15 Neto (Para Gastos 16-30)',
                                    amount: (breakdown.netQuincenal * 100)
                                            .roundToDouble() /
                                        100.0,
                                    frequency: IncomeFrequency.onlyQ2,
                                    origin: IncomeOrigin.fixedSalary,
                                  );
                                  Navigator.pop(ctx);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      behavior: SnackBarBehavior.floating,
                                      content: Text(
                                        'Se registró ${formatCordobas(breakdown.netQuincenal)} en tu 2da Quincena (Gastos del 16 al 30).',
                                      ),
                                    ),
                                  );
                                },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

class _CalendarDateSelectorTile extends StatelessWidget {
  final String label;
  final DateTime? selectedDate;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onPickDate;
  final VoidCallback? onClear;

  const _CalendarDateSelectorTile({
    required this.label,
    required this.selectedDate,
    required this.icon,
    required this.accentColor,
    required this.onPickDate,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final hasDate = selectedDate != null;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onPickDate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: hasDate
              ? accentColor.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasDate
                ? accentColor
                : Theme.of(context).colorScheme.outlineVariant,
            width: hasDate ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_month_rounded,
              color: hasDate ? accentColor : Colors.grey,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasDate
                        ? '📅 Seleccionada: ${ExpenseItem.formatCalendarDate(selectedDate!)} (Toca para cambiar)'
                        : 'Toca aquí para abrir el calendario y elegir fecha',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight:
                          hasDate ? FontWeight.bold : FontWeight.normal,
                      color: hasDate ? accentColor : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            if (onClear != null)
              IconButton(
                tooltip: 'Quitar fecha',
                onPressed: onClear,
                icon: const Icon(Icons.clear_rounded, size: 18),
              )
            else
              Icon(Icons.touch_app_rounded, size: 18, color: accentColor),
          ],
        ),
      ),
    );
  }
}

class _PayrollRow extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  final bool isBold;

  const _PayrollRow({
    required this.label,
    required this.value,
    required this.valueColor,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: isBold ? Colors.white : Colors.white70,
              fontSize: isBold ? 13 : 12.5,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: isBold ? 15 : 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _QuickPresetItem {
  final String label;
  final ExpenseCategory category;
  final IconData icon;

  const _QuickPresetItem({
    required this.label,
    required this.category,
    required this.icon,
  });
}

const List<_QuickPresetItem> _kQuickPresets = [
  _QuickPresetItem(
    label: 'Almuerzo / Comida',
    category: ExpenseCategory.food,
    icon: Icons.restaurant_rounded,
  ),
  _QuickPresetItem(
    label: 'Gasolina / Taxi',
    category: ExpenseCategory.transport,
    icon: Icons.local_gas_station_rounded,
  ),
  _QuickPresetItem(
    label: 'Café / Antojo / Delivery',
    category: ExpenseCategory.antExpense,
    icon: Icons.local_cafe_rounded,
  ),
  _QuickPresetItem(
    label: 'Supermercado / Pulpería',
    category: ExpenseCategory.food,
    icon: Icons.shopping_cart_rounded,
  ),
  _QuickPresetItem(
    label: 'Recarga / Internet',
    category: ExpenseCategory.utilities,
    icon: Icons.phone_iphone_rounded,
  ),
  _QuickPresetItem(
    label: 'Otro Gasto del Día',
    category: ExpenseCategory.antExpense,
    icon: Icons.bolt_rounded,
  ),
];

/// Punto 4: Modal Relámpago para registrar un "Gasto del Día" en 3 segundos.
Future<void> showQuickDailyExpenseModal(
  BuildContext context,
  FinanceController controller,
) async {
  int selectedPresetIndex = 0;
  final amountCtrl = TextEditingController();
  final customTitleCtrl = TextEditingController();
  bool isFirstQuincena = DateTime.now().day <= 15;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setModalState) {
          final activePreset = _kQuickPresets[selectedPresetIndex];

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: Color(0xFFF59E0B),
                        foregroundColor: Colors.white,
                        child: Icon(Icons.bolt_rounded),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '⚡ Gasto Rápido del Día (3 seg)',
                              style: Theme.of(ctx)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const Text(
                              'Elige un ícono, pon el monto en C\$ y se resta al instante',
                              style:
                                  TextStyle(fontSize: 11.5, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '1. ¿En qué gastaste hoy?',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(_kQuickPresets.length, (i) {
                      final item = _kQuickPresets[i];
                      final isSel = i == selectedPresetIndex;
                      return ChoiceChip(
                        avatar: Icon(
                          item.icon,
                          size: 16,
                          color: isSel ? Colors.white : item.category.color,
                        ),
                        label: Text(
                          item.label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight:
                                isSel ? FontWeight.bold : FontWeight.normal,
                            color: isSel ? Colors.white : null,
                          ),
                        ),
                        selected: isSel,
                        selectedColor: const Color(0xFF0F766E),
                        onSelected: (_) {
                          setModalState(() => selectedPresetIndex = i);
                        },
                      );
                    }),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: amountCtrl,
                    autofocus: true,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: '2. Monto gastado en Córdobas (C\$)',
                      hintText: 'Ej. 220',
                      prefixText: 'C\$ ',
                      prefixIcon: Icon(Icons.payments_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: customTitleCtrl,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText:
                          'Detalle opcional (Si lo dejas vacío se guarda como "${activePreset.label}")',
                      prefixIcon: const Icon(Icons.edit_note_rounded),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '3. ¿De cuál quincena sale este gasto?',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(
                          value: true,
                          icon: Icon(Icons.looks_one_rounded),
                          label: Text('1ra Quincena (1-15)'),
                        ),
                        ButtonSegment(
                          value: false,
                          icon: Icon(Icons.looks_two_rounded),
                          label: Text('2da Quincena (16-30)'),
                        ),
                      ],
                      selected: {isFirstQuincena},
                      onSelectionChanged: (vals) {
                        setModalState(() => isFirstQuincena = vals.first);
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFD97706),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.bolt_rounded),
                      label: const Text(
                        'Restar de mi Quincena Ahora',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onPressed: () {
                        final amount = double.tryParse(
                                amountCtrl.text.replaceAll(',', '.')) ??
                            0.0;
                        if (amount <= 0) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Escribe un monto en Córdobas mayor a 0.'),
                            ),
                          );
                          return;
                        }
                        final finalTitle = customTitleCtrl.text.trim().isNotEmpty
                            ? customTitleCtrl.text.trim()
                            : activePreset.label;

                        controller.addQuickDailyExpense(
                          title: finalTitle,
                          category: activePreset.category,
                          amount: amount,
                          isFirstQuincena: isFirstQuincena,
                        );
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            behavior: SnackBarBehavior.floating,
                            content: Text(
                              '⚡ Se restó ${formatCordobas(amount)} ($finalTitle) de tu ${isFirstQuincena ? "1ra Quincena" : "2da Quincena"}.',
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

/// Punto 5: Modal para trasladar el "Sobrante de Quincena" (a la siguiente quincena o a una Alcancía de Ahorro).
Future<void> showTransferLeftoverModal(
  BuildContext context,
  FinanceController controller, {
  required bool fromFirstQuincena,
  required double availableFreeCash,
}) async {
  double selectedAmount = availableFreeCash;
  String? selectedGoalId = controller.savingsGoals.firstOrNull?.id;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setModalState) {
          final goals = controller.savingsGoals;

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: Color(0xFF059669),
                        foregroundColor: Colors.white,
                        child: Icon(Icons.currency_exchange_rounded),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '🔄 Aprovechar Sobrante de ${fromFirstQuincena ? "1ra Quincena" : "2da Quincena"}',
                              style: Theme.of(ctx)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Tienes ${formatCordobas(availableFreeCash)} libres disponibles',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF059669),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Monto a trasladar o ahorrar: ${formatCordobas(selectedAmount)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  if (availableFreeCash > 100)
                    Slider(
                      value: selectedAmount.clamp(1.0, availableFreeCash),
                      min: 1.0,
                      max: availableFreeCash,
                      divisions: 20,
                      label: formatCordobas(selectedAmount, showDecimals: false),
                      onChanged: (v) => setModalState(
                          () => selectedAmount = (v * 100).roundToDouble() / 100.0),
                    ),
                  const SizedBox(height: 8),
                  if (fromFirstQuincena) ...[
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        icon: const Icon(Icons.fast_forward_rounded),
                        label: Text(
                          'Pasar ${formatCordobas(selectedAmount, showDecimals: false)} a la 2da Quincena',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onPressed: () {
                          controller.transferLeftoverQ1ToQ2(selectedAmount);
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              behavior: SnackBarBehavior.floating,
                              content: Text(
                                '🔄 Se pasaron ${formatCordobas(selectedAmount)} libres a tu 2da Quincena.',
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Center(
                      child: Text(
                        '— O guárdalo en una de tus Alcancías —',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (goals.isEmpty)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.savings_rounded),
                        label: const Text(
                            'Crear una Alcancía de Ahorro Primero'),
                        onPressed: () {
                          Navigator.pop(ctx);
                          showSavingsGoalModal(context, controller);
                        },
                      ),
                    )
                  else ...[
                    DropdownButtonFormField<String>(
                      initialValue: selectedGoalId,
                      decoration: const InputDecoration(
                        labelText: 'Selecciona tu Alcancía destino',
                        prefixIcon: Icon(Icons.savings_outlined),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: goals.map((g) {
                        return DropdownMenuItem(
                          value: g.id,
                          child: Text(
                            '${g.title} (${formatCordobas(g.savedAmount, showDecimals: false)} / ${formatCordobas(g.targetAmount, showDecimals: false)})',
                          ),
                        );
                      }).toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setModalState(() => selectedGoalId = v);
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF059669),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        icon: const Icon(Icons.savings_rounded),
                        label: Text(
                          'Enviar ${formatCordobas(selectedAmount, showDecimals: false)} a esta Alcancía',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onPressed: selectedGoalId == null
                            ? null
                            : () {
                                controller.transferQuincenaLeftoverToSavingsGoal(
                                  goalId: selectedGoalId!,
                                  amount: selectedAmount,
                                  fromFirstQuincena: fromFirstQuincena,
                                );
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    behavior: SnackBarBehavior.floating,
                                    content: Text(
                                      '🐷 ¡Se enviaron ${formatCordobas(selectedAmount)} de tu sobrante a tu Alcancía!',
                                    ),
                                  ),
                                );
                              },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
