import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../data/api_class_requirements_repository.dart';
import '../data/fee_api_client.dart';
import '../domain/fee_models.dart';
import 'class_requirements_screen.dart';
import 'fee_adjustments_content.dart';
import 'fee_structure_workflow_content.dart';
import 'payment_reversals_content.dart';
import '../../assessments/presentation/report_pdf_download_stub.dart'
    if (dart.library.html) '../../assessments/presentation/report_pdf_download_web.dart';

enum _FeeTab {
  overview,
  studentFees,
  feeStructure,
  feeCatalogue,
  adjustments,
  reversals,
  classRequirements,
  waivers,
}

enum _FeeOverviewPage { main, collectionByClass, outstandingArrears }

class FeeManagementScreen extends StatefulWidget {
  const FeeManagementScreen({
    super.key,
    required this.customSchoolId,
    required this.schoolName,
    required this.accessToken,
    this.onRefreshAccessToken,
    this.role,
    this.userId,
    this.openRecordPaymentOnLoad = false,
    this.recordPaymentStudentId,
    this.openFeeStructureOnLoad = false,
    this.onRecordPaymentRequestConsumed,
    this.onWorkflowChanged,
    this.onOpenStudent,
    this.api,
  });

  final String customSchoolId;
  final String schoolName;
  final String? accessToken;
  final Future<String?> Function()? onRefreshAccessToken;
  final String? role;
  final int? userId;
  final bool openRecordPaymentOnLoad;
  final String? recordPaymentStudentId;
  final bool openFeeStructureOnLoad;
  final VoidCallback? onRecordPaymentRequestConsumed;
  final VoidCallback? onWorkflowChanged;
  final ValueChanged<String>? onOpenStudent;
  final FeeApiClient? api;

  @override
  State<FeeManagementScreen> createState() => _FeeManagementScreenState();
}

class _FeeManagementScreenState extends State<FeeManagementScreen> {
  late FeeApiClient _api;
  ApiClassRequirementsRepository? _classRequirements;
  late Future<void> _initialLoad;
  FeeManagementOverview? _overview;
  FeeStudentFeesPage? _studentFeesPage;
  CurrentAcademicTerm? _currentTerm;
  List<FeeAcademicTermOption> _feeTerms = const [];
  int? _selectedFeeStructureTermId;
  List<FeeClassCollectionSummary> _classCollections = const [];
  List<FeeStudentFeeRow> _arrears = const [];
  List<FeeClassStructure> _feeStructures = const [];
  List<FeeGradeLevel> _gradeLevels = const [];
  List<FeeWaiverType> _waiverTypes = const [];
  List<FeeWaiverAssignment> _waiverAssignments = const [];
  bool _studentFeesLoaded = false;
  bool _studentFeesLoading = false;
  Object? _studentFeesError;
  Timer? _studentFeeSearchDebounce;
  String _studentFeeSearch = '';
  int? _studentFeeGradeLevelId;
  String? _studentFeePaymentStatus;
  bool _feeStructuresLoaded = false;
  bool _feeStructuresLoading = false;
  Object? _feeStructuresError;
  Future<void>? _gradeLevelsFuture;
  bool _waiversLoaded = false;
  bool _waiversLoading = false;
  Object? _waiversError;
  List<FeePaymentMethod> _paymentMethods = const [];
  _FeeTab _selectedTab = _FeeTab.overview;
  _FeeOverviewPage _overviewPage = _FeeOverviewPage.main;
  bool _overviewDetailLoading = false;
  Object? _overviewDetailError;
  bool _openingRecordPaymentRequest = false;

  bool get _canApproveFinance {
    final role = widget.role?.trim().toUpperCase();
    return role == 'ADMINISTRATOR' ||
        role == 'HEAD_TEACHER' ||
        role == 'SUPER_ADMIN';
  }

  @override
  void initState() {
    super.initState();
    if (widget.openFeeStructureOnLoad) {
      _selectedTab = _FeeTab.feeStructure;
    }
    _api =
        widget.api ??
        FeeApiClient(
          accessToken: widget.accessToken,
          onRefreshAccessToken: widget.onRefreshAccessToken,
        );
    _initialLoad = _loadInitial();
    _maybeOpenRecordPaymentRequest();
  }

