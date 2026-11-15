import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cofiper/main.dart';
import 'package:cofiper/models/financial_models.dart';
import 'package:cofiper/services/nicaragua_bank_gmail_service.dart';
import 'package:cofiper/services/recalculation_engine.dart';
import 'package:cofiper/state/finance_controller.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('Formateador en Córdobas (C\$) y motor de recálculo quincenal', () {
    expect(formatCordobas(12500.50), 'C\$ 12,500.50');

    final incomes = [
      const IncomeItem(
        id: 'i1',
        title: 'Sueldo Quincenal',
        amount: 10000,
        frequency: IncomeFrequency.biweekly, // C$ 10,000 en Q1 y C$ 10,000 en Q2
      ),
      const IncomeItem(
        id: 'i2',
        title: 'Venta de mercadería',
        amount: 2000,
        frequency: IncomeFrequency.onlyQ1,
        origin: IncomeOrigin.extraSaleOrBusiness,
      ),
    ];

    final expenses = [
      const ExpenseItem(
        id: 'e1',
        title: 'Servicio Fijo Q1',
        category: ExpenseCategory.utilities,
        totalAmount: 4000,
        splitMode: SplitMode.onlyQ1,
        q1Allocation: 4000,
        q2Allocation: 0,
      ),
      const ExpenseItem(
        id: 'e2',
        title: 'Tarjeta de Crédito BAC',
        category: ExpenseCategory.creditCard,
        totalAmount: 6000,
        splitMode: SplitMode.twoQuincenasAuto,
        q1Allocation: 3000,
        q2Allocation: 3000,
      ),
    ];

    final balanced = RecalculationEngine.recalculateExpenses(
      incomes: incomes,
      expenses: expenses,
      strategy: AllocationStrategy.liquidityBalance,
      respectCollectedQ1: false,
    );

    final summary = RecalculationEngine.buildSummary(
      incomes: incomes,
      expenses: balanced,
    );
    expect(summary.q1FreeCash, 6000.0);
    expect(summary.q2FreeCash, 6000.0);
    expect(summary.q1ExtraIncome, 2000.0);
  });

  test('Detector de alertas de Gmail para bancos de Nicaragua (BAC, Banpro, LAFISE)', () {
    final bacTx = NicaraguaBankGmailService.parseBankEmailOrAlert(
      rawText:
          'BAC Credomatic informa: Compra aprobada en SUPERMERCADO LA COLONIA por C\$ 1,450.00 con su tarjeta *4512 el dia de hoy.',
    );
    expect(bacTx, isNotNull);
    expect(bacTx!.bank, NicaraguaBank.bacCredomatic);
    expect(bacTx.amountInCordobas, 1450.00);
    expect(bacTx.last4Digits, '4512');

    // Prueba de cobro en dólares (US$ 20.00 a tasa 36.6243 = C$ 732.49)
    final banproUsdTx = NicaraguaBankGmailService.parseBankEmailOrAlert(
      rawText:
          'Notificacion Banpro: Consumo aprobado en NETFLIX por US\$ 20.00 con tarjeta terminacion 8890.',
      usdToCordobaRate: 36.6243,
    );
    expect(banproUsdTx, isNotNull);
    expect(banproUsdTx!.bank, NicaraguaBank.banpro);
    expect(banproUsdTx.wasInDollars, isTrue);
    expect(banproUsdTx.amountInCordobas, 732.49);

    // Al procesar en FinanceController debe sumarse a la tarjeta BAC (*4512) y recalcular las 2 quincenas
    final controller = FinanceController();
    final initialBac = controller.expenses
        .firstWhere((e) => e.title.contains('BAC'))
        .totalAmount;

    controller.processBankAlertText(
      'BAC Credomatic informa: Compra aprobada en LA COLONIA por C\$ 1,200.00 con su tarjeta *4512.',
    );

    final updatedBac = controller.expenses
        .firstWhere((e) => e.title.contains('BAC'))
        .totalAmount;
    expect(updatedBac, initialBac + 1200.0);
  });

  testWidgets('COFIPER pide PIN de seguridad al iniciar y desbloquea con 1234', (WidgetTester tester) async {
    await tester.pumpWidget(const CofiperApp());
    expect(find.textContaining('COFIPER · Acceso Seguro'), findsOneWidget);

    // Ingresar PIN 1234
    await tester.tap(find.text('1'));
    await tester.pump();
    await tester.tap(find.text('2'));
    await tester.pump();
    await tester.tap(find.text('3'));
    await tester.pump();
    await tester.tap(find.text('4'));
    await tester.pumpAndSettle();

    expect(find.textContaining('COFIPER · Control en Córdobas (C\$)'), findsOneWidget);
    expect(find.textContaining('Sincronizar Tarjetas desde Gmail'), findsOneWidget);
  });
}
