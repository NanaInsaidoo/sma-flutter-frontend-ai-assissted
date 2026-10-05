import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../data/staff_api_client.dart';
import '../../common/display_formatters.dart';
import '../../platform/presentation/document_opener.dart';
import '../../theme/app_theme.dart';
import '../../leave/data/leave_api_client.dart';
import '../../leave/presentation/leave_management_screen.dart';

class StaffScreen extends StatefulWidget {
  const StaffScreen({
    super.key,
    this.openAddStaffOnLoad = false,
    this.onAddStaffRequestConsumed,
    this.customSchoolId,
    this.currentUserId,
    this.accessToken,
    this.onRefreshAccessToken,
    this.apiClient,
  });

  final bool openAddStaffOnLoad;
  final VoidCallback? onAddStaffRequestConsumed;
  final String? customSchoolId;
  final int? currentUserId;
  final String? accessToken;
  final Future<String?> Function()? onRefreshAccessToken;
  final StaffApiClient? apiClient;

  @override
  State<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends State<StaffScreen> {
  final List<_StaffMember> _localEduHireDrafts = [];
  List<_StaffMember> _staff = [];
  _StaffTab _tab = _StaffTab.staffList;
  _StaffMember? _selectedStaff;
  String _query = '';
  _StaffSortField _sortField = _StaffSortField.name;
  bool _sortAscending = true;
  bool _isLoadingStaff = false;
  String? _staffError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadStaff();
      if (widget.openAddStaffOnLoad) _openAddStaff();
    });
  }

  @override
  void didUpdateWidget(covariant StaffScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.customSchoolId != oldWidget.customSchoolId ||
        widget.accessToken != oldWidget.accessToken) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadStaff());
    }
    if (widget.openAddStaffOnLoad && !oldWidget.openAddStaffOnLoad) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openAddStaff());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedStaff != null) {
      return _StaffProfilePage(
        staff: _selectedStaff!,
        customSchoolId: widget.customSchoolId?.trim() ?? '',
        apiClient: _apiClient(),
        leaveContent:
            widget.customSchoolId != null &&
                int.tryParse(_selectedStaff!.id) != null
            ? LeaveManagementScreen(
                key: ValueKey('staff-leave-${_selectedStaff!.id}'),
                embedded: true,
                staffUserId: int.parse(_selectedStaff!.id),
                api: LeaveApiClient(
                  schoolId: widget.customSchoolId!,
                  accessToken: widget.accessToken,
                  onRefreshAccessToken: widget.onRefreshAccessToken,
                ),
              )
            : const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Leave history becomes available when the staff account is active.',
                  ),
                ),
              ),
        onBack: () => setState(() => _selectedStaff = null),
        onManageRoles:
            _selectedStaff!.userRoles.isEmpty ||
                int.tryParse(_selectedStaff!.id) == null
            ? null
            : () => _manageRoles(_selectedStaff!),
        onEdit:
            _selectedStaff!.userRoles.isEmpty ||
                int.tryParse(_selectedStaff!.id) == null
            ? null
            : () => _editStaff(_selectedStaff!),
        onSuspend:
            _selectedStaff!.status == _StaffStatus.active &&
                _selectedStaff!.id != '${widget.currentUserId}'
            ? () => _suspendStaff(_selectedStaff!)
            : null,
        onRequirePasswordChange:
            _selectedStaff!.status == _StaffStatus.active &&
                !_selectedStaff!.mustChangePassword &&
                _selectedStaff!.id != '${widget.currentUserId}'
            ? () => _requirePasswordChange(_selectedStaff!)
            : null,
        onApprove: _selectedStaff!.status == _StaffStatus.pendingReview
            ? () => _approveStaff(_selectedStaff!)
            : null,
        onReject: _selectedStaff!.status == _StaffStatus.pendingReview
            ? () => _rejectStaff(_selectedStaff!)
            : null,
        onReactivate: _selectedStaff!.status == _StaffStatus.suspended
            ? () => _reactivateStaff(_selectedStaff!)
            : null,
        onDeactivate:
            (_selectedStaff!.status == _StaffStatus.active ||
                    _selectedStaff!.status == _StaffStatus.suspended) &&
                _selectedStaff!.id != '${widget.currentUserId}'
            ? () => _deactivateStaff(_selectedStaff!)
            : null,
        onResendInvitation: _selectedStaff!.invitationToken.isEmpty
            ? null
            : () => _resendStaffInvitation(_selectedStaff!),
        onCancelInvitation: _selectedStaff!.invitationToken.isEmpty
            ? null
            : () => _cancelStaffInvitation(_selectedStaff!),
        onDeleteInvitation: _selectedStaff!.invitationToken.isEmpty
            ? null
            : () => _deleteStaffInvitation(_selectedStaff!),
      );
    }

    final visibleStaff = _filteredStaff;
    final onboardingStaff = _staff.where(_isStaffOnboarding).toList();
    final establishedStaff = _staff
        .where((staff) => !_isStaffOnboarding(staff))
        .toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StaffHeader(onAddStaff: _openAddStaff),
          const SizedBox(height: 18),
          _StaffMetricRow(staff: _staff),
          const SizedBox(height: 18),
          _StaffTabs(
            selected: _tab,
            staffCount: establishedStaff.length,
            onboardingCount: onboardingStaff.length,
            onChanged: (tab) => setState(() => _tab = tab),
          ),
          const SizedBox(height: 14),
          if (_isLoadingStaff && _staff.isEmpty)
            const _StaffLoadingPanel()
          else if (_staffError != null && _staff.isEmpty)
            _StaffErrorPanel(message: _staffError!, onRetry: _loadStaff)
          else ...[
            if (_staffError != null) ...[
              _StaffInlineError(message: _staffError!, onRetry: _loadStaff),
              const SizedBox(height: 12),
            ],
            switch (_tab) {
              _StaffTab.staffList => _DirectoryPanel(
                staff: _sortStaff(
                  visibleStaff
                      .where((member) => !_isStaffOnboarding(member))
                      .toList(),
                ),
                query: _query,
                onQueryChanged: (value) => setState(() => _query = value),
                onOpenStaff: (member) =>
                    setState(() => _selectedStaff = member),
                currentUserId: widget.currentUserId,
                sortField: _sortField,
                sortAscending: _sortAscending,
                onSort: _changeSort,
              ),
              _StaffTab.onboarding => _OnboardingPanel(
                staff: _sortStaff(
                  visibleStaff.where(_isStaffOnboarding).toList(),
                ),
                hasOnboardingRecords: onboardingStaff.isNotEmpty,
                query: _query,
                onQueryChanged: (value) => setState(() => _query = value),
                onOpenStaff: (member) =>
                    setState(() => _selectedStaff = member),
                sortField: _sortField,
                sortAscending: _sortAscending,
                onSort: _changeSort,
              ),
            },
          ],
        ],
      ),
    );
  }

  Future<void> _manageRoles(_StaffMember staff) async {
    final schoolId = widget.customSchoolId?.trim() ?? '';
    if (schoolId.isEmpty) return;
    final result = await showDialog<_RoleSelectionResult>(
      context: context,
      builder: (context) => _ManageRolesDialog(
        primaryRole: staff.primaryRole,
        roles: staff.userRoles,
      ),
    );
    if (result == null || !mounted) return;
    try {
      await _apiClient().updateSchoolUserRoles(
        customSchoolId: schoolId,
        userId: staff.id,
        primaryRole: result.primaryRole,
        roles: result.roles,
      );
      await _loadStaff();
      if (mounted) {
        _showMessage(
          'Roles updated. New access applies at the next sign-in or token refresh.',
        );
      }
    } on StaffApiException catch (error) {
      if (mounted) _showMessage(error.message);
    }
  }

  StaffApiClient _apiClient() =>
      widget.apiClient ??
      StaffApiClient(
        accessToken: widget.accessToken,
        onRefreshAccessToken: widget.onRefreshAccessToken,
      );

  Future<void> _editStaff(_StaffMember staff) async {
    final schoolId = widget.customSchoolId?.trim() ?? '';
    if (schoolId.isEmpty) return;
    final result = await showDialog<_EditStaffResult>(
      context: context,
      builder: (context) => _EditStaffDialog(staff: staff),
    );
    if (result == null || !mounted) return;
    try {
      await _apiClient().updateSchoolUser(
        customSchoolId: schoolId,
        userId: staff.id,
        body: {
          'firstName': result.firstName,
          'lastName': result.lastName,
          'email': result.email,
          'phoneNumber': result.phoneNumber,
        },
      );
      await _loadStaff();
      if (mounted) _showMessage('Staff profile updated.');
    } on StaffApiException catch (error) {
      if (mounted) _showMessage(error.message);
    }
  }

  Future<String?> _lifecycleReason({
    required String title,
    required String actionLabel,
    required String message,
  }) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message, style: const TextStyle(height: 1.4)),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Reason',
                  hintText: 'Required for the audit trail',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () {
              final reason = controller.text.trim();
              if (reason.isNotEmpty) Navigator.pop(context, reason);
            },
            child: Text(actionLabel),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _suspendStaff(_StaffMember staff) async {
    final schoolId = widget.customSchoolId?.trim() ?? '';
    if (schoolId.isEmpty) return;
    final reason = await _lifecycleReason(
      title: 'Suspend ${staff.fullName}?',
      actionLabel: 'Suspend account',
      message:
          'This blocks sign-in immediately. The account can be reactivated later.',
    );
    if (reason == null || !mounted) return;
    try {
      await _apiClient().suspendSchoolUser(
        customSchoolId: schoolId,
        userId: staff.id,
        reason: reason,
      );
      await _loadStaff();
      if (mounted) _showMessage('Staff account suspended.');
    } on StaffApiException catch (error) {
      if (mounted) _showMessage(error.message);
    }
  }

  Future<void> _reactivateStaff(_StaffMember staff) async {
    final schoolId = widget.customSchoolId?.trim() ?? '';
    if (schoolId.isEmpty) return;
    try {
      await _apiClient().reactivateSchoolUser(
        customSchoolId: schoolId,
        userId: staff.id,
      );
      await _loadStaff();
      if (mounted) _showMessage('Staff account reactivated.');
    } on StaffApiException catch (error) {
      if (mounted) _showMessage(error.message);
    }
  }

  Future<void> _requirePasswordChange(_StaffMember staff) async {
    final schoolId = widget.customSchoolId?.trim() ?? '';
    if (schoolId.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Require password change?'),
        content: Text(
          '${staff.fullName} will be signed out of all current sessions. Their existing password will work only to sign in and create a replacement password before they can use SMA.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Require change'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _apiClient().requirePasswordChange(
        customSchoolId: schoolId,
        userId: staff.id,
      );
      await _loadStaff();
      if (mounted) {
        _showMessage('Password change required. Current sessions signed out.');
      }
    } on StaffApiException catch (error) {
      if (mounted) _showMessage(error.message);
    }
  }

  Future<void> _approveStaff(_StaffMember staff) async {
    final schoolId = widget.customSchoolId?.trim() ?? '';
    if (schoolId.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve staff account?'),
        content: Text(
          '${staff.fullName} will receive active access based on their assigned roles and individual permissions.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Approve account'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _apiClient().approveSchoolUser(
        customSchoolId: schoolId,
        userId: staff.id,
      );
      await _loadStaff();
      if (mounted) _showMessage('Staff account approved.');
    } on StaffApiException catch (error) {
      if (mounted) _showMessage(error.message);
    }
  }

  Future<void> _rejectStaff(_StaffMember staff) async {
    final schoolId = widget.customSchoolId?.trim() ?? '';
    if (schoolId.isEmpty) return;
    final reason = await _lifecycleReason(
      title: 'Reject ${staff.fullName}’s account?',
      actionLabel: 'Reject account',
      message:
          'This denies account access and keeps an audited record of the decision.',
    );
    if (reason == null || !mounted) return;
    try {
      await _apiClient().rejectSchoolUser(
        customSchoolId: schoolId,
        userId: staff.id,
        reason: reason,
      );
      await _loadStaff();
      if (mounted) _showMessage('Staff account rejected.');
    } on StaffApiException catch (error) {
      if (mounted) _showMessage(error.message);
    }
  }

  Future<void> _deactivateStaff(_StaffMember staff) async {
    final schoolId = widget.customSchoolId?.trim() ?? '';
    if (schoolId.isEmpty) return;
    final reason = await _lifecycleReason(
      title: 'Deactivate ${staff.fullName}?',
      actionLabel: 'Deactivate permanently',
      message:
          'This permanently archives the account and blocks sign-in. A school administrator cannot reverse it.',
    );
    if (reason == null || !mounted) return;
    try {
      await _apiClient().deactivateSchoolUser(
        customSchoolId: schoolId,
        userId: staff.id,
        reason: reason,
      );
      await _loadStaff();
      if (mounted) _showMessage('Staff account deactivated.');
    } on StaffApiException catch (error) {
      if (mounted) _showMessage(error.message);
    }
  }

  List<_StaffMember> get _filteredStaff {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return _staff;
    return _staff.where((member) {
      final haystack = [
        member.fullName,
        member.role,
        member.department,
        member.email,
        member.phone,
        member.sourceLabel,
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();
  }

  void _changeSort(_StaffSortField field) {
    setState(() {
      if (_sortField == field) {
        _sortAscending = !_sortAscending;
      } else {
        _sortField = field;
        _sortAscending = true;
      }
    });
  }

  List<_StaffMember> _sortStaff(List<_StaffMember> staff) {
    final sorted = List<_StaffMember>.from(staff);
    sorted.sort((left, right) {
      final comparison = switch (_sortField) {
        _StaffSortField.name => _compareText(left.fullName, right.fullName),
        _StaffSortField.role => _compareText(left.role, right.role),
        _StaffSortField.department => _compareText(
          left.department,
          right.department,
        ),
        _StaffSortField.source => _compareText(
          left.sourceLabel,
          right.sourceLabel,
        ),
        _StaffSortField.status => left.status.index.compareTo(
          right.status.index,
        ),
        _StaffSortField.startDate => _staffDateSortValue(
          left.startDate,
        ).compareTo(_staffDateSortValue(right.startDate)),
      };
      if (comparison != 0) {
        return _sortAscending ? comparison : -comparison;
      }
      return _compareText(left.fullName, right.fullName);
    });
    return sorted;
  }

  Future<void> _loadStaff() async {
    final customSchoolId = widget.customSchoolId?.trim();
    final accessToken = widget.accessToken?.trim();
    if (customSchoolId == null ||
        customSchoolId.isEmpty ||
        accessToken == null ||
        accessToken.isEmpty) {
      if (!mounted) return;
      setState(() {
        _staff = List<_StaffMember>.from(_localEduHireDrafts);
        _staffError = 'School context is not ready. Please sign in again.';
        _isLoadingStaff = false;
      });
      return;
    }

    setState(() {
      _isLoadingStaff = true;
      _staffError = null;
    });

    try {
      final apiClient =
          widget.apiClient ??
          StaffApiClient(
            accessToken: accessToken,
            onRefreshAccessToken: widget.onRefreshAccessToken,
          );
      final results = await Future.wait([
        apiClient.getSchoolStaffUsers(customSchoolId: customSchoolId),
        apiClient.getSchoolStaffProfiles(customSchoolId),
        apiClient
            .getStaffAssignments(customSchoolId)
            .onError((_, __) => const <String, List<String>>{}),
      ]);
      final users = results[0] as List<StaffUserRecord>;
      final profiles = results[1] as List<StaffProfileRecord>;
      final assignmentsByStaffId = results[2] as Map<String, List<String>>;
      final activityRows = await Future.wait(
        users.map((user) async {
          final activity = await apiClient
              .getStaffActivity(user.id)
              .onError((_, __) => const <StaffActivityRecord>[]);
          return (userId: user.id, activity: activity);
        }),
      );
      final activityByUserId = {
        for (final row in activityRows) row.userId: row.activity,
      };
      final profilesByUserId = {
        for (final profile in profiles) profile.userId: profile,
      };
      final nextStaff = [
        ...users.map((user) {
          final profile = profilesByUserId[user.id];
          return _staffFromUserRecord(
            user,
            profile,
            assignmentsByStaffId[profile?.staffId] ?? const [],
            null,
            activityByUserId[user.id] ?? const [],
          );
        }),
        ...profiles
            .where(
              (profile) =>
                  profile.invitationToken.isNotEmpty &&
                  !users.any((user) => user.id == profile.userId),
            )
            .map((profile) => _staffFromInvitationProfile(profile)),
        ..._localEduHireDrafts,
      ];
      if (!mounted) return;
      setState(() {
        _staff = nextStaff;
        _isLoadingStaff = false;
        if (_selectedStaff != null) {
          final selectedId = _selectedStaff!.id;
          _selectedStaff = null;
          for (final staff in nextStaff) {
            if (staff.id == selectedId) {
              _selectedStaff = staff;
              break;
            }
          }
        }
      });
    } on StaffApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _staff = List<_StaffMember>.from(_localEduHireDrafts);
        _staffError = error.message;
        _isLoadingStaff = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _staff = List<_StaffMember>.from(_localEduHireDrafts);
        _staffError = 'Unable to load staff from the server.';
        _isLoadingStaff = false;
      });
    }
  }

  Future<void> _openAddStaff() async {
    widget.onAddStaffRequestConsumed?.call();
    final mode = await showDialog<_AddStaffMode>(
      context: context,
      builder: (context) => const _AddStaffDialog(),
    );
    if (!mounted || mode == null) return;
    if (mode == _AddStaffMode.manual) {
      await _openManualStaffDrawer();
    } else {
      await _openEduHireImportDrawer();
    }
  }

  Future<void> _openManualStaffDrawer() async {
    final customSchoolId = widget.customSchoolId?.trim();
    if (customSchoolId == null || customSchoolId.isEmpty) {
      _showMessage('School context is required before staff can be created.');
      return;
    }
    final created = await showGeneralDialog<_StaffMember>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close add staff form',
      barrierColor: Colors.black.withValues(alpha: .45),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, _, __) => _ManualStaffDrawer(
        customSchoolId: customSchoolId,
        apiClient: _apiClient(),
      ),
      transitionBuilder: (context, animation, _, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
          child: child,
        );
      },
    );
    if (created == null || !mounted) return;
    setState(() {
      _tab = _StaffTab.staffList;
    });
    await _loadStaff();
    if (!mounted) return;
    _showMessage('Staff user and onboarding record created.');
  }

  Future<void> _openEduHireImportDrawer() async {
    final imported = await showGeneralDialog<_StaffMember>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close EduHire import',
      barrierColor: Colors.black.withValues(alpha: .45),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, _, __) => const _EduHireImportDrawer(),
      transitionBuilder: (context, animation, _, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
          child: child,
        );
      },
    );
    if (imported == null || !mounted) return;
    setState(() {
      _localEduHireDrafts.insert(0, imported);
      _staff = [imported, ..._staff.where((staff) => staff.id != imported.id)];
      _tab = _StaffTab.onboarding;
    });
    _showMessage('EduHire candidate imported as a preview draft.');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _resendStaffInvitation(_StaffMember staff) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Resend invitation?'),
        content: Text(
          'A new verification code will be sent to ${staff.fullName}. The previous code will stop working.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep current invitation'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Resend invitation'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await StaffApiClient(
        accessToken: widget.accessToken,
        onRefreshAccessToken: widget.onRefreshAccessToken,
      ).resendStaffInvitation(staff.invitationToken);
      await _loadStaff();
      if (mounted) _showMessage('Invitation sent again.');
    } on StaffApiException catch (error) {
      if (mounted) _showMessage(error.message);
    }
  }

  Future<void> _cancelStaffInvitation(_StaffMember staff) async {
    final schoolId = widget.customSchoolId?.trim() ?? '';
    if (schoolId.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel invitation?'),
        content: Text(
          '${staff.fullName} will no longer be able to activate this invitation. The staff draft will remain available for review.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep invitation'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel invitation'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await StaffApiClient(
        accessToken: widget.accessToken,
        onRefreshAccessToken: widget.onRefreshAccessToken,
      ).cancelStaffInvitation(
        customSchoolId: schoolId,
        invitationToken: staff.invitationToken,
      );
      await _loadStaff();
      if (mounted) _showMessage('Invitation cancelled.');
    } on StaffApiException catch (error) {
      if (mounted) _showMessage(error.message);
    }
  }

  Future<void> _deleteStaffInvitation(_StaffMember staff) async {
    final schoolId = widget.customSchoolId?.trim() ?? '';
    if (schoolId.isEmpty) return;
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete invitation permanently?'),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'The invitation for ${staff.fullName} will be permanently removed. The staff onboarding draft will remain so it can be corrected or invited again.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Reason for deletion',
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep invitation'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) Navigator.pop(context, value);
            },
            child: const Text('Delete permanently'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason == null || reason.isEmpty || !mounted) return;
    try {
      await StaffApiClient(
        accessToken: widget.accessToken,
        onRefreshAccessToken: widget.onRefreshAccessToken,
      ).deleteStaffInvitation(
        customSchoolId: schoolId,
        invitationToken: staff.invitationToken,
        reason: reason,
      );
      setState(() => _selectedStaff = null);
      await _loadStaff();
      if (mounted) _showMessage('Invitation permanently deleted.');
    } on StaffApiException catch (error) {
      if (mounted) _showMessage(error.message);
    }
  }

  _StaffMember _staffFromUserRecord(
    StaffUserRecord user, [
    StaffProfileRecord? profile,
    List<String> assignments = const [],
    StaffFinanceRecord? finance,
    List<StaffActivityRecord> activity = const [],
  ]) {
    final firstName = _clean(user.firstName).isEmpty
        ? _fallbackFirstName(user)
        : _clean(user.firstName);
    final lastName = _clean(user.lastName);
    final role = _formatStaffRoles(user.roles);
    final status = _statusFromAccountStatus(user.accountStatus);
    final category = _categoryForRole(user.role);
    return _StaffMember(
      id: user.id.isEmpty ? user.userName : user.id,
      firstName: firstName,
      lastName: lastName.isEmpty ? '' : lastName,
      role: role,
      primaryRole: user.role,
      userRoles: user.roles,
      department: _clean(profile?.departmentName ?? '').isEmpty
          ? 'Not configured'
          : _clean(profile!.departmentName),
      category: category,
      employmentType: _employmentTypeDisplay(profile?.employmentType),
      contractType: _contractTypeDisplay(profile?.employmentType),
      email: _display(user.email),
      phone: _display(user.phoneNumber),
      dateOfBirth: _formatDate(user.dateOfBirth),
      address: 'Not configured',
      emergencyName: 'Not configured',
      emergencyRelationship: 'Not configured',
      emergencyPhone: 'Not configured',
      startDate: _clean(profile?.startDate ?? '').isNotEmpty
          ? _formatDate(profile!.startDate)
          : _formatDate(user.createdAt),
      status: status,
      sourceLabel: 'School user',
      sourceReference: _display(user.userName),
      color: _colorForRole(user.role),
      assignments: assignments,
      staffProfileId: profile?.staffId ?? '',
      resumes: profile?.resumes ?? const [],
      finance: finance,
      activity: activity,
      invitationToken: profile?.invitationToken ?? '',
      invitationDeliveryStatus: profile?.invitationDeliveryStatus ?? 'NOT_SENT',
      invitationLastSentAt: profile?.invitationLastSentAt ?? '',
      invitationSendCount: profile?.invitationSendCount ?? 0,
      mustChangePassword: user.mustChangePassword,
    );
  }

  _StaffMember _staffFromInvitationProfile(
    StaffProfileRecord profile, [
    StaffFinanceRecord? finance,
  ]) {
    final invitationRoles = profile.invitationRoles;
    final primaryRole = profile.invitationPrimaryRole.isEmpty
        ? (invitationRoles.isEmpty ? '' : invitationRoles.first)
        : profile.invitationPrimaryRole;
    return _StaffMember(
      id: profile.staffId,
      firstName: profile.firstName.isEmpty ? 'Invited' : profile.firstName,
      lastName: profile.lastName,
      role: invitationRoles.isEmpty
          ? (profile.position.isEmpty ? 'Staff' : profile.position)
          : _formatStaffRoles(invitationRoles),
      primaryRole: primaryRole,
      userRoles: invitationRoles,
      department: profile.departmentName.isEmpty
          ? 'Not configured'
          : profile.departmentName,
      category: _categoryForRole(primaryRole),
      employmentType: _employmentTypeDisplay(profile.employmentType),
      contractType: _contractTypeDisplay(profile.employmentType),
      email: _display(profile.email),
      phone: _display(profile.invitationMaskedPhone),
      dateOfBirth: _formatDate(profile.dateOfBirth),
      address: 'Not configured',
      emergencyName: 'Not configured',
      emergencyRelationship: 'Not configured',
      emergencyPhone: 'Not configured',
      startDate: _formatDate(profile.startDate),
      status: profile.invitationStatus.toUpperCase() == 'CANCELLED'
          ? _StaffStatus.inactive
          : _StaffStatus.invited,
      sourceLabel: 'School invitation',
      sourceReference: profile.staffId,
      color: AppColors.green,
      assignments: const [],
      staffProfileId: profile.staffId,
      resumes: profile.resumes,
      finance: finance,
      invitationToken: profile.invitationToken,
      invitationDeliveryStatus: profile.invitationDeliveryStatus,
      invitationLastSentAt: profile.invitationLastSentAt,
      invitationSendCount: profile.invitationSendCount,
    );
  }

  String _employmentTypeDisplay(String? value) {
    final clean = _clean(value ?? '');
    if (clean.isEmpty) return 'Not configured';
    return clean
        .toLowerCase()
        .split('_')
        .map((part) {
          return part.isEmpty
              ? part
              : '${part[0].toUpperCase()}${part.substring(1)}';
        })
        .join('-');
  }

  String _contractTypeDisplay(String? value) {
    final clean = _clean(value ?? '').toUpperCase();
    if (clean.isEmpty) return 'Not configured';
    return clean == 'CONTRACT' ? 'Fixed term' : 'Permanent';
  }

  String _fallbackFirstName(StaffUserRecord user) {
    final userName = _clean(user.userName);
    if (userName.isNotEmpty) return userName;
    final email = _clean(user.email);
    if (email.isNotEmpty) return email.split('@').first;
    return 'Staff';
  }
}

