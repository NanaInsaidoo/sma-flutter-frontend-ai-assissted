import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../data/api_class_requirements_repository.dart';
import '../data/fee_api_client.dart';
import '../domain/fee_models.dart';
import 'class_requirements_screen.dart';
import 'fee_adjustments_content.dart';

enum _FeeTab {
  overview,
  studentFees,
  feeStructure,
  adjustments,
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
  });

  final String customSchoolId;
  final String schoolName;
  final String? accessToken;
  final Future<String?> Function()? onRefreshAccessToken;

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

  @override
  void initState() {
    super.initState();
    _api = FeeApiClient(
      accessToken: widget.accessToken,
      onRefreshAccessToken: widget.onRefreshAccessToken,
    );
    _initialLoad = _loadInitial();
  }

  @override
  void didUpdateWidget(covariant FeeManagementScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.accessToken != widget.accessToken) {
      _api.accessToken = widget.accessToken;
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
    final overview = await _api.getFeeManagementOverview(
      customSchoolId: widget.customSchoolId,
      termId: currentTerm.id,
    );
    if (!mounted) return;
    setState(() {
      _overview = overview;
      _currentTerm = currentTerm;
      _classCollections = overview.collectionByClass;
      _arrears = overview.outstandingArrears;
    });
  }

  Future<void> _reloadFees() async {
    final termId = _activeTermId;
    if (termId <= 0) return;
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
      _FeeTab.adjustments => FeeAdjustmentsContent(
        api: _api,
        customSchoolId: widget.customSchoolId,
        termId: _activeTermId,
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
    final termId = _activeTermId;
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
  ]) async {
    if (_waiverTypes.isEmpty) {
      await _showWaiverTypeDialog();
      if (_waiverTypes.isEmpty || !mounted) return;
    }
    await _loadStudentFees(force: !_studentFeesLoaded);
    if (!mounted || !_studentFeesLoaded) return;
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
          students: _studentFeesPage?.content ?? const [],
          types: _waiverTypes,
          existing: existing,
          money: _money,
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
        title: const Text('Revoke waiver?'),
        content: Text(
          'The waiver will stop reducing ${assignment.studentName}’s balance.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Revoke'),
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
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
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
    return _FeeStructureContent(
      termName: _termName,
      classFees: _classFees(),
      money: _money,
      onAddClassLevel: _openClassLevelSheet,
      onEditClassLevel: _openClassLevelSheet,
      onPublishClassLevel: _publishFeeStructure,
      onDeleteClassLevel: _deleteFeeStructure,
    );
  }

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
            termId: _activeTermId,
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

  Future<void> _publishFeeStructure(_ClassFee classFee) async {
    if (classFee.structureId <= 0 || !classFee.isDraft) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Publish fee structure?'),
        content: Text(
          'Publish ${classFee.title} fees for $_termName? The published version will become the active structure for this class.',
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

  Future<void> _showRecordPaymentForm() async {
    await _loadStudentFees(force: !_studentFeesLoaded);
    if (!mounted || !_studentFeesLoaded) return;
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _RecordPaymentDialog(
        students: _studentFeeRows(),
        selectedStudent: null,
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
      totalFees: row.totalFees,
      paid: row.paid,
      balance: row.balance,
      status: _paymentStatusLabel(row.paymentStatus),
      lastPayment: _formatCompactDate(row.lastPaymentDate),
    );
  }

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
    (_FeeTab.adjustments, 'Fee Adjustments'),
    (_FeeTab.classRequirements, 'Items & Supplies'),
    (_FeeTab.waivers, 'Waivers'),
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
              title: 'Waivers',
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
  const _FeeEmptyCard({required this.message, this.actionLabel, this.onAction});

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

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
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(width: 16),
            OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
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

class _FeeStructureContent extends StatelessWidget {
  const _FeeStructureContent({
    required this.termName,
    required this.classFees,
    required this.money,
    required this.onAddClassLevel,
    required this.onEditClassLevel,
    required this.onPublishClassLevel,
    required this.onDeleteClassLevel,
  });

  final String termName;
  final List<_ClassFee> classFees;
  final String Function(double amount) money;
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
    required this.api,
    required this.money,
    required this.onSearchChanged,
    required this.onGradeLevelChanged,
    required this.onPaymentStatusChanged,
    required this.onPaymentSaved,
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
  final FeeApiClient api;
  final String Function(double amount) money;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<int?> onGradeLevelChanged;
  final ValueChanged<String?> onPaymentStatusChanged;
  final Future<void> Function() onPaymentSaved;

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
                        row.balance <= 0
                            ? const Text('-')
                            : Text(
                                money(row.balance),
                                style: const TextStyle(color: AppColors.red),
                              ),
                      ),
                      DataCell(_PaymentStatus(status: row.status)),
                      DataCell(Text(row.lastPayment)),
                      DataCell(
                        TextButton.icon(
                          onPressed: () => _showStudentDetails(context, row),
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: const Text('Pay'),
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
            onRecordPayment: () =>
                _showRecordPaymentForm(context, rows, selectedStudent: row),
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
  late final TextEditingController _notesController;
  _StudentFeeRow? _student;
  FeePaymentMethod? _method;
  DateTime _paymentDate = DateTime.now();
  bool _saving = false;
  bool _success = false;
  _PaymentReceipt? _receipt;
  PlatformFile? _receiptPhoto;

  bool get _isScopedToStudent => widget.selectedStudent != null;

  @override
  void initState() {
    super.initState();
    _student = widget.selectedStudent;
    _studentController = TextEditingController(
      text: _student == null ? '' : _student!.name,
    );
    _amountController = TextEditingController(
      text: _student == null || _student!.balance <= 0
          ? ''
          : _student!.balance.toStringAsFixed(0),
    );
    _momoReferenceController = TextEditingController();
    _receiptController = TextEditingController();
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _studentController.dispose();
    _amountController.dispose();
    _momoReferenceController.dispose();
    _receiptController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final student = _student;
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    if (_success) {
      return AlertDialog(
        content: SizedBox(
          width: 430,
          child: _PaymentSuccessView(
            receipt: _receipt!,
            onRecordAnother: _resetForAnotherPayment,
            onDone: () => Navigator.pop(context, true),
          ),
        ),
      );
    }

    return AlertDialog(
      title: const Text('Collect Fees'),
      titlePadding: const EdgeInsets.fromLTRB(28, 26, 28, 0),
      content: SizedBox(
        width: 520,
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
                  _PaymentStudentSummary(student: student, money: widget.money),
                ] else ...[
                  _PaymentSectionTitle('Student'),
                  TextFormField(
                    controller: _studentController,
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
                      setState(() {
                        _student = selected;
                        if (selected != null && selected.balance > 0) {
                          _amountController.text = selected.balance
                              .toStringAsFixed(0);
                        }
                      });
                    },
                  ),
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
                                suffixIcon: Icon(Icons.calendar_month_rounded),
                              ),
                              child: Text(_formatDate(_paymentDate)),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                if (student != null && amount > 0) ...[
                  const SizedBox(height: 16),
                  _BalanceAfterPaymentPreview(
                    currentBalance: student.balance,
                    amount: amount,
                    money: widget.money,
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
                  validator: (value) =>
                      value == null ? 'Please select a payment method.' : null,
                  onChanged: (value) => setState(() {
                    _method = widget.paymentMethods.firstWhere(
                      (method) => '${method.id}' == value,
                    );
                  }),
                ),
                if ((_method?.method.toLowerCase() ?? '').contains('mobile') ||
                    (_method?.method.toLowerCase() ?? '').contains('momo')) ...[
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _momoReferenceController,
                    decoration: const InputDecoration(
                      labelText: 'MoMo Reference Number',
                      hintText: 'e.g. ABS1234567890',
                    ),
                  ),
                ],
                _PaymentSectionTitle('Receipt'),
                TextFormField(
                  controller: _receiptController,
                  decoration: const InputDecoration(
                    labelText: 'Physical Receipt Number *',
                    hintText: 'e.g. REC-00421',
                    helperText: 'Enter the number from the paper receipt book',
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Please enter the physical receipt number.'
                      : null,
                ),
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
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
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

  Future<void> _pickReceiptPhoto() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty || !mounted) return;
    final file = result.files.single;
    if (file.bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not read the selected image.')),
      );
      return;
    }
    if (file.size > 5 * 1024 * 1024) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Receipt photo must be 5 MB or smaller.')),
      );
      return;
    }
    setState(() => _receiptPhoto = file);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final student = _student;
    final method = _method;
    if (student == null || method == null || widget.termId <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select a student, payment method, and active term.'),
        ),
      );
      return;
    }
    final amount = double.parse(_amountController.text.trim());
    final physicalReceipt = _receiptController.text.trim();
    setState(() => _saving = true);
    try {
      final receipt = await widget.api.recordPayment(
        FeePaymentRequest(
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
          amount: receipt.amount == 0 ? amount : receipt.amount,
          paymentMethod: receipt.paymentMethod.trim().isEmpty
              ? method.method
              : receipt.paymentMethod,
          paymentDate: receipt.paymentDate ?? _paymentDate,
          remainingBalance: (student.balance - amount)
              .clamp(0, double.infinity)
              .toDouble(),
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
      if (student.balance > 0) {
        _amountController.text = student.balance.toStringAsFixed(0);
      }
    });
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
      _receiptPhoto = null;
      _notesController.clear();
      _paymentDate = DateTime.now();
    });
  }

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
    required this.amount,
    required this.paymentMethod,
    required this.paymentDate,
    required this.remainingBalance,
  });

  final String receiptNumber;
  final String physicalReceiptNumber;
  final String studentName;
  final String className;
  final double amount;
  final String paymentMethod;
  final DateTime paymentDate;
  final double? remainingBalance;
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
            child: const Icon(Icons.image_outlined, color: AppColors.green),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file?.name ?? 'Receipt photo (optional)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  file == null
                      ? 'Attach a JPG, PNG, or WebP image up to 5 MB.'
                      : '${(file!.size / 1024).ceil()} KB selected',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (file != null)
            IconButton(
              tooltip: 'Remove receipt photo',
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
  const _AmountEntryField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      autofocus: true,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
      decoration: InputDecoration(
        labelText: 'Amount to Collect (GH₵)',
        hintText: '0.00',
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
        if (amount == null || amount <= 0) return 'Enter a valid amount';
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
  });

  final double currentBalance;
  final double amount;
  final String Function(double amount) money;

  @override
  Widget build(BuildContext context) {
    final remaining = (currentBalance - amount).clamp(0, double.infinity);
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
                const Text(
                  'Balance after this payment',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Current balance ${money(currentBalance)}',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            money(remaining.toDouble()),
            style: TextStyle(
              color: remaining <= 0 ? AppColors.green : AppColors.amber,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
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
          const Text(
            'Payment Receipt Created',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            'Receipt ${receipt.receiptNumber}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.green,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 18),
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
                _ReceiptLine(
                  label: 'Amount paid',
                  value: _money(receipt.amount),
                  highlight: true,
                ),
                _ReceiptLine(label: 'Method', value: receipt.paymentMethod),
                _ReceiptLine(
                  label: 'Payment date',
                  value: formatDate(receipt.paymentDate),
                ),
                _ReceiptLine(
                  label: 'Physical receipt',
                  value: receipt.physicalReceiptNumber,
                ),
                if (receipt.remainingBalance != null)
                  _ReceiptLine(
                    label: 'Balance after payment',
                    value: _money(receipt.remainingBalance!),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 22),
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
                  '${student.className} · Balance ${money(student.balance)}',
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
    required this.onRecordPayment,
  });

  final _StudentFeeRow row;
  final String Function(double amount) money;
  final FeeApiClient api;
  final String customSchoolId;
  final int termId;
  final VoidCallback onRecordPayment;

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
                                  label: 'Balance',
                                  value: money(account.balance),
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
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: onRecordPayment,
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Collect Fees'),
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  _StudentPaymentHistory _historyFromPayment(FeeStudentPayment payment) {
    return _StudentPaymentHistory(
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
  const _PaymentHistorySection({required this.payments, required this.money});

  final List<_StudentPaymentHistory> payments;
  final String Function(double amount) money;

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
              child: _PaymentHistoryTile(payment: payment, money: money),
            ),
          ),
      ],
    );
  }
}

