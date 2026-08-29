import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_management_app/src/approvals/data/approval_api_client.dart';
import 'package:school_management_app/src/approvals/domain/approval_models.dart';
import 'package:school_management_app/src/approvals/presentation/approvals_screen.dart';
import 'package:school_management_app/src/theme/app_theme.dart';

void main() {
  test('navigation label shows pending requests and approvals separately', () {
    const inbox = ApprovalInbox(
      pendingMyApproval: 5,
      pendingMyRequests: 3,
      myApprovals: [],
      myRequests: [],
    );

    expect(inbox.navigationLabel, 'Requests (3) & Approvals (5)');
    expect(inbox.pendingTotal, 8);
  });

  test('parses structured backend timestamps for approval records', () {
    final item = ApprovalItem.fromJson({
      'key': 'FEE_STRUCTURE:35',
      'type': 'FEE_STRUCTURE',
      'entityId': 35,
      'category': 'Fees',
      'title': 'Fee structure · JHS 2',
      'subtitle': '3 fee items · Version 1',
      'status': 'PENDING_APPROVAL',
      'requesterName': 'Kofi Nketia',
      'approverName': 'Adjoa Mensah',
      'reason': '',
      'requesterNote': 'Updated after the budget review.',
      'createdAt': [2026, 8, 25, 0, 11, 33, 157940000],
      'submittedAt': [2026, 8, 25, 0, 11, 33, 191929000],
      'stateToken': 'PENDING_APPROVAL|2026-08-25T00:11:33.191929',
      'canApprove': true,
      'canReject': true,
      'canWithdraw': false,
      'sourcePage': 'fees',
    });

    expect(item.createdAt, DateTime(2026, 8, 25, 0, 11, 33, 157, 940));
    expect(item.submittedAt, DateTime(2026, 8, 25, 0, 11, 33, 191, 929));
    expect(item.stateToken, 'PENDING_APPROVAL|2026-08-25T00:11:33.191929');
    expect(item.requesterNote, 'Updated after the budget review.');
  });

  testWidgets('shows assigned approvals and completes an approval', (
    tester,
  ) async {
    await _useDesktopSurface(tester);
    final api = _FakeApprovalApiClient();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: ApprovalsScreen(schoolId: 'SCH-1', repository: api),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('My approvals'), findsOneWidget);
    expect(find.text('Fee structure · Basic 1 Stream A'), findsOneWidget);

    await tester.tap(find.text('Fee structure · Basic 1 Stream A'));
    await tester.pumpAndSettle();
    expect(find.text('Approval details'), findsOneWidget);
    expect(find.text('Fees in this request'), findsOneWidget);
    expect(find.text('Tuition Fee'), findsOneWidget);
    expect(find.text('GH₵ 1000.00'), findsOneWidget);
    expect(find.text('GH₵ 1200.00'), findsOneWidget);
    expect(find.text('Nana Boateng'), findsOneWidget);
    expect(find.text('Reason for revision'), findsOneWidget);
    expect(find.text('Tuition updated after budget review.'), findsOneWidget);
    expect(find.text('Request information'), findsNothing);
    expect(find.text('Approve'), findsOneWidget);

    await tester.ensureVisible(find.text('View additional details'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View additional details'));
    await tester.pumpAndSettle();
    expect(find.text('Request information'), findsOneWidget);
    expect(find.text('REQUESTED BY'), findsOneWidget);
    expect(find.text('ASSIGNED APPROVER'), findsOneWidget);
    expect(find.text('CREATED'), findsOneWidget);
    expect(find.text('SUBMITTED'), findsOneWidget);
    expect(find.text('LAST UPDATED'), findsOneWidget);
    expect(find.text('Fee items'), findsNothing);

    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();
    expect(api.lastAction, 'APPROVE');
    expect(find.text('Nothing is waiting for you'), findsOneWidget);
  });

  testWidgets('my requests shows a withdraw action', (tester) async {
    await _useDesktopSurface(tester);
    final api = _FakeApprovalApiClient();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: ApprovalsScreen(schoolId: 'SCH-1', repository: api),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('My requests'));
    await tester.pumpAndSettle();
    expect(find.text('Required items · KG1'), findsOneWidget);
    await tester.tap(find.text('Required items · KG1'));
    await tester.pumpAndSettle();
    expect(find.text('Withdraw approval request'), findsOneWidget);
  });

  testWidgets('stale action reloads approvals and explains the conflict', (
    tester,
  ) async {
    await _useDesktopSurface(tester);
    final api = _ConflictApprovalApiClient();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: ApprovalsScreen(schoolId: 'SCH-1', repository: api),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fee structure · Basic 1 Stream A'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();

    expect(find.text('Request updated'), findsOneWidget);
    expect(find.textContaining('already been approved'), findsOneWidget);
    expect(find.textContaining('list has been refreshed'), findsOneWidget);
    expect(api.inboxLoads, greaterThanOrEqualTo(2));
  });

  testWidgets('shows compact decision details for every approval type', (
    tester,
  ) async {
    await _useDesktopSurface(tester);
    final cases =
        <
          ({
            ApprovalItem item,
            String decisionTitle,
            String section,
            String detail,
          })
        >[
          (
            item: _requiredItemsApproval(),
            decisionTitle: 'Items in this request',
            section: 'Required items',
            detail: 'Exercise Books',
          ),
          (
            item: _feeAdjustmentApproval(),
            decisionTitle: 'Requested fee adjustment',
            section: 'Adjustment request',
            detail: 'Kojo Nyarko',
          ),
          (
            item: _paymentReversalApproval(),
            decisionTitle: 'Requested payment reversal',
            section: 'Payment reversal request',
            detail: 'PAY-2026-0041',
          ),
        ];

    for (final testCase in cases) {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: ApprovalsScreen(
              key: ValueKey(testCase.item.key),
              schoolId: 'SCH-1',
              repository: _SingleApprovalApiClient(testCase.item),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(testCase.item.title));
      await tester.pumpAndSettle();

      expect(find.text(testCase.decisionTitle), findsOneWidget);
      expect(
        find.textContaining(testCase.detail, skipOffstage: false),
        findsAtLeastNWidgets(1),
      );
      expect(find.text('Nana Boateng'), findsOneWidget);
      expect(find.text('24/8/2026 · 9:00 AM'), findsOneWidget);
      expect(find.text('Request information'), findsNothing);

      await tester.ensureVisible(find.text('View additional details'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('View additional details'));
      await tester.pumpAndSettle();
      expect(find.text('Request information'), findsOneWidget);
      expect(find.text('REQUESTED BY'), findsOneWidget);
      expect(find.text('ASSIGNED APPROVER'), findsOneWidget);
      expect(find.text('CREATED'), findsOneWidget);
      expect(find.text('SUBMITTED'), findsOneWidget);
      expect(find.text('LAST UPDATED'), findsOneWidget);
      expect(find.text(testCase.section), findsNothing);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
  });

  testWidgets(
    'required item approvals make quantity dominant and price secondary',
    (tester) async {
      await _useDesktopSurface(tester);
      final item = _requiredItemsApproval();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: ApprovalsScreen(
              schoolId: 'SCH-1',
              repository: _SingleApprovalApiClient(item),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(item.title));
      await tester.pumpAndSettle();

      final quantity = tester.widget<Text>(find.text('6 books'));
      expect(quantity.style?.fontSize, 19);
      expect(quantity.style?.fontWeight, FontWeight.w900);
      expect(quantity.style?.color, AppColors.green);

      final supportingDetails = tester.widget<Text>(
        find.text('2026-09-02 · Est. price GH₵ 15.00 · Est. total GH₵ 90.00'),
      );
      expect(supportingDetails.style?.fontSize, 12);
      expect(supportingDetails.style?.color, AppColors.muted);
    },
  );
}

Future<void> _useDesktopSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1200, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

ApprovalItem _requiredItemsApproval() => ApprovalItem(
  key: 'CLASS_REQUIREMENT:2',
  type: 'CLASS_REQUIREMENT',
  entityId: 2,
  category: 'Items & supplies',
  title: 'Required items · KG1',
  subtitle: '1 item · Version 2',
  status: 'PENDING_APPROVAL',
  requesterName: 'Nana Boateng',
  approverName: 'Adjoa Mensah',
  reason: '',
  createdAt: DateTime(2026, 8, 23, 15),
  submittedAt: DateTime(2026, 8, 24, 9),
  academicPeriod: 'First Term · 2026-2027',
  version: 2,
  detailSections: const [
    ApprovalDetailSection(
      title: 'Required items',
      description: 'The exact supplies submitted by the requester.',
      entries: [
        ApprovalDetailEntry(
          title: 'Exercise Books',
          subtitle: 'Stationery',
          fields: [
            ApprovalDetailField(
              label: 'Quantity',
              value: '6 books',
              emphasized: false,
            ),
            ApprovalDetailField(
              label: 'Due date',
              value: '2026-09-02',
              emphasized: false,
            ),
            ApprovalDetailField(
              label: 'Estimated unit price',
              value: 'GH₵ 15.00',
              emphasized: false,
            ),
            ApprovalDetailField(
              label: 'Estimated total',
              value: 'GH₵ 90.00',
              emphasized: true,
            ),
          ],
        ),
      ],
    ),
  ],
  canApprove: true,
  canReject: true,
  canWithdraw: false,
  sourcePage: 'fees',
);

ApprovalItem _feeAdjustmentApproval() => ApprovalItem(
  key: 'FEE_ADJUSTMENT:3',
  type: 'FEE_ADJUSTMENT',
  entityId: 3,
  category: 'Fee adjustments',
  title: 'Discount · Kojo Nyarko',
  subtitle: 'Examination Fee',
  status: 'PENDING_APPROVAL',
  amount: 90,
  requesterName: 'Nana Boateng',
  approverName: 'Adjoa Mensah',
  reason: 'Scholarship support',
  createdAt: DateTime(2026, 8, 23, 15),
  submittedAt: DateTime(2026, 8, 24, 9),
  academicPeriod: 'First Term · 2026-2027',
  detailSections: const [
    ApprovalDetailSection(
      title: 'Adjustment request',
      description: 'The exact student fee change submitted for approval.',
      entries: [
        ApprovalDetailEntry(
          title: '',
          subtitle: '',
          fields: [
            ApprovalDetailField(
              label: 'Student',
              value: 'Kojo Nyarko',
              emphasized: false,
            ),
            ApprovalDetailField(
              label: 'Amount',
              value: '-GH₵ 90.00',
              emphasized: true,
            ),
          ],
        ),
      ],
    ),
  ],
  canApprove: true,
  canReject: true,
  canWithdraw: false,
  sourcePage: 'fees',
);

ApprovalItem _paymentReversalApproval() => ApprovalItem(
  key: 'PAYMENT_REVERSAL:4',
  type: 'PAYMENT_REVERSAL',
  entityId: 4,
  category: 'Payment reversals',
  title: 'Payment reversal · Ama Ofori',
  subtitle: 'Payment PAY-2026-0041',
  status: 'PENDING_APPROVAL',
  amount: 500,
  requesterName: 'Nana Boateng',
  approverName: 'Adjoa Mensah',
  reason: 'Duplicate payment',
  createdAt: DateTime(2026, 8, 23, 15),
  submittedAt: DateTime(2026, 8, 24, 9),
  academicPeriod: 'First Term · 2026-2027',
  detailSections: const [
    ApprovalDetailSection(
      title: 'Payment reversal request',
      description: 'The original payment submitted for reversal.',
      entries: [
        ApprovalDetailEntry(
          title: '',
          subtitle: '',
          fields: [
            ApprovalDetailField(
              label: 'Student',
              value: 'Ama Ofori',
              emphasized: false,
            ),
            ApprovalDetailField(
              label: 'Payment reference',
              value: 'PAY-2026-0041',
              emphasized: false,
            ),
            ApprovalDetailField(
              label: 'Amount to reverse',
              value: 'GH₵ 500.00',
              emphasized: true,
            ),
            ApprovalDetailField(
              label: 'Reason for reversal',
              value: 'Duplicate payment',
              emphasized: false,
            ),
          ],
        ),
      ],
    ),
  ],
  canApprove: true,
  canReject: true,
  canWithdraw: false,
  sourcePage: 'fees',
);

class _SingleApprovalApiClient extends ApprovalApiClient {
  _SingleApprovalApiClient(this.item) : super(accessToken: 'test');
  final ApprovalItem item;

  @override
  Future<ApprovalInbox> getInbox(String schoolId) async => ApprovalInbox(
    pendingMyApproval: 1,
    pendingMyRequests: 0,
    myApprovals: [item],
    myRequests: const [],
  );

  @override
  Future<ApprovalInbox> performAction({
    required String schoolId,
    required ApprovalItem item,
    required String action,
    String reason = '',
  }) => getInbox(schoolId);
}

class _FakeApprovalApiClient extends ApprovalApiClient {
  _FakeApprovalApiClient() : super(accessToken: 'test');

  String? lastAction;
  var approved = false;

  ApprovalItem get approval => ApprovalItem(
    key: 'FEE_STRUCTURE:1',
    type: 'FEE_STRUCTURE',
    entityId: 1,
    category: 'Fees',
    title: 'Fee structure · Basic 1 Stream A',
    subtitle: '2 fee items · Version 1',
    status: 'PENDING_APPROVAL',
    amount: 1200,
    requesterName: 'Nana Boateng',
    approverName: 'Adjoa Mensah',
    reason: '',
    submittedAt: DateTime(2026, 8, 24, 9),
    createdAt: DateTime(2026, 8, 23, 15),
    academicPeriod: 'First Term · 2026-2027',
    version: 2,
    requesterNote: 'Tuition updated after budget review.',
    detailSections: const [
      ApprovalDetailSection(
        title: 'Fee items',
        description: 'The exact fee lines submitted by the requester.',
        entries: [
          ApprovalDetailEntry(
            title: 'Tuition Fee',
            subtitle: 'Tuition',
            fields: [
              ApprovalDetailField(
                label: 'Amount',
                value: 'GH₵ 1000.00',
                emphasized: true,
              ),
              ApprovalDetailField(
                label: 'Description',
                value: 'Term tuition',
                emphasized: false,
              ),
            ],
          ),
        ],
      ),
    ],
    canApprove: true,
    canReject: true,
    canWithdraw: false,
    sourcePage: 'fees',
  );

  ApprovalItem get request => ApprovalItem(
    key: 'CLASS_REQUIREMENT:2',
    type: 'CLASS_REQUIREMENT',
    entityId: 2,
    category: 'Items & supplies',
    title: 'Required items · KG1',
    subtitle: '3 items · Version 1',
    status: 'PENDING_APPROVAL',
    requesterName: 'Adjoa Mensah',
    approverName: 'Nana Boateng',
    reason: '',
    submittedAt: DateTime(2026, 8, 24, 10),
    canApprove: false,
    canReject: false,
    canWithdraw: true,
    sourcePage: 'fees',
  );

  @override
  Future<ApprovalInbox> getInbox(String schoolId) async => ApprovalInbox(
    pendingMyApproval: approved ? 0 : 1,
    pendingMyRequests: 1,
    myApprovals: approved ? const [] : [approval],
    myRequests: [request],
  );

  @override
  Future<ApprovalInbox> performAction({
    required String schoolId,
    required ApprovalItem item,
    required String action,
    String reason = '',
  }) async {
    lastAction = action;
    if (action == 'APPROVE') approved = true;
    return getInbox(schoolId);
  }
}

class _ConflictApprovalApiClient extends _FakeApprovalApiClient {
  var inboxLoads = 0;

  @override
  Future<ApprovalInbox> getInbox(String schoolId) async {
    inboxLoads += 1;
    return super.getInbox(schoolId);
  }

  @override
  Future<ApprovalInbox> performAction({
    required String schoolId,
    required ApprovalItem item,
    required String action,
    String reason = '',
  }) async {
    throw const ApprovalApiException(
      'This request has already been approved.',
      409,
    );
  }
}