String _clean(String value) => value.trim();

String _display(String value) {
  final clean = _clean(value);
  return clean.isEmpty ? 'Not provided' : clean;
}

String _formatFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kilobytes = bytes / 1024;
  if (kilobytes < 1024) return '${kilobytes.toStringAsFixed(1)} KB';
  return '${(kilobytes / 1024).toStringAsFixed(1)} MB';
}

String _formatRole(String role) {
  return displayRoleName(role);
}

String _formatStaffRoles(Iterable<String> roles) {
  final labels = <String>{};
  for (final role in roles) {
    labels.add(_formatRole(role));
  }
  return labels.isEmpty ? 'Staff' : labels.join(' · ');
}

bool isOptionalStaffReferenceValid({
  required String name,
  required String jobTitle,
  required String organization,
  required String phone,
  required String email,
  required String relationship,
  required String durationKnown,
}) {
  final values = [
    name,
    jobTitle,
    organization,
    phone,
    email,
    relationship,
    durationKnown,
  ].map((value) => value.trim()).toList();
  if (values.every((value) => value.isEmpty)) return true;
  return values.every((value) => value.isNotEmpty) &&
      email.trim().contains('@');
}

_StaffStatus _statusFromAccountStatus(String status) {
  return switch (_clean(status).toUpperCase()) {
    'ACTIVE' => _StaffStatus.active,
    'INVITED' => _StaffStatus.invited,
    'PENDING' => _StaffStatus.passwordSetup,
    'PENDING_REVIEW' || 'PENDING_APPROVAL' => _StaffStatus.pendingReview,
    'SUSPENDED' => _StaffStatus.suspended,
    'INACTIVE' || 'DELETED' => _StaffStatus.inactive,
    _ => _StaffStatus.draft,
  };
}