  @override
  void didUpdateWidget(covariant FeeManagementScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.accessToken != widget.accessToken) {
      _api.accessToken = widget.accessToken;
    }
    if (!oldWidget.openRecordPaymentOnLoad && widget.openRecordPaymentOnLoad) {
      _maybeOpenRecordPaymentRequest();
    }
  }

  @override
  void dispose() {
    _studentFeeSearchDebounce?.cancel();
    _classRequirements?.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    final currentTerm = await _api.getCurrentTerm(widget.customSchoolId);
    final feeTerms = await _api.getAcademicTerms(widget.customSchoolId);
    final overview = await _api.getFeeManagementOverview(
      customSchoolId: widget.customSchoolId,
      termId: currentTerm.id,
    );
    if (!mounted) return;
    setState(() {
      _overview = overview;
      _currentTerm = currentTerm;
      _feeTerms = feeTerms;
      for (final term in feeTerms) {
        if (term.isCurrent) {
          _selectedFeeStructureTermId = term.id;
          break;
        }
      }
      _selectedFeeStructureTermId ??= currentTerm.id;
      _classCollections = overview.collectionByClass;
      _arrears = overview.outstandingArrears;
    });
  }

  void _maybeOpenRecordPaymentRequest() {
    if (!widget.openRecordPaymentOnLoad || _openingRecordPaymentRequest) {
      return;
    }
    // Preserve the student scope before notifying the parent that the
    // one-shot request has been consumed. That callback rebuilds this widget
    // and clears the request fields.
    final requestedStudentId = widget.recordPaymentStudentId;
    _openingRecordPaymentRequest = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      widget.onRecordPaymentRequestConsumed?.call();
      await _initialLoad;
      if (mounted) {
        await _showRecordPaymentForm(selectedStudentId: requestedStudentId);
      }
      _openingRecordPaymentRequest = false;
    });
  }

  Future<void> _reloadFees() async {
    final termId = _activeTermId;
    if (termId <= 0) return;
    widget.onWorkflowChanged?.call();
    final overview = await _api.getFeeManagementOverview(
      customSchoolId: widget.customSchoolId,
      termId: termId,
    );
    if (!mounted) return;
    setState(() {
      _overview = overview;
      _classCollections = overview.collectionByClass;
      _arrears = overview.outstandingArrears;
    });
    if (_studentFeesLoaded) await _loadStudentFees(force: true);
    if (_feeStructuresLoaded) await _loadFeeStructures(force: true);
    if (_waiversLoaded) await _loadWaivers(force: true);
  }

  String _money(double amount) {
    final value = amount % 1 == 0
        ? amount.toStringAsFixed(0)
        : amount.toStringAsFixed(2);
    return 'GH₵ $value';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initialLoad,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _FeePageSkeleton();
        }
        if (snapshot.hasError) {
          return _FeeErrorState(
            message: snapshot.error.toString(),
            onRetry: () => setState(() => _initialLoad = _loadInitial()),
          );
        }
        return _buildContent();
      },
    );
  }

  Widget _buildContent() {
    final overview = _overview;
    if (overview == null) {
      return _FeeErrorState(
        message: 'Fee data is not available.',
        onRetry: () => setState(() => _initialLoad = _loadInitial()),
      );
    }

    return RefreshIndicator(
      onRefresh: _reloadFees,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1280),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FeeTabs(selected: _selectedTab, onChanged: _selectTab),
                const SizedBox(height: 18),
                _selectedContent(overview),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _selectedContent(FeeManagementOverview overview) {
    return switch (_selectedTab) {
      _FeeTab.overview => _FeeOverviewContent(
        page: _overviewPage,
        schoolName: widget.schoolName,
        termName: _termName,
        overview: overview,
        collectionRows: _classCollections.isEmpty
            ? overview.collectionByClass
            : _classCollections,
        arrearsRows: _arrears.isEmpty ? overview.outstandingArrears : _arrears,
        money: _money,
        onRecordPayment: _showRecordPaymentForm,
        onOpenStudentFees: () => _selectTab(_FeeTab.studentFees),
        onOpenStructure: () => _selectTab(_FeeTab.feeStructure),
        onOpenWaivers: () => _selectTab(_FeeTab.waivers),
        loadingDetails: _overviewDetailLoading,
        detailError: _overviewDetailError,
        onRetryDetails: () => _openOverviewPage(_overviewPage),
        onViewAllCollection: () =>
            _openOverviewPage(_FeeOverviewPage.collectionByClass),
        onViewAllArrears: () =>
            _openOverviewPage(_FeeOverviewPage.outstandingArrears),
        onBackToOverview: () =>
            setState(() => _overviewPage = _FeeOverviewPage.main),
      ),
      _FeeTab.studentFees => _buildStudentFeesContent(),
      _FeeTab.feeStructure => _buildFeeStructureContent(),
      _FeeTab.feeCatalogue => FeeStructureWorkflowContent(
        api: _api,
        customSchoolId: widget.customSchoolId,
        termId: 0,
        termName: '',
        currentUserId: widget.userId ?? 0,
        money: _money,
        onChanged: _reloadFees,
        catalogueOnly: true,
      ),
      _FeeTab.adjustments => FeeAdjustmentsContent(
        api: _api,
        customSchoolId: widget.customSchoolId,
        termId: _activeTermId,
        currentUserId: widget.userId ?? 0,
        onChanged: _reloadFees,
      ),
      _FeeTab.reversals => PaymentReversalsContent(
        api: _api,
        customSchoolId: widget.customSchoolId,
        currentTermId: _activeTermId,
        currentUserId: widget.userId ?? 0,
        onChanged: _reloadFees,
      ),
      _FeeTab.classRequirements =>
        _classRequirements == null
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 96),
                  child: CircularProgressIndicator(),
                ),
              )
            : ClassRequirementsScreen(
                repository: _classRequirements!,
                termName: _termName,
                gradeLevels: _gradeLevels,
                canPublish: _canApproveFinance,
                currentUserId: widget.userId ?? 0,
                onWorkflowChanged: widget.onWorkflowChanged,
              ),
      _FeeTab.waivers => _buildWaiversContent(),
    };
  }

  String get _termName {
    final current = _currentTerm?.name.trim() ?? '';
    if (current.isNotEmpty) return current;
    final overviewTerm = _overview?.termName.trim() ?? '';
    final year = _overview?.academicYear.trim() ?? '';
    return [
          if (overviewTerm.isNotEmpty) overviewTerm,
          if (year.isNotEmpty) year,
        ].join(' · ').trim().isEmpty
        ? 'Current term'
        : [
            if (overviewTerm.isNotEmpty) overviewTerm,
            if (year.isNotEmpty) year,
          ].join(' · ');
  }

  int get _activeTermId => _overview?.termId ?? _currentTerm?.id ?? 0;

  int get _feeStructureTermId =>
      _selectedFeeStructureTermId ?? _currentTerm?.id ?? _activeTermId;

  FeeAcademicTermOption? get _selectedFeeStructureTerm {
    for (final term in _feeTerms) {
      if (term.id == _feeStructureTermId) return term;
    }
    return null;
  }

  String get _feeStructureTermName {
    final selected = _selectedFeeStructureTerm;
    if (selected != null && selected.label.trim().isNotEmpty) {
      return selected.label;
    }
    return _termName;
  }

  void _selectTab(_FeeTab tab) {
    setState(() {
      _selectedTab = tab;
      _overviewPage = _FeeOverviewPage.main;
    });
    if (tab == _FeeTab.studentFees) {
      unawaited(_ensureGradeLevels());
      _loadStudentFees();
    }
    if (tab == _FeeTab.feeStructure) {
      _loadFeeStructures();
    }
    if (tab == _FeeTab.classRequirements && _classRequirements == null) {
      _loadClassRequirements();
    }
    if (tab == _FeeTab.waivers && !_waiversLoaded && !_waiversLoading) {
      _loadWaivers();
    }
  }

  Widget _buildStudentFeesContent() {
    if (_studentFeesLoading && !_studentFeesLoaded) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 96),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_studentFeesError != null && !_studentFeesLoaded) {
      return _FeeErrorState(
        message: 'Could not load student fees. $_studentFeesError',
        onRetry: () => _loadStudentFees(force: true),
      );
    }
    return _StudentFeesContent(
      rows: _studentFeeRows(),
      gradeLevels: _gradeLevels,
      selectedGradeLevelId: _studentFeeGradeLevelId,
      selectedPaymentStatus: _studentFeePaymentStatus,
      search: _studentFeeSearch,
      termName: _termName,
      paymentMethods: _paymentMethods,
      customSchoolId: widget.customSchoolId,
      termId: _activeTermId,
      currentUserId: widget.userId ?? 0,
      api: _api,
      money: _money,
      onSearchChanged: _onStudentFeeSearchChanged,
      onGradeLevelChanged: (value) {
        _studentFeeGradeLevelId = value;
        _reloadStudentFeesForFilters();
      },
      onPaymentStatusChanged: (value) {
        _studentFeePaymentStatus = value;
        _reloadStudentFeesForFilters();
      },
      onPaymentSaved: _reloadFees,
      onAssignWaiver: (row) => _showWaiverAssignmentSheet(
        null,
        FeeStudentFeeRow(
          studentId: 0,
          customStudentId: row.id,
          studentName: row.name,
          gradeLevelId: 0,
          className: row.className,
          totalFees: row.totalFees,
          totalAdjustments: 0,
          paid: row.paid,
          balance: row.balance,
          paymentStatus: row.status,
          lastPaymentDate: null,
        ),
      ),
    );
  }

  void _onStudentFeeSearchChanged(String value) {
    _studentFeeSearchDebounce?.cancel();
    _studentFeeSearchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted || value.trim() == _studentFeeSearch) return;
      _studentFeeSearch = value.trim();
      _reloadStudentFeesForFilters();
    });
  }

  void _reloadStudentFeesForFilters() {
    if (!mounted) return;
    setState(() {
      _studentFeesLoaded = false;
      _studentFeesError = null;
    });
    unawaited(_loadStudentFees(force: true));
  }

  Future<void> _loadStudentFees({bool force = false}) async {
    if (_studentFeesLoading || (_studentFeesLoaded && !force)) return;
    final termId = _activeTermId;
    if (termId <= 0) return;
    setState(() {
      _studentFeesLoading = true;
      _studentFeesError = null;
    });
    try {
      final results = await Future.wait<Object>([
        _api.getFeeManagementStudents(
          customSchoolId: widget.customSchoolId,
          termId: termId,
          gradeLevelId: _studentFeeGradeLevelId,
          paymentStatus: _studentFeePaymentStatus,
          search: _studentFeeSearch,
          size: 100,
        ),
        if (_paymentMethods.isEmpty) _api.getPaymentMethods(),
      ]);
      if (!mounted) return;
      setState(() {
        _studentFeesPage = results.first as FeeStudentFeesPage;
        if (results.length > 1) {
          _paymentMethods = results[1] as List<FeePaymentMethod>;
        }
        _studentFeesLoaded = true;
      });
    } catch (error) {
      if (mounted) setState(() => _studentFeesError = error);
    } finally {
      if (mounted) setState(() => _studentFeesLoading = false);
    }
  }

  Future<void> _loadFeeStructures({bool force = false}) async {
    if (_feeStructuresLoading || (_feeStructuresLoaded && !force)) return;
    final termId = _feeStructureTermId;
    if (termId <= 0) return;
    setState(() {
      _feeStructuresLoading = true;
      _feeStructuresError = null;
    });
    try {
      final structures = await _api.getFeeStructuresForTerm(
        customSchoolId: widget.customSchoolId,
        termId: termId,
      );
      await _ensureGradeLevels();
      if (!mounted) return;
      setState(() {
        _feeStructures = structures;
        _feeStructuresLoaded = true;
      });
    } catch (error) {
      if (mounted) setState(() => _feeStructuresError = error);
    } finally {
      if (mounted) setState(() => _feeStructuresLoading = false);
    }
  }

  Future<void> _ensureGradeLevels() {
    if (_gradeLevels.isNotEmpty) return Future<void>.value();
    return _gradeLevelsFuture ??= _loadGradeLevels().whenComplete(
      () => _gradeLevelsFuture = null,
    );
  }

  Future<void> _loadGradeLevels() async {
    final grades = await _api.getSchoolGradeLevels(widget.customSchoolId);
    if (mounted) setState(() => _gradeLevels = grades);
  }

  Future<void> _loadClassRequirements() async {
    final termId = _activeTermId;
    if (termId <= 0) return;
    try {
      await _ensureGradeLevels();
      if (!mounted || _classRequirements != null) return;
      final repository = ApiClassRequirementsRepository(
        api: _api,
        customSchoolId: widget.customSchoolId,
        academicTermId: termId,
      );
      setState(() => _classRequirements = repository);
      await repository.load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Widget _buildWaiversContent() {
    if (_waiversLoading && !_waiversLoaded) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 96),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_waiversError != null && !_waiversLoaded) {
      return _FeeErrorState(
        message: 'Could not load waivers. $_waiversError',
        onRetry: () => _loadWaivers(force: true),
      );
    }
    return _WaiversContent(
      types: _waiverTypes,
      assignments: _waiverAssignments,
      money: _money,
      onAddType: () => _showWaiverTypeDialog(),
      onEditType: (type) => _showWaiverTypeDialog(type),
      onDeleteType: _deleteWaiverType,
      onAssignWaiver: () => _showWaiverAssignmentSheet(),
      onEditAssignment: (assignment) => _showWaiverAssignmentSheet(assignment),
      onRevokeAssignment: _revokeWaiver,
      onWorkflowAction: _performWaiverAction,
      onOpenStudent: widget.onOpenStudent,
    );
  }

  Future<void> _loadWaivers({bool force = false}) async {
    if (_waiversLoading || (_waiversLoaded && !force)) return;
    final termId = _activeTermId;
    if (termId <= 0) return;
    setState(() {
      _waiversLoading = true;
      _waiversError = null;
    });
    try {
      final results = await Future.wait<Object>([
        _api.getWaiverTypes(customSchoolId: widget.customSchoolId),
        _api.getStudentWaivers(
          customSchoolId: widget.customSchoolId,
          academicTermId: termId,
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _waiverTypes = results[0] as List<FeeWaiverType>;
        _waiverAssignments = results[1] as List<FeeWaiverAssignment>;
        _waiversLoaded = true;
      });
    } catch (error) {
      if (mounted) setState(() => _waiversError = error);
    } finally {
      if (mounted) setState(() => _waiversLoading = false);
    }
  }

  Future<void> _showWaiverTypeDialog([FeeWaiverType? existing]) async {
    final name = TextEditingController(text: existing?.name ?? '');
    final description = TextEditingController(
      text: existing?.description ?? '',
    );
    final value = TextEditingController(
      text: existing == null ? '' : '${existing.defaultValue}',
    );
    var valueType = existing?.valueType ?? 'PERCENTAGE';
    var scope = existing?.scope ?? 'ALL_FEES';
    var saving = false;
    String? error;
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            existing == null ? 'Create waiver type' : 'Edit waiver type',
          ),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(
                      labelText: 'Waiver name *',
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: description,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Description'),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: valueType,
                    decoration: const InputDecoration(
                      labelText: 'Reduction method *',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'PERCENTAGE',
                        child: Text('Percentage'),
                      ),
                      DropdownMenuItem(
                        value: 'FIXED_AMOUNT',
                        child: Text('Fixed amount'),
                      ),
                    ],
                    onChanged: saving
                        ? null
                        : (next) => setDialogState(() => valueType = next!),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: value,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: valueType == 'PERCENTAGE'
                          ? 'Default percentage *'
                          : 'Default amount (GH₵) *',
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: scope,
                    decoration: const InputDecoration(
                      labelText: 'Applies to *',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'ALL_FEES',
                        child: Text('All assessed fees'),
                      ),
                      DropdownMenuItem(
                        value: 'SELECTED_FEE_ITEMS',
                        child: Text('Selected fee items'),
                      ),
                    ],
                    onChanged: saving
                        ? null
                        : (next) => setDialogState(() => scope = next!),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        error!,
                        style: const TextStyle(color: AppColors.red),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving
                  ? null
                  : () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      final amount = double.tryParse(value.text.trim());
                      if (name.text.trim().isEmpty ||
                          amount == null ||
                          amount <= 0) {
                        setDialogState(
                          () => error =
                              'Enter a name and a value greater than zero.',
                        );
                        return;
                      }
                      setDialogState(() {
                        saving = true;
                        error = null;
                      });
                      try {
                        await _api.saveWaiverType(
                          customSchoolId: widget.customSchoolId,
                          waiverTypeId: existing?.id,
                          name: name.text,
                          description: description.text,
                          valueType: valueType,
                          defaultValue: amount,
                          scope: scope,
                        );
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext, true);
                        }
                      } catch (caught) {
                        setDialogState(() {
                          saving = false;
                          error = '$caught';
                        });
                      }
                    },
              child: Text(saving ? 'Saving...' : 'Save waiver type'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    description.dispose();
    value.dispose();
    if (saved == true) await _loadWaivers(force: true);
  }

  Future<void> _deleteWaiverType(FeeWaiverType type) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove waiver type?'),
        content: Text(
          'Remove “${type.name}”? Existing active assignments must be revoked first.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _api.deleteWaiverType(
        customSchoolId: widget.customSchoolId,
        waiverTypeId: type.id,
      );
      await _loadWaivers(force: true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  Future<void> _showWaiverAssignmentSheet([
    FeeWaiverAssignment? existing,
    FeeStudentFeeRow? initialStudent,
  ]) async {
    if (_waiverTypes.isEmpty) {
      await _showWaiverTypeDialog();
      if (_waiverTypes.isEmpty || !mounted) return;
    }
    final saved = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Close waiver editor',
      barrierColor: Colors.black.withValues(alpha: .45),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) => Align(
        alignment: Alignment.centerRight,
        child: _WaiverAssignmentSheet(
          api: _api,
          customSchoolId: widget.customSchoolId,
          academicTermId: _activeTermId,
          initialStudent: initialStudent,
          types: _waiverTypes,
          existing: existing,
          money: _money,
          currentUserId: widget.userId ?? 0,
        ),
      ),
      transitionBuilder: (context, animation, secondaryAnimation, child) =>
          SlideTransition(
            position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
                .animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                ),
            child: child,
          ),
    );
    if (saved == true) {
      await _loadWaivers(force: true);
      await _reloadFees();
    }
  }

  Future<void> _openOverviewPage(_FeeOverviewPage page) async {
    setState(() {
      _overviewPage = page;
      _overviewDetailLoading = true;
      _overviewDetailError = null;
    });
    try {
      if (page == _FeeOverviewPage.collectionByClass) {
        final rows = await _api.getFeeManagementClasses(
          customSchoolId: widget.customSchoolId,
          termId: _activeTermId,
        );
        if (mounted) setState(() => _classCollections = rows);
      } else if (page == _FeeOverviewPage.outstandingArrears) {
        final rows = await _api.getFeeManagementArrears(
          customSchoolId: widget.customSchoolId,
          termId: _activeTermId,
        );
        if (mounted) setState(() => _arrears = rows);
      }
    } catch (error) {
      if (mounted) setState(() => _overviewDetailError = error);
    } finally {
      if (mounted) setState(() => _overviewDetailLoading = false);
    }
  }

  Future<void> _revokeWaiver(FeeWaiverAssignment assignment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request waiver revocation?'),
        content: Text(
          'A draft revocation request will be created. The waiver remains active until another authorized person approves it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Create request'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _api.revokeStudentWaiver(
        customSchoolId: widget.customSchoolId,
        customStudentId: assignment.customStudentId,
        waiverId: assignment.id,
      );
      await _loadWaivers(force: true);
      await _reloadFees();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Revocation request saved as draft.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  Future<void> _performWaiverAction(
    FeeWaiverAssignment assignment,
    String action,
  ) async {
    int? approverId;
    String? reason;
    if (action == 'SUBMIT') {
      final approvers = (await _api.getFeeAdjustmentApprovers(
        widget.customSchoolId,
      )).where((item) => item.id != (widget.userId ?? 0)).toList();
      if (!mounted) return;
      approverId = await showDialog<int>(
        context: context,
        builder: (context) => _WaiverApproverDialog(approvers: approvers),
      );
      if (approverId == null) return;
    } else if (action == 'REJECT') {
      reason = await _showWaiverReasonDialog(
        title: 'Reject waiver request',
        hint: 'Explain what the requester should change.',
      );
      if (reason == null) return;
    } else if (action == 'WITHDRAW') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Withdraw approval request?'),
          content: const Text(
            'The request will return to Draft so you can edit and resubmit it.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Withdraw request'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    try {
      await _api.performStudentWaiverAction(
        customSchoolId: widget.customSchoolId,
        waiverId: assignment.id,
        action: action,
        reason: reason,
        approverId: approverId,
      );
      await _loadWaivers(force: true);
      await _reloadFees();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(switch (action) {
              'SUBMIT' => 'Waiver submitted for approval.',
              'WITHDRAW' =>
                'Approval request withdrawn. The waiver is now Draft.',
              'APPROVE' => 'Waiver approved.',
              'REJECT' => 'Waiver returned to Draft with your reason.',
              _ => 'Waiver updated.',
            }),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Request changed'),
          content: Text('$error'),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Refresh'),
            ),
          ],
        ),
      );
      await _loadWaivers(force: true);
    }
  }

  Future<String?> _showWaiverReasonDialog({
    required String title,
    required String hint,
  }) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: InputDecoration(labelText: 'Reason *', hintText: hint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(context, controller.text.trim());
              }
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Widget _buildFeeStructureContent() {
    if (_feeStructuresLoading && !_feeStructuresLoaded) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 96),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_feeStructuresError != null && !_feeStructuresLoaded) {
      return _FeeErrorState(
        message: 'Could not load the fee structure. $_feeStructuresError',
        onRetry: () => _loadFeeStructures(force: true),
      );
    }
    return FeeStructureWorkflowContent(
      api: _api,
      customSchoolId: widget.customSchoolId,
      termId: _feeStructureTermId,
      termName: _feeStructureTermName,
      currentUserId: widget.userId ?? 0,
      money: _money,
      onChanged: _reloadFees,
    );
  }

  // ignore: unused_element
  void _changeFeeStructureTerm(int termId) {
    if (termId <= 0 || termId == _feeStructureTermId) return;
    setState(() {
      _selectedFeeStructureTermId = termId;
      _feeStructures = const [];
      _feeStructuresLoaded = false;
      _feeStructuresError = null;
    });
    unawaited(_loadFeeStructures(force: true));
  }

  // ignore: unused_element
  Future<void> _openClassLevelSheet([_ClassFee? classFee]) async {
    FeeGradeLevel? selectedGradeLevel;
    if (classFee == null) {
      final availableGradeLevels = _gradeLevels
          .where(
            (grade) => !_feeStructures.any(
              (structure) => structure.gradeLevelId == grade.id,
            ),
          )
          .toList();
      if (availableGradeLevels.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All class levels already have a fee setup.'),
          ),
        );
        return;
      }
      selectedGradeLevel = await showDialog<FeeGradeLevel>(
        context: context,
        builder: (context) => SimpleDialog(
          title: const Text('Select class level'),
          children: availableGradeLevels
              .map(
                (grade) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, grade),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      grade.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      );
      if (selectedGradeLevel == null || !mounted) return;
    }
    final saved = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Close class level fee editor',
      barrierColor: Colors.black.withValues(alpha: .45),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.centerRight,
          child: _ClassLevelFeeSheet(
            classFee: classFee,
            selectedGradeLevel: selectedGradeLevel,
            money: _money,
            customSchoolId: widget.customSchoolId,
            termId: _feeStructureTermId,
            api: _api,
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final offset =
            Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            );
        return SlideTransition(position: offset, child: child);
      },
    );
    if (saved == true) {
      await _reloadFees();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            classFee == null
                ? 'Class fee setup added.'
                : 'Class level fee updated.',
          ),
          backgroundColor: AppColors.green,
        ),
      );
    }
  }

  // ignore: unused_element
  Future<void> _publishFeeStructure(_ClassFee classFee) async {
    if (classFee.structureId <= 0 || !classFee.isDraft) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Publish fee structure?'),
        content: Text(
          'Publish ${classFee.title} fees for $_feeStructureTermName? The published version will become the active structure for this class.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Publish'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _api.publishFeeStructure(
        customSchoolId: widget.customSchoolId,
        structureId: classFee.structureId,
      );
      await _reloadFees();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fee structure published.'),
          backgroundColor: AppColors.green,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error'), backgroundColor: AppColors.red),
      );
    }
  }

  // ignore: unused_element
  Future<void> _deleteFeeStructure(_ClassFee classFee) async {
    if (classFee.structureId <= 0 || !classFee.isDraft) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete draft fee structure?'),
        content: Text(
          'Delete the unpublished ${classFee.title} fee structure? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete draft'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _api.deleteFeeStructure(
        customSchoolId: widget.customSchoolId,
        structureId: classFee.structureId,
      );
      await _reloadFees();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Draft fee structure deleted.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error'), backgroundColor: AppColors.red),
      );
    }
  }

  Future<void> _showRecordPaymentForm({String? selectedStudentId}) async {
    final scopedStudentId = selectedStudentId?.trim() ?? '';
    if (scopedStudentId.isNotEmpty) {
      _studentFeeSearch = scopedStudentId;
      _studentFeeGradeLevelId = null;
      _studentFeePaymentStatus = null;
    }
    await _loadStudentFees(
      force: scopedStudentId.isNotEmpty || !_studentFeesLoaded,
    );
    if (!mounted || !_studentFeesLoaded) return;
    final students = _studentFeeRows();
    _StudentFeeRow? selectedStudent;
    if (scopedStudentId.isNotEmpty) {
      for (final student in students) {
        if (student.id == scopedStudentId) {
          selectedStudent = student;
          break;
        }
      }
      if (selectedStudent == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'This student does not have an active fee account for the current term.',
            ),
            backgroundColor: AppColors.red,
          ),
        );
        return;
      }
    }
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _RecordPaymentDialog(
        students: students,
        selectedStudent: selectedStudent,
        paymentMethods: _paymentMethods,
        customSchoolId: widget.customSchoolId,
        termId: _activeTermId,
        api: _api,
        money: _money,
      ),
    );
    if (saved == true) {
      await _reloadFees();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment recorded successfully.'),
          backgroundColor: AppColors.green,
        ),
      );
    }
  }

  List<_StudentFeeRow> _studentFeeRows() {
    return (_studentFeesPage?.content ?? const <FeeStudentFeeRow>[])
        .map(_studentRowFromApi)
        .toList();
  }

  _StudentFeeRow _studentRowFromApi(FeeStudentFeeRow row) {
    return _StudentFeeRow(
      name: row.studentName,
      id: row.customStudentId,
      className: row.className.trim().isEmpty ? 'Not assigned' : row.className,
      totalFees: row.totalFees + row.totalAdjustments,
      paid: row.paid,
      balance: row.balance,
      status: _paymentStatusLabel(row.paymentStatus),
      lastPayment: _formatCompactDate(row.lastPaymentDate),
    );
  }

  // ignore: unused_element
  List<_ClassFee> _classFees() {
    return _feeStructures
        .map(
          (structure) => _ClassFee(
            structureId: structure.structureId,
            gradeLevelId: structure.gradeLevelId,
            level: structure.levelCode.trim().isEmpty
                ? structure.fullName
                : structure.levelCode,
            title: structure.fullName.trim().isEmpty
                ? structure.levelCode
                : structure.fullName,
            version: structure.version,
            status: structure.status,
            items: structure.feeItems
                .map(
                  (item) => _ClassFeeItem(
                    item.feeName.trim().isEmpty ? item.category : item.feeName,
                    item.amount,
                    feeId: item.feeId,
                    categoryId: item.categoryId,
                    category: item.category,
                    description: item.description,
                    status: item.status,
                    dueDate: item.dueDate,
                  ),
                )
                .toList(),
          ),
        )
        .toList();
  }

  String _paymentStatusLabel(String value) {
    final normalized = value.trim().toUpperCase();
    return switch (normalized) {
      'PAID' => 'Paid',
      'PARTIAL' || 'PARTIALLY_PAID' => 'Partial',
      'UNPAID' => 'Unpaid',
      'CREDIT' => 'Credit',
      'NO_FEES' => 'No fees',
      _ => value.trim().isEmpty ? 'Unpaid' : value,
    };
  }

  String _formatCompactDate(DateTime? date) {
    if (date == null) return '-';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

class _FeeTabs extends StatelessWidget {
  const _FeeTabs({required this.selected, required this.onChanged});

  final _FeeTab selected;
  final ValueChanged<_FeeTab> onChanged;

  static const _items = [
    (_FeeTab.overview, 'Overview'),
    (_FeeTab.studentFees, 'Student Fees'),
    (_FeeTab.feeStructure, 'Fee Structure'),
    (_FeeTab.feeCatalogue, 'Fee Catalogue'),
    (_FeeTab.adjustments, 'Fee Adjustments'),
    (_FeeTab.reversals, 'Payment Reversals'),
    (_FeeTab.classRequirements, 'Items & Supplies'),
    (_FeeTab.waivers, 'Waivers & Discounts'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: _items.map((item) {
          final active = item.$1 == selected;
          return InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => onChanged(item.$1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: active ? AppColors.green : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                item.$2,
                style: TextStyle(
                  color: active ? Colors.white : AppColors.muted,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _FeeOverviewContent extends StatelessWidget {
  const _FeeOverviewContent({
    required this.page,
    required this.schoolName,
    required this.termName,
    required this.overview,
    required this.collectionRows,
    required this.arrearsRows,
    required this.money,
    required this.onRecordPayment,
    required this.onOpenStudentFees,
    required this.onOpenStructure,
    required this.onOpenWaivers,
    required this.loadingDetails,
    required this.detailError,
    required this.onRetryDetails,
    required this.onViewAllCollection,
    required this.onViewAllArrears,
    required this.onBackToOverview,
  });

  final _FeeOverviewPage page;
  final String schoolName;
  final String termName;
  final FeeManagementOverview overview;
  final List<FeeClassCollectionSummary> collectionRows;
  final List<FeeStudentFeeRow> arrearsRows;
  final String Function(double amount) money;
  final VoidCallback onRecordPayment;
  final VoidCallback onOpenStudentFees;
  final VoidCallback onOpenStructure;
  final VoidCallback onOpenWaivers;
  final bool loadingDetails;
  final Object? detailError;
  final VoidCallback onRetryDetails;
  final VoidCallback onViewAllCollection;
  final VoidCallback onViewAllArrears;
  final VoidCallback onBackToOverview;

  @override
  Widget build(BuildContext context) {
    if (page == _FeeOverviewPage.collectionByClass) {
      if (loadingDetails) {
        return _OverviewDetailLoading(
          title: 'Collection by class',
          onBack: onBackToOverview,
        );
      }
      if (detailError != null) {
        return _OverviewDetailError(
          title: 'Collection by class',
          message: 'Could not load class collections. $detailError',
          onBack: onBackToOverview,
          onRetry: onRetryDetails,
        );
      }
      return _CollectionByClassPage(
        rows: collectionRows,
        money: money,
        onBack: onBackToOverview,
      );
    }
    if (page == _FeeOverviewPage.outstandingArrears) {
      if (loadingDetails) {
        return _OverviewDetailLoading(
          title: 'Outstanding arrears',
          onBack: onBackToOverview,
        );
      }
      if (detailError != null) {
        return _OverviewDetailError(
          title: 'Outstanding arrears',
          message: 'Could not load outstanding arrears. $detailError',
          onBack: onBackToOverview,
          onRetry: onRetryDetails,
        );
      }
      return _OutstandingArrearsPage(
        rows: arrearsRows,
        money: money,
        onBack: onBackToOverview,
      );
    }

    final totalExpected = overview.totalExpected;
    final totalCollected = overview.totalCollected;
    final outstanding = overview.outstanding;
    final priorArrears = overview.arrearsPriorTerms;
    final collectionRate = overview.collectionRate / 100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Fees & Requirements',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 6),
        Text(
          [
            if (schoolName.trim().isNotEmpty) schoolName.trim(),
            termName,
          ].join(' · '),
          style: const TextStyle(color: AppColors.muted),
        ),
        const SizedBox(height: 22),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth < 720
                ? 1
                : constraints.maxWidth < 1060
                ? 2
                : 4;
            final width =
                (constraints.maxWidth - ((columns - 1) * 14)) / columns;
            final cards = [
              _OverviewMetricCard(
                width: width,
                title: 'Total expected',
                value: money(totalExpected),
                subtitle: '${overview.totalStudents} students · $termName',
                icon: Icons.receipt_long_rounded,
                color: AppColors.purple,
              ),
              _OverviewMetricCard(
                width: width,
                title: 'Total collected',
                value: money(totalCollected),
                subtitle:
                    '${overview.collectionRate.toStringAsFixed(1)}% collection rate',
                icon: Icons.check_circle_rounded,
                color: AppColors.green,
              ),
              _OverviewMetricCard(
                width: width,
                title: 'Outstanding',
                value: money(outstanding),
                subtitle:
                    '${overview.unpaidOrPartialStudents} students unpaid/partial',
                icon: Icons.warning_amber_rounded,
                color: AppColors.amber,
              ),
              _OverviewMetricCard(
                width: width,
                title: 'Arrears (prior terms)',
                value: money(priorArrears),
                subtitle: 'From ${overview.arrearsStudentCount} students',
                icon: Icons.calendar_month_rounded,
                color: AppColors.blue,
              ),
            ];
            return Wrap(spacing: 14, runSpacing: 14, children: cards);
          },
        ),
        const SizedBox(height: 18),
        _CollectionProgressCard(
          progress: collectionRate,
          collected: totalCollected,
          expected: totalExpected,
          title: 'Overall Collection Progress · $termName',
          money: money,
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 980;
            return Flex(
              direction: narrow ? Axis.vertical : Axis.horizontal,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: narrow ? 0 : 2,
                  child: _CollectionByClassCard(
                    rows: collectionRows,
                    money: money,
                    onViewAll: onViewAllCollection,
                  ),
                ),
                SizedBox(width: narrow ? 0 : 18, height: narrow ? 18 : 0),
                Expanded(
                  flex: narrow ? 0 : 1,
                  child: _QuickActionsCard(
                    onRecordPayment: onRecordPayment,
                    onOpenStudentFees: onOpenStudentFees,
                    onOpenStructure: onOpenStructure,
                    onOpenWaivers: onOpenWaivers,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        _OutstandingArrearsCard(
          rows: arrearsRows,
          money: money,
          onViewAll: onViewAllArrears,
        ),
      ],
    );
  }
}

class _OverviewDetailLoading extends StatelessWidget {
  const _OverviewDetailLoading({required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SubPageHeader(
          title: title,
          subtitle: 'Loading current-term data...',
          onBack: onBack,
        ),
        const SizedBox(height: 18),
        const Card(
          child: SizedBox(
            height: 220,
            width: double.infinity,
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      ],
    );
  }
}

class _OverviewDetailError extends StatelessWidget {
  const _OverviewDetailError({
    required this.title,
    required this.message,
    required this.onBack,
    required this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback onBack;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SubPageHeader(
          title: title,
          subtitle: 'Current-term detail could not be loaded.',
          onBack: onBack,
        ),
        const SizedBox(height: 18),
        _FeeErrorState(message: message, onRetry: onRetry),
      ],
    );
  }
}

class _OverviewMetricCard extends StatelessWidget {
  const _OverviewMetricCard({
    required this.width,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  final double width;
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: const TextStyle(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CollectionProgressCard extends StatelessWidget {
  const _CollectionProgressCard({
    required this.progress,
    required this.collected,
    required this.expected,
    required this.title,
    required this.money,
  });

  final double progress;
  final double collected;
  final double expected;
  final String title;
  final String Function(double amount) money;

  @override
  Widget build(BuildContext context) {
    final percent = (progress * 100).round();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 9,
                backgroundColor: AppColors.border,
                valueColor: const AlwaysStoppedAnimation(AppColors.green),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${money(collected)} collected of ${money(expected)} expected',
                    style: const TextStyle(color: AppColors.muted),
                  ),
                ),
                Text(
                  '$percent%',
                  style: const TextStyle(
                    color: AppColors.green,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CollectionByClassCard extends StatelessWidget {
  const _CollectionByClassCard({
    required this.rows,
    required this.money,
    required this.onViewAll,
  });

  final List<FeeClassCollectionSummary> rows;
  final String Function(double amount) money;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Collection by Class',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                TextButton(onPressed: onViewAll, child: const Text('View all')),
              ],
            ),
            const SizedBox(height: 14),
            if (rows.isEmpty)
              const _FeeEmptyCard(message: 'No class collection data yet.')
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingTextStyle: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .5,
                  ),
                  columns: const [
                    DataColumn(label: Text('CLASS')),
                    DataColumn(label: Text('STUDENTS')),
                    DataColumn(label: Text('EXPECTED')),
                    DataColumn(label: Text('COLLECTED')),
                    DataColumn(label: Text('RATE')),
                  ],
                  rows: rows.take(6).map((row) {
                    final rate = row.collectionRate / 100;
                    return DataRow(
                      cells: [
                        DataCell(Text(row.className)),
                        DataCell(Text('${row.students}')),
                        DataCell(Text(money(row.expected))),
                        DataCell(Text(money(row.collected))),
                        DataCell(_RateBar(rate: rate)),
                      ],
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CollectionByClassPage extends StatelessWidget {
  const _CollectionByClassPage({
    required this.rows,
    required this.money,
    required this.onBack,
  });

  final List<FeeClassCollectionSummary> rows;
  final String Function(double amount) money;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final totalExpected = rows.fold<double>(
      0,
      (sum, row) => sum + row.expected,
    );
    final totalCollected = rows.fold<double>(
      0,
      (sum, row) => sum + row.collected,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SubPageHeader(
          title: 'Collection by Class',
          subtitle:
              '${rows.length} classes · ${money(totalCollected)} collected of ${money(totalExpected)} expected',
          onBack: onBack,
        ),
        const SizedBox(height: 18),
        if (rows.isEmpty)
          const _FeeEmptyCard(message: 'No class collection data yet.')
        else
          Card(
            clipBehavior: Clip.antiAlias,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(
                  const Color(0xFFF8FAF9),
                ),
                headingTextStyle: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .5,
                ),
                columnSpacing: 68,
                columns: const [
                  DataColumn(label: Text('CLASS')),
                  DataColumn(label: Text('STUDENTS')),
                  DataColumn(label: Text('EXPECTED')),
                  DataColumn(label: Text('COLLECTED')),
                  DataColumn(label: Text('OUTSTANDING')),
                  DataColumn(label: Text('RATE')),
                ],
                rows: rows.map((row) {
                  final rate = row.collectionRate / 100;
                  return DataRow(
                    cells: [
                      DataCell(Text(row.className)),
                      DataCell(Text('${row.students}')),
                      DataCell(Text(money(row.expected))),
                      DataCell(Text(money(row.collected))),
                      DataCell(Text(money(row.outstanding))),
                      DataCell(_RateBar(rate: rate)),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
      ],
    );
  }
}

class _QuickActionsCard extends StatelessWidget {
  const _QuickActionsCard({
    required this.onRecordPayment,
    required this.onOpenStudentFees,
    required this.onOpenStructure,
    required this.onOpenWaivers,
  });

  final VoidCallback onRecordPayment;
  final VoidCallback onOpenStudentFees;
  final VoidCallback onOpenStructure;
  final VoidCallback onOpenWaivers;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quick Actions',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 14),
            _QuickActionTile(
              icon: Icons.payments_rounded,
              color: AppColors.green,
              title: 'Record Payment',
              subtitle: 'Enter a new fee payment',
              onTap: onRecordPayment,
            ),
            _QuickActionTile(
              icon: Icons.groups_rounded,
              color: AppColors.blue,
              title: 'Student Fee List',
              subtitle: 'View student balances',
              onTap: onOpenStudentFees,
            ),
            _QuickActionTile(
              icon: Icons.settings_rounded,
              color: AppColors.purple,
              title: 'Fee Structure',
              subtitle: 'Configure term fees',
              onTap: onOpenStructure,
            ),
            _QuickActionTile(
              icon: Icons.local_offer_rounded,
              color: AppColors.amber,
              title: 'Waivers & discounts',
              subtitle: 'Manage exemptions',
              onTap: onOpenWaivers,
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: const Color(0xFFF8FAF9),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: enabled ? .16 : .08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: enabled ? color : AppColors.muted,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: enabled ? AppColors.text : AppColors.muted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: enabled ? AppColors.muted : AppColors.border,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OutstandingArrearsCard extends StatelessWidget {
  const _OutstandingArrearsCard({
    required this.rows,
    required this.money,
    required this.onViewAll,
  });

  final List<FeeStudentFeeRow> rows;
  final String Function(double amount) money;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Outstanding Arrears',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                const Text(
                  '',
                  style: TextStyle(
                    color: AppColors.red,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  '${rows.length} Students',
                  style: const TextStyle(
                    color: AppColors.red,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 12),
                TextButton(onPressed: onViewAll, child: const Text('View all')),
              ],
            ),
            const SizedBox(height: 14),
            if (rows.isEmpty)
              const _FeeEmptyCard(message: 'No outstanding arrears right now.')
            else
              ...rows.take(4).map((row) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.red.withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.red.withValues(alpha: .15),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              row.studentName,
                              style: const TextStyle(
                                color: AppColors.red,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              row.className,
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            money(row.balance),
                            style: const TextStyle(
                              color: AppColors.red,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            row.paymentStatus,
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _OutstandingArrearsPage extends StatelessWidget {
  const _OutstandingArrearsPage({
    required this.rows,
    required this.money,
    required this.onBack,
  });

  final List<FeeStudentFeeRow> rows;
  final String Function(double amount) money;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final total = rows.fold<double>(0, (sum, row) => sum + row.balance);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SubPageHeader(
          title: 'Outstanding Arrears',
          subtitle: '${rows.length} students · ${money(total)} outstanding',
          onBack: onBack,
        ),
        const SizedBox(height: 18),
        if (rows.isEmpty)
          const _FeeEmptyCard(message: 'No outstanding arrears right now.')
        else
          Card(
            clipBehavior: Clip.antiAlias,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(
                  const Color(0xFFF8FAF9),
                ),
                headingTextStyle: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .5,
                ),
                columnSpacing: 78,
                columns: const [
                  DataColumn(label: Text('STUDENT')),
                  DataColumn(label: Text('CLASS')),
                  DataColumn(label: Text('AMOUNT')),
                  DataColumn(label: Text('STATUS')),
                  DataColumn(label: Text('LAST PAYMENT')),
                  DataColumn(label: Text('ACTION')),
                ],
                rows: rows.map((row) {
                  return DataRow(
                    cells: [
                      DataCell(
                        _StudentNameCell(
                          name: row.studentName,
                          id: row.customStudentId,
                        ),
                      ),
                      DataCell(Text(row.className)),
                      DataCell(
                        Text(
                          money(row.balance),
                          style: const TextStyle(color: AppColors.red),
                        ),
                      ),
                      DataCell(Text(row.paymentStatus)),
                      DataCell(Text(_formatDateLabel(row.lastPaymentDate))),
                      DataCell(
                        TextButton.icon(
                          onPressed: () {},
                          icon: const Icon(
                            Icons.notifications_active_outlined,
                            size: 16,
                          ),
                          label: const Text('Send reminder'),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
      ],
    );
  }
}

class _FeeEmptyCard extends StatelessWidget {
  const _FeeEmptyCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAF9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.muted),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDateLabel(DateTime? date) {
  if (date == null) return '-';
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

class _SubPageHeader extends StatelessWidget {
  const _SubPageHeader({
    required this.title,
    required this.subtitle,
    required this.onBack,
  });

  final String title;
  final String subtitle;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Wrap(
          spacing: 14,
          runSpacing: 14,
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.spaceBetween,
          children: [
            SizedBox(
              width: 760,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: const [
                      Text(
                        'Fee Overview',
                        style: TextStyle(
                          color: AppColors.green,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: AppColors.muted,
                      ),
                      Text(
                        'View all',
                        style: TextStyle(color: AppColors.muted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(color: AppColors.muted),
                  ),
                ],
              ),
            ),
            OutlinedButton.icon(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Back to Fee Overview'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RateBar extends StatelessWidget {
  const _RateBar({required this.rate});

  final double rate;

  @override
  Widget build(BuildContext context) {
    final color = rate >= .85
        ? AppColors.green
        : rate >= .75
        ? AppColors.amber
        : AppColors.red;
    return SizedBox(
      width: 170,
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: rate.clamp(0, 1),
                minHeight: 6,
                backgroundColor: AppColors.border,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${(rate * 100).round()}%',
            style: TextStyle(color: color, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

// Kept temporarily while older deep links migrate to the stream workflow.
// ignore: unused_element
class _FeeStructureContent extends StatelessWidget {
  const _FeeStructureContent({
    required this.termName,
    required this.terms,
    required this.selectedTermId,
    required this.classFees,
    required this.money,
    required this.onTermChanged,
    required this.onAddClassLevel,
    required this.onEditClassLevel,
    required this.onPublishClassLevel,
    required this.onDeleteClassLevel,
  });

  final String termName;
  final List<FeeAcademicTermOption> terms;
  final int selectedTermId;
  final List<_ClassFee> classFees;
  final String Function(double amount) money;
  final ValueChanged<int> onTermChanged;
  final VoidCallback? onAddClassLevel;
  final ValueChanged<_ClassFee>? onEditClassLevel;
  final ValueChanged<_ClassFee>? onPublishClassLevel;
  final ValueChanged<_ClassFee>? onDeleteClassLevel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Fee Structure',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.greenSoft,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${classFees.length} Class Levels',
                          style: const TextStyle(
                            color: AppColors.green,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Text(
                        '$termName · Click Edit to configure fees.',
                        style: const TextStyle(color: AppColors.muted),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            FilledButton.icon(
              onPressed: onAddClassLevel,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Fee Setup'),
            ),
          ],
        ),
        if (terms.isNotEmpty) ...[
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_month_outlined,
                  color: AppColors.green,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Fee term',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Choose the current or prepared term whose fees you want to configure.',
                        style: TextStyle(color: AppColors.muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 300,
                  child: DropdownButtonFormField<int>(
                    key: const ValueKey('fee-structure-term-selector'),
                    value: selectedTermId,
                    decoration: const InputDecoration(
                      labelText: 'Academic term',
                      isDense: true,
                    ),
                    items: terms
                        .map(
                          (term) => DropdownMenuItem<int>(
                            value: term.id,
                            child: Text(
                              '${term.label}${term.isCurrent
                                  ? ' · Current'
                                  : term.isPrepared
                                  ? ' · Prepared'
                                  : ''}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) onTermChanged(value);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth < 720
                ? 1
                : constraints.maxWidth < 1100
                ? 2
                : 3;
            final cardWidth =
                (constraints.maxWidth - ((columns - 1) * 18)) / columns;
            if (classFees.isEmpty) {
              return const _FeeEmptyCard(
                message: 'No fee structures found for this term.',
              );
            }
            return Wrap(
              spacing: 18,
              runSpacing: 18,
              children: classFees.map((fee) {
                return SizedBox(
                  width: cardWidth,
                  child: _ClassFeeCard(
                    classFee: fee,
                    money: money,
                    onEdit: onEditClassLevel == null
                        ? null
                        : () => onEditClassLevel!(fee),
                    onPublish: onPublishClassLevel == null || !fee.isDraft
                        ? null
                        : () => onPublishClassLevel!(fee),
                    onDelete: onDeleteClassLevel == null || !fee.isDraft
                        ? null
                        : () => onDeleteClassLevel!(fee),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

class _ClassFeeCard extends StatelessWidget {
  const _ClassFeeCard({
    required this.classFee,
    required this.money,
    required this.onEdit,
    required this.onPublish,
    required this.onDelete,
  });

  final _ClassFee classFee;
  final String Function(double amount) money;
  final VoidCallback? onEdit;
  final VoidCallback? onPublish;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        classFee.level.toUpperCase(),
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .5,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: classFee.isDraft
                            ? AppColors.amber.withValues(alpha: .12)
                            : AppColors.greenSoft,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        classFee.isDraft
                            ? 'Draft v${classFee.version}'
                            : 'Published v${classFee.version}',
                        style: TextStyle(
                          color: classFee.isDraft
                              ? AppColors.amber
                              : AppColors.green,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  classFee.title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 16),
                ...classFee.activeItems.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.name,
                            style: const TextStyle(color: AppColors.muted),
                          ),
                        ),
                        Text(
                          money(item.amount),
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  ),
                ),
                if (classFee.discontinuedItemCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      '${classFee.discontinuedItemCount} discontinued fee ${classFee.discontinuedItemCount == 1 ? 'item' : 'items'}',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                const Divider(height: 26),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Total / Term',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                    Text(
                      money(classFee.total),
                      style: const TextStyle(
                        color: AppColors.green,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            color: const Color(0xFFF8FAF9),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Edit'),
                  ),
                ),
                if (classFee.isDraft) ...[
                  Expanded(
                    child: TextButton.icon(
                      onPressed: onPublish,
                      icon: const Icon(Icons.publish_rounded, size: 16),
                      label: const Text('Publish'),
                    ),
                  ),
                  Expanded(
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.red,
                      ),
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline_rounded, size: 16),
                      label: const Text('Delete'),
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

class _ClassFee {
  const _ClassFee({
    required this.structureId,
    required this.gradeLevelId,
    required this.level,
    required this.title,
    required this.version,
    required this.status,
    required this.items,
  });

  final int structureId;
  final int gradeLevelId;
  final String level;
  final String title;
  final int version;
  final String status;
  final List<_ClassFeeItem> items;

  bool get isDraft => status.trim().toUpperCase() == 'DRAFT';
  List<_ClassFeeItem> get activeItems =>
      items.where((item) => item.isActive).toList();
  int get discontinuedItemCount => items.length - activeItems.length;
  double get total => activeItems.fold(0, (sum, item) => sum + item.amount);
}

class _ClassFeeItem {
  const _ClassFeeItem(
    this.name,
    this.amount, {
    this.feeId = 0,
    this.categoryId = 0,
    this.category = '',
    this.description = '',
    this.status = 'ACTIVE',
    this.dueDate,
  });

  final String name;
  final double amount;
  final int feeId;
  final int categoryId;
  final String category;
  final String description;
  final String status;
  final DateTime? dueDate;

  bool get isActive => status.trim().toUpperCase() != 'INACTIVE';
}

class _ClassLevelFeeSheet extends StatefulWidget {
  const _ClassLevelFeeSheet({
    required this.classFee,
    required this.selectedGradeLevel,
    required this.money,
    required this.customSchoolId,
    required this.termId,
    required this.api,
  });

  final _ClassFee? classFee;
  final FeeGradeLevel? selectedGradeLevel;
  final String Function(double amount) money;
  final String customSchoolId;
  final int termId;
  final FeeApiClient api;

  @override
  State<_ClassLevelFeeSheet> createState() => _ClassLevelFeeSheetState();
}

class _ClassLevelFeeSheetState extends State<_ClassLevelFeeSheet> {
  final _formKey = GlobalKey<FormState>();
  late final List<_EditableFeeItem> _items;
  int? _selectedGradeLevelId;
  bool _saving = false;

  bool get _editing => widget.classFee != null;

  double get _total => _items.fold<double>(
    0,
    (sum, item) => sum + (double.tryParse(item.amount.text.trim()) ?? 0),
  );

  @override
  void initState() {
    super.initState();
    final fee = widget.classFee;
    _selectedGradeLevelId = fee?.gradeLevelId ?? widget.selectedGradeLevel?.id;
    _items = (fee?.items ?? const [_ClassFeeItem('Tuition Fee', 0)])
        .map(
          (item) => _EditableFeeItem(
            name: TextEditingController(text: item.name),
            amount: TextEditingController(text: item.amount.toStringAsFixed(0)),
            active: item.isActive,
            original: item,
          ),
        )
        .toList();
  }

  @override
  void dispose() {
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: SafeArea(
        child: SizedBox(
          width: 430,
          height: double.infinity,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 14, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _editing ? 'Edit Class Fees' : 'Set Up Class Fees',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _editing
                                ? 'Update this class fee structure'
                                : 'Create a fee structure for a class level',
                            style: const TextStyle(color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context, false),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.greenSoft,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'CLASS LEVEL',
                                style: TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                widget.classFee?.title ??
                                    widget.selectedGradeLevel?.name ??
                                    'Class level',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                        const Row(
                          children: [
                            Text(
                              'FEE ITEMS',
                              style: TextStyle(
                                color: AppColors.muted,
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                letterSpacing: .5,
                              ),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'drag to reorder',
                              style: TextStyle(
                                color: AppColors.muted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ReorderableListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          buildDefaultDragHandles: false,
                          proxyDecorator: (child, index, animation) {
                            return Material(
                              color: Colors.transparent,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: .12,
                                      ),
                                      blurRadius: 18,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: child,
                              ),
                            );
                          },
                          itemCount: _items.length,
                          onReorder: _reorderItem,
                          itemBuilder: (context, index) {
                            return Padding(
                              key: ValueKey(_items[index]),
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _EditableFeeItemRow(
                                index: index,
                                item: _items[index],
                                canRemove: _items[index].active
                                    ? _items
                                              .where((item) => item.active)
                                              .length >
                                          1
                                    : true,
                                discontinueMode:
                                    widget.classFee?.isDraft == false,
                                onChanged: () => setState(() {}),
                                onRemove: () => _removeItem(index),
                                onRestore: () =>
                                    setState(() => _items[index].active = true),
                              ),
                            );
                          },
                        ),
                        TextButton.icon(
                          onPressed: _addItem,
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Add fee item'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAF9),
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Total per Term',
                            style: TextStyle(
                              color: AppColors.muted,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        Text(
                          widget.money(_total),
                          style: const TextStyle(
                            color: AppColors.green,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _saving ? null : _save,
                            icon: _saving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.check_rounded),
                            label: Text(_editing ? 'Save' : 'Save Fee Setup'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _addItem() {
    setState(() {
      _items.add(
        _EditableFeeItem(
          name: TextEditingController(),
          amount: TextEditingController(text: '0'),
          active: true,
          original: null,
        ),
      );
    });
  }

  Future<void> _removeItem(int index) async {
    final item = _items[index];
    if (widget.classFee?.isDraft == false && item.active) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Discontinue fee item?'),
          content: Text(
            '${item.name.text.trim()} will be excluded from the replacement fee structure. The published version remains unchanged until you publish the new draft.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Discontinue'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      setState(() => item.active = false);
      return;
    }
    setState(() {
      final removedItem = _items.removeAt(index);
      removedItem.dispose();
    });
  }

  void _reorderItem(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _items.removeAt(oldIndex);
      _items.insert(newIndex, item);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_items.any((item) => item.active)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Keep at least one active fee item in this setup.'),
        ),
      );
      return;
    }
    final classFee = widget.classFee;
    final gradeLevelId = classFee?.gradeLevelId ?? _selectedGradeLevelId ?? 0;
    if (gradeLevelId <= 0 || widget.termId <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select a class level before saving fee setup.'),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.api.saveFeeStructure(
        customSchoolId: widget.customSchoolId,
        structureId: classFee?.structureId ?? 0,
        gradeLevelId: gradeLevelId,
        streamId: widget.classFee?.structureId ?? 0,
        termId: widget.termId,
        feeItems: _items.map((item) {
          final original = item.original;
          return FeeStructureItem(
            feeId: original?.feeId ?? 0,
            categoryId: original?.categoryId ?? 0,
            category: original?.category ?? '',
            feeName: item.name.text.trim(),
            amount: double.tryParse(item.amount.text.trim()) ?? 0,
            description: original?.description ?? '',
            status: item.active ? 'ACTIVE' : 'INACTIVE',
            dueDate: original?.dueDate,
          );
        }).toList(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          backgroundColor: AppColors.red,
        ),
      );
    }
  }
}

class _EditableFeeItem {
  _EditableFeeItem({
    required this.name,
    required this.amount,
    required this.active,
    required this.original,
  });

  final TextEditingController name;
  final TextEditingController amount;
  bool active;
  final _ClassFeeItem? original;

  void dispose() {
    name.dispose();
    amount.dispose();
  }
}

class _EditableFeeItemRow extends StatelessWidget {
  const _EditableFeeItemRow({
    required this.index,
    required this.item,
    required this.canRemove,
    required this.discontinueMode,
    required this.onChanged,
    required this.onRemove,
    required this.onRestore,
  });

  final int index;
  final _EditableFeeItem item;
  final bool canRemove;
  final bool discontinueMode;
  final VoidCallback onChanged;
  final VoidCallback onRemove;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ReorderableDragStartListener(
          index: index,
          child: Container(
            width: 38,
            height: 50,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAF9),
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.drag_indicator_rounded,
              color: AppColors.muted,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TextFormField(
            controller: item.name,
            enabled: item.active,
            decoration: InputDecoration(
              hintText: 'Fee item name',
              suffixText: item.active ? null : 'Discontinued',
            ),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Enter fee item name'
                : null,
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 118,
          child: TextFormField(
            controller: item.amount,
            enabled: item.active,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              prefixText: 'GH₵ ',
              hintText: '0',
            ),
            onChanged: (_) => onChanged(),
            validator: (value) {
              final amount = double.tryParse(value?.trim() ?? '');
              if (amount == null || amount < 0) {
                return 'Invalid';
              }
              return null;
            },
          ),
        ),
        if (item.active)
          IconButton(
            onPressed: canRemove ? onRemove : null,
            color: AppColors.red,
            icon: Icon(
              discontinueMode
                  ? Icons.do_not_disturb_on_outlined
                  : Icons.close_rounded,
            ),
            tooltip: discontinueMode
                ? 'Discontinue fee item'
                : 'Remove fee item',
          )
        else
          IconButton(
            onPressed: onRestore,
            color: AppColors.green,
            icon: const Icon(Icons.restore_rounded),
            tooltip: 'Restore fee item',
          ),
      ],
    );
  }
}

class _StudentFeesContent extends StatelessWidget {
  const _StudentFeesContent({
    required this.rows,
    required this.gradeLevels,
    required this.selectedGradeLevelId,
    required this.selectedPaymentStatus,
    required this.search,
    required this.termName,
    required this.paymentMethods,
    required this.customSchoolId,
    required this.termId,
    required this.currentUserId,
    required this.api,
    required this.money,
    required this.onSearchChanged,
    required this.onGradeLevelChanged,
    required this.onPaymentStatusChanged,
    required this.onPaymentSaved,
    required this.onAssignWaiver,
  });

  final List<_StudentFeeRow> rows;
  final List<FeeGradeLevel> gradeLevels;
  final int? selectedGradeLevelId;
  final String? selectedPaymentStatus;
  final String search;
  final String termName;
  final List<FeePaymentMethod> paymentMethods;
  final String customSchoolId;
  final int termId;
  final int currentUserId;
  final FeeApiClient api;
  final String Function(double amount) money;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<int?> onGradeLevelChanged;
  final ValueChanged<String?> onPaymentStatusChanged;
  final Future<void> Function() onPaymentSaved;
  final ValueChanged<_StudentFeeRow> onAssignWaiver;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Student Fees',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${rows.length} ${rows.length == 1 ? 'Student' : 'Students'}',
                    style: const TextStyle(
                      color: AppColors.green,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: () => _showRecordPaymentForm(context, rows),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Collect Fees'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _StudentFeeFilters(
          gradeLevels: gradeLevels,
          selectedGradeLevelId: selectedGradeLevelId,
          selectedPaymentStatus: selectedPaymentStatus,
          search: search,
          termName: termName,
          onSearchChanged: onSearchChanged,
          onGradeLevelChanged: onGradeLevelChanged,
          onPaymentStatusChanged: onPaymentStatusChanged,
        ),
        const SizedBox(height: 18),
        if (rows.isEmpty)
          const _FeeEmptyCard(message: 'No student fee records found.')
        else
          Card(
            clipBehavior: Clip.antiAlias,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(
                  const Color(0xFFF8FAF9),
                ),
                headingTextStyle: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .5,
                ),
                dataRowMinHeight: 58,
                dataRowMaxHeight: 70,
                columnSpacing: 52,
                columns: const [
                  DataColumn(label: Text('STUDENT')),
                  DataColumn(label: Text('CLASS')),
                  DataColumn(label: Text('TOTAL FEES')),
                  DataColumn(label: Text('PAID')),
                  DataColumn(label: Text('BALANCE')),
                  DataColumn(label: Text('STATUS')),
                  DataColumn(label: Text('LAST PAYMENT')),
                  DataColumn(label: Text('')),
                ],
                rows: rows.map((row) {
                  return DataRow(
                    onSelectChanged: (_) => _showStudentDetails(context, row),
                    cells: [
                      DataCell(_StudentNameCell(name: row.name, id: row.id)),
                      DataCell(Text(row.className)),
                      DataCell(Text(money(row.totalFees))),
                      DataCell(
                        row.paid <= 0
                            ? const Text('-')
                            : Text(
                                money(row.paid),
                                style: const TextStyle(color: AppColors.green),
                              ),
                      ),
                      DataCell(
                        row.balance == 0
                            ? const Text('-')
                            : Text(
                                row.balance < 0
                                    ? 'Credit ${money(row.balance.abs())}'
                                    : money(row.balance),
                                style: TextStyle(
                                  color: row.balance > 0
                                      ? AppColors.red
                                      : AppColors.green,
                                ),
                              ),
                      ),
                      DataCell(_PaymentStatus(status: row.status)),
                      DataCell(Text(row.lastPayment)),
                      DataCell(
                        TextButton.icon(
                          onPressed: () => _showStudentDetails(context, row),
                          icon: Icon(
                            row.balance > 0
                                ? Icons.add_rounded
                                : Icons.visibility_outlined,
                            size: 16,
                          ),
                          label: Text(row.balance > 0 ? 'Pay' : 'View'),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
      ],
    );
  }

  void _showStudentDetails(BuildContext context, _StudentFeeRow row) {
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close student fee details',
      barrierColor: Colors.black.withValues(alpha: .42),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.centerRight,
          child: _StudentFeeDetailPanel(
            row: row,
            money: money,
            api: api,
            customSchoolId: customSchoolId,
            termId: termId,
            currentUserId: currentUserId,
            onRecordPayment: () => _showRecordPaymentForm(
              context,
              rows,
              selectedStudent: row,
              closeDetailsAfterSave: true,
            ),
            onAssignWaiver: () {
              Navigator.pop(context);
              onAssignWaiver(row);
            },
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final offset =
            Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            );
        return SlideTransition(position: offset, child: child);
      },
    );
  }

  Future<void> _showRecordPaymentForm(
    BuildContext context,
    List<_StudentFeeRow> rows, {
    _StudentFeeRow? selectedStudent,
    bool closeDetailsAfterSave = false,
  }) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _RecordPaymentDialog(
        students: rows,
        selectedStudent: selectedStudent,
        paymentMethods: paymentMethods,
        customSchoolId: customSchoolId,
        termId: termId,
        api: api,
        money: money,
      ),
    );
    if (saved == true) {
      await onPaymentSaved();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment recorded successfully.'),
          backgroundColor: AppColors.green,
        ),
      );
      if (closeDetailsAfterSave && context.mounted) {
        Navigator.of(context).pop();
      }
    }
  }
}

class _StudentFeeFilters extends StatelessWidget {
  const _StudentFeeFilters({
    required this.gradeLevels,
    required this.selectedGradeLevelId,
    required this.selectedPaymentStatus,
    required this.search,
    required this.termName,
    required this.onSearchChanged,
    required this.onGradeLevelChanged,
    required this.onPaymentStatusChanged,
  });

  final List<FeeGradeLevel> gradeLevels;
  final int? selectedGradeLevelId;
  final String? selectedPaymentStatus;
  final String search;
  final String termName;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<int?> onGradeLevelChanged;
  final ValueChanged<String?> onPaymentStatusChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        final searchWidth = compact
            ? constraints.maxWidth
            : constraints.maxWidth * .40;
        final filterWidth = compact
            ? constraints.maxWidth
            : (constraints.maxWidth - searchWidth - 20) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            SizedBox(
              width: searchWidth,
              child: TextFormField(
                key: ValueKey('student-fee-search-$search'),
                initialValue: search,
                onChanged: onSearchChanged,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search_rounded),
                  hintText: 'Search by name or ID',
                ),
              ),
            ),
            SizedBox(
              width: filterWidth,
              child: DropdownButtonFormField<int?>(
                value: selectedGradeLevelId,
                decoration: const InputDecoration(labelText: 'Class'),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('All classes'),
                  ),
                  ...gradeLevels.map(
                    (grade) => DropdownMenuItem<int?>(
                      value: grade.curriculumGradeLevelId,
                      child: Text(grade.name),
                    ),
                  ),
                ],
                onChanged: onGradeLevelChanged,
              ),
            ),
            SizedBox(
              width: filterWidth,
              child: DropdownButtonFormField<String?>(
                value: selectedPaymentStatus,
                decoration: InputDecoration(
                  labelText: 'Payment status · $termName',
                ),
                items: const [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text('All statuses'),
                  ),
                  DropdownMenuItem(value: 'NO_FEES', child: Text('No fees')),
                  DropdownMenuItem(value: 'UNPAID', child: Text('Unpaid')),
                  DropdownMenuItem(value: 'PARTIAL', child: Text('Partial')),
                  DropdownMenuItem(value: 'PAID', child: Text('Paid')),
                ],
                onChanged: onPaymentStatusChanged,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StudentNameCell extends StatelessWidget {
  const _StudentNameCell({required this.name, required this.id});

  final String name;
  final String id;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 3),
          Text(
            id,
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _PaymentStatus extends StatelessWidget {
  const _PaymentStatus({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase();
    final color = switch (normalized) {
      'paid' => AppColors.green,
      'partial' => AppColors.amber,
      _ => AppColors.red,
    };
    return Container(
      width: 150,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }
}

/// Household collection uses the same single-student form as fees and student profiles.
Future<bool?> showHouseholdFeeCollection({
  required BuildContext context,
  required FeeApiClient api,
  required String customSchoolId,
  required int householdId,
}) async {
  try {
    final term = await api.getCurrentTerm(customSchoolId);
    final options = await api.getHouseholdPaymentOptions(
      customSchoolId: customSchoolId,
      householdId: householdId,
      termId: term.id,
    );
    final methods = await api.getPaymentMethods();
    if (!context.mounted) return false;
    final students = options.students
        .map(
          (student) => _StudentFeeRow(
            name: student.studentName,
            id: student.customStudentId,
            className: '',
            totalFees: student.balance,
            paid: 0,
            balance: student.balance,
            status: '',
            lastPayment: '',
          ),
        )
        .toList();
    if (students.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This household has no students.')),
      );
      return false;
    }
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _RecordPaymentDialog(
        students: students,
        selectedStudent: students.length == 1 ? students.single : null,
        paymentMethods: methods,
        customSchoolId: customSchoolId,
        termId: term.id,
        api: api,
        money: (value) => 'GH₵ ${value.toStringAsFixed(2)}',
      ),
    );
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    }
    return false;
  }
}

class _RecordPaymentDialog extends StatefulWidget {
  const _RecordPaymentDialog({
    required this.students,
    required this.selectedStudent,
    required this.paymentMethods,
    required this.customSchoolId,
    required this.termId,
    required this.api,
    required this.money,
  });

  final List<_StudentFeeRow> students;
  final _StudentFeeRow? selectedStudent;
  final List<FeePaymentMethod> paymentMethods;
  final String customSchoolId;
  final int termId;
  final FeeApiClient api;
  final String Function(double amount) money;

  @override
  State<_RecordPaymentDialog> createState() => _RecordPaymentDialogState();
}

class _RecordPaymentDialogState extends State<_RecordPaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _studentController;
  late final TextEditingController _amountController;
  late final TextEditingController _momoReferenceController;
  late final TextEditingController _receiptController;
  late final TextEditingController _chequeNumberController;
  late final TextEditingController _chequeBankController;
  late final TextEditingController _notesController;
  _StudentFeeRow? _student;
  List<HouseholdPaymentItem> _feeItems = [];
  HouseholdPaymentItem? _feeItem;
  bool _loadingFees = false;
  String? _feeError;
  int _feeLoadVersion = 0;
  FeePaymentMethod? _method;
  DateTime _paymentDate = DateTime.now();
  DateTime _chequeDate = DateTime.now();
  bool _saving = false;
  bool _success = false;
  _PaymentReceipt? _receipt;
  PlatformFile? _receiptPhoto;
  late String _idempotencyKey = _newPaymentRequestKey();

  bool get _isScopedToStudent => widget.selectedStudent != null;
  bool get _isCheque =>
      (_method?.method.trim().toLowerCase() ?? '') == 'cheque';

  @override
  void initState() {
    super.initState();
    _student = widget.selectedStudent;
    _studentController = TextEditingController(
      text: _student == null ? '' : _student!.name,
    );
    _amountController = TextEditingController();
    _momoReferenceController = TextEditingController();
    _receiptController = TextEditingController();
    _chequeNumberController = TextEditingController();
    _chequeBankController = TextEditingController();
    _notesController = TextEditingController();
    _loadFeeItems();
  }

  @override
  void dispose() {
    _studentController.dispose();
    _amountController.dispose();
    _momoReferenceController.dispose();
    _receiptController.dispose();
    _chequeNumberController.dispose();
    _chequeBankController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final student = _student;
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    if (_success) {
      return AlertDialog(
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .78,
          ),
          child: SingleChildScrollView(
            child: SizedBox(
              width: 430,
              child: _PaymentSuccessView(
                receipt: _receipt!,
                onRecordAnother: _resetForAnotherPayment,
                onDone: () => Navigator.pop(context, true),
              ),
            ),
          ),
        ),
      );
    }

    return AlertDialog(
      title: const Text('Collect Fees'),
      titlePadding: const EdgeInsets.fromLTRB(28, 26, 28, 0),
      content: SizedBox(
        width: 520,
        child: AbsorbPointer(
          absorbing: _saving,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    student == null
                        ? 'Enter payment details below'
                        : 'Collecting fees from ${student.name}',
                    style: const TextStyle(color: AppColors.muted),
                  ),
                  if (_isScopedToStudent && student != null) ...[
                    const SizedBox(height: 18),
                    _PaymentStudentSummary(
                      student: student,
                      money: widget.money,
                    ),
                  ] else ...[
                    _PaymentSectionTitle('Student'),
                    TextFormField(
                      key: const ValueKey('payment-student-search'),
                      controller: _studentController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Student Name or ID',
                        hintText: 'Search by name or student ID...',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a student name or ID.';
                        }
                        return null;
                      },
                      onChanged: (value) {
                        final selected = _findExactStudent(value);
                        final changed = _student?.id != selected?.id;
                        setState(() {
                          _student = selected;
                          if (changed) _amountController.clear();
                        });
                        if (changed) {
                          _loadFeeItems();
                        }
                      },
                    ),
                    if (student == null)
                      _StudentSuggestions(
                        query: _studentController.text,
                        students: widget.students,
                        onSelected: _selectStudent,
                      ),
                    if (student != null) ...[
                      const SizedBox(height: 12),
                      _PaymentStudentSummary(
                        student: student,
                        money: widget.money,
                      ),
                    ],
                  ],
                  _PaymentSectionTitle('Payment Details'),
                  if (_loadingFees)
                    const LinearProgressIndicator()
                  else if (_feeError != null) ...[
                    Text(
                      _feeError!,
                      style: const TextStyle(color: AppColors.red),
                    ),
                    TextButton(
                      onPressed: _loadFeeItems,
                      child: const Text('Retry fee items'),
                    ),
                  ] else ...[
                    DropdownButtonFormField<int>(
                      key: ValueKey('payment-fee-item-$_feeLoadVersion'),
                      value: _feeItem?.assessmentId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Fee item *',
                        hintText: 'Select the fee being paid',
                      ),
                      items: _feeItems
                          .map(
                            (item) => DropdownMenuItem(
                              value: item.assessmentId,
                              child: Text(
                                '${item.feeName} · GH₵ ${item.outstandingAmount.toStringAsFixed(2)} due',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      validator: (_) => _feeItem == null
                          ? 'Select the fee item being paid.'
                          : null,
                      onChanged: _saving
                          ? null
                          : (id) => setState(() {
                              _feeItem = _feeItems.firstWhere(
                                (item) => item.assessmentId == id,
                              );
                              _amountController.clear();
                            }),
                    ),
                    if (student != null && _feeItems.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'No fee items available to pay. Fees may be unassessed, paid, or awaiting payment clearance.',
                        ),
                      ),
                  ],
                  const SizedBox(height: 14),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 560;
                      final width = compact
                          ? constraints.maxWidth
                          : (constraints.maxWidth - 14) / 2;
                      return Wrap(
                        spacing: 14,
                        runSpacing: 14,
                        children: [
                          SizedBox(
                            width: width,
                            child: _AmountEntryField(
                              controller: _amountController,
                              autofocus: _isScopedToStudent,
                              onChanged: () => setState(() {}),
                            ),
                          ),
                          SizedBox(
                            width: width,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: _pickDate,
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Payment date',
                                  suffixIcon: Icon(
                                    Icons.calendar_month_rounded,
                                  ),
                                ),
                                child: Text(_formatDate(_paymentDate)),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  if (student != null &&
                      _feeItem != null &&
                      amount > 0 &&
                      amount <= _feeItem!.outstandingAmount) ...[
                    const SizedBox(height: 16),
                    _BalanceAfterPaymentPreview(
                      currentBalance: student.balance,
                      amount: amount,
                      money: widget.money,
                      pending: _isCheque,
                    ),
                  ],
                  if (_feeItem != null &&
                      amount > _feeItem!.outstandingAmount) ...[
                    const SizedBox(height: 14),
                    const Text(
                      'Amount exceeds the selected fee item’s balance.',
                      style: TextStyle(color: AppColors.red),
                    ),
                  ],
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: _method == null ? null : '${_method!.id}',
                    decoration: const InputDecoration(
                      labelText: 'Payment Method',
                    ),
                    items: widget.paymentMethods
                        .map(
                          (method) => DropdownMenuItem(
                            value: '${method.id}',
                            child: Text(method.method),
                          ),
                        )
                        .toList(),
                    validator: (value) => value == null
                        ? 'Please select a payment method.'
                        : null,
                    onChanged: (value) => setState(() {
                      _method = widget.paymentMethods.firstWhere(
                        (method) => '${method.id}' == value,
                      );
                    }),
                  ),
                  if ((_method?.method.toLowerCase() ?? '').contains(
                        'mobile',
                      ) ||
                      (_method?.method.toLowerCase() ?? '').contains(
                        'momo',
                      )) ...[
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _momoReferenceController,
                      decoration: const InputDecoration(
                        labelText: 'MoMo Reference Number',
                        hintText: 'e.g. ABS1234567890',
                      ),
                    ),
                  ],
                  if (_isCheque) ...[
                    _PaymentSectionTitle('Cheque details'),
                    TextFormField(
                      controller: _chequeNumberController,
                      decoration: const InputDecoration(
                        labelText: 'Cheque number *',
                        hintText: 'Enter the number printed on the cheque',
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Please enter the cheque number.'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _chequeBankController,
                      decoration: const InputDecoration(
                        labelText: 'Bank *',
                        hintText: 'Bank that issued the cheque',
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Please enter the bank.'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: _pickChequeDate,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Cheque date *',
                          suffixIcon: Icon(Icons.calendar_month_rounded),
                        ),
                        child: Text(_formatDate(_chequeDate)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'The student balance will not change until this cheque is marked as cleared.',
                      style: TextStyle(
                        color: AppColors.amber,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ] else ...[
                    _PaymentSectionTitle('Receipt'),
                    TextFormField(
                      controller: _receiptController,
                      decoration: const InputDecoration(
                        labelText: 'Physical Receipt Number *',
                        hintText: 'e.g. REC-00421',
                        helperText:
                            'Enter the number from the paper receipt book',
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Please enter the physical receipt number.'
                          : null,
                    ),
                  ],
                  const SizedBox(height: 14),
                  _ReceiptPhotoField(
                    file: _receiptPhoto,
                    onChoose: _pickReceiptPhoto,
                    onRemove: () => setState(() => _receiptPhoto = null),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _notesController,
                    minLines: 2,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Notes (optional)',
                      hintText:
                          'e.g. Partial payment, balance to be paid next week...',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _saving || _loadingFees || _feeError != null
              ? null
              : _save,
          icon: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check_rounded),
          label: const Text('Save Payment'),
        ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _paymentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _paymentDate = picked);
  }

  Future<void> _pickChequeDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _chequeDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _chequeDate = picked);
  }

  Future<void> _pickReceiptPhoto() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const [
        'jpg',
        'jpeg',
        'png',
        'webp',
        'gif',
        'bmp',
        'pdf',
        'doc',
        'docx',
      ],
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty || !mounted) return;
    final file = result.files.single;
    if (file.bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not read the selected file.')),
      );
      return;
    }
    if (file.size > 5 * 1024 * 1024) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Receipt attachment must be 5 MB or smaller.'),
        ),
      );
      return;
    }
    setState(() => _receiptPhoto = file);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final student = _student;
    final method = _method;
    final fee = _feeItem;
    if (student == null ||
        method == null ||
        fee == null ||
        _loadingFees ||
        widget.termId <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select a student, payment method, and active term.'),
        ),
      );
      return;
    }
    final amount = double.parse(_amountController.text.trim());
    if (!amount.isFinite || amount > fee.outstandingAmount) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enter an amount within the selected fee item’s balance.',
          ),
          backgroundColor: AppColors.amber,
        ),
      );
      return;
    }
    final physicalReceipt = _receiptController.text.trim();
    setState(() => _saving = true);
    try {
      final receipt = await widget.api.recordPayment(
        FeePaymentRequest(
          assessmentId: fee.assessmentId,
          customStudentId: student.id,
          customSchoolId: widget.customSchoolId,
          payerName: student.name,
          amount: amount,
          paymentDate: _paymentDate,
          paymentMethodId: method.id,
          referenceNumber: _momoReferenceController.text.trim().isEmpty
              ? physicalReceipt
              : _momoReferenceController.text.trim(),
          receivedBy: 'School Admin',
          description: _notesController.text.trim(),
          termId: widget.termId,
          physicalReceiptNumber: physicalReceipt,
          receiptPhotoBytes: _receiptPhoto?.bytes,
          receiptPhotoFileName: _receiptPhoto?.name,
          chequeNumber: _isCheque ? _chequeNumberController.text.trim() : null,
          chequeBank: _isCheque ? _chequeBankController.text.trim() : null,
          chequeDate: _isCheque ? _chequeDate : null,
          idempotencyKey: _idempotencyKey,
        ),
      );
      if (!mounted) return;
      setState(() {
        _saving = false;
        _success = true;
        _receipt = _PaymentReceipt(
          receiptNumber: receipt.receiptNumber.trim().isEmpty
              ? physicalReceipt
              : receipt.receiptNumber,
          physicalReceiptNumber: physicalReceipt,
          studentName: receipt.studentName.trim().isEmpty
              ? student.name
              : receipt.studentName,
          className: student.className,
          feeName: fee.feeName,
          amount: receipt.amount == 0 ? amount : receipt.amount,
          paymentMethod: receipt.paymentMethod.trim().isEmpty
              ? method.method
              : receipt.paymentMethod,
          paymentDate: receipt.paymentDate ?? _paymentDate,
          remainingBalance: receipt.status == 'PENDING'
              ? (student.balance < 0 ? 0 : student.balance)
              : receipt.balance,
          creditBalance: receipt.status == 'PENDING'
              ? 0
              : receipt.creditBalance,
          overpaymentAmount: receipt.overpaymentAmount,
          pending: receipt.status == 'PENDING',
        );
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          backgroundColor: AppColors.red,
        ),
      );
    }
  }

  _StudentFeeRow? _findExactStudent(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    for (final student in widget.students) {
      if (student.name.toLowerCase() == normalized ||
          student.id.toLowerCase() == normalized) {
        return student;
      }
    }
    return null;
  }

  void _selectStudent(_StudentFeeRow student) {
    setState(() {
      _student = student;
      _studentController.text = student.name;
      _amountController.clear();
    });
    _loadFeeItems();
  }

  Future<void> _loadFeeItems() async {
    final version = ++_feeLoadVersion;
    final student = _student;
    setState(() {
      _feeItem = null;
      _feeItems = [];
      _feeError = null;
      _loadingFees = student != null;
    });
    if (student == null) return;
    try {
      final options = await widget.api.getStudentPaymentOptions(
        customSchoolId: widget.customSchoolId,
        customStudentId: student.id,
        termId: widget.termId,
      );
      if (!mounted || version != _feeLoadVersion) return;
      setState(() {
        _feeItems = options.items
            .where((item) => item.outstandingAmount > 0)
            .toList();
        _loadingFees = false;
      });
    } catch (error) {
      if (!mounted || version != _feeLoadVersion) return;
      setState(() {
        _feeError = 'Unable to load fee items. $error';
        _loadingFees = false;
      });
    }
  }

  void _resetForAnotherPayment() {
    setState(() {
      _success = false;
      _receipt = null;
      if (!_isScopedToStudent) {
        _student = null;
        _studentController.clear();
      }
      _amountController.clear();
      _method = null;
      _momoReferenceController.clear();
      _receiptController.clear();
      _chequeNumberController.clear();
      _chequeBankController.clear();
      _receiptPhoto = null;
      _notesController.clear();
      _paymentDate = DateTime.now();
      _chequeDate = DateTime.now();
      _idempotencyKey = _newPaymentRequestKey();
    });
    _loadFeeItems();
  }

  String _newPaymentRequestKey() =>
      'SCHOOL-PAYMENT-${DateTime.now().microsecondsSinceEpoch}';

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

class _PaymentReceipt {
  const _PaymentReceipt({
    required this.receiptNumber,
    required this.physicalReceiptNumber,
    required this.studentName,
    required this.className,
    required this.feeName,
    required this.amount,
    required this.paymentMethod,
    required this.paymentDate,
    required this.remainingBalance,
    required this.creditBalance,
    required this.overpaymentAmount,
    required this.pending,
  });

  final String receiptNumber;
  final String physicalReceiptNumber;
  final String studentName;
  final String className;
  final String feeName;
  final double amount;
  final String paymentMethod;
  final DateTime paymentDate;
  final double? remainingBalance;
  final double creditBalance;
  final double overpaymentAmount;
  final bool pending;
}

class _PaymentSectionTitle extends StatelessWidget {
  const _PaymentSectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 12),
      child: Row(
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: .7,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(child: Divider(color: AppColors.border)),
        ],
      ),
    );
  }
}

class _ReceiptPhotoField extends StatelessWidget {
  const _ReceiptPhotoField({
    required this.file,
    required this.onChoose,
    required this.onRemove,
  });

  final PlatformFile? file;
  final VoidCallback onChoose;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.greenSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.attach_file, color: AppColors.green),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file?.name ?? 'Physical receipt (optional)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  file == null
                      ? 'Images, PDF, DOC or DOCX · up to 5 MB.'
                      : '${(file!.size / 1024).ceil()} KB selected',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (file != null)
            IconButton(
              tooltip: 'Remove receipt attachment',
              onPressed: onRemove,
              icon: const Icon(Icons.close_rounded),
            ),
          OutlinedButton.icon(
            onPressed: onChoose,
            icon: Icon(file == null ? Icons.attach_file : Icons.swap_horiz),
            label: Text(file == null ? 'Attach' : 'Replace'),
          ),
        ],
      ),
    );
  }
}

class _StudentSuggestions extends StatelessWidget {
  const _StudentSuggestions({
    required this.query,
    required this.students,
    required this.onSelected,
  });

  final String query;
  final List<_StudentFeeRow> students;
  final ValueChanged<_StudentFeeRow> onSelected;

  @override
  Widget build(BuildContext context) {
    final q = query.trim().toLowerCase();
    if (q.length < 2) return const SizedBox.shrink();
    final matches = students
        .where(
          (student) =>
              student.name.toLowerCase().contains(q) ||
              student.id.toLowerCase().contains(q),
        )
        .take(5)
        .toList();
    if (matches.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 4),
      constraints: const BoxConstraints(maxHeight: 190),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: matches.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final student = matches[index];
          return ListTile(
            dense: true,
            title: Text(
              student.name,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            subtitle: Text(
              '${student.className} · ${student.id} · Balance: ${_moneyShort(student.balance)}',
            ),
            onTap: () => onSelected(student),
          );
        },
      ),
    );
  }

  String _moneyShort(double amount) => 'GH₵ ${amount.toStringAsFixed(0)}';
}

class _AmountEntryField extends StatelessWidget {
  const _AmountEntryField({
    required this.controller,
    required this.autofocus,
    required this.onChanged,
  });

  final TextEditingController controller;
  final bool autofocus;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: const ValueKey('payment-amount'),
      controller: controller,
      autofocus: autofocus,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
      decoration: InputDecoration(
        labelText: 'Amount to Collect (GH₵)',
        hintText: 'Enter amount',
        prefixText: 'GH₵ ',
        prefixStyle: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w900,
          color: AppColors.text,
        ),
        filled: true,
        fillColor: AppColors.greenSoft,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.green.withValues(alpha: .22)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.green, width: 1.4),
        ),
      ),
      onChanged: (_) => onChanged(),
      validator: (value) {
        final amount = double.tryParse(value?.trim() ?? '');
        if (amount == null ||
            !amount.isFinite ||
            amount <= 0 ||
            !RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(value!.trim())) {
          return 'Enter a positive amount with up to 2 decimal places';
        }
        return null;
      },
    );
  }
}

class _BalanceAfterPaymentPreview extends StatelessWidget {
  const _BalanceAfterPaymentPreview({
    required this.currentBalance,
    required this.amount,
    required this.money,
    required this.pending,
  });

  final double currentBalance;
  final double amount;
  final String Function(double amount) money;
  final bool pending;

  @override
  Widget build(BuildContext context) {
    final projected = currentBalance - amount;
    final remaining = pending
        ? currentBalance.clamp(0, double.infinity).toDouble()
        : projected.clamp(0, double.infinity).toDouble();
    final projectedCredit = (-projected).clamp(0, double.infinity).toDouble();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAF9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pending
                      ? 'Balance while cheque is pending'
                      : 'Balance after this payment',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  currentBalance < 0
                      ? 'Current credit ${money(currentBalance.abs())}'
                      : 'Current balance ${money(currentBalance)}',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                money(remaining),
                style: TextStyle(
                  color: remaining <= 0 ? AppColors.green : AppColors.amber,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (projectedCredit > 0) ...[
                const SizedBox(height: 3),
                Text(
                  '${pending ? 'Credit if cleared' : 'Credit'} ${money(projectedCredit)}',
                  style: const TextStyle(
                    color: AppColors.green,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _PaymentSuccessView extends StatelessWidget {
  const _PaymentSuccessView({
    required this.receipt,
    required this.onRecordAnother,
    required this.onDone,
  });

  final _PaymentReceipt receipt;
  final VoidCallback onRecordAnother;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    String formatDate(DateTime date) {
      const months = [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ];
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.greenSoft,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.green.withValues(alpha: .35)),
            ),
            child: const Icon(
              Icons.check_rounded,
              color: AppColors.green,
              size: 36,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            receipt.pending ? 'Cheque Recorded' : 'Payment Receipt Created',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            receipt.pending
                ? 'Pending reference ${receipt.receiptNumber}'
                : 'Receipt ${receipt.receiptNumber}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.green,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 18),
          if (receipt.pending) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.amber.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Awaiting bank clearance. This is not an official payment receipt and the student balance has not changed.',
                style: TextStyle(
                  color: AppColors.amber,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAF9),
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                _ReceiptLine(label: 'Student', value: receipt.studentName),
                _ReceiptLine(label: 'Class', value: receipt.className),
                _ReceiptLine(label: 'Fee item', value: receipt.feeName),
                _ReceiptLine(
                  label: receipt.pending ? 'Amount presented' : 'Amount paid',
                  value: _money(receipt.amount),
                  highlight: true,
                ),
                _ReceiptLine(label: 'Method', value: receipt.paymentMethod),
                _ReceiptLine(
                  label: 'Payment date',
                  value: formatDate(receipt.paymentDate),
                ),
                if (receipt.physicalReceiptNumber.trim().isNotEmpty)
                  _ReceiptLine(
                    label: 'Physical receipt',
                    value: receipt.physicalReceiptNumber,
                  ),
                if (receipt.remainingBalance != null)
                  _ReceiptLine(
                    label: receipt.pending
                        ? 'Balance while pending'
                        : 'Balance after payment',
                    value: _money(receipt.remainingBalance!),
                  ),
                if (receipt.creditBalance > 0)
                  _ReceiptLine(
                    label: 'Credit balance',
                    value: _money(receipt.creditBalance),
                    highlight: true,
                  ),
                if (receipt.overpaymentAmount > 0)
                  _ReceiptLine(
                    label: receipt.pending
                        ? 'Excess if cleared'
                        : 'Overpayment accepted',
                    value: _money(receipt.overpaymentAmount),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          if (!receipt.pending) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Receipt preview and print will be connected to the receipt API.',
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.print_rounded, size: 18),
                    label: const Text('Print receipt'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Receipt sharing will be connected to SMS/email later.',
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.ios_share_rounded, size: 18),
                    label: const Text('Share'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onRecordAnother,
                  child: const Text('Record another'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: onDone,
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _money(double amount) {
    final value = amount % 1 == 0
        ? amount.toStringAsFixed(0)
        : amount.toStringAsFixed(2);
    return 'GH₵ $value';
  }
}

class _ReceiptLine extends StatelessWidget {
  const _ReceiptLine({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.muted,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: highlight ? AppColors.green : AppColors.text,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentStudentSummary extends StatelessWidget {
  const _PaymentStudentSummary({required this.student, required this.money});

  final _StudentFeeRow student;
  final String Function(double amount) money;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.greenSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.name,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  student.balance < 0
                      ? '${student.id}${student.className.isEmpty ? '' : ' · ${student.className}'} · Credit ${money(student.balance.abs())}'
                      : '${student.id}${student.className.isEmpty ? '' : ' · ${student.className}'} · Balance ${money(student.balance)}',
                  style: const TextStyle(color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StudentFeeDetailPanel extends StatelessWidget {
  const _StudentFeeDetailPanel({
    required this.row,
    required this.money,
    required this.api,
    required this.customSchoolId,
    required this.termId,
    required this.currentUserId,
    required this.onRecordPayment,
    required this.onAssignWaiver,
  });

  final _StudentFeeRow row;
  final String Function(double amount) money;
  final FeeApiClient api;
  final String customSchoolId;
  final int termId;
  final int currentUserId;
  final VoidCallback onRecordPayment;
  final VoidCallback onAssignWaiver;

  @override
  Widget build(BuildContext context) {
    final initials = row.name
        .split(RegExp(r'\s+'))
        .where((part) => part.trim().isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();
    return Material(
      color: Colors.white,
      child: SizedBox(
        width: 430,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(22),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.green,
                      child: Text(
                        initials.isEmpty ? '-' : initials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            row.name,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${row.className} · ${row.id}',
                            style: const TextStyle(color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                      tooltip: 'Close',
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: FutureBuilder<FeeStudentAccount>(
                  future: api.getStudentFeeAccount(
                    customSchoolId: customSchoolId,
                    customStudentId: row.id,
                    academicTermId: termId,
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Padding(
                        padding: EdgeInsets.all(22),
                        child: _InlineLoadingState(
                          message: 'Loading student fee account...',
                        ),
                      );
                    }
                    if (snapshot.hasError || snapshot.data == null) {
                      return Padding(
                        padding: const EdgeInsets.all(22),
                        child: _FeeEmptyCard(
                          message:
                              'Could not load this fee account: ${snapshot.error ?? 'No data returned'}',
                        ),
                      );
                    }
                    final account = snapshot.data!;
                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _StudentFeeTotalCard(
                                  label: 'Expected',
                                  value: money(account.totalExpected),
                                  color: AppColors.text,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _StudentFeeTotalCard(
                                  label: 'Paid',
                                  value: money(account.totalPaid),
                                  color: AppColors.green,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _StudentFeeTotalCard(
                                  label: account.balance < 0
                                      ? 'Credit'
                                      : 'Balance',
                                  value: money(account.balance.abs()),
                                  color: account.balance > 0
                                      ? AppColors.red
                                      : AppColors.green,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          _FeeBreakdownSection(account: account, money: money),
                          const SizedBox(height: 18),
                          if (account.payments.isEmpty)
                            const _FeeEmptyCard(
                              message: 'No payments recorded for this student.',
                            )
                          else
                            _PaymentHistorySection(
                              payments: account.payments
                                  .map(_historyFromPayment)
                                  .toList(),
                              money: money,
                              api: api,
                              customSchoolId: customSchoolId,
                              currentUserId: currentUserId,
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: onRecordPayment,
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Collect Fees'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: onAssignWaiver,
                            icon: const Icon(Icons.savings_outlined),
                            label: const Text('Assign waiver or discount'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {},
                            icon: const Icon(Icons.print_outlined),
                            label: const Text('Print Statement'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _StudentPaymentHistory _historyFromPayment(FeeStudentPayment payment) {
    return _StudentPaymentHistory(
      id: payment.id,
      status: payment.status,
      method: payment.paymentMethod.trim().isEmpty
          ? 'Payment'
          : payment.paymentMethod,
      receiptNumber: payment.referenceNumber.trim().isEmpty
          ? 'PAY-${payment.id}'
          : payment.referenceNumber,
      amount: payment.netAmount,
      date: _formatDateLabel(payment.paymentDate),
      term: payment.termId > 0 ? 'Term ${payment.termId}' : 'Current term',
      recordedBy: payment.receivedBy.trim().isEmpty
          ? 'School staff'
          : payment.receivedBy,
      statusReason: payment.statusReason,
      chequeNumber: payment.chequeNumber,
      chequeBank: payment.chequeBank,
      chequeDate: payment.chequeDate,
      overpaymentAmount: payment.overpaymentAmount,
      overpaymentReason: payment.overpaymentReason,
    );
  }
}

class _InlineLoadingState extends StatelessWidget {
  const _InlineLoadingState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAF9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.muted),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeeBreakdownSection extends StatelessWidget {
  const _FeeBreakdownSection({required this.account, required this.money});

  final FeeStudentAccount account;
  final String Function(double amount) money;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: false,
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
        title: const Text(
          'Fee Details',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(
          '${account.assessments.length} fee items · ${money(account.totalExpected)} expected',
          style: const TextStyle(color: AppColors.muted),
        ),
        children: [
          if (account.assessments.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 14),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'No fee assessments exist for this student in this term.',
                  style: TextStyle(color: AppColors.muted),
                ),
              ),
            )
          else
            ...account.assessments.map(
              (item) => _FeeAssessmentRow(item: item, money: money),
            ),
          if (account.adjustments.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.only(top: 14, bottom: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'ADJUSTMENTS',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .5,
                  ),
                ),
              ),
            ),
            ...account.adjustments.map(
              (adjustment) =>
                  _FeeAdjustmentRow(adjustment: adjustment, money: money),
            ),
          ],
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Expected this term',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                Text(
                  money(account.totalExpected),
                  style: const TextStyle(
                    color: AppColors.green,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StudentFeeTotalCard extends StatelessWidget {
  const _StudentFeeTotalCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAF9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: .4,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeeAssessmentRow extends StatelessWidget {
  const _FeeAssessmentRow({required this.item, required this.money});

  final FeeAssessmentLine item;
  final String Function(double amount) money;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.feeName,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                if (item.categoryName.trim().isNotEmpty ||
                    item.dueDate != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    [
                      if (item.categoryName.trim().isNotEmpty)
                        item.categoryName.trim(),
                      if (item.dueDate != null)
                        'Due ${_formatDateLabel(item.dueDate)}',
                    ].join(' · '),
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Text(
            money(item.amount),
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _FeeAdjustmentRow extends StatelessWidget {
  const _FeeAdjustmentRow({required this.adjustment, required this.money});

  final FeeAccountAdjustment adjustment;
  final String Function(double amount) money;

  @override
  Widget build(BuildContext context) {
    final status = adjustment.status.trim().toUpperCase();
    final affectsBalance =
        status == 'APPROVED' || status == 'COMPLETE' || status == 'COMPLETED';
    final title = adjustment.feeName.trim().isEmpty
        ? adjustment.adjustmentType
        : '${adjustment.adjustmentType} · ${adjustment.feeName}';
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                if (adjustment.description.trim().isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    adjustment.description,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${adjustment.amount >= 0 ? '+' : '-'}${money(adjustment.amount.abs())}',
                style: TextStyle(
                  color: adjustment.amount < 0
                      ? AppColors.green
                      : AppColors.text,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: affectsBalance
                      ? AppColors.greenSoft
                      : const Color(0xFFFFF3DF),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  status.isEmpty ? 'PENDING' : status.replaceAll('_', ' '),
                  style: TextStyle(
                    color: affectsBalance
                        ? AppColors.green
                        : const Color(0xFFB66A00),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PaymentHistorySection extends StatelessWidget {
  const _PaymentHistorySection({
    required this.payments,
    required this.money,
    required this.api,
    required this.customSchoolId,
    required this.currentUserId,
  });

  final List<_StudentPaymentHistory> payments;
  final String Function(double amount) money;
  final FeeApiClient api;
  final String customSchoolId;
  final int currentUserId;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Payment History',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            Text(
              '${payments.length} payment${payments.length == 1 ? '' : 's'}',
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (payments.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAF9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: const Text(
              'No payments recorded for this student yet.',
              style: TextStyle(color: AppColors.muted),
            ),
          )
        else
          ...payments.map(
            (payment) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _PaymentHistoryTile(
                payment: payment,
                money: money,
                api: api,
                customSchoolId: customSchoolId,
                currentUserId: currentUserId,
              ),
            ),
          ),
      ],
    );
  }
}

class _PaymentHistoryTile extends StatefulWidget {
  const _PaymentHistoryTile({
    required this.payment,
    required this.money,
    required this.api,
    required this.customSchoolId,
    required this.currentUserId,
  });

  final _StudentPaymentHistory payment;
  final String Function(double amount) money;
  final FeeApiClient api;
  final String customSchoolId;
  final int currentUserId;

  @override
  State<_PaymentHistoryTile> createState() => _PaymentHistoryTileState();
}

class _PaymentHistoryTileState extends State<_PaymentHistoryTile> {
  late Future<List<PaymentReversal>> _reversals;
  late String _status;
  late String _statusReason;
  late String _referenceNumber;
  bool _updating = false;

  @override
  void initState() {
    super.initState();
    _status = widget.payment.status.toUpperCase();
    _statusReason = widget.payment.statusReason;
    _referenceNumber = widget.payment.receiptNumber;
    _reload();
  }

  Future<void> _changeChequeStatus({required bool clear}) async {
    final reason = TextEditingController();
    String? validationError;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(clear ? 'Mark cheque as cleared' : 'Reject cheque'),
          content: SizedBox(
            width: 430,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  clear
                      ? 'Confirm that the bank has cleared cheque ${widget.payment.chequeNumber}.'
                      : 'The balance will remain unchanged and this cheque will stay in the audit history.',
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: reason,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: clear
                        ? 'Clearance note *'
                        : 'Rejection reason *',
                    hintText: clear
                        ? 'e.g. Cleared on bank statement'
                        : 'e.g. Returned unpaid by bank',
                    errorText: validationError,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (reason.text.trim().length < 5) {
                  setDialogState(
                    () => validationError = 'Enter at least 5 characters.',
                  );
                  return;
                }
                Navigator.pop(dialogContext, true);
              },
              style: clear
                  ? null
                  : FilledButton.styleFrom(backgroundColor: AppColors.red),
              child: Text(clear ? 'Confirm clearance' : 'Reject cheque'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) {
      reason.dispose();
      return;
    }
    setState(() => _updating = true);
    try {
      final updated = clear
          ? await widget.api.clearPendingPayment(
              paymentId: widget.payment.id,
              notes: reason.text,
            )
          : await widget.api.rejectPendingPayment(
              paymentId: widget.payment.id,
              reason: reason.text,
            );
      if (!mounted) return;
      setState(() {
        _updating = false;
        _status = updated.status.toUpperCase();
        _statusReason = updated.statusReason;
        if (updated.referenceNumber.trim().isNotEmpty) {
          _referenceNumber = updated.referenceNumber;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            clear
                ? 'Cheque cleared. The balance and official receipt are now available.'
                : 'Cheque rejected. The student balance was not changed.',
          ),
          backgroundColor: clear ? AppColors.green : AppColors.red,
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(() => _updating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$error'), backgroundColor: AppColors.red),
        );
      }
    } finally {
      reason.dispose();
    }
  }

  void _reload() {
    _reversals = widget.api.getPaymentReversals(
      customSchoolId: widget.customSchoolId,
      paymentId: widget.payment.id,
    );
  }

  Future<void> _openReversal([PaymentReversal? existing]) async {
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PaymentReversalDialog(
        api: widget.api,
        customSchoolId: widget.customSchoolId,
        payment: widget.payment,
        existing: existing,
        currentUserId: widget.currentUserId,
      ),
    );
    if (changed == true && mounted) setState(_reload);
  }

  @override
  Widget build(BuildContext context) {
    final payment = widget.payment;
    final money = widget.money;
    final reversed = _status == 'REVERSED';
    final pendingCheque = _status == 'PENDING' && payment.isCheque;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.greenSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  size: 18,
                  color: AppColors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      payment.method,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$_referenceNumber · ${payment.term} · ${payment.recordedBy}',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    money(payment.amount),
                    style: TextStyle(
                      color: reversed ? AppColors.red : AppColors.green,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    payment.date,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              if (!reversed && !pendingCheque && _status == 'COMPLETED')
                IconButton(
                  key: Key('reverse-payment-${payment.id}'),
                  tooltip: 'Request reversal',
                  onPressed: () => _openReversal(),
                  icon: const Icon(Icons.undo_rounded, color: AppColors.red),
                ),
            ],
          ),
          if (payment.isCheque) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${payment.chequeBank} · Cheque ${payment.chequeNumber}${payment.chequeDate == null ? '' : ' · ${_formatDateLabel(payment.chequeDate)}'}',
                style: const TextStyle(color: AppColors.muted, fontSize: 11),
              ),
            ),
          ],
          if (payment.overpaymentAmount > 0) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.amber.withValues(alpha: .09),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Overpayment ${money(payment.overpaymentAmount)} · ${payment.overpaymentReason}',
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
          if (pendingCheque) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'PENDING CLEARANCE · Balance unchanged',
                    style: TextStyle(
                      color: AppColors.amber,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                OutlinedButton(
                  onPressed: _updating
                      ? null
                      : () => _changeChequeStatus(clear: false),
                  child: const Text('Reject'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _updating
                      ? null
                      : () => _changeChequeStatus(clear: true),
                  child: const Text('Mark cleared'),
                ),
              ],
            ),
          ],
          if (_status == 'FAILED')
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'REJECTED · ${_statusReason.isEmpty ? 'Cheque did not clear.' : _statusReason}',
                  style: const TextStyle(
                    color: AppColors.red,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          if (reversed)
            const Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'REVERSED · The original receipt remains in the audit trail.',
                  style: TextStyle(
                    color: AppColors.red,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          FutureBuilder<List<PaymentReversal>>(
            future: _reversals,
            builder: (context, snapshot) {
              final rows = snapshot.data ?? const <PaymentReversal>[];
              if (rows.isEmpty) return const SizedBox.shrink();
              final latest = rows.first;
              return InkWell(
                key: Key('payment-reversal-${payment.id}'),
                onTap: () => _openReversal(latest),
                child: Container(
                  margin: const EdgeInsets.only(top: 10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: latest.status == 'PENDING_APPROVAL'
                        ? AppColors.amber.withValues(alpha: .10)
                        : const Color(0xFFF8FAF9),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.assignment_return_outlined, size: 17),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${latest.status.replaceAll('_', ' ')} · ${latest.approverName.isEmpty ? 'No approver selected' : latest.approverName}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, size: 18),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PaymentReversalDialog extends StatefulWidget {
  const _PaymentReversalDialog({
    required this.api,
    required this.customSchoolId,
    required this.payment,
    required this.currentUserId,
    this.existing,
  });

  final FeeApiClient api;
  final String customSchoolId;
  final _StudentPaymentHistory payment;
  final int currentUserId;
  final PaymentReversal? existing;

  @override
  State<_PaymentReversalDialog> createState() => _PaymentReversalDialogState();
}

class _PaymentReversalDialogState extends State<_PaymentReversalDialog> {
  late final TextEditingController _reason;
  late final TextEditingController _actionReason;
  late Future<List<FeeAdjustmentApprover>> _approvers;
  int? _approverId;
  bool _saving = false;
  String? _error;

  bool get _requester =>
      widget.existing?.requestedBy == '${widget.currentUserId}';
  bool get _approver =>
      !_requester && widget.existing?.approverId == widget.currentUserId;
  bool get _canSelectApprover => widget.existing == null || _requester;

  @override
  void initState() {
    super.initState();
    _reason = TextEditingController(text: widget.existing?.reason ?? '');
    _actionReason = TextEditingController();
    _approverId = widget.existing?.approverId == 0
        ? null
        : widget.existing?.approverId;
    _approvers = widget.api.getFeeAdjustmentApprovers(widget.customSchoolId);
  }

  @override
  void dispose() {
    _reason.dispose();
    _actionReason.dispose();
    super.dispose();
  }

  Future<void> _create(bool submit) async {
    if (_reason.text.trim().length < 10) {
      setState(
        () => _error = 'Enter a reversal reason of at least 10 characters.',
      );
      return;
    }
    if (submit && _approverId == null) {
      setState(
        () => _error = 'Select an approver or save the reversal as a draft.',
      );
      return;
    }
    await _run(
      () => widget.api.createPaymentReversal(
        customSchoolId: widget.customSchoolId,
        paymentId: widget.payment.id,
        reason: _reason.text,
        approverId: _approverId,
        submitForApproval: submit,
      ),
    );
  }

  Future<void> _action(String action) async {
    final reasonRequired = const {
      'CANCEL',
      'REASSIGN',
      'REJECT',
    }.contains(action);
    if (reasonRequired && _actionReason.text.trim().length < 5) {
      setState(
        () =>
            _error = 'Enter a reason of at least 5 characters for this action.',
      );
      return;
    }
    if ((action == 'SUBMIT' || action == 'REASSIGN') && _approverId == null) {
      setState(() => _error = 'Select an approver first.');
      return;
    }
    await _run(
      () => widget.api.performPaymentReversalAction(
        customSchoolId: widget.customSchoolId,
        reversalId: widget.existing!.id,
        action: action,
        reason: _actionReason.text.trim().isEmpty
            ? 'Approved'
            : _actionReason.text,
        approverId: _approverId,
      ),
    );
  }

  Future<void> _run(Future<PaymentReversal> Function() operation) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await operation();
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = '$error';
        });
      }
    }
  }

  Future<void> _downloadConfirmation() async {
    final reversal = widget.existing!;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final bytes = await widget.api.downloadPaymentReversalConfirmation(
        customSchoolId: widget.customSchoolId,
        reversalId: reversal.id,
      );
      final reference = reversal.reversalReference.trim().isEmpty
          ? 'payment-reversal-${reversal.id}'
          : reversal.reversalReference.trim();
      final downloaded = await downloadReportPdf('$reference.pdf', bytes);
      if (!downloaded) {
        throw const FeeApiException(
          'The confirmation could not be downloaded.',
        );
      }
      if (mounted) setState(() => _saving = false);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = '$error';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.existing;
    final active = existing?.isActive ?? true;
    return AlertDialog(
      title: Text(
        existing == null ? 'Request payment reversal' : 'Reversal request',
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.red.withValues(alpha: .07),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${widget.payment.receiptNumber} · ${widget.payment.moneyLabel}\nThe original receipt will be retained and marked Reversed after approval.',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 16),
              if (existing != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color:
                        (existing.status == 'APPROVED'
                                ? AppColors.green
                                : AppColors.amber)
                            .withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    existing.status.replaceAll('_', ' '),
                    style: TextStyle(
                      color: existing.status == 'APPROVED'
                          ? AppColors.green
                          : AppColors.amber,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (existing.reversalReference.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Reversal reference: ${existing.reversalReference}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
                const SizedBox(height: 14),
              ],
              TextField(
                key: const Key('payment-reversal-reason'),
                controller: _reason,
                enabled: existing == null,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Reason for reversal *',
                  alignLabelWithHint: true,
                ),
              ),
              if (active) ...[
                const SizedBox(height: 14),
                FutureBuilder<List<FeeAdjustmentApprover>>(
                  future: _approvers,
                  builder: (context, snapshot) {
                    final approvers =
                        (snapshot.data ?? const <FeeAdjustmentApprover>[])
                            .where(
                              (item) =>
                                  !_canSelectApprover ||
                                  item.id != widget.currentUserId,
                            )
                            .toList();
                    return DropdownButtonFormField<int>(
                      key: const Key('payment-reversal-approver'),
                      value: approvers.any((item) => item.id == _approverId)
                          ? _approverId
                          : null,
                      decoration: const InputDecoration(labelText: 'Approver'),
                      items: approvers
                          .map(
                            (item) => DropdownMenuItem(
                              value: item.id,
                              child: Text('${item.name} · ${item.role}'),
                            ),
                          )
                          .toList(),
                      onChanged: _saving || !_canSelectApprover
                          ? null
                          : (value) => setState(() => _approverId = value),
                    );
                  },
                ),
              ],
              if (existing != null && active) ...[
                const SizedBox(height: 14),
                TextField(
                  controller: _actionReason,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Action reason',
                    alignLabelWithHint: true,
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(
                    color: AppColors.red,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Close'),
        ),
        if (existing == null) ...[
          OutlinedButton(
            key: const Key('save-reversal-draft'),
            onPressed: _saving ? null : () => _create(false),
            child: const Text('Save draft'),
          ),
          FilledButton(
            key: const Key('submit-reversal'),
            onPressed: _saving ? null : () => _create(true),
            child: const Text('Submit for approval'),
          ),
        ] else if (existing.status == 'DRAFT' && _requester) ...[
          OutlinedButton(
            onPressed: _saving ? null : () => _action('CANCEL'),
            child: const Text('Cancel request'),
          ),
          FilledButton(
            onPressed: _saving ? null : () => _action('SUBMIT'),
            child: const Text('Submit for approval'),
          ),
        ] else if (existing.status == 'PENDING_APPROVAL') ...[
          if (_requester) ...[
            OutlinedButton(
              onPressed: _saving ? null : () => _action('CANCEL'),
              child: const Text('Cancel request'),
            ),
            OutlinedButton(
              onPressed: _saving ? null : () => _action('REASSIGN'),
              child: const Text('Change approver'),
            ),
          ],
          if (_approver) ...[
            OutlinedButton(
              onPressed: _saving ? null : () => _action('REJECT'),
              child: const Text('Reject'),
            ),
            FilledButton(
              key: const Key('approve-reversal'),
              onPressed: _saving ? null : () => _action('APPROVE'),
              child: const Text('Approve reversal'),
            ),
          ],
        ] else if (existing.status == 'APPROVED') ...[
          FilledButton.icon(
            key: const Key('download-reversal-confirmation'),
            onPressed: _saving ? null : _downloadConfirmation,
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('Download confirmation'),
          ),
        ],
      ],
    );
  }
}

extension on _StudentPaymentHistory {
  String get moneyLabel => 'GH₵${amount.toStringAsFixed(2)}';
}

class _StudentPaymentHistory {
  const _StudentPaymentHistory({
    required this.id,
    required this.status,
    required this.method,
    required this.receiptNumber,
    required this.amount,
    required this.date,
    required this.term,
    required this.recordedBy,
    required this.statusReason,
    required this.chequeNumber,
    required this.chequeBank,
    required this.chequeDate,
    required this.overpaymentAmount,
    required this.overpaymentReason,
  });

  final int id;
  final String status;
  final String method;
  final String receiptNumber;
  final double amount;
  final String date;
  final String term;
  final String recordedBy;
  final String statusReason;
  final String chequeNumber;
  final String chequeBank;
  final DateTime? chequeDate;
  final double overpaymentAmount;
  final String overpaymentReason;

  bool get isCheque => method.trim().toLowerCase() == 'cheque';
}

class _StudentFeeRow {
  const _StudentFeeRow({
    required this.name,
    required this.id,
    required this.className,
    required this.totalFees,
    required this.paid,
    required this.balance,
    required this.status,
    required this.lastPayment,
  });

  final String name;
  final String id;
  final String className;
  final double totalFees;
  final double paid;
  final double balance;
  final String status;
  final String lastPayment;
}

class _WaiversContent extends StatefulWidget {
  const _WaiversContent({
    required this.types,
    required this.assignments,
    required this.money,
    required this.onAddType,
    required this.onEditType,
    required this.onDeleteType,
    required this.onAssignWaiver,
    required this.onEditAssignment,
    required this.onRevokeAssignment,
    required this.onWorkflowAction,
    required this.onOpenStudent,
  });

  final List<FeeWaiverType> types;
  final List<FeeWaiverAssignment> assignments;
  final String Function(double amount) money;
  final VoidCallback onAddType;
  final ValueChanged<FeeWaiverType> onEditType;
  final ValueChanged<FeeWaiverType> onDeleteType;
  final VoidCallback onAssignWaiver;
  final ValueChanged<FeeWaiverAssignment> onEditAssignment;
  final ValueChanged<FeeWaiverAssignment> onRevokeAssignment;
  final Future<void> Function(FeeWaiverAssignment, String) onWorkflowAction;
  final ValueChanged<String>? onOpenStudent;

  @override
  State<_WaiversContent> createState() => _WaiversContentState();
}

class _WaiversContentState extends State<_WaiversContent> {
  final _searchController = TextEditingController();
  var _selectedView = 0;
  var _studentSortColumnIndex = 0;
  var _studentSortAscending = true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeAssignments = widget.assignments
        .where((item) => item.status == 'ACTIVE')
        .toList(growable: false);
    final pendingAssignments = widget.assignments
        .where((item) => _isPendingWaiverStatus(item.status))
        .toList(growable: false);
    final activeStudentCount = activeAssignments
        .map((item) => item.customStudentId)
        .toSet()
        .length;
    final totalWaived = activeAssignments.fold<double>(
      0,
      (total, item) => total + item.waivedAmount,
    );
    final query = _searchController.text.trim().toLowerCase();
    final studentRows = _sortedStudents(
      _studentWaiverRows(
        widget.assignments,
      ).where((item) => item.matches(query)).toList(),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final title = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Waivers & Discounts',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Manage financial support types and review the students receiving them.',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            );
            final actions = Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: widget.onAssignWaiver,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Assign waiver or discount'),
                ),
              ],
            );
            if (constraints.maxWidth < 760) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [title, const SizedBox(height: 14), actions],
              );
            }
            return Row(
              children: [
                Expanded(child: title),
                const SizedBox(width: 16),
                actions,
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = constraints.maxWidth >= 800
                ? (constraints.maxWidth - 24) / 3
                : constraints.maxWidth >= 500
                ? (constraints.maxWidth - 12) / 2
                : constraints.maxWidth;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: cardWidth,
                  child: _WaiverMetricCard(
                    key: const Key('waiver-summary-total'),
                    label: 'Total waiver value',
                    value: widget.money(totalWaived),
                    caption: 'Active waivers this term',
                    icon: Icons.savings_outlined,
                    color: AppColors.green,
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _WaiverMetricCard(
                    key: const Key('waiver-summary-students'),
                    label: 'Students receiving support',
                    value: '$activeStudentCount',
                    caption: 'Students currently covered',
                    icon: Icons.school_outlined,
                    color: AppColors.blue,
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _WaiverMetricCard(
                    key: const Key('waiver-summary-pending'),
                    label: 'Support requests pending',
                    value: '${pendingAssignments.length}',
                    caption: 'Awaiting a decision',
                    icon: Icons.hourglass_top_rounded,
                    color: AppColors.amber,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _WaiverViewTab(
                      key: const Key('waiver-view-waivers'),
                      selected: _selectedView == 0,
                      label: 'Waiver & discount types',
                      count: widget.types.length,
                      onTap: () => setState(() => _selectedView = 0),
                    ),
                    _WaiverViewTab(
                      key: const Key('waiver-view-students'),
                      selected: _selectedView == 1,
                      label: 'Students on waivers & discounts',
                      count: _studentWaiverRows(widget.assignments).length,
                      onTap: () => setState(() => _selectedView = 1),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(18),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final search = SizedBox(
                      width: constraints.maxWidth < 520
                          ? constraints.maxWidth
                          : 420,
                      child: TextField(
                        key: const Key('waiver-search'),
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: _selectedView == 0
                              ? 'Search waiver or discount type'
                              : 'Search student, ID or class',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: _searchController.text.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Clear search',
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {});
                                  },
                                  icon: const Icon(Icons.close_rounded),
                                ),
                        ),
                      ),
                    );
                    final count = Text(
                      _selectedView == 0
                          ? '${_matchingTypes(query).length} ${_matchingTypes(query).length == 1 ? 'type' : 'types'}'
                          : '${studentRows.length} ${studentRows.length == 1 ? 'student' : 'students'}',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontWeight: FontWeight.w800,
                      ),
                    );
                    if (constraints.maxWidth < 620) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [search, const SizedBox(height: 10), count],
                      );
                    }
                    return Row(children: [search, const Spacer(), count]);
                  },
                ),
              ),
              if (_selectedView == 0)
                _WaiverTypesList(
                  types: _matchingTypes(query),
                  money: widget.money,
                  onAdd: widget.onAddType,
                  onEdit: widget.onEditType,
                  onDelete: widget.onDeleteType,
                )
              else
                _StudentsOnWaiversTable(
                  rows: studentRows,
                  money: widget.money,
                  sortColumnIndex: _studentSortColumnIndex,
                  sortAscending: _studentSortAscending,
                  onSort: (column, ascending) => setState(() {
                    _studentSortColumnIndex = column;
                    _studentSortAscending = ascending;
                  }),
                  onOpenStudent: widget.onOpenStudent,
                ),
            ],
          ),
        ),
      ],
    );
  }

  List<FeeWaiverType> _matchingTypes(String query) {
    if (query.isEmpty) return widget.types;
    return widget.types
        .where((type) {
          return type.name.toLowerCase().contains(query) ||
              type.description.toLowerCase().contains(query) ||
              type.valueType.toLowerCase().contains(query);
        })
        .toList(growable: false);
  }

  List<_StudentWaiverRowData> _sortedStudents(
    List<_StudentWaiverRowData> rows,
  ) {
    int compare(_StudentWaiverRowData a, _StudentWaiverRowData b) {
      return switch (_studentSortColumnIndex) {
        0 => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        1 => a.className.toLowerCase().compareTo(b.className.toLowerCase()),
        2 => a.activeCount.compareTo(b.activeCount),
        3 => a.totalWaived.compareTo(b.totalWaived),
        4 => a.pendingCount.compareTo(b.pendingCount),
        _ => a.status.compareTo(b.status),
      };
    }

    rows.sort((a, b) {
      final result = compare(a, b);
      return _studentSortAscending ? result : -result;
    });
    return rows;
  }
}

class _WaiverMetricCard extends StatelessWidget {
  const _WaiverMetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.caption,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final String caption;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .45,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  caption,
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WaiverViewTab extends StatelessWidget {
  const _WaiverViewTab({
    super.key,
    required this.selected,
    required this.label,
    required this.count,
    required this.onTap,
  });

  final bool selected;
  final String label;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.green.withValues(alpha: .11)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: selected ? AppColors.green : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: selected ? AppColors.green : AppColors.text,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 8),
            _SmallCountBadge(count: count, selected: selected),
          ],
        ),
      ),
    );
  }
}

class _SmallCountBadge extends StatelessWidget {
  const _SmallCountBadge({required this.count, required this.selected});

  final int count;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: selected ? AppColors.green : const Color(0xFFE9EEEC),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          color: selected ? Colors.white : AppColors.muted,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _WaiverTypeTile extends StatelessWidget {
  const _WaiverTypeTile({
    required this.type,
    required this.money,
    required this.onEdit,
    required this.onDelete,
  });

  final FeeWaiverType type;
  final String Function(double amount) money;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAF9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  type.name,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  type.description,
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            type.isPercentage
                ? '${type.defaultValue % 1 == 0 ? type.defaultValue.toStringAsFixed(0) : type.defaultValue.toStringAsFixed(2)}%'
                : money(type.defaultValue),
            style: const TextStyle(
              color: AppColors.purple,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 10),
          PopupMenuButton<String>(
            tooltip: 'Waiver type actions',
            onSelected: (value) => value == 'edit' ? onEdit() : onDelete(),
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit type')),
              PopupMenuItem(value: 'delete', child: Text('Remove type')),
            ],
          ),
        ],
      ),
    );
  }
}

class _WaiverTypesList extends StatelessWidget {
  const _WaiverTypesList({
    required this.types,
    required this.money,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  final List<FeeWaiverType> types;
  final String Function(double amount) money;
  final VoidCallback onAdd;
  final ValueChanged<FeeWaiverType> onEdit;
  final ValueChanged<FeeWaiverType> onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Types available to this school',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              FilledButton.icon(
                key: const Key('add-waiver-type'),
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add type'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (types.isEmpty)
            const _FeeEmptyCard(
              message: 'No waiver or discount types match this search.',
            )
          else
            ...types.map(
              (type) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _WaiverTypeTile(
                  type: type,
                  money: money,
                  onEdit: () => onEdit(type),
                  onDelete: () => onDelete(type),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

bool _isPendingWaiverStatus(String status) =>
    status.trim().toUpperCase() == 'PENDING_APPROVAL';

class _StudentWaiverRowData {
  const _StudentWaiverRowData({
    required this.id,
    required this.name,
    required this.className,
    required this.activeCount,
    required this.pendingCount,
    required this.totalWaived,
  });

  final String id;
  final String name;
  final String className;
  final int activeCount;
  final int pendingCount;
  final double totalWaived;

  String get status => pendingCount > 0 ? 'Pending action' : 'Active';
  bool matches(String query) =>
      query.isEmpty ||
      [
        id,
        name,
        className,
        status,
      ].any((value) => value.toLowerCase().contains(query));
}

List<_StudentWaiverRowData> _studentWaiverRows(
  List<FeeWaiverAssignment> assignments,
) {
  final grouped = <String, List<FeeWaiverAssignment>>{};
  for (final assignment in assignments.where(
    (item) => item.status != 'REVOKED',
  )) {
    grouped.putIfAbsent(assignment.customStudentId, () => []).add(assignment);
  }
  return grouped.entries.map((entry) {
    final rows = entry.value;
    final first = rows.first;
    final active = rows.where((item) => item.status == 'ACTIVE').toList();
    return _StudentWaiverRowData(
      id: entry.key,
      name: first.studentName,
      className: first.className,
      activeCount: active.length,
      pendingCount: rows
          .where((item) => _isPendingWaiverStatus(item.status))
          .length,
      totalWaived: active.fold(0, (sum, item) => sum + item.waivedAmount),
    );
  }).toList();
}

class _WaiverApproverDialog extends StatefulWidget {
  const _WaiverApproverDialog({required this.approvers});

  final List<FeeAdjustmentApprover> approvers;

  @override
  State<_WaiverApproverDialog> createState() => _WaiverApproverDialogState();
}

class _WaiverApproverDialogState extends State<_WaiverApproverDialog> {
  int? _selectedId;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Submit waiver for approval'),
      content: SizedBox(
        width: 440,
        child: widget.approvers.isEmpty
            ? const Text('No other eligible approver is available.')
            : DropdownButtonFormField<int>(
                value: _selectedId,
                decoration: const InputDecoration(labelText: 'Approver *'),
                items: widget.approvers
                    .map(
                      (approver) => DropdownMenuItem(
                        value: approver.id,
                        child: Text('${approver.name} · ${approver.role}'),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _selectedId = value),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _selectedId == null
              ? null
              : () => Navigator.pop(context, _selectedId),
          child: const Text('Submit request'),
        ),
      ],
    );
  }
}

class _StudentsOnWaiversTable extends StatelessWidget {
  const _StudentsOnWaiversTable({
    required this.rows,
    required this.money,
    required this.sortColumnIndex,
    required this.sortAscending,
    required this.onSort,
    required this.onOpenStudent,
  });

  final List<_StudentWaiverRowData> rows;
  final String Function(double amount) money;
  final int sortColumnIndex;
  final bool sortAscending;
  final void Function(int, bool) onSort;
  final ValueChanged<String>? onOpenStudent;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(18, 0, 18, 18),
        child: _FeeEmptyCard(
          message: 'No students currently have a waiver or discount.',
        ),
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        sortColumnIndex: sortColumnIndex,
        sortAscending: sortAscending,
        headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAF9)),
        headingTextStyle: const TextStyle(
          color: AppColors.muted,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: .5,
        ),
        columnSpacing: 54,
        columns: [
          DataColumn(label: const Text('STUDENT'), onSort: onSort),
          DataColumn(label: const Text('CLASS'), onSort: onSort),
          DataColumn(
            label: const Text('ACTIVE WAIVERS'),
            numeric: true,
            onSort: onSort,
          ),
          DataColumn(
            label: const Text('TOTAL VALUE'),
            numeric: true,
            onSort: onSort,
          ),
          DataColumn(
            label: const Text('PENDING'),
            numeric: true,
            onSort: onSort,
          ),
          DataColumn(label: const Text('STATUS'), onSort: onSort),
        ],
        rows: rows
            .map(
              (row) => DataRow(
                cells: [
                  DataCell(
                    _StudentNameCell(name: row.name, id: row.id),
                    onTap: onOpenStudent == null
                        ? null
                        : () => onOpenStudent!(row.id),
                    showEditIcon: false,
                  ),
                  DataCell(Text(row.className)),
                  DataCell(Text('${row.activeCount}')),
                  DataCell(
                    Text(
                      money(row.totalWaived),
                      style: const TextStyle(
                        color: AppColors.green,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  DataCell(Text('${row.pendingCount}')),
                  DataCell(
                    _StatusPill(
                      label: row.status,
                      color: row.pendingCount > 0
                          ? AppColors.amber
                          : AppColors.green,
                    ),
                  ),
                ],
              ),
            )
            .toList(),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _WaiverAssignmentSheet extends StatefulWidget {
  const _WaiverAssignmentSheet({
    required this.api,
    required this.customSchoolId,
    required this.academicTermId,
    required this.initialStudent,
    required this.types,
    required this.existing,
    required this.money,
    required this.currentUserId,
  });

  final FeeApiClient api;
  final String customSchoolId;
  final int academicTermId;
  final FeeStudentFeeRow? initialStudent;
  final List<FeeWaiverType> types;
  final FeeWaiverAssignment? existing;
  final String Function(double amount) money;
  final int currentUserId;

  @override
  State<_WaiverAssignmentSheet> createState() => _WaiverAssignmentSheetState();
}

class _WaiverAssignmentSheetState extends State<_WaiverAssignmentSheet> {
  late final TextEditingController _value;
  late final TextEditingController _reason;
  late final TextEditingController _studentSearch;
  String? _studentId;
  FeeStudentFeeRow? _selectedStudent;
  List<FeeStudentFeeRow> _studentResults = const [];
  Timer? _studentSearchDebounce;
  bool _searchingStudents = false;
  int? _typeId;
  FeeStudentAccount? _account;
  Set<int> _assessmentIds = {};
  bool _loadingAccount = false;
  bool _saving = false;
  String? _error;

  FeeWaiverType? get _type {
    for (final type in widget.types) {
      if (type.id == _typeId) return type;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _selectedStudent = widget.initialStudent;
    _studentId =
        existing?.customStudentId ?? widget.initialStudent?.customStudentId;
    _studentSearch = TextEditingController(
      text: existing == null
          ? (widget.initialStudent?.studentName ?? '')
          : '${existing.studentName} · ${existing.customStudentId}',
    );
    _typeId =
        existing?.waiverTypeId ??
        (widget.types.isEmpty ? null : widget.types.first.id);
    _value = TextEditingController(
      text: existing == null
          ? '${_type?.defaultValue ?? ''}'
          : '${existing.value}',
    );
    _reason = TextEditingController(text: existing?.reason ?? '');
    _assessmentIds =
        existing?.assessments.map((item) => item.assessmentId).toSet() ?? {};
    if (_studentId != null) _loadAccount();
  }

  @override
  void dispose() {
    _value.dispose();
    _reason.dispose();
    _studentSearchDebounce?.cancel();
    _studentSearch.dispose();
    super.dispose();
  }

  void _searchStudents(String query) {
    if (_selectedStudent != null && query != _selectedStudent!.studentName) {
      setState(() {
        _selectedStudent = null;
        _studentId = null;
        _account = null;
        _assessmentIds.clear();
      });
    }
    _studentSearchDebounce?.cancel();
    if (query.trim().length < 2) {
      setState(() => _studentResults = const []);
      return;
    }
    _studentSearchDebounce = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted) return;
      setState(() => _searchingStudents = true);
      try {
        final page = await widget.api.getFeeManagementStudents(
          customSchoolId: widget.customSchoolId,
          termId: widget.academicTermId,
          search: query.trim(),
          size: 8,
        );
        if (mounted) setState(() => _studentResults = page.content);
      } catch (error) {
        if (mounted) setState(() => _error = '$error');
      } finally {
        if (mounted) setState(() => _searchingStudents = false);
      }
    });
  }

  void _selectStudent(FeeStudentFeeRow student) {
    setState(() {
      _selectedStudent = student;
      _studentId = student.customStudentId;
      _studentSearch.text = student.studentName;
      _studentResults = const [];
      _account = null;
      _assessmentIds.clear();
    });
    _loadAccount();
  }

  Future<void> _loadAccount() async {
    final studentId = _studentId;
    if (studentId == null || studentId.isEmpty) return;
    setState(() {
      _loadingAccount = true;
      _error = null;
    });
    try {
      final account = await widget.api.getStudentFeeAccount(
        customSchoolId: widget.customSchoolId,
        customStudentId: studentId,
        academicTermId: widget.academicTermId,
      );
      if (mounted) setState(() => _account = account);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _loadingAccount = false);
    }
  }

  double get _eligibleAmount {
    final assessments = _account?.assessments ?? const <FeeAssessmentLine>[];
    final type = _type;
    if (type == null) return 0;
    if (type.appliesToAllFees) {
      return assessments.fold(0, (total, item) => total + item.amount);
    }
    return assessments
        .where((item) => _assessmentIds.contains(item.assessmentId))
        .fold(0, (total, item) => total + item.amount);
  }

  double get _waivedAmount {
    final type = _type;
    final value = double.tryParse(_value.text.trim()) ?? 0;
    if (type == null) return 0;
    return type.isPercentage ? _eligibleAmount * value / 100 : value;
  }

  Future<void> _save({bool submit = false}) async {
    final type = _type;
    final studentId = _studentId;
    final value = double.tryParse(_value.text.trim());
    if (studentId == null ||
        type == null ||
        value == null ||
        value <= 0 ||
        _reason.text.trim().isEmpty) {
      setState(
        () => _error =
            'Select a student and waiver type, then enter a value and reason.',
      );
      return;
    }
    if (!type.appliesToAllFees && _assessmentIds.isEmpty) {
      setState(() => _error = 'Select at least one fee item.');
      return;
    }
    if (_waivedAmount > _eligibleAmount) {
      setState(() => _error = 'The waiver cannot exceed the selected fees.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved = await widget.api.saveStudentWaiver(
        customSchoolId: widget.customSchoolId,
        customStudentId: studentId,
        waiverId: widget.existing?.id,
        academicTermId: widget.academicTermId,
        waiverTypeId: type.id,
        value: value,
        assessmentIds: type.appliesToAllFees
            ? const []
            : _assessmentIds.toList(),
        reason: _reason.text,
      );
      if (submit) {
        final approvers = (await widget.api.getFeeAdjustmentApprovers(
          widget.customSchoolId,
        )).where((item) => item.id != widget.currentUserId).toList();
        if (!mounted) return;
        final approverId = await showDialog<int>(
          context: context,
          builder: (context) => _WaiverApproverDialog(approvers: approvers),
        );
        if (approverId == null) {
          setState(() => _saving = false);
          return;
        }
        await widget.api.performStudentWaiverAction(
          customSchoolId: widget.customSchoolId,
          waiverId: saved.id,
          action: 'SUBMIT',
          approverId: approverId,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = '$error';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final type = _type;
    return Material(
      color: Colors.white,
      child: SafeArea(
        child: SizedBox(
          width: 560,
          height: double.infinity,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 14, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.existing == null
                                ? 'Assign student waiver'
                                : 'Edit student waiver',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Reduce selected fees without changing the original assessments.',
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _saving
                          ? null
                          : () => Navigator.pop(context, false),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        key: const Key('waiver-student-search'),
                        controller: _studentSearch,
                        enabled: widget.existing == null && !_saving,
                        onChanged: _searchStudents,
                        decoration: InputDecoration(
                          labelText: 'Find student by name or ID *',
                          hintText: 'Start typing a student name or ID',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: _searchingStudents
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                      ),
                      if (_studentResults.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            children: _studentResults
                                .map(
                                  (student) => ListTile(
                                    key: Key(
                                      'waiver-student-${student.customStudentId}',
                                    ),
                                    title: Text(
                                      student.studentName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    subtitle: Text(
                                      '${student.customStudentId} · ${student.className}',
                                    ),
                                    trailing: const Icon(
                                      Icons.chevron_right_rounded,
                                    ),
                                    onTap: () => _selectStudent(student),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      if (_studentId != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.green.withValues(alpha: .08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${_selectedStudent?.studentName ?? widget.existing?.studentName ?? ''}\n${_studentId!} · ${_selectedStudent?.className ?? widget.existing?.className ?? ''}',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int>(
                        value: _typeId,
                        decoration: const InputDecoration(
                          labelText: 'Waiver type *',
                        ),
                        items: widget.types
                            .map(
                              (item) => DropdownMenuItem(
                                value: item.id,
                                child: Text(item.name),
                              ),
                            )
                            .toList(),
                        onChanged: _saving
                            ? null
                            : (next) => setState(() {
                                _typeId = next;
                                _assessmentIds.clear();
                                final selected = _type;
                                _value.text = selected == null
                                    ? ''
                                    : '${selected.defaultValue}';
                              }),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _value,
                        onChanged: (_) => setState(() {}),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: type?.isPercentage == true
                              ? 'Percentage *'
                              : 'Amount (GH₵) *',
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (_loadingAccount)
                        const Center(child: CircularProgressIndicator())
                      else if (_account != null) ...[
                        Text(
                          type?.appliesToAllFees == true
                              ? 'Included fee items'
                              : 'Select fee items *',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 8),
                        ..._account!.assessments.map(
                          (assessment) => CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            value:
                                type?.appliesToAllFees == true ||
                                _assessmentIds.contains(
                                  assessment.assessmentId,
                                ),
                            onChanged: type?.appliesToAllFees == true || _saving
                                ? null
                                : (selected) => setState(() {
                                    selected == true
                                        ? _assessmentIds.add(
                                            assessment.assessmentId,
                                          )
                                        : _assessmentIds.remove(
                                            assessment.assessmentId,
                                          );
                                  }),
                            title: Text(assessment.feeName),
                            secondary: Text(
                              widget.money(assessment.amount),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      TextField(
                        controller: _reason,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Reason *',
                          hintText: 'Why is this waiver being granted?',
                        ),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.green.withValues(alpha: .08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.green.withValues(alpha: .25),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Fee impact',
                                    style: TextStyle(
                                      color: AppColors.muted,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${widget.money(_eligibleAmount)} eligible · ${widget.money((_eligibleAmount - _waivedAmount).clamp(0, double.infinity))} after waiver',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '−${widget.money(_waivedAmount)}',
                              style: const TextStyle(
                                color: AppColors.green,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: const TextStyle(color: AppColors.red),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving
                            ? null
                            : () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving ? null : () => _save(),
                        child: const Text('Save draft'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _saving ? null : () => _save(submit: true),
                        child: Text(
                          _saving ? 'Saving...' : 'Submit for approval',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeePageSkeleton extends StatelessWidget {
  const _FeePageSkeleton();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: List.generate(
          5,
          (index) => Container(
            height: index == 0 ? 118 : 96,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
          ),
        ),
      ),
    );
  }
}

class _FeeErrorState extends StatelessWidget {
  const _FeeErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                size: 44,
                color: AppColors.red,
              ),
              const SizedBox(height: 12),
              const Text(
                'Unable to load fees and requirements',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: 440,
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.muted),
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
