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
  final noteOrWeekCtrl =
      TextEditingController(text: existing?.noteOrWeek ?? '');

  IncomeOrigin selectedOrigin = existing?.origin ??
      (defaultToExtraSale
          ? IncomeOrigin.extraSaleOrBusiness
          : IncomeOrigin.fixedSalary);

  IncomeFrequency selectedFrequency = existing?.frequency ??
      (selectedOrigin == IncomeOrigin.extraSaleOrBusiness
          ? IncomeFrequency.onlyQ1
          : IncomeFrequency.biweekly);

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
          final previewItem = IncomeItem(
            id: 'preview',
            title: 'Preview',
            amount: parsedAmount,
            frequency: selectedFrequency,
            origin: selectedOrigin,
          );
          final isExtra = selectedOrigin == IncomeOrigin.extraSaleOrBusiness;

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
                          selectedFrequency =
                              next == IncomeOrigin.extraSaleOrBusiness
                                  ? IncomeFrequency.onlyQ1
                                  : IncomeFrequency.biweekly;
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
                        : '¿Cada cuánto recibes este ingreso?',
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
                              : IncomeFrequency.values)
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

                        if (existing == null) {
                          controller.addIncome(
                            title: title,
                            amount: amount,
                            frequency: selectedFrequency,
                            origin: selectedOrigin,
                            noteOrWeek: note,
                          );
                        } else {
                          controller.updateIncome(
                            existing.copyWith(
                              title: title,
                              amount: amount,
                              frequency: selectedFrequency,
                              origin: selectedOrigin,
                              noteOrWeek: note,
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
  final dueDayCtrl = TextEditingController(
    text: existing?.dueDay?.toString() ?? '',
  );
  final cutoffDayCtrl = TextEditingController(
    text: existing?.cutoffDay?.toString() ?? '',
  );
  final notesCtrl = TextEditingController(text: existing?.notes ?? '');

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
                  Row(
                    children: [
                      if (selectedCategory == ExpenseCategory.creditCard) ...[
                        Expanded(
                          child: TextField(
                            controller: cutoffDayCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Día de Corte (1-31)',
                              prefixIcon: Icon(Icons.calendar_today_rounded),
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: TextField(
                          controller: dueDayCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: isDebtOrCard
                                ? 'Fecha Límite Pago (1-31)'
                                : 'Día de Pago (Opcional)',
                            prefixIcon:
                                const Icon(Icons.event_available_rounded),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nota o recordatorio (Opcional)',
                      hintText: 'Ej. Cuota 4 de 12, pagar antes del 28...',
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
                        final dueDay = int.tryParse(dueDayCtrl.text.trim());
                        final cutoffDay =
                            int.tryParse(cutoffDayCtrl.text.trim());
                        final notes = notesCtrl.text.trim().isEmpty
                            ? null
                            : notesCtrl.text.trim();

                        if (existing == null) {
                          controller.addExpense(
                            title: title,
                            category: selectedCategory,
                            totalAmount: amount,
                            splitMode: selectedSplitMode,
                            dueDay: dueDay,
                            cutoffDay: cutoffDay,
                            notes: notes,
                          );
                        } else {
                          controller.updateExpense(
                            existing.copyWith(
                              title: title,
                              category: selectedCategory,
                              totalAmount: amount,
                              splitMode: selectedSplitMode,
                              dueDay: dueDay,
                              cutoffDay: cutoffDay,
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