int _compareText(String left, String right) =>
    left.toLowerCase().compareTo(right.toLowerCase());

DateTime _staffDateSortValue(String value) {
  final iso = DateTime.tryParse(value);
  if (iso != null) return iso;
  final parts = value.trim().split(RegExp(r'\s+'));
  if (parts.length == 3) {
    const months = {
      'jan': 1,
      'feb': 2,
      'mar': 3,
      'apr': 4,
      'may': 5,
      'jun': 6,
      'jul': 7,
      'aug': 8,
      'sep': 9,
      'oct': 10,
      'nov': 11,
      'dec': 12,
    };
    final day = int.tryParse(parts[0]);
    final month = months[parts[1].toLowerCase()];
    final year = int.tryParse(parts[2]);
    if (day != null && month != null && year != null) {
      return DateTime(year, month, day);
    }
  }
  return DateTime(9999);
}

String _categoryForRole(String role) {
  return switch (_clean(role).toUpperCase()) {
    'TEACHER' ||
    'CLASS_TEACHER' ||
    'SUBJECT_TEACHER' ||
    'HEAD_TEACHER' ||
    'ASSISTANT_HEAD_TEACHER' => 'Teaching',
    _ => 'Support',
  };
}

Color _colorForRole(String role) {
  return switch (_clean(role).toUpperCase()) {
    'CLASS_TEACHER' || 'SUBJECT_TEACHER' => AppColors.green,
    'HEAD_TEACHER' || 'ASSISTANT_HEAD_TEACHER' => AppColors.blue,
    'BURSAR' => AppColors.amber,
    'SECRETARY' => AppColors.purple,
    _ => AppColors.green,
  };
}

String _formatDate(String raw) {
  final clean = _clean(raw);
  if (clean.isEmpty) return 'Not provided';
  DateTime? date = DateTime.tryParse(clean.replaceFirst(' ', 'T'));
  if (date == null && clean.startsWith('[') && clean.endsWith(']')) {
    final parts = RegExp(r'\d+')
        .allMatches(clean)
        .map((match) => int.tryParse(match.group(0) ?? ''))
        .whereType<int>()
        .toList();
    if (parts.length >= 3) {
      date = DateTime(parts[0], parts[1], parts[2]);
    }
  }
  if (date == null) return clean;
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

String _formatDateTime(String raw) {
  final date = DateTime.tryParse(raw.trim().replaceFirst(' ', 'T'));
  if (date == null) return _formatDate(raw);
  final local = date.toLocal();
  final hour = local.hour == 0
      ? 12
      : (local.hour > 12 ? local.hour - 12 : local.hour);
  final minutes = local.minute.toString().padLeft(2, '0');
  final period = local.hour >= 12 ? 'PM' : 'AM';
  return '${_formatDate(local.toIso8601String())} at $hour:$minutes $period';
}

String _staffInvitationDeliveryLabel(String value) {
  return switch (value.trim().toUpperCase()) {
    'SENT' => 'Sent',
    'FAILED' => 'Send failed',
    _ => 'Not sent',
  };
}

class _InfoPair extends StatelessWidget {
  const _InfoPair({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 150),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.text,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _StaffHeader extends StatelessWidget {
  const _StaffHeader({required this.onAddStaff});

  final VoidCallback onAddStaff;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Staff Management',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Manage staff records, onboarding drafts, and EduHire imports.',
                style: TextStyle(color: AppColors.muted, fontSize: 15),
              ),
            ],
          ),
        ),
        FilledButton.icon(
          onPressed: onAddStaff,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add staff'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.green,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          ),
        ),
      ],
    );
  }
}

class _StaffMetricRow extends StatelessWidget {
  const _StaffMetricRow({required this.staff});

  final List<_StaffMember> staff;