class _PaymentHistoryTile extends StatelessWidget {
  const _PaymentHistoryTile({required this.payment, required this.money});

  final _StudentPaymentHistory payment;
  final String Function(double amount) money;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
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
                  '${payment.receiptNumber} · ${payment.term} · ${payment.recordedBy}',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                money(payment.amount),
                style: const TextStyle(
                  color: AppColors.green,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                payment.date,
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StudentPaymentHistory {
  const _StudentPaymentHistory({
    required this.method,
    required this.receiptNumber,
    required this.amount,
    required this.date,
    required this.term,
    required this.recordedBy,
  });

  final String method;
  final String receiptNumber;
  final double amount;
  final String date;
  final String term;
  final String recordedBy;
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

class _WaiversContent extends StatelessWidget {
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

  @override
  Widget build(BuildContext context) {
    final activeAssignments = assignments
        .where((item) => item.status == 'ACTIVE')
        .toList();
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
                    'Waivers & Discounts',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${types.length} active ${types.length == 1 ? 'type' : 'types'} · ${activeAssignments.length} active ${activeAssignments.length == 1 ? 'student waiver' : 'student waivers'}',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            OutlinedButton.icon(
              onPressed: onAddType,
              icon: const Icon(Icons.tune_rounded),
              label: const Text('New waiver type'),
            ),
            const SizedBox(width: 10),
            FilledButton.icon(
              onPressed: onAssignWaiver,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Assign waiver'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Waiver Types',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 16),
                if (types.isEmpty)
                  _FeeEmptyCard(
                    message:
                        'No waiver types configured. Create a type before assigning a waiver.',
                    actionLabel: 'Create waiver type',
                    onAction: onAddType,
                  )
                else
                  ...types.map(
                    (type) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _WaiverTypeTile(
                        type: type,
                        money: money,
                        onEdit: () => onEditType(type),
                        onDelete: () => onDeleteType(type),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        _StudentsWithWaiversTable(
          assignments: assignments,
          money: money,
          onEdit: onEditAssignment,
          onRevoke: onRevokeAssignment,
        ),
      ],
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

class _StudentsWithWaiversTable extends StatelessWidget {
  const _StudentsWithWaiversTable({
    required this.assignments,
    required this.money,
    required this.onEdit,
    required this.onRevoke,
  });

  final List<FeeWaiverAssignment> assignments;
  final String Function(double amount) money;
  final ValueChanged<FeeWaiverAssignment> onEdit;
  final ValueChanged<FeeWaiverAssignment> onRevoke;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Students with Waivers',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                Text(
                  '${assignments.length} ${assignments.length == 1 ? 'assignment' : 'assignments'}',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (assignments.isEmpty)
              const _FeeEmptyCard(
                message: 'No waivers have been assigned for this term.',
              )
            else
              SingleChildScrollView(
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
                  columnSpacing: 86,
                  columns: const [
                    DataColumn(label: Text('STUDENT')),
                    DataColumn(label: Text('CLASS')),
                    DataColumn(label: Text('WAIVER TYPE')),
                    DataColumn(label: Text('ELIGIBLE FEES')),
                    DataColumn(label: Text('WAIVED')),
                    DataColumn(label: Text('STATUS')),
                    DataColumn(label: Text('ACTIONS')),
                  ],
                  rows: assignments.map((assignment) {
                    return DataRow(
                      cells: [
                        DataCell(
                          _StudentNameCell(
                            name: assignment.studentName,
                            id: assignment.customStudentId,
                          ),
                        ),
                        DataCell(Text(assignment.className)),
                        DataCell(_WaiverBadge(label: assignment.waiverType)),
                        DataCell(Text(money(assignment.eligibleAmount))),
                        DataCell(
                          Text(
                            '−${money(assignment.waivedAmount)}',
                            style: const TextStyle(color: AppColors.green),
                          ),
                        ),
                        DataCell(
                          _StatusPill(
                            label: assignment.status == 'ACTIVE'
                                ? 'Active'
                                : 'Revoked',
                            color: assignment.status == 'ACTIVE'
                                ? AppColors.green
                                : AppColors.muted,
                          ),
                        ),
                        DataCell(
                          assignment.status == 'ACTIVE'
                              ? Row(
                                  children: [
                                    TextButton(
                                      onPressed: () => onEdit(assignment),
                                      child: const Text('Edit'),
                                    ),
                                    TextButton(
                                      onPressed: () => onRevoke(assignment),
                                      child: const Text('Revoke'),
                                    ),
                                  ],
                                )
                              : const Text('—'),
                        ),
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

class _WaiverBadge extends StatelessWidget {
  const _WaiverBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.purple.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.purple,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
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
    required this.students,
    required this.types,
    required this.existing,
    required this.money,
  });

  final FeeApiClient api;
  final String customSchoolId;
  final int academicTermId;
  final List<FeeStudentFeeRow> students;
  final List<FeeWaiverType> types;
  final FeeWaiverAssignment? existing;
  final String Function(double amount) money;

  @override
  State<_WaiverAssignmentSheet> createState() => _WaiverAssignmentSheetState();
}

class _WaiverAssignmentSheetState extends State<_WaiverAssignmentSheet> {
  late final TextEditingController _value;
  late final TextEditingController _reason;
  String? _studentId;
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
    _studentId = existing?.customStudentId;
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
    super.dispose();
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

  Future<void> _save() async {
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
      await widget.api.saveStudentWaiver(
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
                      DropdownButtonFormField<String>(
                        value: _studentId,
                        decoration: const InputDecoration(
                          labelText: 'Student *',
                        ),
                        items: widget.students
                            .map(
                              (student) => DropdownMenuItem(
                                value: student.customStudentId,
                                child: Text(
                                  '${student.studentName} · ${student.className}',
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: widget.existing != null || _saving
                            ? null
                            : (next) {
                                setState(() {
                                  _studentId = next;
                                  _account = null;
                                  _assessmentIds.clear();
                                });
                                _loadAccount();
                              },
                      ),
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
                      child: FilledButton(
                        onPressed: _saving ? null : _save,
                        child: Text(_saving ? 'Saving...' : 'Save waiver'),
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
