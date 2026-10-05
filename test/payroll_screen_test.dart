import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:school_management_app/src/payroll/data/payroll_api_client.dart';
import 'package:school_management_app/src/payroll/presentation/payroll_screen.dart';

void main() {
  test('payroll estimate includes earnings, pension, PAYE, and deductions', () {
    final value = calculatePayrollEstimate(
      basicPay: 5000,
      houseAllowance: 50,
      transportAllowance: 200,
      otherAllowances: 567,
      houseTaxable: true,
      transportTaxable: false,
      otherTaxable: true,
      ssnitContributing: true,
      tier3Percentage: 0,
      taxRelief: 0,
      unionDues: 0,
      otherDeductions: 0,
    );

    expect(value.gross, 5817);
    expect(value.ssnitEmployee, 275);
    expect(value.ssnitEmployer, 650);
    expect(value.netPay, lessThan(value.gross));
  });

  testWidgets('authorised payroll manager can save staff payroll draft', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1500, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = _FakePayrollApi();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PayrollScreen(
            schoolId: 'SCH-1',
            accessToken: 'token',
            api: api,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sena Owusu'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('payroll-basic-pay')),
      '5000',
    );
    await tester.pump();
    expect(find.text('GH¢ 5,817.00'), findsWidgets);
    await tester.ensureVisible(
      find.byKey(const ValueKey('payroll-save-draft')),
    );
    await tester.tap(find.byKey(const ValueKey('payroll-save-draft')));
    await tester.pumpAndSettle();

    expect(api.saved?['payrollStatus'], 'DRAFT');
    expect(api.saved?['basicPay'], 5000);
  });

  testWidgets('view-only payroll access hides all mutation actions', (
    tester,
  ) async {
    final api = _FakePayrollApi(canEdit: false);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PayrollScreen(
            schoolId: 'SCH-1',
            accessToken: 'token',
            api: api,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sena Owusu'));
    await tester.pumpAndSettle();

    expect(find.textContaining('view-only payroll access'), findsOneWidget);
    expect(find.byKey(const ValueKey('payroll-save-draft')), findsNothing);
    expect(find.byKey(const ValueKey('payroll-activate')), findsNothing);
  });
}

class _FakePayrollApi extends PayrollApiClient {
  _FakePayrollApi({this.canEdit = true})
    : super(
        schoolId: 'SCH-1',
        accessToken: 'token',
        client: MockClient((_) async => throw UnimplementedError()),
      );

  final bool canEdit;
  Map<String, dynamic>? saved;

  @override
  Future<PayrollAccess> getAccess() async =>
      PayrollAccess(canView: true, canEdit: canEdit);

  @override
  Future<List<PayrollStaffRecord>> getStaff() async => const [
    PayrollStaffRecord(
      staffId: 'STAFF-1',
      name: 'Sena Owusu',
      jobTitle: 'Teacher',
      department: 'Teaching',
      employmentType: 'FULL_TIME',
      payrollStatus: 'DRAFT',
      basicPay: 0,
      grossSalary: 0,
      paymentMethod: 'BANK',
      paymentAccountLabel: 'GCB Bank •••• 7890',
    ),
  ];

  @override
  Future<PayrollConfiguration> getConfiguration(String staffId) async =>
      const PayrollConfiguration(
        payrollStatus: 'DRAFT',
        payType: 'PERMANENT',
        payGrade: '',
        tier2Provider: '',
        effectiveDate: '2026-10-01',
        ssnitStatus: 'CONTRIBUTING',
        basicPay: 0,
        houseAllowance: 50,
        transportAllowance: 200,
        otherAllowances: 567,
        houseAllowanceTaxable: true,
        transportAllowanceTaxable: false,
        otherAllowancesTaxable: true,
        grossSalary: 817,
        ssnitNumber: '',
        tinNumber: '',
        unionName: '',
        unionDues: 0,
        tier3Percentage: 0,
        otherDeductions: 0,
        taxRelief: 0,
        ssnitEmployee: 0,
        ssnitEmployer: 0,
        chargeableIncome: 0,
        estimatedPaye: 0,
        netPay: 0,
        paymentMethod: 'BANK',
        paymentAccountLabel: 'GCB Bank •••• 7890',
      );

  @override
  Future<PayrollConfiguration> saveConfiguration({
    required String staffId,
    required Map<String, dynamic> body,
  }) async {
    saved = body;
    return getConfiguration(staffId);
  }
}