  @override
  Widget build(BuildContext context) {
    final active = staff.where((item) => item.status == _StaffStatus.active);
    final established = staff.where((item) => !_isStaffOnboarding(item));
    final teaching = established.where((item) => item.category == 'Teaching');
    final nonTeaching = established.where((item) => item.category == 'Support');
    final onboarding = staff.where(_isStaffOnboarding);
    final metrics = [
      _StaffMetric(
        'Active staff',
        active.length.toString(),
        'Ready for school operations',
        Icons.verified_user_rounded,
        AppColors.green,
      ),
      _StaffMetric(
        'Teaching staff',
        teaching.length.toString(),
        'Teachers and academic staff',
        Icons.menu_book_rounded,
        AppColors.blue,
      ),
      _StaffMetric(
        'Support staff',
        nonTeaching.length.toString(),
        'Admin, finance, and operations',
        Icons.badge_rounded,
        AppColors.purple,
      ),
      _StaffMetric(
        'In onboarding',
        onboarding.length.toString(),
        'Draft, invited, or awaiting activation',
        Icons.assignment_turned_in_rounded,
        AppColors.amber,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 960 ? 4 : 2;
        const gap = 14.0;
        final width = (constraints.maxWidth - (columns - 1) * gap) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: metrics
              .map(
                (metric) => SizedBox(width: width, child: _MetricTile(metric)),
              )
              .toList(),
        );
      },
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile(this.metric);

  final _StaffMetric metric;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: metric.color.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(metric.icon, color: metric.color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    metric.label.toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 11,
                      letterSpacing: .7,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    metric.value,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    metric.caption,
                    style: const TextStyle(color: AppColors.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StaffTabs extends StatelessWidget {
  const _StaffTabs({
    required this.selected,
    required this.staffCount,
    required this.onboardingCount,
    required this.onChanged,
  });

  final _StaffTab selected;
  final int staffCount;
  final int onboardingCount;
  final ValueChanged<_StaffTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      children: [
        _TabButton(
          label: 'Staff List',
          count: staffCount,
          countKey: const ValueKey('staff-list-count'),
          icon: Icons.groups_rounded,
          selected: selected == _StaffTab.staffList,
          onTap: () => onChanged(_StaffTab.staffList),
        ),
        _TabButton(
          label: 'Onboarding',
          count: onboardingCount,
          countKey: const ValueKey('staff-onboarding-count'),
          icon: Icons.assignment_ind_rounded,
          selected: selected == _StaffTab.onboarding,
          onTap: () => onChanged(_StaffTab.onboarding),
        ),
      ],
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.count,
    required this.countKey,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final Key countKey;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(selected ? Icons.check_rounded : icon, size: 18),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          const SizedBox(width: 9),
          Container(
            key: countKey,
            constraints: const BoxConstraints(minWidth: 24),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: selected ? Colors.white : AppColors.background,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$count',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected ? AppColors.green : AppColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: selected ? AppColors.green : AppColors.muted,
        backgroundColor: selected ? AppColors.greenSoft : Colors.white,
        side: BorderSide(
          color: selected ? AppColors.green : AppColors.border,
          width: selected ? 1.4 : 1,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _DirectoryPanel extends StatelessWidget {
  const _DirectoryPanel({
    required this.staff,
    required this.query,
    required this.onQueryChanged,
    required this.onOpenStaff,
    required this.currentUserId,
    required this.sortField,
    required this.sortAscending,
    required this.onSort,
  });

  final List<_StaffMember> staff;
  final String query;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<_StaffMember> onOpenStaff;
  final int? currentUserId;
  final _StaffSortField sortField;
  final bool sortAscending;
  final ValueChanged<_StaffSortField> onSort;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _PanelSearch(
            value: query,
            hint: 'Search staff by name, role, department, email, or phone',
            onChanged: onQueryChanged,
            resultCount: staff.length,
            resultLabel: staff.length == 1 ? 'staff member' : 'staff members',
          ),
          const Divider(height: 1, color: AppColors.border),
          LayoutBuilder(
            builder: (context, constraints) {
              const minimumWidth = 1120.0;
              final tableWidth = constraints.maxWidth < minimumWidth
                  ? minimumWidth
                  : constraints.maxWidth;
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: tableWidth,
                  child: Column(
                    children: [
                      _StaffTableHeader(
                        showSource: false,
                        sortField: sortField,
                        sortAscending: sortAscending,
                        onSort: onSort,
                      ),
                      if (staff.isEmpty)
                        const _EmptyPanel(
                          icon: Icons.group_off_rounded,
                          title: 'No staff found',
                          body:
                              'Try a different search term or add a staff member.',
                        )
                      else
                        ...staff.map(
                          (member) => _StaffRow(
                            staff: member,
                            showSource: false,
                            isCurrentUser:
                                member.id == currentUserId?.toString(),
                            onTap: () => onOpenStaff(member),
                          ),
                        ),
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

class _OnboardingPanel extends StatelessWidget {
  const _OnboardingPanel({
    required this.staff,
    required this.hasOnboardingRecords,
    required this.query,
    required this.onQueryChanged,
    required this.onOpenStaff,
    required this.sortField,
    required this.sortAscending,
    required this.onSort,
  });

  final List<_StaffMember> staff;
  final bool hasOnboardingRecords;
  final String query;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<_StaffMember> onOpenStaff;
  final _StaffSortField sortField;
  final bool sortAscending;
  final ValueChanged<_StaffSortField> onSort;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _PanelSearch(
            value: query,
            hint: 'Search staff onboarding',
            onChanged: onQueryChanged,
            resultCount: staff.length,
            resultLabel: staff.length == 1 ? 'person' : 'people',
          ),
          const Divider(height: 1, color: AppColors.border),
          LayoutBuilder(
            builder: (context, constraints) {
              const minimumWidth = 1240.0;
              final tableWidth = constraints.maxWidth < minimumWidth
                  ? minimumWidth
                  : constraints.maxWidth;
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: tableWidth,
                  child: Column(
                    children: [
                      _StaffTableHeader(
                        showSource: true,
                        sortField: sortField,
                        sortAscending: sortAscending,
                        onSort: onSort,
                      ),
                      if (staff.isEmpty)
                        _EmptyPanel(
                          icon: Icons.assignment_late_outlined,
                          title: hasOnboardingRecords && query.trim().isNotEmpty
                              ? 'No onboarding matches'
                              : 'No staff currently onboarding',
                          body: hasOnboardingRecords && query.trim().isNotEmpty
                              ? 'No onboarding records match "${query.trim()}". Clear the search or try another name.'
                              : 'Drafts, invitations, verification progress, and EduHire imports will appear here.',
                        )
                      else
                        ...staff.map(
                          (member) => _StaffRow(
                            staff: member,
                            showSource: true,
                            onTap: () => onOpenStaff(member),
                          ),
                        ),
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

class _StaffLoadingPanel extends StatelessWidget {
  const _StaffLoadingPanel();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 42),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
            SizedBox(width: 14),
            Text(
              'Loading staff from the school platform...',
              style: TextStyle(
                color: AppColors.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StaffErrorPanel extends StatelessWidget {
  const _StaffErrorPanel({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 44),
        child: Column(
          children: [
            const Icon(Icons.cloud_off_rounded, color: AppColors.red, size: 44),
            const SizedBox(height: 14),
            const Text(
              'Unable to load staff',
              style: TextStyle(
                color: AppColors.text,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted, fontSize: 15),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
              style: FilledButton.styleFrom(backgroundColor: AppColors.green),
            ),
          ],
        ),
      ),
    );
  }
}

class _StaffInlineError extends StatelessWidget {
  const _StaffInlineError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.red.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.red.withValues(alpha: .25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.red),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _PanelSearch extends StatelessWidget {
  const _PanelSearch({
    required this.value,
    required this.hint,
    required this.onChanged,
    required this.resultCount,
    required this.resultLabel,
  });

  final String value;
  final String hint;
  final ValueChanged<String> onChanged;
  final int resultCount;
  final String resultLabel;

  @override
  Widget build(BuildContext context) {
    final searchField = TextField(
      controller: TextEditingController(text: value)
        ..selection = TextSelection.collapsed(offset: value.length),
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: value.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear search',
                onPressed: () => onChanged(''),
                icon: const Icon(Icons.close_rounded),
              ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 16,
        ),
      ),
    );
    final count = Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.greenSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.green.withValues(alpha: .2)),
      ),
      child: Text(
        '$resultCount $resultLabel',
        style: const TextStyle(
          color: AppColors.green,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 640) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [searchField, const SizedBox(height: 10), count],
            );
          }
          return Row(
            children: [
              Expanded(child: searchField),
              const SizedBox(width: 12),
              count,
            ],
          );
        },
      ),
    );
  }
}

class _StaffTableHeader extends StatelessWidget {
  const _StaffTableHeader({
    required this.showSource,
    required this.sortField,
    required this.sortAscending,
    required this.onSort,
  });

  final bool showSource;
  final _StaffSortField sortField;
  final bool sortAscending;
  final ValueChanged<_StaffSortField> onSort;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF7F9F9),
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: _SortableHeader(
              label: 'Staff member',
              field: _StaffSortField.name,
              activeField: sortField,
              ascending: sortAscending,
              onSort: onSort,
            ),
          ),
          Expanded(
            flex: 2,
            child: _SortableHeader(
              label: 'Role',
              field: _StaffSortField.role,
              activeField: sortField,
              ascending: sortAscending,
              onSort: onSort,
            ),
          ),
          Expanded(
            flex: 2,
            child: _SortableHeader(
              label: 'Department',
              field: _StaffSortField.department,
              activeField: sortField,
              ascending: sortAscending,
              onSort: onSort,
            ),
          ),
          if (showSource)
            Expanded(
              child: _SortableHeader(
                label: 'Source',
                field: _StaffSortField.source,
                activeField: sortField,
                ascending: sortAscending,
                onSort: onSort,
              ),
            ),
          Expanded(
            child: _SortableHeader(
              label: 'Status',
              field: _StaffSortField.status,
              activeField: sortField,
              ascending: sortAscending,
              onSort: onSort,
            ),
          ),
          Expanded(
            child: _SortableHeader(
              label: 'Start date',
              field: _StaffSortField.startDate,
              activeField: sortField,
              ascending: sortAscending,
              onSort: onSort,
            ),
          ),
          const SizedBox(width: 88, child: _HeaderLabel('Actions')),
        ],
      ),
    );
  }
}

class _SortableHeader extends StatelessWidget {
  const _SortableHeader({
    required this.label,
    required this.field,
    required this.activeField,
    required this.ascending,
    required this.onSort,
  });

  final String label;
  final _StaffSortField field;
  final _StaffSortField activeField;
  final bool ascending;
  final ValueChanged<_StaffSortField> onSort;

  @override
  Widget build(BuildContext context) {
    final active = field == activeField;
    return Tooltip(
      message: active
          ? 'Sort ${ascending ? 'descending' : 'ascending'} by $label'
          : 'Sort by $label',
      child: InkWell(
        key: ValueKey('staff-sort-${field.name}'),
        onTap: () => onSort(field),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: _HeaderLabel(label, active: active)),
              const SizedBox(width: 4),
              Icon(
                active
                    ? (ascending
                          ? Icons.arrow_upward_rounded
                          : Icons.arrow_downward_rounded)
                    : Icons.unfold_more_rounded,
                size: 15,
                color: active ? AppColors.green : AppColors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderLabel extends StatelessWidget {
  const _HeaderLabel(this.text, {this.active = false});

  final String text;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: active ? AppColors.green : AppColors.muted,
        fontSize: 11,
        letterSpacing: .7,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _StaffRow extends StatelessWidget {
  const _StaffRow({
    required this.staff,
    required this.showSource,
    this.isCurrentUser = false,
    required this.onTap,
  });

  final _StaffMember staff;
  final bool showSource;
  final bool isCurrentUser;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 88),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _InitialsBadge(name: staff.fullName, color: staff.color),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                staff.fullName,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.text,
                                ),
                              ),
                            ),
                            if (isCurrentUser) ...[
                              const SizedBox(width: 8),
                              const _CurrentUserBadge(),
                            ],
                          ],
                        ),
                        const SizedBox(height: 5),
                        _StaffContactLine(
                          icon: Icons.mail_outline_rounded,
                          value: staff.email,
                        ),
                        const SizedBox(height: 2),
                        _StaffContactLine(
                          icon: Icons.phone_outlined,
                          value: staff.phone,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                staff.role,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                staff.department,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.muted),
              ),
            ),
            if (showSource)
              Expanded(child: _SourceBadge(source: staff.sourceLabel)),
            Expanded(child: _StatusBadge(status: staff.status)),
            Expanded(
              child: Text(
                staff.startDate,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.muted),
              ),
            ),
            SizedBox(
              width: 88,
              child: OutlinedButton(
                onPressed: onTap,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  side: const BorderSide(color: AppColors.border),
                ),
                child: const Text('Open'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StaffContactLine extends StatelessWidget {
  const _StaffContactLine({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: AppColors.muted),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class _CurrentUserBadge extends StatelessWidget {
  const _CurrentUserBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('current-staff-user-badge'),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.greenSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.green.withValues(alpha: .28)),
      ),
      child: const Text(
        'Me',
        style: TextStyle(
          color: AppColors.green,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _StaffProfilePage extends StatefulWidget {
  const _StaffProfilePage({
    required this.staff,
    required this.customSchoolId,
    required this.apiClient,
    required this.onBack,
    this.onEdit,
    this.onManageRoles,
    this.onSuspend,
    this.onRequirePasswordChange,
    this.onApprove,
    this.onReject,
    this.onReactivate,
    this.onDeactivate,
    this.onResendInvitation,
    this.onCancelInvitation,
    this.onDeleteInvitation,
    required this.leaveContent,
  });

  final _StaffMember staff;
  final String customSchoolId;
  final StaffApiClient apiClient;
  final Widget leaveContent;
  final VoidCallback onBack;
  final VoidCallback? onEdit;
  final VoidCallback? onManageRoles;
  final VoidCallback? onSuspend;
  final VoidCallback? onRequirePasswordChange;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback? onReactivate;
  final VoidCallback? onDeactivate;
  final VoidCallback? onResendInvitation;
  final VoidCallback? onCancelInvitation;
  final VoidCallback? onDeleteInvitation;

  @override
  State<_StaffProfilePage> createState() => _StaffProfilePageState();
}

class _StaffProfilePageState extends State<_StaffProfilePage> {
  _StaffProfileTab _tab = _StaffProfileTab.profile;

  @override
  Widget build(BuildContext context) {
    final staff = widget.staff;
    final profileSummary = [
      staff.role,
      if (staff.department != 'Not configured') staff.department,
      if (staff.employmentType != 'Not configured') staff.employmentType,
    ].join(' · ');
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextButton.icon(
            onPressed: widget.onBack,
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Back to staff'),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final identity = Row(
                    children: [
                      _InitialsBadge(
                        name: staff.fullName,
                        color: staff.color,
                        size: 64,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 12,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  staff.fullName,
                                  style: const TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.text,
                                  ),
                                ),
                                _StatusBadge(status: staff.status),
                                if (staff.mustChangePassword)
                                  const _SoftBadge(
                                    label: 'Password change required',
                                    color: AppColors.amber,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              profileSummary,
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                  final actions = Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      if (widget.onEdit != null)
                        OutlinedButton.icon(
                          onPressed: widget.onEdit,
                          icon: const Icon(
                            Icons.person_outline_rounded,
                            size: 18,
                          ),
                          label: const Text('Edit profile'),
                        ),
                      OutlinedButton.icon(
                        onPressed: widget.onManageRoles,
                        icon: const Icon(
                          Icons.admin_panel_settings_outlined,
                          size: 18,
                        ),
                        label: const Text('Manage roles'),
                      ),
                      _StaffAccountActionsMenu(
                        staff: staff,
                        onRequirePasswordChange: widget.onRequirePasswordChange,
                        onApprove: widget.onApprove,
                        onReject: widget.onReject,
                        onSuspend: widget.onSuspend,
                        onReactivate: widget.onReactivate,
                        onDeactivate: widget.onDeactivate,
                        onResendInvitation: widget.onResendInvitation,
                        onCancelInvitation: widget.onCancelInvitation,
                        onDeleteInvitation: widget.onDeleteInvitation,
                      ),
                    ],
                  );
                  if (constraints.maxWidth < 880) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [identity, const SizedBox(height: 18), actions],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: identity),
                      const SizedBox(width: 18),
                      actions,
                    ],
                  );
                },
              ),
            ),
          ),
          if (staff.status == _StaffStatus.invited) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 24,
                  runSpacing: 10,
                  children: [
                    _InfoPair(
                      label: 'Invitation',
                      value: _staffInvitationDeliveryLabel(
                        staff.invitationDeliveryStatus,
                      ),
                    ),
                    _InfoPair(
                      label: 'Send attempts',
                      value: '${staff.invitationSendCount}',
                    ),
                    _InfoPair(
                      label: 'Last sent',
                      value: staff.invitationLastSentAt.isEmpty
                          ? 'Not sent'
                          : _formatDateTime(staff.invitationLastSentAt),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 18),
          _StaffProfileTabs(
            selected: _tab,
            onChanged: (tab) => setState(() => _tab = tab),
          ),
          const SizedBox(height: 14),
          _profileContent(staff),
        ],
      ),
    );
  }

  Widget _profileContent(_StaffMember staff) {
    switch (_tab) {
      case _StaffProfileTab.profile:
        return _ProfileTab(staff: staff);
      case _StaffProfileTab.documents:
        return _DocumentsTab(
          staff: staff,
          onView: _viewDocument,
          onDownload: _downloadDocument,
        );
      case _StaffProfileTab.leave:
        return widget.leaveContent;
      case _StaffProfileTab.activity:
        return _ActivityTab(staff: staff);
    }
  }

  Future<void> _viewDocument(StaffResumeRecord document) async {
    if (!_canAccessDocument(document)) return;
    prepareDocumentWindow();
    try {
      final url = await widget.apiClient.getStaffDocumentAccessUrl(
        customSchoolId: widget.customSchoolId,
        documentId: document.documentId,
        download: false,
      );
      await openDocumentUrl(url);
    } on StaffApiException catch (error) {
      if (mounted) _showDocumentMessage(error.message);
    } catch (_) {
      if (mounted) {
        _showDocumentMessage('Could not open this document securely.');
      }
    }
  }

  Future<void> _downloadDocument(StaffResumeRecord document) async {
    if (!_canAccessDocument(document)) return;
    try {
      final url = await widget.apiClient.getStaffDocumentAccessUrl(
        customSchoolId: widget.customSchoolId,
        documentId: document.documentId,
        download: true,
      );
      await downloadDocumentUrl(url, document.fileName);
      if (mounted) _showDocumentMessage('Download started.');
    } on StaffApiException catch (error) {
      if (mounted) _showDocumentMessage(error.message);
    } catch (_) {
      if (mounted) {
        _showDocumentMessage('Could not download this document securely.');
      }
    }
  }

  bool _canAccessDocument(StaffResumeRecord document) {
    if (widget.customSchoolId.isEmpty || document.documentId.trim().isEmpty) {
      _showDocumentMessage('The secure document link is unavailable.');
      return false;
    }
    return true;
  }

  void _showDocumentMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _StaffAccountActionsMenu extends StatelessWidget {
  const _StaffAccountActionsMenu({
    required this.staff,
    required this.onRequirePasswordChange,
    required this.onApprove,
    required this.onReject,
    required this.onSuspend,
    required this.onReactivate,
    required this.onDeactivate,
    required this.onResendInvitation,
    required this.onCancelInvitation,
    required this.onDeleteInvitation,
  });

  final _StaffMember staff;
  final VoidCallback? onRequirePasswordChange;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback? onSuspend;
  final VoidCallback? onReactivate;
  final VoidCallback? onDeactivate;
  final VoidCallback? onResendInvitation;
  final VoidCallback? onCancelInvitation;
  final VoidCallback? onDeleteInvitation;

  @override
  Widget build(BuildContext context) {
    final cancelledInvitation =
        staff.status == _StaffStatus.inactive &&
        staff.invitationToken.isNotEmpty;
    final actions = <_StaffAccountAction>[
      if (staff.status == _StaffStatus.invited) ...[
        if (onResendInvitation != null)
          _StaffAccountAction(
            label: 'Resend invitation',
            icon: Icons.forward_to_inbox_rounded,
            onSelected: onResendInvitation!,
          ),
        if (onCancelInvitation != null)
          _StaffAccountAction(
            label: 'Cancel invitation',
            icon: Icons.cancel_outlined,
            onSelected: onCancelInvitation!,
          ),
        if (onDeleteInvitation != null)
          _StaffAccountAction(
            label: 'Delete permanently',
            icon: Icons.delete_outline_rounded,
            onSelected: onDeleteInvitation!,
            destructive: true,
          ),
      ],
      if (staff.status == _StaffStatus.pendingReview) ...[
        if (onApprove != null)
          _StaffAccountAction(
            label: 'Approve account',
            icon: Icons.check_circle_outline_rounded,
            onSelected: onApprove!,
          ),
        if (onReject != null)
          _StaffAccountAction(
            label: 'Reject account',
            icon: Icons.cancel_outlined,
            onSelected: onReject!,
            destructive: true,
          ),
      ],
      if (staff.status == _StaffStatus.active) ...[
        if (onRequirePasswordChange != null)
          _StaffAccountAction(
            key: ValueKey('staff-require-password-change-${staff.id}'),
            label: 'Require password change',
            icon: Icons.lock_reset_rounded,
            onSelected: onRequirePasswordChange!,
          ),
        if (onSuspend != null)
          _StaffAccountAction(
            label: 'Suspend account',
            icon: Icons.pause_circle_outline_rounded,
            onSelected: onSuspend!,
          ),
        if (onDeactivate != null)
          _StaffAccountAction(
            label: 'Deactivate and archive',
            icon: Icons.archive_outlined,
            onSelected: onDeactivate!,
            destructive: true,
          ),
      ],
      if (staff.status == _StaffStatus.suspended) ...[
        if (onReactivate != null)
          _StaffAccountAction(
            label: 'Reactivate account',
            icon: Icons.restart_alt_rounded,
            onSelected: onReactivate!,
          ),
        if (onDeactivate != null)
          _StaffAccountAction(
            label: 'Deactivate and archive',
            icon: Icons.archive_outlined,
            onSelected: onDeactivate!,
            destructive: true,
          ),
      ],
      if (cancelledInvitation && onDeleteInvitation != null)
        _StaffAccountAction(
          label: 'Delete permanently',
          icon: Icons.delete_outline_rounded,
          onSelected: onDeleteInvitation!,
          destructive: true,
        ),
    ];
    if (actions.isEmpty) return const SizedBox.shrink();

    return MenuAnchor(
      menuChildren: [
        for (final action in actions)
          MenuItemButton(
            key: action.key,
            onPressed: action.onSelected,
            leadingIcon: Icon(
              action.icon,
              size: 19,
              color: action.destructive ? AppColors.red : AppColors.text,
            ),
            child: Text(
              action.label,
              style: TextStyle(
                color: action.destructive ? AppColors.red : AppColors.text,
              ),
            ),
          ),
      ],
      builder: (context, controller, child) => OutlinedButton.icon(
        onPressed: controller.isOpen ? controller.close : controller.open,
        icon: const Icon(Icons.manage_accounts_outlined, size: 18),
        label: const Text('Account actions'),
      ),
    );
  }
}

class _StaffAccountAction {
  const _StaffAccountAction({
    this.key,
    required this.label,
    required this.icon,
    required this.onSelected,
    this.destructive = false,
  });

  final Key? key;
  final String label;
  final IconData icon;
  final VoidCallback onSelected;
  final bool destructive;
}

class _RoleSelectionResult {
  const _RoleSelectionResult({required this.primaryRole, required this.roles});

  final String primaryRole;
  final List<String> roles;
}

class _EditStaffResult {
  const _EditStaffResult({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phoneNumber,
  });

  final String firstName;
  final String lastName;
  final String email;
  final String phoneNumber;
}

class _EditStaffDialog extends StatefulWidget {
  const _EditStaffDialog({required this.staff});

  final _StaffMember staff;

  @override
  State<_EditStaffDialog> createState() => _EditStaffDialogState();
}

class _EditStaffDialogState extends State<_EditStaffDialog> {
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  String? _error;

  @override
  void initState() {
    super.initState();
    _firstName = TextEditingController(text: widget.staff.firstName);
    _lastName = TextEditingController(text: widget.staff.lastName);
    _email = TextEditingController(
      text: widget.staff.email == 'Not provided' ? '' : widget.staff.email,
    );
    _phone = TextEditingController(
      text: widget.staff.phone == 'Not provided' ? '' : widget.staff.phone,
    );
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _save() {
    final firstName = _firstName.text.trim();
    final lastName = _lastName.text.trim();
    final email = _email.text.trim();
    final digits = _phone.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (firstName.isEmpty || lastName.isEmpty) {
      setState(() => _error = 'First and last name are required.');
      return;
    }
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }
    if (digits.length < 10 || digits.length > 15) {
      setState(
        () => _error = 'Enter a valid phone number with 10 to 15 digits.',
      );
      return;
    }
    Navigator.pop(
      context,
      _EditStaffResult(
        firstName: firstName,
        lastName: lastName,
        email: email,
        phoneNumber: _phone.text.trim().startsWith('+')
            ? _phone.text.trim().replaceAll(' ', '')
            : digits,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit staff profile'),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _firstName,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'First name',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _lastName,
                      decoration: const InputDecoration(labelText: 'Last name'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _error!,
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
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save changes')),
      ],
    );
  }
}

class _ManageRolesDialog extends StatefulWidget {
  const _ManageRolesDialog({required this.primaryRole, required this.roles});

  final String primaryRole;
  final List<String> roles;

  @override
  State<_ManageRolesDialog> createState() => _ManageRolesDialogState();
}

class _ManageRolesDialogState extends State<_ManageRolesDialog> {
  late final List<(String, String)> _options;
  late String _primaryRole;
  late Set<String> _roles;

  @override
  void initState() {
    super.initState();
    final incomingPrimary = widget.primaryRole.trim().toUpperCase();
    final incomingRoles = widget.roles
        .map((role) => role.trim().toUpperCase())
        .toSet();
    final teacherRole =
        incomingPrimary == 'SUBJECT_TEACHER' &&
            !incomingRoles.contains('CLASS_TEACHER')
        ? 'SUBJECT_TEACHER'
        : 'CLASS_TEACHER';
    _options = [
      ('ADMINISTRATOR', 'Administrator'),
      ('HEADMASTER', 'Headmaster'),
      ('HEAD_TEACHER', 'Head teacher'),
      ('ASSISTANT_HEAD_TEACHER', 'Assistant head teacher'),
      (teacherRole, 'Teacher'),
      ('BURSAR', 'Bursar'),
      ('SECRETARY', 'Secretary'),
    ];
    _primaryRole = incomingPrimary;
    if (!_options.any((option) => option.$1 == _primaryRole)) {
      _primaryRole = incomingRoles.firstWhere(
        (role) => _options.any((option) => option.$1 == role),
        orElse: () => teacherRole,
      );
    }
    _roles = incomingRoles;
    _roles.add(_primaryRole);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Manage staff roles'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'The primary role is the workspace shown immediately after sign-in. Additional roles are available through the workspace switcher.',
                style: TextStyle(color: AppColors.muted, height: 1.4),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.green.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.green.withValues(alpha: .24),
                  ),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.auto_awesome_outlined, color: AppColors.green),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Class and subject responsibilities are managed through Classes & Sections. Staff see one Teacher workspace containing their assigned classes and subjects.',
                        style: TextStyle(height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _primaryRole,
                decoration: const InputDecoration(labelText: 'Primary role'),
                items: _options
                    .map(
                      (option) => DropdownMenuItem(
                        value: option.$1,
                        child: Text(option.$2),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() {
                  if (value == null) return;
                  _primaryRole = value;
                  _roles.add(value);
                }),
              ),
              const SizedBox(height: 12),
              ..._options.map((option) {
                final isPrimary = option.$1 == _primaryRole;
                final assignmentManaged = option.$1 == 'SUBJECT_TEACHER';
                return CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(option.$2),
                  subtitle: isPrimary
                      ? Text(
                          assignmentManaged
                              ? 'Primary workspace · subject assignments managed automatically'
                              : 'Primary workspace',
                        )
                      : assignmentManaged
                      ? const Text('Subject assignments managed automatically')
                      : null,
                  value: _roles.contains(option.$1),
                  onChanged: isPrimary || assignmentManaged
                      ? null
                      : (selected) => setState(() {
                          if (selected == true) {
                            _roles.add(option.$1);
                          } else {
                            _roles.remove(option.$1);
                          }
                        }),
                );
              }),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            _RoleSelectionResult(
              primaryRole: _primaryRole,
              roles: [
                _primaryRole,
                ..._roles.where((role) => role != _primaryRole),
              ],
            ),
          ),
          child: const Text('Save roles'),
        ),
      ],
    );
  }
}

class _StaffProfileTabs extends StatelessWidget {
  const _StaffProfileTabs({required this.selected, required this.onChanged});

  final _StaffProfileTab selected;
  final ValueChanged<_StaffProfileTab> onChanged;

  @override
  Widget build(BuildContext context) {
    final tabs = [
      (_StaffProfileTab.profile, 'Profile', Icons.person_outline_rounded),
      (_StaffProfileTab.documents, 'Documents', Icons.folder_outlined),
      (_StaffProfileTab.leave, 'Leave', Icons.event_available_outlined),
      (_StaffProfileTab.activity, 'Account history', Icons.history_rounded),
    ];
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: tabs
              .map(
                (tab) => _ProfileTabButton(
                  label: tab.$2,
                  icon: tab.$3,
                  selected: selected == tab.$1,
                  onTap: () => onChanged(tab.$1),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _ProfileTabButton extends StatelessWidget {
  const _ProfileTabButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 13, 16, 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? AppColors.green : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? AppColors.green : AppColors.muted,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: selected ? AppColors.green : AppColors.muted,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab({required this.staff});

  final _StaffMember staff;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _OverviewTab(staff: staff),
        const SizedBox(height: 14),
        _EmploymentTab(staff: staff),
        const SizedBox(height: 14),
        _AssignmentsTab(staff: staff),
      ],
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.staff});

  final _StaffMember staff;

  @override
  Widget build(BuildContext context) {
    final emergencyContact =
        staff.emergencyName == 'Not configured' &&
            staff.emergencyRelationship == 'Not configured' &&
            staff.emergencyPhone == 'Not configured'
        ? 'Not configured'
        : '${staff.emergencyName}\n${staff.emergencyRelationship} · ${staff.emergencyPhone}';
    return _ProfileSectionCard(
      title: 'Contact and personal details',
      description: 'Contact information and essential personal records.',
      child: _ProfileGrid(
        cards: [
          _InfoCard('Email', staff.email, Icons.mail_outline_rounded),
          _InfoCard('Phone', staff.phone, Icons.phone_rounded),
          _InfoCard('Date of birth', staff.dateOfBirth, Icons.cake_rounded),
          _InfoCard('Address', staff.address, Icons.location_on_outlined),
          _InfoCard(
            'Emergency contact',
            emergencyContact,
            Icons.emergency_rounded,
          ),
          _InfoCard(
            'Source',
            staff.sourceLabel == 'EduHire'
                ? 'Imported from EduHire\n${staff.sourceReference}'
                : 'Created manually in SMA',
            Icons.cloud_sync_rounded,
          ),
        ],
      ),
    );
  }
}

class _EmploymentTab extends StatelessWidget {
  const _EmploymentTab({required this.staff});

  final _StaffMember staff;

  @override
  Widget build(BuildContext context) {
    return _ProfileSectionCard(
      title: 'Employment details',
      description: 'Role, department, contract, and start information.',
      child: _ProfileGrid(
        cards: [
          _InfoCard('Role', staff.role, Icons.work_outline_rounded),
          _InfoCard('Department', staff.department, Icons.apartment_rounded),
          _InfoCard(
            'Employment type',
            staff.employmentType,
            Icons.badge_rounded,
          ),
          _InfoCard('Contract type', staff.contractType, Icons.description),
          _InfoCard('Expected start date', staff.startDate, Icons.event),
          _InfoCard('Category', staff.category, Icons.category_rounded),
        ],
      ),
    );
  }
}

class _ProfileSectionCard extends StatelessWidget {
  const _ProfileSectionCard({
    required this.title,
    required this.description,
    required this.child,
  });

  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(description, style: const TextStyle(color: AppColors.muted)),
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }
}

class _AssignmentsTab extends StatelessWidget {
  const _AssignmentsTab({required this.staff});

  final _StaffMember staff;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Assignments',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            if (staff.assignments.isEmpty)
              const _EmptyPanel(
                icon: Icons.assignment_outlined,
                title: 'No assignments yet',
                body:
                    'Class, subject, or administrative assignments will appear here.',
              )
            else
              ...staff.assignments.map(
                (assignment) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.greenSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.assignment_turned_in_rounded,
                      color: AppColors.green,
                    ),
                  ),
                  title: Text(assignment),
                  subtitle: const Text('Current academic year'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DocumentsTab extends StatefulWidget {
  const _DocumentsTab({
    required this.staff,
    required this.onView,
    required this.onDownload,
  });

  final _StaffMember staff;
  final Future<void> Function(StaffResumeRecord document) onView;
  final Future<void> Function(StaffResumeRecord document) onDownload;

  @override
  State<_DocumentsTab> createState() => _DocumentsTabState();
}

class _DocumentsTabState extends State<_DocumentsTab> {
  String? _busyAction;

  Future<void> _run(
    String action,
    StaffResumeRecord document,
    Future<void> Function(StaffResumeRecord document) callback,
  ) async {
    if (_busyAction != null) return;
    setState(() => _busyAction = '$action:${document.documentId}');
    try {
      await callback(document);
    } finally {
      if (mounted) setState(() => _busyAction = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Documents',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            if (widget.staff.resumes.isEmpty)
              const _EmptyPanel(
                icon: Icons.folder_open_rounded,
                title: 'No documents uploaded',
                body:
                    'Resumes and other employment documents uploaded for this staff member will appear here.',
              )
            else ...[
              ...widget.staff.resumes.map(
                (resume) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.greenSoft,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final identity = Row(
                        children: [
                          const Icon(
                            Icons.description_outlined,
                            color: AppColors.green,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  resume.fileName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  '${_formatFileSize(resume.fileSize)} · ${resume.status.toLowerCase()}',
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                      final actions = Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const _SoftBadge(
                            label: 'Resume',
                            color: AppColors.green,
                          ),
                          OutlinedButton.icon(
                            key: ValueKey(
                              'staff-document-view-${resume.documentId}',
                            ),
                            onPressed: _busyAction == null
                                ? () => _run('view', resume, widget.onView)
                                : null,
                            icon: _busyAction == 'view:${resume.documentId}'
                                ? const SizedBox.square(
                                    dimension: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.visibility_outlined),
                            label: const Text('View'),
                          ),
                          FilledButton.icon(
                            key: ValueKey(
                              'staff-document-download-${resume.documentId}',
                            ),
                            onPressed: _busyAction == null
                                ? () => _run(
                                    'download',
                                    resume,
                                    widget.onDownload,
                                  )
                                : null,
                            icon: _busyAction == 'download:${resume.documentId}'
                                ? const SizedBox.square(
                                    dimension: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.download_rounded),
                            label: const Text('Download'),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.green,
                            ),
                          ),
                        ],
                      );
                      if (constraints.maxWidth < 720) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            identity,
                            const SizedBox(height: 12),
                            actions,
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(child: identity),
                          const SizedBox(width: 16),
                          actions,
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActivityTab extends StatelessWidget {
  const _ActivityTab({required this.staff});

  final _StaffMember staff;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Account history',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            const Text(
              'Administrative changes to this staff account are recorded here.',
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 12),
            if (staff.activity.isEmpty)
              const _EmptyPanel(
                icon: Icons.history_rounded,
                title: 'No account history yet',
                body:
                    'Role, access, suspension, reactivation, and other account changes will appear here.',
              )
            else
              ...staff.activity.map(
                (activity) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.history_rounded),
                  title: Text(
                    activity.description.isEmpty
                        ? _formatRole(activity.actionType)
                        : activity.description,
                  ),
                  subtitle: Text(
                    '${activity.actorName} · ${_formatDateTime(activity.timestamp)}',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProfileGrid extends StatelessWidget {
  const _ProfileGrid({required this.cards});

  final List<_InfoCard> cards;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 960
            ? 3
            : constraints.maxWidth >= 560
            ? 2
            : 1;
        const gap = 12.0;
        final width = (constraints.maxWidth - (columns - 1) * gap) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: cards
              .map((card) => SizedBox(width: width, child: card))
              .toList(),
        );
      },
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard(this.label, this.value, this.icon);

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 92),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.green.withValues(alpha: .09),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, color: AppColors.green, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label.toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 11,
                      letterSpacing: .7,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    value,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddStaffDialog extends StatelessWidget {
  const _AddStaffDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Add staff',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: AppColors.text,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Start a manual staff record or import a hired candidate from EduHire.',
                          style: TextStyle(color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: _AddModeCard(
                      icon: Icons.edit_note_rounded,
                      title: 'Add manually',
                      body:
                          'Create a staff draft from school recruitment or walk-in records.',
                      onTap: () => Navigator.pop(context, _AddStaffMode.manual),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _AddModeCard(
                      icon: Icons.cloud_download_rounded,
                      title: 'Import from EduHire',
                      body:
                          'Use EduHire school, job, candidate, application, and DOB to pull a hired candidate.',
                      onTap: () =>
                          Navigator.pop(context, _AddStaffMode.eduhire),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddModeCard extends StatelessWidget {
  const _AddModeCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF8FAFA),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.greenSoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: AppColors.green),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                body,
                style: const TextStyle(color: AppColors.muted, height: 1.35),
              ),
              const SizedBox(height: 16),
              const Row(
                children: [
                  Text(
                    'Continue',
                    style: TextStyle(
                      color: AppColors.green,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(width: 6),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 17,
                    color: AppColors.green,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ManualStaffDrawer extends StatefulWidget {
  const _ManualStaffDrawer({
    required this.customSchoolId,
    required this.apiClient,
  });

  final String customSchoolId;
  final StaffApiClient apiClient;

  @override
  State<_ManualStaffDrawer> createState() => _ManualStaffDrawerState();
}

class _ManualStaffDrawerState extends State<_ManualStaffDrawer> {
  final _firstName = TextEditingController();
  final _middleName = TextEditingController();
  final _lastName = TextEditingController();
  final _dateOfBirth = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _startDate = TextEditingController();
  final _bankName = TextEditingController();
  final _bankBranch = TextEditingController();
  final _accountName = TextEditingController();
  final _accountNumber = TextEditingController();
  final _confirmAccountNumber = TextEditingController();
  final _mobileMoneyNetwork = TextEditingController();
  final _mobileMoneyNumber = TextEditingController();
  final _confirmMobileMoneyNumber = TextEditingController();
  final _mobileMoneyRegisteredName = TextEditingController();
  final List<_ReferenceForm> _references = [];

  int _step = 0;
  StaffJobTitleOption? _jobTitle;
  String? _employmentType;
  String _paymentMethod = 'ADD_LATER';
  StaffLookupOption? _department;
  String? _staffId;
  String? _invitationToken;
  String? _invitationMaskedPhone;
  bool _loadingLookups = true;
  bool _saving = false;
  String? _error;
  List<StaffLookupOption> _departments = const [];
  List<StaffJobTitleOption> _jobTitles = const [];
  PlatformFile? _resume;

  @override
  void initState() {
    super.initState();
    _loadLookups();
  }

  @override
  void dispose() {
    _firstName.dispose();
    _middleName.dispose();
    _lastName.dispose();
    _dateOfBirth.dispose();
    _email.dispose();
    _phone.dispose();
    _startDate.dispose();
    _bankName.dispose();
    _bankBranch.dispose();
    _accountName.dispose();
    _accountNumber.dispose();
    _confirmAccountNumber.dispose();
    _mobileMoneyNetwork.dispose();
    _mobileMoneyNumber.dispose();
    _confirmMobileMoneyNumber.dispose();
    _mobileMoneyRegisteredName.dispose();
    for (final reference in _references) {
      reference.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _RightDrawerScaffold(
      title: 'Add staff manually',
      subtitle: 'Step ${_step + 1} of 5 — ${_stepTitle(_step)}',
      footer: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _saving
                  ? null
                  : _step == 0
                  ? () => Navigator.pop(context)
                  : () => setState(() => _step -= 1),
              child: Text(_step == 0 ? 'Cancel' : 'Back'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.icon(
              onPressed: _saving || _loadingLookups ? null : _continue,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      _step == 4
                          ? Icons.check_rounded
                          : Icons.arrow_forward_rounded,
                    ),
              label: Text(_step == 4 ? 'Finish staff' : 'Continue'),
              style: FilledButton.styleFrom(backgroundColor: AppColors.green),
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepProgress(currentStep: _step),
          const SizedBox(height: 16),
          if (_error != null) ...[
            _DrawerError(message: _error!),
            const SizedBox(height: 14),
          ],
          if (_loadingLookups)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: CircularProgressIndicator(),
              ),
            )
          else
            _stepContent(),
        ],
      ),
    );
  }

  Widget _stepContent() {
    return switch (_step) {
      0 => _identityStep(),
      1 => _employmentStep(),
      2 => _paymentAccountStep(),
      3 => _resumeStep(),
      _ => _referencesStep(),
    };
  }

  Widget _identityStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _DrawerSectionTitle('Invitation identity'),
        const Text(
          'The school records the staff details and sends a restricted SMS invitation. The staff member verifies their own information, chooses their permanent password, and decides whether to connect any possible existing account.',
          style: TextStyle(color: AppColors.muted, height: 1.35),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _DrawerField(
                controller: _firstName,
                label: 'First name *',
                hint: 'e.g. Abena',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _DrawerField(
                controller: _middleName,
                label: 'Middle name',
                hint: 'Optional',
              ),
            ),
          ],
        ),
        _DrawerField(
          controller: _lastName,
          label: 'Last name *',
          hint: 'e.g. Mensah',
        ),
        _DateDrawerField(
          controller: _dateOfBirth,
          label: 'Date of birth (optional)',
          onPick: () => _pickDate(_dateOfBirth, lastDate: DateTime.now()),
        ),
        Row(
          children: [
            Expanded(
              child: _DrawerField(
                controller: _email,
                label: 'Email (optional)',
                hint: 'name@school.edu.gh',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _DrawerField(
                controller: _phone,
                label: 'Phone *',
                hint: '+233241234567',
              ),
            ),
          ],
        ),
        DropdownButtonFormField<StaffJobTitleOption>(
          key: const Key('staff-job-title'),
          value: _jobTitle,
          decoration: const InputDecoration(labelText: 'Job title *'),
          items: _jobTitles
              .map(
                (title) =>
                    DropdownMenuItem(value: title, child: Text(title.name)),
              )
              .toList(),
          onChanged: (value) => setState(() => _jobTitle = value),
        ),
        if (_jobTitle != null) ...[
          const SizedBox(height: 8),
          Text(
            'Default authority: ${_jobTitle!.authorityName}. Additional or individual access can be assigned safely in Settings.',
            style: const TextStyle(color: AppColors.muted, height: 1.35),
          ),
        ],
        const SizedBox(height: 12),
        const Text(
          'The staff member will receive an SMS code and create their own global username and permanent password.',
          style: TextStyle(color: AppColors.muted, height: 1.35),
        ),
      ],
    );
  }

  Widget _employmentStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _DrawerSectionTitle('Employment details'),
        DropdownButtonFormField<StaffLookupOption>(
          value: _department,
          decoration: const InputDecoration(labelText: 'Department *'),
          items: _departments
              .map(
                (department) => DropdownMenuItem(
                  value: department,
                  child: Text(department.name),
                ),
              )
              .toList(),
          onChanged: (value) => setState(() => _department = value),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _employmentType,
          decoration: const InputDecoration(
            labelText: 'Employment type (optional)',
            hintText: 'Not specified',
          ),
          items: const [
            DropdownMenuItem(value: 'FULL_TIME', child: Text('Full-time')),
            DropdownMenuItem(value: 'PART_TIME', child: Text('Part-time')),
            DropdownMenuItem(value: 'CONTRACT', child: Text('Contract')),
            DropdownMenuItem(value: 'TEMPORARY', child: Text('Temporary')),
            DropdownMenuItem(value: 'CASUAL', child: Text('Casual')),
          ],
          onChanged: (value) => setState(() => _employmentType = value),
        ),
        _DateDrawerField(
          controller: _startDate,
          label: 'Expected start date *',
          onPick: () => _pickDate(_startDate),
        ),
      ],
    );
  }

  Widget _paymentAccountStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _DrawerSectionTitle('Salary payment account'),
        const Text(
          'Record where this staff member should be paid. Salary, tax, pension, allowances, and deductions are configured later in the dedicated Payroll workspace.',
          style: TextStyle(color: AppColors.muted, height: 1.35),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              key: const Key('staff-payment-bank'),
              label: const Text('Bank account'),
              selected: _paymentMethod == 'BANK',
              onSelected: (_) => setState(() => _paymentMethod = 'BANK'),
            ),
            ChoiceChip(
              key: const Key('staff-payment-momo'),
              label: const Text('Mobile Money'),
              selected: _paymentMethod == 'MOBILE_MONEY',
              onSelected: (_) =>
                  setState(() => _paymentMethod = 'MOBILE_MONEY'),
            ),
            ChoiceChip(
              key: const Key('staff-payment-later'),
              label: const Text('Add later'),
              selected: _paymentMethod == 'ADD_LATER',
              onSelected: (_) => setState(() => _paymentMethod = 'ADD_LATER'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (_paymentMethod == 'BANK') ...[
          _DrawerField(
            key: const Key('staff-bank-name'),
            controller: _bankName,
            label: 'Bank name *',
            hint: 'e.g. GCB Bank',
          ),
          _DrawerField(
            controller: _bankBranch,
            label: 'Branch',
            hint: 'Optional',
          ),
          _DrawerField(
            controller: _accountName,
            label: 'Account name *',
            hint: 'Name registered with the bank',
          ),
          Row(
            children: [
              Expanded(
                child: _DrawerField(
                  key: const Key('staff-account-number'),
                  controller: _accountNumber,
                  label: 'Account number *',
                  hint: 'Enter account number',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DrawerField(
                  controller: _confirmAccountNumber,
                  label: 'Confirm account number *',
                  hint: 'Re-enter account number',
                ),
              ),
            ],
          ),
        ] else if (_paymentMethod == 'MOBILE_MONEY') ...[
          _DrawerField(
            key: const Key('staff-momo-network'),
            controller: _mobileMoneyNetwork,
            label: 'Network *',
            hint: 'MTN MoMo, Telecel Cash, or AT Money',
          ),
          _DrawerField(
            controller: _mobileMoneyRegisteredName,
            label: 'Registered account name *',
            hint: 'Name registered to the wallet',
          ),
          Row(
            children: [
              Expanded(
                child: _DrawerField(
                  key: const Key('staff-momo-number'),
                  controller: _mobileMoneyNumber,
                  label: 'Mobile Money number *',
                  hint: '024 000 0000',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DrawerField(
                  controller: _confirmMobileMoneyNumber,
                  label: 'Confirm number *',
                  hint: 'Re-enter number',
                ),
              ),
            ],
          ),
        ] else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.greenSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'You can finish staff onboarding now and add the payment account from Payroll later.',
              style: TextStyle(color: AppColors.green, height: 1.35),
            ),
          ),
      ],
    );
  }

  Widget _resumeStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _DrawerSectionTitle('Resume document'),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFA),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              const Icon(Icons.description_outlined, color: AppColors.green),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _resume == null
                      ? 'Upload the staff resume or CV.'
                      : _resume!.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _pickResume,
                icon: const Icon(Icons.upload_file_rounded),
                label: Text(_resume == null ? 'Choose file' : 'Change'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Accepted formats: PDF, DOC, DOCX, or RTF. Maximum file size is controlled by the backend.',
          style: TextStyle(color: AppColors.muted),
        ),
      ],
    );
  }

  Widget _referencesStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _DrawerSectionTitle('Employment references'),
        const Text(
          'References are optional. Add one when the school wants to record a referee for this staff member.',
          style: TextStyle(color: AppColors.muted),
        ),
        const SizedBox(height: 14),
        ...List.generate(
          _references.length,
          (index) => _ReferenceCard(
            index: index,
            reference: _references[index],
            canRemove: true,
            onRemove: () => setState(() {
              _references.removeAt(index).dispose();
            }),
          ),
        ),
        OutlinedButton.icon(
          onPressed: _references.length >= 5
              ? null
              : () => setState(() => _references.add(_ReferenceForm())),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add reference'),
        ),
      ],
    );
  }

  Future<void> _loadLookups() async {
    setState(() {
      _loadingLookups = true;
      _error = null;
    });
    try {
      final results = await Future.wait<dynamic>([
        widget.apiClient.getDepartments(widget.customSchoolId),
        widget.apiClient.getJobTitles(widget.customSchoolId),
      ]);
      if (!mounted) return;
      setState(() {
        _departments = (results[0] as List<StaffLookupOption>)
            .where((item) => item.id.isNotEmpty && item.name.isNotEmpty)
            .toList();
        _jobTitles = (results[1] as List<StaffJobTitleOption>)
            .where((item) => item.id.isNotEmpty && item.name.isNotEmpty)
            .toList();
        _loadingLookups = false;
      });
    } on StaffApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loadingLookups = false;
      });
    }
  }

  Future<void> _continue() async {
    setState(() => _error = null);
    final validation = _validateStep();
    if (validation != null) {
      setState(() => _error = validation);
      return;
    }

    setState(() => _saving = true);
    try {
      switch (_step) {
        case 0:
          await _createUserIfNeeded();
        case 1:
          await _initiateStaffIfNeeded();
        case 2:
          await _savePaymentAccount();
        case 3:
          await _uploadResume();
        default:
          await _saveReferencesAndFinish();
          return;
      }
      if (!mounted) return;
      setState(() {
        _saving = false;
        _step += 1;
      });
    } on StaffApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error.message;
      });
    }
  }

  String? _validateStep() {
    if (_step == 0) {
      if (_firstName.text.trim().isEmpty ||
          _lastName.text.trim().isEmpty ||
          _phone.text.trim().isEmpty ||
          _jobTitle == null) {
        return 'Complete the required staff identity fields.';
      }
      if (_email.text.trim().isNotEmpty && !_email.text.contains('@')) {
        return 'Enter a valid email address.';
      }
      final digits = _phone.text.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.length < 10 || digits.length > 15) {
        return 'Enter a valid phone number with 10 to 15 digits.';
      }
    }
    if (_step == 1) {
      if (_department == null || _startDate.text.trim().isEmpty) {
        return 'Complete the employment details before continuing.';
      }
    }
    if (_step == 2) {
      if (_staffId == null) return 'Start staff onboarding first.';
      if (_paymentMethod == 'BANK') {
        if (_bankName.text.trim().isEmpty ||
            _accountName.text.trim().isEmpty ||
            _accountNumber.text.trim().isEmpty) {
          return 'Complete the required bank account details.';
        }
        if (_accountNumber.text.replaceAll(' ', '') !=
            _confirmAccountNumber.text.replaceAll(' ', '')) {
          return 'The bank account numbers do not match.';
        }
      }
      if (_paymentMethod == 'MOBILE_MONEY') {
        if (_mobileMoneyNetwork.text.trim().isEmpty ||
            _mobileMoneyRegisteredName.text.trim().isEmpty ||
            _mobileMoneyNumber.text.trim().isEmpty) {
          return 'Complete the required Mobile Money details.';
        }
        if (_normalisePhone(_mobileMoneyNumber.text) !=
            _normalisePhone(_confirmMobileMoneyNumber.text)) {
          return 'The Mobile Money numbers do not match.';
        }
      }
    }
    if (_step == 3 && _resume == null) {
      return 'Upload the staff resume before continuing.';
    }
    if (_step == 4) {
      for (final reference in _references) {
        if (!reference.isValid) {
          return 'Complete the reference you started or remove it before finishing.';
        }
      }
    }
    return null;
  }

  Future<void> _createUserIfNeeded() async {
    // Access accounts are created by the invitee after SMS verification.
    // Step 1 only validates the school-supplied identity data.
  }

  Future<void> _initiateStaffIfNeeded() async {
    if (_staffId != null && _staffId!.isNotEmpty) return;
    final result = await widget.apiClient.initiateOnboarding(
      body: {
        'customSchoolId': widget.customSchoolId,
        'firstName': _firstName.text.trim(),
        if (_middleName.text.trim().isNotEmpty)
          'middleName': _middleName.text.trim(),
        'lastName': _lastName.text.trim(),
        if (_dateOfBirth.text.trim().isNotEmpty)
          'dateOfBirth': _dateOfBirth.text.trim(),
        if (_email.text.trim().isNotEmpty) 'email': _email.text.trim(),
        'phoneNumber': _normalisePhone(_phone.text),
        'jobTitleId': int.parse(_jobTitle!.id),
        'primaryRole': _jobTitle!.baseRole,
        'roles': [_jobTitle!.baseRole],
        'position': _jobTitle!.name,
        'departmentId': _department!.id,
        if (_employmentType != null) 'employmentType': _employmentType,
        'startDate': _startDate.text.trim(),
      },
    );
    if (result.staffId.isEmpty) {
      throw const StaffApiException(
        'Staff onboarding started, but the backend did not return a staff ID.',
      );
    }
    _staffId = result.staffId;
    _invitationToken = result.invitationToken;
    _invitationMaskedPhone = result.invitationMaskedPhone;
  }

  Future<void> _savePaymentAccount() async {
    if (_paymentMethod == 'ADD_LATER') return;
    await widget.apiClient.savePaymentAccount(
      customSchoolId: widget.customSchoolId,
      staffId: _staffId!,
      body: {
        'paymentMethod': _paymentMethod,
        if (_paymentMethod == 'BANK') ...{
          'bankName': _bankName.text.trim(),
          'bankBranch': _bankBranch.text.trim(),
          'accountName': _accountName.text.trim(),
          'accountNumber': _accountNumber.text.trim(),
        },
        if (_paymentMethod == 'MOBILE_MONEY') ...{
          'mobileMoneyNetwork': _mobileMoneyNetwork.text.trim(),
          'mobileMoneyNumber': _normalisePhone(_mobileMoneyNumber.text),
          'mobileMoneyRegisteredName': _mobileMoneyRegisteredName.text.trim(),
        },
      },
    );
  }

  Future<void> _uploadResume() async {
    final file = _resume!;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      throw const StaffApiException('Could not read the selected resume file.');
    }
    await widget.apiClient.uploadResume(
      customSchoolId: widget.customSchoolId,
      staffId: _staffId!,
      bytes: bytes,
      fileName: file.name,
    );
  }

  Future<void> _saveReferencesAndFinish() async {
    final completedReferences = _references
        .where((reference) => reference.hasAnyValue)
        .toList();
    for (final reference in completedReferences) {
      await widget.apiClient.createEmploymentReference(
        staffId: _staffId!,
        body: reference.toJson(),
      );
    }
    if (!mounted) return;
    final roleLabel = _jobTitle?.name ?? 'Staff';
    Navigator.pop(
      context,
      _StaffMember(
        id: _staffId!,
        firstName: _firstName.text.trim(),
        lastName: _lastName.text.trim(),
        role: roleLabel,
        department: _department?.name ?? 'Unassigned',
        category: _jobTitle?.baseRole.contains('TEACHER') == true
            ? 'Teaching'
            : 'Support',
        employmentType: _employmentTypeLabel,
        contractType: _employmentType == 'CONTRACT'
            ? 'Fixed term'
            : _employmentType == null
            ? 'Not specified'
            : 'Permanent',
        email: _email.text.trim(),
        phone: _phone.text.trim(),
        dateOfBirth: _dateOfBirth.text.trim(),
        address: 'Not provided',
        emergencyName: 'Not provided',
        emergencyRelationship: 'Emergency contact',
        emergencyPhone: 'Not provided',
        startDate: _startDate.text.trim(),
        status: _StaffStatus.draft,
        sourceLabel: 'Manual',
        sourceReference: _invitationToken?.isNotEmpty == true
            ? 'Invitation sent to ${_invitationMaskedPhone ?? 'staff phone'}'
            : 'Manual staff invitation',
        color: AppColors.green,
        assignments: const [],
      ),
    );
  }

  Future<void> _pickDate(
    TextEditingController controller, {
    DateTime? lastDate,
  }) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: lastDate == null
          ? now
          : DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(1940),
      lastDate: lastDate ?? DateTime(now.year + 5),
    );
    if (picked == null) return;
    controller.text = _dateOnly(picked);
  }

  Future<void> _pickResume() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'doc', 'docx', 'rtf'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    setState(() => _resume = result.files.single);
  }

  String? _stepTitle(int step) {
    return const [
      'Staff login',
      'Employment details',
      'Payment account',
      'Resume upload',
      'References',
    ][step];
  }

  String _normalisePhone(String value) {
    final trimmed = value.trim().replaceAll(' ', '');
    if (trimmed.startsWith('+')) return trimmed;
    return trimmed.replaceAll(RegExp(r'[^0-9]'), '');
  }

  String get _employmentTypeLabel {
    return switch (_employmentType) {
      'FULL_TIME' => 'Full-time',
      'PART_TIME' => 'Part-time',
      'CONTRACT' => 'Contract',
      'TEMPORARY' => 'Temporary',
      'CASUAL' => 'Casual',
      _ => 'Not specified',
    };
  }

  String _dateOnly(DateTime date) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)}';
  }
}

class _StepProgress extends StatelessWidget {
  const _StepProgress({required this.currentStep});

  final int currentStep;

  static const _labels = [
    'Login',
    'Employment',
    'Payment account',
    'Resume',
    'References',
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(_labels.length, (index) {
        final complete = index < currentStep;
        final active = index == currentStep;
        final color = complete || active ? AppColors.green : AppColors.muted;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: complete || active ? AppColors.greenSoft : Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: complete || active ? AppColors.green : AppColors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                complete ? Icons.check_rounded : Icons.circle_outlined,
                size: 15,
                color: color,
              ),
              const SizedBox(width: 6),
              Text(
                _labels[index],
                style: TextStyle(
                  color: active ? AppColors.green : color,
                  fontWeight: active ? FontWeight.w900 : FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _DrawerError extends StatelessWidget {
  const _DrawerError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Color(0xFFDC2626),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF991B1B),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateDrawerField extends StatelessWidget {
  const _DateDrawerField({
    required this.controller,
    required this.label,
    required this.onPick,
  });

  final TextEditingController controller;
  final String label;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        readOnly: true,
        onTap: onPick,
        decoration: InputDecoration(
          labelText: label,
          hintText: 'YYYY-MM-DD',
          suffixIcon: IconButton(
            onPressed: onPick,
            icon: const Icon(Icons.calendar_today_rounded),
          ),
        ),
      ),
    );
  }
}

class _ReferenceForm {
  final referenceName = TextEditingController();
  final referenceJobTitle = TextEditingController();
  final referenceOrganization = TextEditingController();
  final referencePhoneNumber = TextEditingController();
  final referenceEmail = TextEditingController();
  final relationshipToApplicant = TextEditingController();
  final durationKnown = TextEditingController();
  bool canBeContacted = true;

  bool get hasAnyValue => [
    referenceName,
    referenceJobTitle,
    referenceOrganization,
    referencePhoneNumber,
    referenceEmail,
    relationshipToApplicant,
    durationKnown,
  ].any((controller) => controller.text.trim().isNotEmpty);

  bool get isValid => isOptionalStaffReferenceValid(
    name: referenceName.text,
    jobTitle: referenceJobTitle.text,
    organization: referenceOrganization.text,
    phone: referencePhoneNumber.text,
    email: referenceEmail.text,
    relationship: relationshipToApplicant.text,
    durationKnown: durationKnown.text,
  );

  Map<String, dynamic> toJson() {
    return {
      'referenceName': referenceName.text.trim(),
      'referenceJobTitle': referenceJobTitle.text.trim(),
      'referenceOrganization': referenceOrganization.text.trim(),
      'referencePhoneNumber': referencePhoneNumber.text.trim(),
      'referenceEmail': referenceEmail.text.trim(),
      'relationshipToApplicant': relationshipToApplicant.text.trim(),
      'durationKnown': durationKnown.text.trim(),
      'canBeContacted': canBeContacted,
    };
  }

  void dispose() {
    referenceName.dispose();
    referenceJobTitle.dispose();
    referenceOrganization.dispose();
    referencePhoneNumber.dispose();
    referenceEmail.dispose();
    relationshipToApplicant.dispose();
    durationKnown.dispose();
  }
}

class _ReferenceCard extends StatefulWidget {
  const _ReferenceCard({
    required this.index,
    required this.reference,
    required this.canRemove,
    required this.onRemove,
  });

  final int index;
  final _ReferenceForm reference;
  final bool canRemove;
  final VoidCallback onRemove;

  @override
  State<_ReferenceCard> createState() => _ReferenceCardState();
}

class _ReferenceCardState extends State<_ReferenceCard> {
  @override
  Widget build(BuildContext context) {
    final reference = widget.reference;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Reference ${widget.index + 1}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
              if (widget.canRemove)
                IconButton(
                  onPressed: widget.onRemove,
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
            ],
          ),
          _DrawerField(
            controller: reference.referenceName,
            label: 'Full name *',
            hint: 'e.g. Kojo Mensah',
          ),
          Row(
            children: [
              Expanded(
                child: _DrawerField(
                  controller: reference.referenceJobTitle,
                  label: 'Job title *',
                  hint: 'Head teacher',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DrawerField(
                  controller: reference.referenceOrganization,
                  label: 'Organization *',
                  hint: 'Previous school',
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: _DrawerField(
                  controller: reference.referencePhoneNumber,
                  label: 'Phone *',
                  hint: '+233241234567',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DrawerField(
                  controller: reference.referenceEmail,
                  label: 'Email *',
                  hint: 'name@example.com',
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: _DrawerField(
                  controller: reference.relationshipToApplicant,
                  label: 'Relationship *',
                  hint: 'Former supervisor',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DrawerField(
                  controller: reference.durationKnown,
                  label: 'Duration known *',
                  hint: '3 years',
                ),
              ),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: reference.canBeContacted,
            activeColor: AppColors.green,
            title: const Text('Can be contacted'),
            onChanged: (value) =>
                setState(() => reference.canBeContacted = value),
          ),
        ],
      ),
    );
  }
}

class _EduHireImportDrawer extends StatefulWidget {
  const _EduHireImportDrawer();

  @override
  State<_EduHireImportDrawer> createState() => _EduHireImportDrawerState();
}

class _EduHireImportDrawerState extends State<_EduHireImportDrawer> {
  final _schoolId = TextEditingController(text: 'SCH-1001');
  final _jobId = TextEditingController(text: 'JOB-1001');
  final _candidateId = TextEditingController(text: 'CAND-1001');
  final _applicationId = TextEditingController(text: 'APP-1001');
  final _dob = TextEditingController(text: '1991-04-12');
  bool _candidateFound = false;

  @override
  Widget build(BuildContext context) {
    return _RightDrawerScaffold(
      title: 'Import from EduHire',
      subtitle:
          'Verify the hired candidate using EduHire identifiers, then create a staff draft.',
      footer: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.icon(
              onPressed: _candidateFound ? _createDraft : null,
              icon: const Icon(Icons.cloud_download_rounded),
              label: const Text('Create staff draft'),
              style: FilledButton.styleFrom(backgroundColor: AppColors.green),
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _DrawerSectionTitle('EduHire lookup'),
          _DrawerField(
            controller: _schoolId,
            label: 'EduHire school ID',
            hint: 'SCH-1001',
          ),
          Row(
            children: [
              Expanded(
                child: _DrawerField(
                  controller: _jobId,
                  label: 'Job ID',
                  hint: 'JOB-1001',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DrawerField(
                  controller: _candidateId,
                  label: 'Candidate ID',
                  hint: 'CAND-1001',
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: _DrawerField(
                  controller: _applicationId,
                  label: 'Application ID',
                  hint: 'APP-1001',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DrawerField(
                  controller: _dob,
                  label: 'Candidate DOB',
                  hint: 'YYYY-MM-DD',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => setState(() => _candidateFound = true),
            icon: const Icon(Icons.search_rounded),
            label: const Text('Find candidate'),
          ),
          if (_candidateFound) ...[
            const SizedBox(height: 18),
            const _EduHirePreviewCard(),
          ],
        ],
      ),
    );
  }

  void _createDraft() {
    Navigator.pop(
      context,
      _eduhireStaff.copyWith(
        id: 'eduhire-${DateTime.now().millisecondsSinceEpoch}',
      ),
    );
  }
}

class _EduHirePreviewCard extends StatelessWidget {
  const _EduHirePreviewCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.greenSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.green.withValues(alpha: .25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _InitialsBadge(
                name: 'Abena Mensah',
                color: AppColors.green,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Abena Mensah',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Mathematics Teacher · Full-time',
                      style: TextStyle(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              const _SoftBadge(label: 'Hired', color: AppColors.green),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Screening checks are complete. Full interview notes, messages, and recruitment documents remain in EduHire.',
            style: TextStyle(color: AppColors.text, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _RightDrawerScaffold extends StatelessWidget {
  const _RightDrawerScaffold({
    required this.title,
    required this.subtitle,
    required this.child,
    required this.footer,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Material(
        color: Colors.white,
        child: SizedBox(
          width: 520,
          height: double.infinity,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 18, 14, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppColors.text,
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
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.border),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(22),
                  child: child,
                ),
              ),
              const Divider(height: 1, color: AppColors.border),
              Padding(padding: const EdgeInsets.all(16), child: footer),
            ],
          ),
        ),
      ),
    );
  }
}

class _DrawerSectionTitle extends StatelessWidget {
  const _DrawerSectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: AppColors.muted,
          fontSize: 12,
          letterSpacing: .8,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _DrawerField extends StatelessWidget {
  const _DrawerField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
  });

  final TextEditingController controller;
  final String label;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(labelText: label, hintText: hint),
      ),
    );
  }
}

class _InitialsBadge extends StatelessWidget {
  const _InitialsBadge({
    required this.name,
    required this.color,
    this.size = 46,
  });

  final String name;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initials = name
        .split(' ')
        .where((part) => part.trim().isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(size >= 70 ? 18 : 12),
      ),
      child: Text(
        initials.isEmpty ? 'ST' : initials,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: size >= 70 ? 24 : 13,
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final _StaffStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      _StaffStatus.active => AppColors.green,
      _StaffStatus.invited => AppColors.blue,
      _StaffStatus.passwordSetup => AppColors.blue,
      _StaffStatus.pendingReview => AppColors.amber,
      _StaffStatus.draft => AppColors.muted,
      _StaffStatus.suspended => AppColors.red,
      _StaffStatus.inactive => AppColors.red,
    };
    final label = switch (status) {
      _StaffStatus.active => 'Active',
      _StaffStatus.invited => 'Invited',
      _StaffStatus.passwordSetup => 'Password setup',
      _StaffStatus.pendingReview => 'Pending review',
      _StaffStatus.draft => 'Draft',
      _StaffStatus.suspended => 'Suspended',
      _StaffStatus.inactive => 'Deactivated',
    };
    return _SoftBadge(label: label, color: color);
  }
}

class _SourceBadge extends StatelessWidget {
  const _SourceBadge({required this.source});

  final String source;

  @override
  Widget build(BuildContext context) {
    final color = source == 'EduHire' ? AppColors.blue : AppColors.green;
    return _SoftBadge(label: source, color: color);
  }
}

class _SoftBadge extends StatelessWidget {
  const _SoftBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: DecoratedBox(
        key: ValueKey('staff-soft-badge-$label'),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(26),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 38, color: AppColors.muted),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 5),
            Text(body, style: const TextStyle(color: AppColors.muted)),
          ],
        ),
      ),
    );
  }
}

enum _StaffTab { staffList, onboarding }

enum _StaffSortField { name, role, department, source, status, startDate }

enum _StaffProfileTab { profile, documents, leave, activity }

enum _AddStaffMode { manual, eduhire }

enum _StaffStatus {
  active,
  invited,
  passwordSetup,
  pendingReview,
  draft,
  suspended,
  inactive,
}

bool _isStaffOnboarding(_StaffMember staff) => switch (staff.status) {
  _StaffStatus.draft ||
  _StaffStatus.invited ||
  _StaffStatus.passwordSetup ||
  _StaffStatus.pendingReview => true,
  _StaffStatus.inactive => staff.sourceLabel == 'School invitation',
  _StaffStatus.active || _StaffStatus.suspended => false,
};

class _StaffMetric {
  const _StaffMetric(
    this.label,
    this.value,
    this.caption,
    this.icon,
    this.color,
  );

  final String label;
  final String value;
  final String caption;
  final IconData icon;
  final Color color;
}

class _StaffMember {
  const _StaffMember({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.role,
    this.primaryRole = '',
    this.userRoles = const [],
    required this.department,
    required this.category,
    required this.employmentType,
    required this.contractType,
    required this.email,
    required this.phone,
    required this.dateOfBirth,
    required this.address,
    required this.emergencyName,
    required this.emergencyRelationship,
    required this.emergencyPhone,
    required this.startDate,
    required this.status,
    required this.sourceLabel,
    required this.sourceReference,
    required this.color,
    required this.assignments,
    this.staffProfileId = '',
    this.resumes = const [],
    this.finance,
    this.activity = const [],
    this.invitationToken = '',
    this.invitationDeliveryStatus = 'NOT_SENT',
    this.invitationLastSentAt = '',
    this.invitationSendCount = 0,
    this.mustChangePassword = false,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String role;
  final String primaryRole;
  final List<String> userRoles;
  final String department;
  final String category;
  final String employmentType;
  final String contractType;
  final String email;
  final String phone;
  final String dateOfBirth;
  final String address;
  final String emergencyName;
  final String emergencyRelationship;
  final String emergencyPhone;
  final String startDate;
  final _StaffStatus status;
  final String sourceLabel;
  final String sourceReference;
  final Color color;
  final List<String> assignments;
  final String staffProfileId;
  final List<StaffResumeRecord> resumes;
  final StaffFinanceRecord? finance;
  final List<StaffActivityRecord> activity;
  final String invitationToken;
  final String invitationDeliveryStatus;
  final String invitationLastSentAt;
  final int invitationSendCount;
  final bool mustChangePassword;

  String get fullName => '$firstName $lastName';

  _StaffMember copyWith({String? id}) {
    return _StaffMember(
      id: id ?? this.id,
      firstName: firstName,
      lastName: lastName,
      role: role,
      primaryRole: primaryRole,
      userRoles: userRoles,
      department: department,
      category: category,
      employmentType: employmentType,
      contractType: contractType,
      email: email,
      phone: phone,
      dateOfBirth: dateOfBirth,
      address: address,
      emergencyName: emergencyName,
      emergencyRelationship: emergencyRelationship,
      emergencyPhone: emergencyPhone,
      startDate: startDate,
      status: status,
      sourceLabel: sourceLabel,
      sourceReference: sourceReference,
      color: color,
      assignments: assignments,
      staffProfileId: staffProfileId,
      resumes: resumes,
      finance: finance,
      activity: activity,
      invitationToken: invitationToken,
      invitationDeliveryStatus: invitationDeliveryStatus,
      invitationLastSentAt: invitationLastSentAt,
      invitationSendCount: invitationSendCount,
      mustChangePassword: mustChangePassword,
    );
  }
}

const _eduhireStaff = _StaffMember(
  id: 'eduhire-1001',
  firstName: 'Abena',
  lastName: 'Mensah',
  role: 'Mathematics Teacher',
  department: 'Mathematics',
  category: 'Teaching',
  employmentType: 'Full-time',
  contractType: 'Permanent',
  email: 'abena.mensah@example.com',
  phone: '+233 24 000 0000',
  dateOfBirth: '12 Apr 1991',
  address: 'Accra, Ghana',
  emergencyName: 'Kojo Mensah',
  emergencyRelationship: 'Brother',
  emergencyPhone: '+233 24 111 2222',
  startDate: '1 Sep 2026',
  status: _StaffStatus.draft,
  sourceLabel: 'EduHire',
  sourceReference: 'APP-1001 · CAND-1001',
  color: AppColors.green,
  assignments: ['Pending class teacher assignment'],
);
