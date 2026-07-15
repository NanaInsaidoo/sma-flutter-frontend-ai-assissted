import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../data/platform_api_client.dart';
import '../data/platform_repository.dart';
import '../domain/platform_models.dart';
import 'document_opener.dart';
import 'school_creation_screen.dart';

class SchoolDetailScreen extends StatefulWidget {
  const SchoolDetailScreen({
    super.key,
    required this.school,
    required this.repository,
    required this.accessToken,
    required this.onRefreshAccessToken,
    required this.onSchoolUpdated,
    required this.onBack,
    required this.onViewAccountManager,
    required this.canViewAccountManagerDetails,
  });

  final ManagedSchool school;
  final PlatformRepository repository;
  final String? accessToken;
  final Future<String?> Function() onRefreshAccessToken;
  final VoidCallback onSchoolUpdated;
  final VoidCallback onBack;
  final ValueChanged<String> onViewAccountManager;
  final bool canViewAccountManagerDetails;

  @override
  State<SchoolDetailScreen> createState() => _SchoolDetailScreenState();
}

class _SchoolDetailScreenState extends State<SchoolDetailScreen> {
  int _tab = 0;
  int? _preparingEditStep;
  bool _preparingReassign = false;
  bool _approvingSchool = false;
  SchoolStatus? _changingSchoolStatus;
  SchoolUserInfo? _selectedUser;
  late ManagedSchool _school;
  late Future<_SchoolProfileData> _profileFuture;

  @override
  void initState() {
    super.initState();
    _school = widget.school;
    _profileFuture = _loadProfile();
  }

  @override
  void didUpdateWidget(covariant SchoolDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.school.code != widget.school.code ||
        oldWidget.school.accountManager != widget.school.accountManager ||
        oldWidget.school.accountManagerId != widget.school.accountManagerId) {
      _school = widget.school;
    }
  }

  Future<_SchoolProfileData> _loadProfile() async {
    final results = await Future.wait<dynamic>([
      widget.repository.getSchoolOnboardingRecord(_school.code),
      widget.repository.getSchoolDocuments(_school.code),
      widget.repository.getSchoolGradeLevels(_school.code),
    ]);
    return _SchoolProfileData(
      record: results[0] as SchoolOnboardingRecord,
      documents: results[1] as List<SchoolDocumentInfo>,
      gradeLevels: results[2] as List<SchoolGradeLevelInfo>,
    );
  }

  void _retryProfile() {
    setState(() => _profileFuture = _loadProfile());
  }

  Future<void> _openReassignDialog() async {
    if (_preparingReassign) return;
    setState(() => _preparingReassign = true);
    try {
      final reasons = await widget.repository.getSchoolAssignmentReasons();
      if (!mounted) return;
      final reassigned = await showDialog<AccountManagerProfile>(
        context: context,
        barrierDismissible: false,
        builder: (context) => _ReassignSchoolDialog(
          school: _school,
          reasons: reasons,
          repository: widget.repository,
        ),
      );
      if (reassigned == null || !mounted) return;
      setState(() {
        _school = _school.copyWith(
          accountManager: reassigned.name,
          accountManagerId: reassigned.id,
        );
      });
      widget.onSchoolUpdated();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_school.name} was reassigned successfully.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not prepare reassignment. ${error.toString()}'),
        ),
      );
    } finally {
      if (mounted) setState(() => _preparingReassign = false);
    }
  }

  Future<void> _approveSchool() async {
    if (_approvingSchool) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Approve school?'),
        content: Text(
          '${_school.name} will be marked as approved and can proceed as an active school on the platform.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.verified_rounded, size: 18),
            label: const Text('Approve school'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _approvingSchool = true);
    try {
      await widget.repository.changeSchoolStatus(
        customSchoolId: _school.code,
        status: SchoolStatus.approved,
        reason: 'School registration reviewed and approved',
      );
      if (!mounted) return;
      setState(() {
        _school = _school.copyWith(status: SchoolStatus.approved, progress: 1);
        _profileFuture = _loadProfile();
      });
      widget.onSchoolUpdated();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_school.name} has been approved.')),
      );
    } catch (error) {
      if (!mounted) return;
      final detail = error.toString().replaceFirst('ClientException: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not approve school. $detail')),
      );
    } finally {
      if (mounted) setState(() => _approvingSchool = false);
    }
  }

  Future<void> _changeSchoolStatus({
    required SchoolStatus status,
    required String title,
    required String message,
    required String confirmLabel,
    required String reason,
  }) async {
    if (_changingSchoolStatus != null || _approvingSchool) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor:
                  status == SchoolStatus.suspended ||
                      status == SchoolStatus.deleted
                  ? AppColors.red
                  : null,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _changingSchoolStatus = status);
    try {
      await widget.repository.changeSchoolStatus(
        customSchoolId: _school.code,
        status: status,
        reason: reason,
      );
      if (!mounted) return;
      setState(() {
        _school = _school.copyWith(status: status);
        _profileFuture = _loadProfile();
      });
      widget.onSchoolUpdated();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_school.name} is now ${status.label}.')),
      );
    } catch (error) {
      if (!mounted) return;
      final detail = error.toString().replaceFirst('ClientException: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update school status. $detail')),
      );
    } finally {
      if (mounted) setState(() => _changingSchoolStatus = null);
    }
  }

  Future<void> _suspendSchool() {
    return _changeSchoolStatus(
      status: SchoolStatus.suspended,
      title: 'Suspend school?',
      message:
          '${_school.name} will be suspended. School users may lose access until the school is reactivated.',
      confirmLabel: 'Suspend school',
      reason: 'School suspended by platform administrator',
    );
  }

  Future<void> _deleteSchool() {
    return _changeSchoolStatus(
      status: SchoolStatus.deleted,
      title: 'Delete school?',
      message:
          '${_school.name} will be marked as deleted. This is a soft delete, so the record is retained but removed from normal active use.',
      confirmLabel: 'Delete school',
      reason: 'School deleted by platform administrator',
    );
  }

  Future<void> _viewDocument(SchoolDocumentInfo document) async {
    try {
      final documentId = document.documentId.trim();
      if (documentId.isEmpty) {
        throw StateError('The saved document reference is unavailable.');
      }
      prepareDocumentWindow();
      final url = await widget.repository.getSchoolDocumentDownloadUrl(
        customSchoolId: _school.code,
        documentId: documentId,
      );
      await openDocumentUrl(url);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open this document.')),
      );
    }
  }

  Future<void> _editProfileStep(int step) async {
    if (_preparingEditStep != null) return;
    setState(() => _preparingEditStep = step);
    try {
      final profile = await _profileFuture;
      final api = PlatformApiClient(
        accessToken: widget.accessToken,
        onRefreshAccessToken: widget.onRefreshAccessToken,
      );
      var lookups = await api.getSchoolCreationLookups();
      final address = _map(profile.record.data['address']);
      final region = _map(address['region']);
      final regionId = int.tryParse(
        (region['id'] ?? address['regionId'] ?? '').toString(),
      );
      if (regionId != null && regionId > 0) {
        final districtLookups = await api.getDistrictLookups(regionId);
        lookups = lookups.copyWith(
          districts: districtLookups.districts,
          districtIds: districtLookups.districtIds,
        );
      }
      if (!mounted) return;
      final edited = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          final size = MediaQuery.sizeOf(dialogContext);
          return Dialog(
            insetPadding: const EdgeInsets.all(16),
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              width: size.width.clamp(320, 980).toDouble(),
              height: (size.height * .9).clamp(520, 860).toDouble(),
              child: SchoolCreationScreen(
                accessToken: widget.accessToken,
                onRefreshAccessToken: widget.onRefreshAccessToken,
                repository: widget.repository,
                initialLookups: lookups,
                initialRecord: profile.record,
                initialDocuments: profile.documents,
                initialGradeLevels: profile.gradeLevels,
                existingSchool: _school,
                initialStep: step,
                singleStepEdit: true,
                onBack: () => Navigator.pop(dialogContext, false),
                onCreated: () => Navigator.pop(dialogContext, true),
                onStepSaved: widget.onSchoolUpdated,
                onStepUpdated: () async {
                  try {
                    final refreshed = await _loadProfile();
                    if (mounted) {
                      setState(() {
                        _profileFuture = Future.value(refreshed);
                      });
                    }
                  } catch (_) {
                    if (mounted) {
                      setState(() => _profileFuture = _loadProfile());
                    }
                  }
                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext, true);
                  }
                },
              ),
            ),
          );
        },
      );
      if (edited != true || !mounted) return;
      widget.onSchoolUpdated();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('School information updated successfully.'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not prepare this section for editing.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _preparingEditStep = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final school = _school;
    final selectedUser = _selectedUser;
    if (selectedUser != null) {
      return _SchoolUserDetailPage(
        user: selectedUser.copyWith(
          customSchoolId: school.code,
          schoolName: school.name,
        ),
        school: school,
        repository: widget.repository,
        onBack: () => setState(() => _selectedUser = null),
        onChanged: () => widget.onSchoolUpdated(),
      );
    }
    final status = _schoolStatus(school.status);
    final changingStatus = _changingSchoolStatus;
    final actionsDisabled =
        _preparingReassign || _approvingSchool || changingStatus != null;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextButton.icon(
            onPressed: widget.onBack,
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            label: const Text('Back to Schools'),
          ),
          const SizedBox(height: 12),
          _HeroCard(
            avatar: _initials(school.name),
            title: school.name,
            subtitle:
                '${school.code} · ${school.town}, ${school.region} Region',
            statusLabel: status.$1,
            statusColor: status.$2,
            actions: [
              if (school.status == SchoolStatus.pendingApproval)
                FilledButton.icon(
                  onPressed: actionsDisabled ? null : _approveSchool,
                  icon: _approvingSchool
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.verified_rounded, size: 18),
                  label: Text(
                    _approvingSchool ? 'Approving...' : 'Approve school',
                  ),
                ),
              OutlinedButton.icon(
                onPressed: actionsDisabled ? null : _openReassignDialog,
                icon: _preparingReassign
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.swap_horiz_rounded, size: 18),
                label: Text(_preparingReassign ? 'Preparing...' : 'Reassign'),
              ),
              if (school.status != SchoolStatus.suspended &&
                  school.status != SchoolStatus.deleted)
                OutlinedButton.icon(
                  onPressed: actionsDisabled ? null : _suspendSchool,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.red,
                    side: const BorderSide(color: AppColors.red),
                  ),
                  icon: changingStatus == SchoolStatus.suspended
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.pause_circle_outline_rounded, size: 18),
                  label: Text(
                    changingStatus == SchoolStatus.suspended
                        ? 'Suspending...'
                        : 'Suspend',
                  ),
                ),
              if (school.status != SchoolStatus.deleted)
                OutlinedButton.icon(
                  onPressed: actionsDisabled ? null : _deleteSchool,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.red,
                    side: const BorderSide(color: AppColors.red),
                  ),
                  icon: changingStatus == SchoolStatus.deleted
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.delete_outline_rounded, size: 18),
                  label: Text(
                    changingStatus == SchoolStatus.deleted
                        ? 'Deleting...'
                        : 'Delete',
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          _Tabs(
            selected: _tab,
            labels: const [
              'Overview',
              'School Profile',
              'Users',
              'Subscription',
              'Activity',
            ],
            onSelected: (index) => setState(() => _tab = index),
          ),
          const SizedBox(height: 16),
          switch (_tab) {
            0 => _SchoolOverview(
              school: school,
              onViewAccountManager: widget.onViewAccountManager,
              canViewAccountManagerDetails: widget.canViewAccountManagerDetails,
            ),
            1 => FutureBuilder<_SchoolProfileData>(
              future: _profileFuture,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _ProfileLoadError(onRetry: _retryProfile);
                }
                if (!snapshot.hasData) return const _ProfileLoading();
                return _SchoolProfile(
                  school: school,
                  profile: snapshot.requireData,
                  onEditStep: _editProfileStep,
                  preparingStep: _preparingEditStep,
                  onViewDocument: _viewDocument,
                );
              },
            ),
            2 => _SchoolUsers(
              school: school,
              repository: widget.repository,
              onOpenUser: (user) => setState(() => _selectedUser = user),
            ),
            3 => _SubscriptionPanel(school: school),
            _ => _ActivityPanel(
              activities: [
                'School administrator logged in',
                'Account manager updated contact information',
                'Subscription reminder sent to bursar',
                'System generated onboarding progress report',
              ],
            ),
          },
        ],
      ),
    );
  }
}

class AccountManagerDetailScreen extends StatefulWidget {
  const AccountManagerDetailScreen({
    super.key,
    required this.manager,
    required this.schools,
    required this.repository,
    required this.onBack,
    required this.onManagerUpdated,
    required this.onManagerDeleted,
    required this.onViewSchool,
  });

  final AccountManagerProfile manager;
  final List<ManagedSchool> schools;
  final PlatformRepository repository;
  final VoidCallback onBack;
  final ValueChanged<AccountManagerProfile> onManagerUpdated;
  final VoidCallback onManagerDeleted;
  final ValueChanged<ManagedSchool> onViewSchool;

  @override
  State<AccountManagerDetailScreen> createState() =>
      _AccountManagerDetailScreenState();
}

class _AccountManagerDetailScreenState
    extends State<AccountManagerDetailScreen> {
  late AccountManagerProfile _manager;
  bool _busy = false;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _manager = widget.manager;
  }

  @override
  void didUpdateWidget(covariant AccountManagerDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.manager != widget.manager) _manager = widget.manager;
  }

  @override
  Widget build(BuildContext context) {
    final manager = _manager;
    final assigned = widget.schools
        .where((school) => school.accountManager == manager.name)
        .toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextButton.icon(
                onPressed: widget.onBack,
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text('Back to Account Managers'),
              ),
              const SizedBox(height: 12),
              _AccountManagerProfileHeader(
                manager: manager,
                assignedCount: assigned.length,
                busy: _busy,
                onApprove: () => _changeStatus(
                  AccountManagerStatus.active,
                  reason: 'Approved by Super Admin',
                ),
                onSuspend: () => _changeStatus(
                  AccountManagerStatus.suspended,
                  reason: 'Suspended by Super Admin',
                ),
                onReactivate: () => _changeStatus(
                  AccountManagerStatus.active,
                  reason: 'Reactivated by Super Admin',
                ),
                onForceResetPassword: _forceResetPassword,
                onResendCredentials: _resendCredentials,
                onDelete: _deleteManager,
              ),
              const SizedBox(height: 16),
              _InfoGrid(
                items: [
                  _InfoItem('Email', manager.email),
                  _InfoItem('Phone', manager.phone),
                  _InfoItem('Joined', _formatReadableDate(manager.joined)),
                  _InfoItem('Invite Method', manager.inviteMethod),
                  _InfoItem(
                    'Last Active',
                    _formatReadableDate(manager.lastActive),
                  ),
                  _InfoItem('Schools Assigned', '${assigned.length}'),
                ],
              ),
              const SizedBox(height: 22),
              _AccountManagerTabs(
                selected: _tab,
                onSelected: (index) => setState(() => _tab = index),
              ),
              const SizedBox(height: 16),
              if (_tab == 0)
                _AssignedSchoolsPanel(
                  schools: assigned,
                  onViewSchool: widget.onViewSchool,
                )
              else
                const _ActivityPanel(
                  title: 'Activity Log',
                  activities: [
                    'Account manager profile opened',
                    'Assigned schools reviewed',
                    'Credential actions available',
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _changeStatus(
    AccountManagerStatus status, {
    required String reason,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final updated = await widget.repository.updateAccountManagerStatus(
        accountManagerId: _manager.id,
        status: status,
        reason: reason,
      );
      if (!mounted) return;
      setState(() => _manager = updated);
      widget.onManagerUpdated(updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${updated.name} updated successfully.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not update account manager. ${_actionError(error)}'),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteManager() async {
    if (_busy) return;
    final confirmed = await _confirmAccountManagerAction(
      title: 'Delete account manager?',
      message:
          'This will remove ${_manager.name} from account manager access. This action should only be used when the account is no longer needed.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.repository.deleteAccountManager(
        accountManagerId: _manager.id,
        reason: 'Deleted by Super Admin',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_manager.name} deleted successfully.')),
      );
      widget.onManagerDeleted();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not delete account manager. ${_actionError(error)}'),
        ),
      );
      setState(() => _busy = false);
    }
  }

  Future<void> _forceResetPassword() async {
    await _runAccountManagerCredentialAction(
      title: 'Force reset password?',
      message:
          'This will generate a new temporary password for ${_manager.name}, mark the account as requiring password change, and send the credentials.',
      confirmLabel: 'Force reset',
      action: () =>
          widget.repository.forceResetAccountManagerPassword(manager: _manager),
    );
  }

  Future<void> _resendCredentials() async {
    await _runAccountManagerCredentialAction(
      title: 'Send temporary password?',
      message:
          'This will generate and send temporary login credentials to ${_manager.name}.',
      confirmLabel: 'Send temporary password',
      action: () =>
          widget.repository.resendAccountManagerCredentials(manager: _manager),
    );
  }

  Future<void> _runAccountManagerCredentialAction({
    required String title,
    required String message,
    required String confirmLabel,
    required Future<SchoolAdministratorInviteResult> Function() action,
  }) async {
    if (_busy) return;
    final confirmed = await _confirmAccountManagerAction(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    try {
      final result = await action();
      if (!mounted) return;
      final suffix =
          result.temporaryPassword == null || result.temporaryPassword!.isEmpty
          ? ''
          : ' Temporary password: ${result.temporaryPassword}';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${result.message}$suffix')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not complete credential action. ${_actionError(error)}',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirmAccountManagerAction({
    required String title,
    required String message,
    required String confirmLabel,
    bool destructive = false,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(backgroundColor: AppColors.red)
                : null,
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }
}

class _AccountManagerProfileHeader extends StatelessWidget {
  const _AccountManagerProfileHeader({
    required this.manager,
    required this.assignedCount,
    required this.busy,
    required this.onApprove,
    required this.onSuspend,
    required this.onReactivate,
    required this.onForceResetPassword,
    required this.onResendCredentials,
    required this.onDelete,
  });

  final AccountManagerProfile manager;
  final int assignedCount;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onSuspend;
  final VoidCallback onReactivate;
  final VoidCallback onForceResetPassword;
  final VoidCallback onResendCredentials;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final status = _managerStatus(manager.status);
    final pending = manager.status == AccountManagerStatus.pendingApproval;
    final active = manager.status == AccountManagerStatus.active;
    final suspended = manager.status == AccountManagerStatus.suspended;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 820;
            final avatar = _Avatar(label: _initials(manager.name), size: 64);
            final meta = Wrap(
              spacing: 18,
              runSpacing: 6,
              children: [
                _ManagerMeta(
                  icon: Icons.mail_outline_rounded,
                  text: manager.email,
                ),
                _ManagerMeta(
                  icon: Icons.phone_iphone_rounded,
                  text: manager.phone,
                ),
                _ManagerMeta(
                  icon: Icons.apartment_rounded,
                  text: '$assignedCount schools assigned',
                ),
              ],
            );
            final primaryActions = Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: busy ? null : onForceResetPassword,
                  icon: const Icon(Icons.lock_reset_rounded, size: 18),
                  label: const Text('Force reset password'),
                ),
                OutlinedButton.icon(
                  onPressed: busy ? null : onResendCredentials,
                  icon: const Icon(Icons.mark_email_read_outlined, size: 18),
                  label: const Text('Send temporary password'),
                ),
                if (pending)
                  FilledButton.icon(
                    onPressed: busy ? null : onApprove,
                    icon: const Icon(Icons.check_circle_rounded, size: 18),
                    label: const Text('Approve AM'),
                  )
                else if (active)
                  TextButton.icon(
                    onPressed: busy ? null : onSuspend,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.red,
                      backgroundColor: AppColors.red.withValues(alpha: .1),
                    ),
                    icon: const Icon(
                      Icons.pause_circle_outline_rounded,
                      size: 18,
                    ),
                    label: const Text('Suspend AM'),
                  )
                else if (suspended)
                  FilledButton.icon(
                    onPressed: busy ? null : onReactivate,
                    icon: const Icon(Icons.restart_alt_rounded, size: 18),
                    label: const Text('Reactivate AM'),
                  ),
                OutlinedButton.icon(
                  onPressed: busy ? null : onDelete,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.red,
                    side: const BorderSide(color: AppColors.red),
                  ),
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text('Delete'),
                ),
              ],
            );
            final identity = Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                avatar,
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        manager.name,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      meta,
                      const SizedBox(height: 18),
                      primaryActions,
                    ],
                  ),
                ),
              ],
            );
            if (narrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  identity,
                  const SizedBox(height: 16),
                  _StatusPill(label: status.$1, color: status.$2),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: identity),
                const SizedBox(width: 18),
                _StatusPill(label: status.$1, color: status.$2),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ManagerMeta extends StatelessWidget {
  const _ManagerMeta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: AppColors.muted),
        const SizedBox(width: 5),
        Text(
          text,
          style: const TextStyle(color: AppColors.muted, fontSize: 13),
        ),
      ],
    );
  }
}

class _AccountManagerTabs extends StatelessWidget {
  const _AccountManagerTabs({required this.selected, required this.onSelected});

  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          _AccountManagerTabButton(
            label: 'Assigned Schools',
            selected: selected == 0,
            onTap: () => onSelected(0),
          ),
          _AccountManagerTabButton(
            label: 'Activity Log',
            selected: selected == 1,
            onTap: () => onSelected(1),
          ),
        ],
      ),
    );
  }
}

class _AccountManagerTabButton extends StatelessWidget {
  const _AccountManagerTabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? AppColors.green : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.green : AppColors.muted,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _SchoolOverview extends StatelessWidget {
  const _SchoolOverview({
    required this.school,
    required this.onViewAccountManager,
    required this.canViewAccountManagerDetails,
  });

  final ManagedSchool school;
  final ValueChanged<String> onViewAccountManager;
  final bool canViewAccountManagerDetails;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _InfoGrid(
          items: [
            _InfoItem('Total Students', '${school.students}'),
            _InfoItem('Total Staff', '${school.staff}'),
            _InfoItem('Last Active', school.lastActive),
            _InfoItem('Approved On', school.approvedDate),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                _Avatar(label: _initials(school.accountManager)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ACCOUNT MANAGER',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .7,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        school.accountManager,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
                if (canViewAccountManagerDetails)
                  TextButton(
                    onPressed: () =>
                        onViewAccountManager(school.accountManager),
                    child: const Text('View →'),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const _ActivityPanel(
          title: 'Recent Activity',
          compact: true,
          activities: [
            'Attendance summary synced',
            'Fee reminder generated',
            'School profile reviewed',
          ],
        ),
      ],
    );
  }
}

class _SchoolProfile extends StatelessWidget {
  const _SchoolProfile({
    required this.school,
    required this.profile,
    required this.onEditStep,
    required this.preparingStep,
    required this.onViewDocument,
  });
  final ManagedSchool school;
  final _SchoolProfileData profile;
  final ValueChanged<int> onEditStep;
  final int? preparingStep;
  final ValueChanged<SchoolDocumentInfo> onViewDocument;

  Widget _editButton(int step) => OutlinedButton.icon(
    onPressed: preparingStep == null ? () => onEditStep(step) : null,
    icon: preparingStep == step
        ? const SizedBox(
            width: 15,
            height: 15,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(Icons.edit_outlined, size: 15),
    label: Text(preparingStep == step ? 'Preparing...' : 'Edit'),
  );

  @override
  Widget build(BuildContext context) {
    final data = profile.record.data;
    final registration = _map(data['registrationDetails']);
    final welfare = _map(data['socialWelfareCompliance']);
    final address = _map(data['address']);
    final gps = _map(address['gpsLocation']);
    final contact = _map(data['contactInfo']);
    final term = _map(data['currentAcademicTerm']);
    final events = _list(term['events']);
    return Column(
      children: [
        _SectionCard(
          title: 'School Information',
          trailing: _editButton(0),
          items: [
            _InfoItem(
              'School Name',
              _field(data, const ['schoolName', 'name'], school.name),
            ),
            _InfoItem(
              'Custom School ID',
              _field(data, const ['customSchoolId'], school.code),
            ),
            _InfoItem('Category', _objectField(data['category'])),
            _InfoItem(
              'Education Level',
              _objectField(
                data['educationLevel'],
                valueKeys: const ['name', 'level'],
              ),
            ),
            _InfoItem('Year Founded', _field(data, const ['yearFounded'])),
            _InfoItem('School Motto', _field(data, const ['motto'])),
            _InfoItem(
              'Registration Status',
              profile.record.progress.registrationStatus.replaceAll('_', ' '),
            ),
            _InfoItem(
              'Current Step',
              profile.record.progress.currentStep.replaceAll('_', ' '),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _SectionCard(
          title: 'Registration Details',
          trailing: _editButton(1),
          items: [
            _InfoItem(
              'GES Registration Number',
              _field(registration, const [
                'gesRegistrationNumber',
                'registrationNumberGes',
                'registrationNumber',
                'gesNumber',
              ]),
            ),
            _InfoItem(
              'GES Registration Type',
              _objectField(
                registration['gesRegistrationType'] ??
                    registration['registrationType'],
              ),
            ),
            _InfoItem(
              'GES Registration Date',
              _dateField(registration['gesRegistrationDate']),
            ),
            _InfoItem(
              'Business Registration Number',
              _field(registration, const [
                'businessRegistrationNumber',
                'businessRegNumber',
                'businessNumber',
              ]),
            ),
            _InfoItem(
              'Business Registration Type',
              _objectField(registration['businessRegistrationType']),
            ),
            _InfoItem(
              'Business Registration Date',
              _dateField(registration['businessRegistrationDate']),
            ),
            _InfoItem(
              'GEMIS Code',
              _field(registration, const ['gemisCode', 'gemisNumber', 'gemis']),
            ),
            _InfoItem(
              'Tax ID Number',
              _field(registration, const ['taxIdNumber', 'taxId', 'tinNumber']),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _SectionCard(
          title: 'Social Welfare Compliance',
          trailing: _editButton(2),
          items: [
            _InfoItem(
              'Approval Number',
              _field(welfare, const ['approvalNumber']),
            ),
            _InfoItem(
              'Approval Officer',
              _field(welfare, const ['approvalOfficerName', 'approvalOfficer']),
            ),
            _InfoItem('Approval Date', _dateField(welfare['approvalDate'])),
            _InfoItem('Expiry Date', _dateField(welfare['expiryDate'])),
            _InfoItem(
              'Compliance Status',
              _objectField(welfare['complianceStatus']),
            ),
            _InfoItem('Notes', _field(welfare, const ['notes'])),
          ],
        ),
        const SizedBox(height: 14),
        _SectionCard(
          title: 'Address & Location',
          trailing: _editButton(3),
          items: [
            _InfoItem('House Number', _field(address, const ['houseNumber'])),
            _InfoItem(
              'Street Name',
              _field(address, const ['streetName', 'streetAddress']),
            ),
            _InfoItem(
              'Additional Directions',
              _field(address, const [
                'additionalDirection',
                'additionalDirections',
              ]),
            ),
            _InfoItem(
              'Ghana Post Address',
              _field(address, const ['ghanaPostAddress', 'digitalAddress']),
            ),
            _InfoItem(
              'City / Town',
              _objectField(address['city'], fallback: school.town),
            ),
            _InfoItem(
              'District',
              _objectField(address['district'], fallback: school.district),
            ),
            _InfoItem(
              'Region',
              _objectField(address['region'], fallback: school.region),
            ),
            _InfoItem('Country', _objectField(address['country'])),
            _InfoItem('Latitude', _field(gps, const ['latitude'])),
            _InfoItem('Longitude', _field(gps, const ['longitude'])),
          ],
        ),
        const SizedBox(height: 14),
        _SectionCard(
          title: 'Contact Information',
          trailing: _editButton(4),
          items: const [],
          child: _ContactInformationView(contact: contact),
        ),
        const SizedBox(height: 14),
        _SectionCard(
          title: 'Required Documents',
          trailing: _editButton(5),
          items: const [],
          child: _DocumentsView(
            documents: profile.documents,
            onViewDocument: onViewDocument,
          ),
        ),
        const SizedBox(height: 14),
        _SectionCard(
          title: 'Grade Levels & Class Structure',
          trailing: _editButton(6),
          items: const [],
          child: _GradeStructureView(gradeLevels: profile.gradeLevels),
        ),
        const SizedBox(height: 14),
        _SectionCard(
          title: 'Academic Term',
          trailing: _editButton(7),
          items: [
            _InfoItem(
              'Academic Year',
              _objectField(
                term['academicYear'],
                valueKeys: const ['year', 'name'],
              ),
            ),
            _InfoItem('Academic Term', _objectField(term['termType'])),
            _InfoItem('Start Date', _dateField(term['startDate'])),
            _InfoItem('End Date', _dateField(term['endDate'])),
            _InfoItem('Description', _field(term, const ['description'])),
          ],
        ),
        const SizedBox(height: 14),
        _SectionCard(
          title: 'School Calendar Events',
          trailing: _editButton(7),
          items: const [],
          child: _CalendarEventsList(events: events),
        ),
      ],
    );
  }
}

class _SchoolProfileData {
  const _SchoolProfileData({
    required this.record,
    required this.documents,
    required this.gradeLevels,
  });

  final SchoolOnboardingRecord record;
  final List<SchoolDocumentInfo> documents;
  final List<SchoolGradeLevelInfo> gradeLevels;
}

class _ProfileLoading extends StatelessWidget {
  const _ProfileLoading();

  @override
  Widget build(BuildContext context) => const Card(
    child: Padding(
      padding: EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Loading complete school profile...'),
          ],
        ),
      ),
    ),
  );
}

class _ProfileLoadError extends StatelessWidget {
  const _ProfileLoadError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              color: AppColors.red,
              size: 38,
            ),
            const SizedBox(height: 10),
            const Text(
              'Could not load the complete school profile',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 5),
            const Text(
              'Check your connection and try again.',
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _SchoolUsers extends StatefulWidget {
  const _SchoolUsers({
    required this.school,
    required this.repository,
    required this.onOpenUser,
  });
  final ManagedSchool school;
  final PlatformRepository repository;
  final ValueChanged<SchoolUserInfo> onOpenUser;

  @override
  State<_SchoolUsers> createState() => _SchoolUsersState();
}

class _SchoolUsersState extends State<_SchoolUsers> {
  late Future<List<SchoolUserInfo>> _usersFuture;
  final List<SchoolUserInfo> _optimisticUsers = [];

  @override
  void initState() {
    super.initState();
    _usersFuture = _loadUsers();
  }

  Future<List<SchoolUserInfo>> _loadUsers() =>
      widget.repository.getSchoolUsers(widget.school.code);

  void _refreshUsers() {
    setState(() => _usersFuture = _loadUsers());
  }

  List<SchoolUserInfo> _mergeUsers(List<SchoolUserInfo> users) {
    final merged = [..._optimisticUsers];
    for (final user in users) {
      final existingIndex = merged.indexWhere(
        (local) =>
            (local.id.isNotEmpty && local.id == user.id) ||
            (local.email.isNotEmpty &&
                local.email.toLowerCase() == user.email.toLowerCase()),
      );
      if (existingIndex >= 0) {
        merged[existingIndex] = user;
      } else {
        merged.add(user);
      }
    }
    return merged;
  }

  Future<void> _showInviteDialog(BuildContext context) async {
    final result = await showDialog<SchoolAdministratorInviteResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _InviteSchoolAdministratorDialog(
        school: widget.school,
        repository: widget.repository,
      ),
    );
    if (result == null || !context.mounted) return;
    final user = result.user;
    if (user != null) {
      setState(() {
        _optimisticUsers.removeWhere(
          (existing) =>
              (existing.id.isNotEmpty && existing.id == user.id) ||
              existing.email.toLowerCase() == user.email.toLowerCase(),
        );
        _optimisticUsers.insert(0, user);
      });
    }
    _refreshUsers();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(
          Icons.mark_email_read_outlined,
          color: AppColors.green,
          size: 38,
        ),
        title: const Text('Administrator invited'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(result.message, textAlign: TextAlign.center),
            if (result.username != null) ...[
              const SizedBox(height: 14),
              _InviteCredential(label: 'Username', value: result.username!),
            ],
            if (result.temporaryPassword != null) ...[
              const SizedBox(height: 8),
              _InviteCredential(
                label: 'Temporary Password',
                value: result.temporaryPassword!,
              ),
            ],
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<SchoolUserInfo>>(
      future: _usersFuture,
      builder: (context, snapshot) {
        final users = _mergeUsers(snapshot.data ?? const <SchoolUserInfo>[]);
        final hasAdmin = users.any((user) => user.isAdministrator);
        return Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'All Users (${snapshot.hasData ? users.length : '...'})',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: snapshot.hasError ? _refreshUsers : null,
                      icon: const Icon(Icons.refresh_rounded, size: 17),
                      label: const Text('Retry'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: () => _showInviteDialog(context),
                      icon: Icon(hasAdmin ? Icons.person_add_alt : Icons.add),
                      label: Text(
                        hasAdmin ? 'Invite another admin' : 'Invite admin',
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.border),
              if (snapshot.connectionState == ConnectionState.waiting)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (snapshot.hasError)
                const Padding(
                  padding: EdgeInsets.all(28),
                  child: _EmptyState(
                    icon: Icons.cloud_off_outlined,
                    title: 'Could not load school users',
                    detail: 'Check your connection and try again.',
                  ),
                )
              else if (users.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(28),
                  child: _EmptyState(
                    icon: Icons.person_off_outlined,
                    title: 'No users found',
                    detail:
                        'Invite a school administrator to create the first account.',
                  ),
                )
              else
                ...users.map(
                  (user) => _SchoolUserRow(
                    user: user,
                    onTap: () => widget.onOpenUser(user),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _SchoolUserRow extends StatelessWidget {
  const _SchoolUserRow({required this.user, required this.onTap});
  final SchoolUserInfo user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = _userStatus(user.status);
    final role = user.role.replaceAll('_', ' ').toLowerCase();
    final roleLabel = role
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              _Avatar(label: _initials(user.name), size: 38),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 5,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          user.name,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: user.isAdministrator
                                ? AppColors.greenSoft
                                : AppColors.background,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            roleLabel.isEmpty ? 'Not assigned' : roleLabel,
                            style: TextStyle(
                              color: user.isAdministrator
                                  ? AppColors.green
                                  : AppColors.muted,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${user.email} · ${user.phoneNumber} · Last login: ${user.lastLogin}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _StatusPill(label: status.label, color: status.color),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _SchoolUserDetailPage extends StatefulWidget {
  const _SchoolUserDetailPage({
    required this.user,
    required this.school,
    required this.repository,
    required this.onBack,
    required this.onChanged,
  });

  final SchoolUserInfo user;
  final ManagedSchool school;
  final PlatformRepository repository;
  final VoidCallback onBack;
  final VoidCallback onChanged;

  @override
  State<_SchoolUserDetailPage> createState() => _SchoolUserDetailPageState();
}

class _SchoolUserDetailPageState extends State<_SchoolUserDetailPage> {
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _runAction(
    Future<void> Function() action,
    String successMessage,
  ) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      setState(() => _busy = false);
      widget.onChanged();
      widget.onBack();
      messenger.showSnackBar(SnackBar(content: Text(successMessage)));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _runCredentialAction(
    Future<SchoolAdministratorInviteResult> Function() action,
  ) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await action();
      if (!mounted) return;
      setState(() => _busy = false);
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.lock_reset_rounded, color: AppColors.green),
          title: const Text('Credential action complete'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(result.message),
              if (result.username != null) ...[
                const SizedBox(height: 12),
                _InviteCredential(label: 'Username', value: result.username!),
              ],
              if (result.temporaryPassword != null) ...[
                const SizedBox(height: 8),
                _InviteCredential(
                  label: 'Temporary password',
                  value: result.temporaryPassword!,
                ),
              ],
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final status = _userStatus(user.status);
    final statusValue = user.status.toUpperCase();
    final isActive = statusValue == 'ACTIVE' || statusValue == 'APPROVED';
    final isSuspended = statusValue == 'SUSPENDED';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _busy ? null : widget.onBack,
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: const Text('Back to Users'),
                ),
              ),
              const SizedBox(height: 12),
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.red.withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.red.withValues(alpha: .18),
                    ),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: AppColors.red),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              _UserProfileHero(
                user: user,
                status: status,
                busy: _busy,
                onResendCredentials: () => _runCredentialAction(
                  () => widget.repository.resendSchoolUserCredentials(
                    customSchoolId: user.customSchoolId,
                    userId: user.id,
                  ),
                ),
                onResetPassword: () => _runCredentialAction(
                  () => widget.repository.resetSchoolUserPassword(
                    customSchoolId: user.customSchoolId,
                    userId: user.id,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _UserAccountActionsCard(
                user: user,
                busy: _busy,
                isActive: isActive,
                isSuspended: isSuspended,
                onApprove: () => _runAction(
                  () => widget.repository.approveSchoolUser(
                    customSchoolId: user.customSchoolId,
                    userId: user.id,
                  ),
                  'User approved successfully.',
                ),
                onReject: () => _runAction(
                  () => widget.repository.rejectSchoolUser(
                    customSchoolId: user.customSchoolId,
                    userId: user.id,
                    reason: 'Rejected by Super Admin',
                  ),
                  'User rejected.',
                ),
                onSuspend: () => _runAction(
                  () => widget.repository.suspendSchoolUser(
                    customSchoolId: user.customSchoolId,
                    userId: user.id,
                    reason: 'Suspended by Super Admin',
                  ),
                  'User suspended.',
                ),
                onReactivate: () => _runAction(
                  () => widget.repository.reactivateSchoolUser(
                    customSchoolId: user.customSchoolId,
                    userId: user.id,
                  ),
                  'User reactivated.',
                ),
              ),
              if (_busy) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
              ],
              const SizedBox(height: 18),
              _UserInfoGrid(user: user),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserProfileHero extends StatelessWidget {
  const _UserProfileHero({
    required this.user,
    required this.status,
    required this.busy,
    required this.onResendCredentials,
    required this.onResetPassword,
  });

  final SchoolUserInfo user;
  final ({String label, Color color, IconData icon}) status;
  final bool busy;
  final VoidCallback onResendCredentials;
  final VoidCallback onResetPassword;

  @override
  Widget build(BuildContext context) {
    final schoolName = user.schoolName.isEmpty
        ? 'This school'
        : user.schoolName;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 700;
          final avatar = Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 74,
                height: 74,
                decoration: BoxDecoration(
                  color: AppColors.greenSoft,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.green, width: 2),
                ),
              ),
              _Avatar(label: _initials(user.name), size: 62),
            ],
          );
          final details = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    user.name,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  _StatusPill(label: status.label, color: status.color),
                ],
              ),
              const SizedBox(height: 8),
              _SmallChip(label: _titleCase(user.role)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 14,
                runSpacing: 8,
                children: [
                  _UserMetaLine(icon: Icons.email_outlined, label: user.email),
                  _UserMetaLine(
                    icon: Icons.phone_outlined,
                    label: user.phoneNumber.isEmpty
                        ? 'No phone provided'
                        : user.phoneNumber,
                  ),
                  _UserMetaLine(icon: Icons.school_outlined, label: schoolName),
                  _UserMetaLine(
                    icon: Icons.calendar_today_outlined,
                    label:
                        'Joined ${_formatReadableDate(user.createdAt.isEmpty ? user.invitedAt : user.createdAt)}',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  OutlinedButton.icon(
                    onPressed: busy ? null : onResendCredentials,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Resend credentials'),
                  ),
                  FilledButton.icon(
                    onPressed: busy ? null : onResetPassword,
                    icon: const Icon(Icons.lock_outline_rounded),
                    label: const Text('Reset password'),
                  ),
                ],
              ),
            ],
          );
          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [avatar, const SizedBox(height: 16), details],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              avatar,
              const SizedBox(width: 18),
              Expanded(child: details),
            ],
          );
        },
      ),
    );
  }
}

class _UserMetaLine extends StatelessWidget {
  const _UserMetaLine({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.muted),
        const SizedBox(width: 5),
        Text(
          label.isEmpty ? 'Not provided' : label,
          style: const TextStyle(color: AppColors.muted, fontSize: 13),
        ),
      ],
    );
  }
}

class _UserAccountActionsCard extends StatelessWidget {
  const _UserAccountActionsCard({
    required this.user,
    required this.busy,
    required this.isActive,
    required this.isSuspended,
    required this.onApprove,
    required this.onReject,
    required this.onSuspend,
    required this.onReactivate,
  });

  final SchoolUserInfo user;
  final bool busy;
  final bool isActive;
  final bool isSuspended;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onSuspend;
  final VoidCallback onReactivate;

  @override
  Widget build(BuildContext context) {
    final status = _userStatus(user.status);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 680;
            final copy = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Account controls',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                Text(
                  user.isPendingApproval
                      ? 'Review this user registration and approve or reject access.'
                      : 'Current status: ${status.label}. Use these actions to manage account access.',
                  style: const TextStyle(color: AppColors.muted),
                ),
              ],
            );
            final actions = Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: isNarrow ? WrapAlignment.start : WrapAlignment.end,
              children: [
                if (user.isPendingApproval) ...[
                  OutlinedButton.icon(
                    onPressed: busy ? null : onReject,
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Reject'),
                  ),
                  FilledButton.icon(
                    onPressed: busy ? null : onApprove,
                    icon: const Icon(Icons.check_circle_rounded),
                    label: const Text('Approve user'),
                  ),
                ] else if (isActive)
                  OutlinedButton.icon(
                    onPressed: busy ? null : onSuspend,
                    icon: const Icon(Icons.pause_circle_outline_rounded),
                    label: const Text('Suspend account'),
                  )
                else if (isSuspended)
                  FilledButton.icon(
                    onPressed: busy ? null : onReactivate,
                    icon: const Icon(Icons.restart_alt_rounded),
                    label: const Text('Reactivate account'),
                  )
                else
                  _StatusPill(label: status.label, color: status.color),
              ],
            );
            if (isNarrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [copy, const SizedBox(height: 14), actions],
              );
            }
            return Row(
              children: [
                Expanded(child: copy),
                const SizedBox(width: 18),
                actions,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _UserInfoGrid extends StatelessWidget {
  const _UserInfoGrid({required this.user});

  final SchoolUserInfo user;

  @override
  Widget build(BuildContext context) {
    final cells = [
      (
        'Username',
        user.username.isEmpty ? 'Not provided' : user.username,
        true,
      ),
      ('Last Login', _formatReadableDate(user.lastLogin), false),
      ('Login Count', 'Not provided', false),
      ('Invited By', 'System Administrator', false),
      (
        'Invited On',
        _formatReadableDate(
          user.invitedAt.isEmpty ? user.createdAt : user.invitedAt,
        ),
        false,
      ),
      ('Date of Birth', _formatReadableDate(user.dateOfBirth), false),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 760
            ? 3
            : constraints.maxWidth >= 520
            ? 2
            : 1;
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: cells.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              childAspectRatio: columns == 1 ? 5.2 : 3.4,
            ),
            itemBuilder: (context, index) {
              final cell = cells[index];
              return _UserInfoCell(
                label: cell.$1,
                value: cell.$2,
                mono: cell.$3,
              );
            },
          ),
        );
      },
    );
  }
}

class _UserInfoCell extends StatelessWidget {
  const _UserInfoCell({
    required this.label,
    required this.value,
    required this.mono,
  });

  final String label;
  final String value;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: AppColors.border.withValues(alpha: .45)),
          bottom: BorderSide(color: AppColors.border.withValues(alpha: .45)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 10,
              letterSpacing: .7,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value.isEmpty ? 'Not provided' : value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.text,
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              fontFamily: mono ? 'monospace' : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallChip extends StatelessWidget {
  const _SmallChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.greenSoft,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.green,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _InviteSchoolAdministratorDialog extends StatefulWidget {
  const _InviteSchoolAdministratorDialog({
    required this.school,
    required this.repository,
  });

  final ManagedSchool school;
  final PlatformRepository repository;

  @override
  State<_InviteSchoolAdministratorDialog> createState() =>
      _InviteSchoolAdministratorDialogState();
}

class _InviteSchoolAdministratorDialogState
    extends State<_InviteSchoolAdministratorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _middleName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _dateOfBirth = TextEditingController();
  DateTime? _selectedDate;
  bool _emailDelivery = true;
  bool _smsDelivery = true;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _firstName.dispose();
    _middleName.dispose();
    _lastName.dispose();
    _email.dispose();
    _phone.dispose();
    _dateOfBirth.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime(now.year - 25),
      firstDate: DateTime(1940),
      lastDate: DateTime(now.year - 18, now.month, now.day),
    );
    if (selected == null) return;
    setState(() {
      _selectedDate = selected;
      _dateOfBirth.text = _dateField(selected.toIso8601String());
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null) {
      setState(() => _error = 'Select the administrator’s date of birth.');
      return;
    }
    if (!_emailDelivery && !_smsDelivery) {
      setState(() => _error = 'Select email, SMS, or both for the invitation.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final result = await widget.repository.inviteSchoolAdministrator(
        customSchoolId: widget.school.code,
        invite: SchoolAdministratorInvite(
          firstName: _firstName.text,
          middleName: _middleName.text,
          lastName: _lastName.text,
          email: _email.text,
          phoneNumber: _phone.text,
          dateOfBirth: _selectedDate!,
          emailDelivery: _emailDelivery,
          smsDelivery: _smsDelivery,
        ),
      );
      if (mounted) Navigator.pop(context, result);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 760),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Invite School Administrator',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _submitting
                          ? null
                          : () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                Text(
                  'Create an administrator account for ${widget.school.name}. Login details will be delivered using the selected methods.',
                  style: const TextStyle(color: AppColors.muted, height: 1.45),
                ),
                const SizedBox(height: 20),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 520;
                    final first = _InviteField(
                      controller: _firstName,
                      label: 'First Name',
                      validator: _required,
                    );
                    final last = _InviteField(
                      controller: _lastName,
                      label: 'Last Name',
                      validator: _required,
                    );
                    if (compact) {
                      return Column(
                        children: [first, const SizedBox(height: 14), last],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: first),
                        const SizedBox(width: 12),
                        Expanded(child: last),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 14),
                _InviteField(
                  controller: _middleName,
                  label: 'Middle Name (optional)',
                ),
                const SizedBox(height: 14),
                _InviteField(
                  controller: _email,
                  label: 'Email Address',
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    final required = _required(value);
                    if (required != null) return required;
                    return RegExp(
                          r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                        ).hasMatch(value!)
                        ? null
                        : 'Enter a valid email address.';
                  },
                ),
                const SizedBox(height: 14),
                _InviteField(
                  controller: _phone,
                  label: 'Phone Number',
                  hint: '+233 24 000 0000',
                  keyboardType: TextInputType.phone,
                  validator: _phoneValidator,
                ),
                const SizedBox(height: 14),
                _InviteField(
                  controller: _dateOfBirth,
                  label: 'Date of Birth',
                  hint: 'Select date',
                  readOnly: true,
                  onTap: _pickDate,
                  suffixIcon: const Icon(
                    Icons.calendar_today_outlined,
                    size: 18,
                  ),
                  validator: _required,
                ),
                const SizedBox(height: 18),
                const Text(
                  'DELIVER INVITATION BY',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .7,
                  ),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _emailDelivery,
                  onChanged: _submitting
                      ? null
                      : (value) =>
                            setState(() => _emailDelivery = value ?? false),
                  title: const Text('Email'),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _smsDelivery,
                  onChanged: _submitting
                      ? null
                      : (value) =>
                            setState(() => _smsDelivery = value ?? false),
                  title: const Text('SMS'),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.red.withValues(alpha: .08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: AppColors.red),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _submitting
                          ? null
                          : () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: _submitting ? null : _submit,
                      icon: _submitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_outlined, size: 17),
                      label: Text(
                        _submitting ? 'Sending...' : 'Send Invitation',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'This field is required.' : null;

  String? _phoneValidator(String? value) {
    final required = _required(value);
    if (required != null) return required;
    var digits = value!.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('233')) {
      // Already in Ghana international format.
    } else if (digits.startsWith('0')) {
      digits = '233${digits.substring(1)}';
    } else {
      digits = '233$digits';
    }
    if (digits.length < 10 || digits.length > 15) {
      return 'Enter a valid number, for example 024 123 4567.';
    }
    return null;
  }
}

class _InviteField extends StatelessWidget {
  const _InviteField({
    required this.controller,
    required this.label,
    this.hint,
    this.keyboardType,
    this.validator,
    this.readOnly = false,
    this.onTap,
    this.suffixIcon,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final bool readOnly;
  final VoidCallback? onTap;
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    keyboardType: keyboardType,
    validator: validator,
    readOnly: readOnly,
    onTap: onTap,
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
    ),
  );
}

class _InviteCredential extends StatelessWidget {
  const _InviteCredential({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.greenSoft,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.muted, fontSize: 11),
        ),
        const SizedBox(height: 3),
        SelectableText(
          value,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ],
    ),
  );
}

class _SubscriptionPanel extends StatelessWidget {
  const _SubscriptionPanel({required this.school});
  final ManagedSchool school;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Subscription & Billing',
      items: [
        _InfoItem('Plan', school.subscriptionPlan),
        _InfoItem('Status', school.subscriptionStatus),
        _InfoItem('Renewal Date', school.renewalDate),
        _InfoItem('Payment Channel', 'Mobile Money / Bank'),
      ],
      trailing: OutlinedButton.icon(
        onPressed: () {},
        icon: const Icon(Icons.receipt_long_outlined, size: 18),
        label: const Text('View Billing'),
      ),
    );
  }
}

class _AssignedSchoolsPanel extends StatelessWidget {
  const _AssignedSchoolsPanel({
    required this.schools,
    required this.onViewSchool,
  });

  final List<ManagedSchool> schools;
  final ValueChanged<ManagedSchool> onViewSchool;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 860;
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _AssignedSchoolsHeader(),
          if (schools.isEmpty)
            const _AssignedSchoolsEmptyRow()
          else
            ...schools.map((school) {
              final status = _schoolStatus(school.status);
              return Container(
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.border)),
                ),
                child: InkWell(
                  onTap: () => onViewSchool(school),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 15,
                    ),
                    child: wide
                        ? Row(
                            children: [
                              Expanded(
                                flex: 4,
                                child: _AssignedSchoolNameCell(school: school),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  school.region.trim().isEmpty
                                      ? '-'
                                      : school.region,
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: Text('${school.students}'),
                              ),
                              Expanded(
                                flex: 2,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: _StatusPill(
                                    label: status.$1,
                                    color: status.$2,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: OutlinedButton(
                                    onPressed: () => onViewSchool(school),
                                    child: const Text('View School →'),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _AssignedSchoolNameCell(school: school),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 10,
                                runSpacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    school.region.trim().isEmpty
                                        ? '-'
                                        : school.region,
                                    style: const TextStyle(
                                      color: AppColors.muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    '${school.students} students',
                                    style: const TextStyle(
                                      color: AppColors.muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                  _StatusPill(
                                    label: status.$1,
                                    color: status.$2,
                                  ),
                                  TextButton(
                                    onPressed: () => onViewSchool(school),
                                    child: const Text('View School →'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _AssignedSchoolNameCell extends StatelessWidget {
  const _AssignedSchoolNameCell({required this.school});

  final ManagedSchool school;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Avatar(label: _initials(school.name)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                school.name,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 3),
              Text(
                school.code,
                style: const TextStyle(color: AppColors.muted, fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AssignedSchoolsHeader extends StatelessWidget {
  const _AssignedSchoolsHeader();

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 860;
    const style = TextStyle(
      color: AppColors.muted,
      fontSize: 10,
      fontWeight: FontWeight.w800,
      letterSpacing: .7,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          const Expanded(flex: 4, child: Text('SCHOOL NAME', style: style)),
          if (wide) ...[
            const Expanded(flex: 2, child: Text('REGION', style: style)),
            const Expanded(flex: 1, child: Text('STUDENTS', style: style)),
            const Expanded(flex: 2, child: Text('STATUS', style: style)),
            const Expanded(flex: 2, child: Text('ACTIONS', style: style)),
          ],
        ],
      ),
    );
  }
}

class _AssignedSchoolsEmptyRow extends StatelessWidget {
  const _AssignedSchoolsEmptyRow();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          const _Avatar(label: '—'),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'No schools assigned yet',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 4),
                Text(
                  'Assign schools will appear in this table.',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.avatar,
    required this.title,
    required this.subtitle,
    required this.statusLabel,
    required this.statusColor,
    required this.actions,
  });

  final String avatar;
  final String title;
  final String subtitle;
  final String statusLabel;
  final Color statusColor;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Wrap(
          spacing: 16,
          runSpacing: 16,
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.spaceBetween,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Avatar(label: avatar, size: 58),
                const SizedBox(width: 14),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 5),
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
              ],
            ),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _StatusPill(label: statusLabel, color: statusColor),
                ...actions,
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoGrid extends StatelessWidget {
  const _InfoGrid({required this.items});
  final List<_InfoItem> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final responsiveColumns = constraints.maxWidth >= 760
            ? 3
            : constraints.maxWidth >= 480
            ? 2
            : 1;
        final columns = responsiveColumns;
        const gap = 12.0;
        final width = (constraints.maxWidth - (columns - 1) * gap) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: items
              .map((item) => SizedBox(width: width, child: _InfoBlock(item)))
              .toList(),
        );
      },
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.items,
    this.trailing,
    this.child,
  });
  final String title;
  final List<_InfoItem> items;
  final Widget? trailing;
  final Widget? child;

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
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 14),
            child ?? _InfoGrid(items: items),
          ],
        ),
      ),
    );
  }
}

class _ContactInformationView extends StatelessWidget {
  const _ContactInformationView({required this.contact});

  final Map<String, dynamic> contact;

  @override
  Widget build(BuildContext context) {
    final personalPhones = _contactRows(
      contact['personalPhoneNumbers'],
      valueKeys: const ['number', 'phoneNumber'],
    );
    final workPhones = _contactRows(
      contact['workPhoneNumbers'],
      valueKeys: const ['number', 'phoneNumber'],
    );
    final emails = _list(contact['emails'])
        .map((value) => value.toString().trim())
        .where((value) => value.isNotEmpty)
        .toList();
    final socialMedia = _socialMediaRows(contact['socialMedia']);
    final website = _field(contact, const ['website']);

    final hasAny =
        personalPhones.isNotEmpty ||
        workPhones.isNotEmpty ||
        emails.isNotEmpty ||
        socialMedia.isNotEmpty ||
        website != 'Not provided';
    if (!hasAny) {
      return const _EmptyState(
        icon: Icons.contact_phone_outlined,
        title: 'No contact information added',
        detail:
            'Phone numbers, email addresses, and social links will appear here.',
      );
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children:
          [
            _ContactGroupCard(
              title: 'Personal phones',
              icon: Icons.phone_iphone_rounded,
              rows: personalPhones,
            ),
            _ContactGroupCard(
              title: 'Work phones',
              icon: Icons.phone_in_talk_rounded,
              rows: workPhones,
            ),
            _ContactGroupCard(
              title: 'Emails',
              icon: Icons.alternate_email_rounded,
              rows: emails,
            ),
            if (website != 'Not provided')
              _ContactGroupCard(
                title: 'Website',
                icon: Icons.language_rounded,
                rows: [website],
              ),
            _ContactGroupCard(
              title: 'Social media',
              icon: Icons.public_rounded,
              rows: socialMedia,
            ),
          ].where((card) => card.rows.isNotEmpty).map((card) {
            return SizedBox(width: 310, child: card);
          }).toList(),
    );
  }
}

class _ContactGroupCard extends StatelessWidget {
  const _ContactGroupCard({
    required this.title,
    required this.icon,
    required this.rows,
  });

  final String title;
  final IconData icon;
  final List<String> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.green, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...rows.map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                row,
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentsView extends StatelessWidget {
  const _DocumentsView({required this.documents, required this.onViewDocument});

  final List<SchoolDocumentInfo> documents;
  final ValueChanged<SchoolDocumentInfo> onViewDocument;

  @override
  Widget build(BuildContext context) {
    if (documents.isEmpty) {
      return const _EmptyState(
        icon: Icons.description_outlined,
        title: 'No documents uploaded',
        detail:
            'Uploaded school registration and compliance files will appear here.',
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 980
            ? 3
            : constraints.maxWidth >= 640
            ? 2
            : 1;
        const gap = 12.0;
        final width = (constraints.maxWidth - (columns - 1) * gap) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: documents.map((document) {
            return SizedBox(
              width: width,
              child: _DocumentCard(
                document: document,
                onView: () => onViewDocument(document),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({required this.document, required this.onView});

  final SchoolDocumentInfo document;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    final status = document.status.trim().isEmpty
        ? 'Available'
        : _titleCase(document.status);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onView,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.greenSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.description_rounded,
                color: AppColors.green,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _titleCase(document.documentType),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .4,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    document.fileName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _SmallPill(label: status, color: AppColors.green),
                      const SizedBox(width: 8),
                      const Text(
                        'Open',
                        style: TextStyle(
                          color: AppColors.green,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.open_in_new_rounded, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}

class _GradeStructureView extends StatelessWidget {
  const _GradeStructureView({required this.gradeLevels});

  final List<SchoolGradeLevelInfo> gradeLevels;

  @override
  Widget build(BuildContext context) {
    if (gradeLevels.isEmpty) {
      return const _EmptyState(
        icon: Icons.account_tree_outlined,
        title: 'No grade levels configured',
        detail: 'Configured grade levels and stream counts will appear here.',
      );
    }

    final activeGrades = gradeLevels
        .where((grade) => grade.status.trim().toUpperCase() == 'ACTIVE')
        .toList();
    final visibleGrades = activeGrades.isEmpty ? gradeLevels : activeGrades;
    final groups = _groupGradeLevels(visibleGrades);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: groups.entries.map((entry) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.key.toUpperCase(),
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 10.5,
                  letterSpacing: .7,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: entry.value.map((grade) {
                  return _GradeChip(grade: grade);
                }).toList(),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _GradeChip extends StatelessWidget {
  const _GradeChip({required this.grade});

  final SchoolGradeLevelInfo grade;

  @override
  Widget build(BuildContext context) {
    final streams = grade.numberOfStreams;
    final streamLabel = streams == 1 ? '1 stream' : '$streams streams';
    final inactive = grade.status.trim().toUpperCase() != 'ACTIVE';
    return Container(
      constraints: const BoxConstraints(minWidth: 130),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: inactive ? AppColors.background : AppColors.greenSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: inactive
              ? AppColors.border
              : AppColors.green.withValues(alpha: .18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            grade.gradeLevelName,
            style: TextStyle(
              color: inactive ? AppColors.muted : AppColors.text,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            streamLabel,
            style: TextStyle(
              color: inactive ? AppColors.muted : AppColors.green,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarEventsList extends StatelessWidget {
  const _CalendarEventsList({required this.events});

  final List<dynamic> events;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return const _EmptyState(
        icon: Icons.event_busy_outlined,
        title: 'No events added',
        detail:
            'Term holidays, sports days, and school events will appear here.',
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 980
            ? 3
            : constraints.maxWidth >= 640
            ? 2
            : 1;
        const gap = 12.0;
        final width = (constraints.maxWidth - (columns - 1) * gap) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: events.asMap().entries.map((entry) {
            return SizedBox(
              width: width,
              child: _CalendarEventCard(
                event: _map(entry.value),
                fallbackName: 'Event ${entry.key + 1}',
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _CalendarEventCard extends StatelessWidget {
  const _CalendarEventCard({required this.event, required this.fallbackName});

  final Map<String, dynamic> event;
  final String fallbackName;

  @override
  Widget build(BuildContext context) {
    final name = _field(event, const ['name', 'eventName'], fallbackName);
    final type = _objectField(event['eventType']);
    final description = _field(event, const ['description']);
    final dateRange = _dateRange(event['startDate'], event['endDate']);
    final timeRange = _timeRange(event['startTime'], event['endTime']);
    final isSchoolDay = event['isSchoolDay'] == true;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _SmallPill(
                label: isSchoolDay ? 'School day' : 'No school',
                color: isSchoolDay ? AppColors.green : AppColors.amber,
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (type != 'Not provided') ...[
            Text(
              type,
              style: const TextStyle(
                color: AppColors.green,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
          ],
          if (description != 'Not provided') ...[
            Text(
              description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
          ],
          _EventMetaRow(icon: Icons.date_range_rounded, text: dateRange),
          const SizedBox(height: 7),
          _EventMetaRow(icon: Icons.schedule_rounded, text: timeRange),
        ],
      ),
    );
  }
}

class _EventMetaRow extends StatelessWidget {
  const _EventMetaRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: AppColors.muted),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.muted, fontSize: 11.5),
          ),
        ),
      ],
    );
  }
}

class _SmallPill extends StatelessWidget {
  const _SmallPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _InfoBlock extends StatelessWidget {
  const _InfoBlock(this.item);
  final _InfoItem item;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.label.toUpperCase(),
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: .7,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          item.value,
          maxLines: 6,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

class _InfoItem {
  const _InfoItem(this.label, this.value);
  final String label;
  final String value;
}

class _Tabs extends StatelessWidget {
  const _Tabs({
    required this.selected,
    required this.labels,
    required this.onSelected,
  });
  final int selected;
  final List<String> labels;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(labels.length, (index) {
          final active = selected == index;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              selected: active,
              onSelected: (_) => onSelected(index),
              label: Text(labels[index]),
              selectedColor: AppColors.greenSoft,
              side: BorderSide(
                color: active ? AppColors.green : AppColors.border,
              ),
              labelStyle: TextStyle(
                color: active ? AppColors.green : AppColors.muted,
                fontWeight: active ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _ActivityPanel extends StatelessWidget {
  const _ActivityPanel({
    required this.activities,
    this.title = 'Activity Log',
    this.compact = false,
  });
  final List<String> activities;
  final String title;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final shown = compact ? activities.take(3).toList() : activities;
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(18),
            child: Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          ...shown.map(
            (activity) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(
                children: [
                  const _Avatar(label: '✓', size: 34),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      activity,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const Text(
                    'Today',
                    style: TextStyle(color: AppColors.muted, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReassignSchoolDialog extends StatefulWidget {
  const _ReassignSchoolDialog({
    required this.school,
    required this.reasons,
    required this.repository,
  });

  final ManagedSchool school;
  final List<SchoolAssignmentReasonOption> reasons;
  final PlatformRepository repository;

  @override
  State<_ReassignSchoolDialog> createState() => _ReassignSchoolDialogState();
}

class _ReassignSchoolDialogState extends State<_ReassignSchoolDialog> {
  final _notes = TextEditingController();
  final _search = TextEditingController();
  AccountManagerProfile? _selectedManager;
  SchoolAssignmentReasonOption? _selectedReason;
  List<AccountManagerProfile> _results = const [];
  Timer? _debounce;
  bool _submitting = false;
  bool _searching = false;
  String? _error;
  String? _searchError;

  @override
  void dispose() {
    _debounce?.cancel();
    _notes.dispose();
    _search.dispose();
    super.dispose();
  }

  bool get _isOtherReason => _selectedReason?.value == 'OTHER';

  List<AccountManagerProfile> _excludeCurrent(
    List<AccountManagerProfile> managers,
  ) {
    final currentId = widget.school.accountManagerId.trim();
    final currentName = widget.school.accountManager.trim().toLowerCase();
    return managers.where((manager) {
      final managerId = manager.id.trim();
      if (currentId.isNotEmpty && managerId == currentId) return false;
      if (currentId.isEmpty &&
          currentName.isNotEmpty &&
          manager.name.trim().toLowerCase() == currentName) {
        return false;
      }
      return managerId.isNotEmpty;
    }).toList();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    final query = value.trim();
    setState(() {
      _selectedManager = null;
      _searchError = null;
      if (query.length < 2) {
        _results = const [];
        _searching = false;
      } else {
        _searching = true;
      }
    });
    if (query.length < 2) return;
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final results = await widget.repository.searchAccountManagers(
          searchTerm: query,
          userStatuses: const ['ACTIVE'],
          size: 10,
        );
        if (!mounted || _search.text.trim() != query) return;
        setState(() {
          _results = _excludeCurrent(results);
          _searching = false;
        });
      } catch (error) {
        if (!mounted || _search.text.trim() != query) return;
        setState(() {
          _results = const [];
          _searching = false;
          _searchError = error.toString().replaceFirst('Exception: ', '');
        });
      }
    });
  }

  void _selectManager(AccountManagerProfile manager) {
    setState(() {
      _selectedManager = manager;
      _search.text = manager.name;
      _results = const [];
      _searchError = null;
      _error = null;
    });
  }

  Future<void> _submit() async {
    final manager = _selectedManager;
    final reason = _selectedReason;
    if (manager == null) {
      setState(() => _error = 'Select the new account manager.');
      return;
    }
    if (reason == null) {
      setState(() => _error = 'Select the reassignment reason.');
      return;
    }
    if (_isOtherReason && _notes.text.trim().isEmpty) {
      setState(() => _error = 'Enter the reason for this reassignment.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.repository.assignSchoolsToAccountManager(
        accountManagerId: manager.id,
        customSchoolIds: [widget.school.code],
        reason: reason.value,
        notes: _notes.text,
      );
      if (mounted) Navigator.pop(context, manager);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit =
        !_submitting && _selectedManager != null && widget.reasons.isNotEmpty;
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Reassign Account Manager',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _submitting
                        ? null
                        : () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              Text(
                'Move ${widget.school.name} to a different account manager. This will update the school assignment immediately.',
                style: const TextStyle(color: AppColors.muted, height: 1.45),
              ),
              const SizedBox(height: 20),
              _ReassignReadOnlyRow(
                label: 'School',
                value: '${widget.school.name} · ${widget.school.code}',
              ),
              const SizedBox(height: 16),
              _ReassignTransferPreview(
                currentManager: widget.school.accountManager.isEmpty
                    ? 'Not assigned'
                    : widget.school.accountManager,
                newManager: _selectedManager?.name,
              ),
              const SizedBox(height: 18),
              const Text(
                'Search for the new account manager',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _search,
                enabled: !_submitting && _selectedManager == null,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  labelText: 'New Account Manager',
                  hintText: 'Type name, email, phone, or region',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _selectedManager == null
                      ? null
                      : IconButton(
                          tooltip: 'Change selected manager',
                          onPressed: _submitting
                              ? null
                              : () {
                                  setState(() {
                                    _selectedManager = null;
                                    _search.clear();
                                    _results = const [];
                                  });
                                },
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
              ),
              if (_selectedManager != null) ...[
                const SizedBox(height: 8),
                _SelectedAccountManagerCard(
                  manager: _selectedManager!,
                  onChange: _submitting
                      ? null
                      : () {
                          setState(() {
                            _selectedManager = null;
                            _search.clear();
                            _results = const [];
                          });
                        },
                ),
              ] else ...[
                const SizedBox(height: 8),
                _AccountManagerSearchResults(
                  query: _search.text,
                  searching: _searching,
                  error: _searchError,
                  results: _results,
                  onSelect: _selectManager,
                ),
              ],
              const SizedBox(height: 16),
              DropdownButtonFormField<SchoolAssignmentReasonOption>(
                value: _selectedReason,
                decoration: const InputDecoration(
                  labelText: 'Reason',
                  hintText: 'Select reason',
                ),
                items: widget.reasons
                    .map(
                      (reason) => DropdownMenuItem(
                        value: reason,
                        child: Text(reason.label),
                      ),
                    )
                    .toList(),
                onChanged: _submitting
                    ? null
                    : (value) => setState(() => _selectedReason = value),
              ),
              if (_isOtherReason) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _notes,
                  enabled: !_submitting,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Specify Reason',
                    hintText: 'Explain why this school is being reassigned',
                  ),
                ),
              ] else ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _notes,
                  enabled: !_submitting,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Notes',
                    hintText: 'Optional internal note',
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.red.withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.red.withValues(alpha: .18),
                    ),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: AppColors.red),
                  ),
                ),
              ],
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _submitting
                        ? null
                        : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: canSubmit ? _submit : null,
                    icon: _submitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.swap_horiz_rounded),
                    label: Text(
                      _submitting ? 'Reassigning...' : 'Confirm Reassign',
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

class _AccountManagerSearchResults extends StatelessWidget {
  const _AccountManagerSearchResults({
    required this.query,
    required this.searching,
    required this.error,
    required this.results,
    required this.onSelect,
  });

  final String query;
  final bool searching;
  final String? error;
  final List<AccountManagerProfile> results;
  final ValueChanged<AccountManagerProfile> onSelect;

  @override
  Widget build(BuildContext context) {
    final trimmed = query.trim();
    if (trimmed.length < 2) {
      return const _PickerHelpBox(
        icon: Icons.manage_search_rounded,
        message:
            'Type at least 2 characters to search active account managers.',
      );
    }
    if (searching) {
      return const _PickerHelpBox(
        icon: Icons.search_rounded,
        message: 'Searching account managers...',
        loading: true,
      );
    }
    if (error != null) {
      return _PickerHelpBox(
        icon: Icons.error_outline_rounded,
        message: 'Could not search account managers. $error',
        color: AppColors.red,
      );
    }
    if (results.isEmpty) {
      return const _PickerHelpBox(
        icon: Icons.person_search_rounded,
        message: 'No active account manager matched this search.',
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: results
            .map(
              (manager) => _AccountManagerResultTile(
                manager: manager,
                onSelect: () => onSelect(manager),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _ReassignTransferPreview extends StatelessWidget {
  const _ReassignTransferPreview({
    required this.currentManager,
    required this.newManager,
  });

  final String currentManager;
  final String? newManager;

  @override
  Widget build(BuildContext context) {
    final selectedNewManager = newManager?.trim();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAF9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 520;
          final current = _ReassignTransferParty(
            label: 'Current Account Manager',
            value: currentManager,
            icon: Icons.person_pin_circle_outlined,
          );
          final next = _ReassignTransferParty(
            label: 'New Account Manager',
            value: selectedNewManager == null || selectedNewManager.isEmpty
                ? 'Search and select below'
                : selectedNewManager,
            icon: Icons.person_add_alt_1_rounded,
            highlighted: selectedNewManager != null &&
                selectedNewManager.isNotEmpty,
          );
          final arrow = Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.greenSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              stacked
                  ? Icons.keyboard_arrow_down_rounded
                  : Icons.arrow_forward_rounded,
              color: AppColors.green,
            ),
          );
          if (stacked) {
            return Column(
              children: [
                current,
                const SizedBox(height: 10),
                arrow,
                const SizedBox(height: 10),
                next,
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: current),
              const SizedBox(width: 12),
              arrow,
              const SizedBox(width: 12),
              Expanded(child: next),
            ],
          );
        },
      ),
    );
  }
}

class _ReassignTransferParty extends StatelessWidget {
  const _ReassignTransferParty({
    required this.label,
    required this.value,
    required this.icon,
    this.highlighted = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: highlighted ? AppColors.greenSoft : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: highlighted
              ? AppColors.green.withValues(alpha: .35)
              : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: highlighted ? Colors.white : AppColors.greenSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.green, size: 19),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
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

class _AccountManagerResultTile extends StatelessWidget {
  const _AccountManagerResultTile({
    required this.manager,
    required this.onSelect,
  });

  final AccountManagerProfile manager;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final status = _managerStatus(manager.status);
    return InkWell(
      onTap: onSelect,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            _Avatar(label: _initials(manager.name), size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    manager.name,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      if (manager.email.isNotEmpty) manager.email,
                      if (manager.phone.isNotEmpty) manager.phone,
                      manager.region,
                      '${manager.schoolCount} schools',
                    ].join(' · '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _StatusPill(label: status.$1, color: status.$2),
          ],
        ),
      ),
    );
  }
}

class _SelectedAccountManagerCard extends StatelessWidget {
  const _SelectedAccountManagerCard({
    required this.manager,
    required this.onChange,
  });

  final AccountManagerProfile manager;
  final VoidCallback? onChange;

  @override
  Widget build(BuildContext context) {
    final status = _managerStatus(manager.status);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.greenSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.green.withValues(alpha: .25)),
      ),
      child: Row(
        children: [
          _Avatar(label: _initials(manager.name), size: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  manager.name,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  '${manager.region} · ${manager.schoolCount} schools',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          _StatusPill(label: status.$1, color: status.$2),
          const SizedBox(width: 8),
          TextButton(onPressed: onChange, child: const Text('Change')),
        ],
      ),
    );
  }
}

class _PickerHelpBox extends StatelessWidget {
  const _PickerHelpBox({
    required this.icon,
    required this.message,
    this.loading = false,
    this.color = AppColors.muted,
  });

  final IconData icon;
  final String message;
  final bool loading;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.border),
    ),
    child: Row(
      children: [
        if (loading)
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          Icon(icon, color: color, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(message, style: TextStyle(color: color, fontSize: 12)),
        ),
      ],
    ),
  );
}

class _ReassignReadOnlyRow extends StatelessWidget {
  const _ReassignReadOnlyRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.background,
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
            fontWeight: FontWeight.w800,
            letterSpacing: .7,
          ),
        ),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
      ],
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Icon(icon, color: AppColors.muted, size: 36),
      const SizedBox(height: 8),
      Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      const SizedBox(height: 4),
      Text(
        detail,
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.muted, fontSize: 12),
      ),
    ],
  );
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.label, this.size = 40});
  final String label;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: AppColors.greenSoft,
      borderRadius: BorderRadius.circular(size * .22),
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: AppColors.green,
        fontWeight: FontWeight.w900,
        fontSize: 12,
      ),
    ),
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      '● $label',
      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800),
    ),
  );
}

(String, Color) _schoolStatus(SchoolStatus status) => switch (status) {
  SchoolStatus.approved => ('Approved', const Color(0xFF059669)),
  SchoolStatus.inProgress => ('In Progress', AppColors.amber),
  SchoolStatus.completed => ('Completed', AppColors.amber),
  SchoolStatus.pendingApproval => ('Pending Approval', AppColors.amber),
  SchoolStatus.needsRevision => ('Needs Revision', AppColors.blue),
  SchoolStatus.rejected => ('Rejected', AppColors.red),
  SchoolStatus.suspended => ('Suspended', AppColors.red),
  SchoolStatus.inactive => ('Inactive', AppColors.muted),
  SchoolStatus.deleted => ('Deleted', AppColors.red),
};

(String, Color) _managerStatus(AccountManagerStatus status) => switch (status) {
  AccountManagerStatus.active => ('Active', const Color(0xFF059669)),
  AccountManagerStatus.pendingApproval => ('Pending approval', AppColors.amber),
  AccountManagerStatus.invited => ('Invited', AppColors.blue),
  AccountManagerStatus.suspended => ('Suspended', AppColors.red),
};

({String label, Color color, IconData icon}) _userStatus(String rawStatus) {
  final status = rawStatus.trim().toUpperCase();
  return switch (status) {
    'ACTIVE' || 'APPROVED' => (
      label: 'Active',
      color: AppColors.green,
      icon: Icons.verified_user_rounded,
    ),
    'PENDING' || 'PENDING_APPROVAL' || 'AWAITING_APPROVAL' => (
      label: 'Pending Approval',
      color: AppColors.amber,
      icon: Icons.pending_actions_rounded,
    ),
    'SUSPENDED' => (
      label: 'Suspended',
      color: AppColors.red,
      icon: Icons.pause_circle_filled_rounded,
    ),
    'REJECTED' => (
      label: 'Rejected',
      color: AppColors.red,
      icon: Icons.cancel_rounded,
    ),
    _ => (
      label: rawStatus.isEmpty ? 'Unknown' : _titleCase(rawStatus),
      color: AppColors.muted,
      icon: Icons.help_outline_rounded,
    ),
  };
}

String _initials(String value) {
  final words = value
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .take(2);
  final initials = words.map((word) => word[0].toUpperCase()).join();
  return initials.isEmpty ? 'S' : initials;
}

String _formatReadableDate(String value) {
  final raw = value.trim();
  if (raw.isEmpty) return 'Not provided';
  if (raw.toLowerCase() == 'never') return 'Never';

  final arrayDate = RegExp(
    r'^\[(\d{4}),\s*(\d{1,2}),\s*(\d{1,2})',
  ).firstMatch(raw);
  if (arrayDate != null) {
    final year = int.tryParse(arrayDate.group(1)!);
    final month = int.tryParse(arrayDate.group(2)!);
    final day = int.tryParse(arrayDate.group(3)!);
    if (year != null && month != null && day != null) {
      return _formatDayMonthYear(DateTime(year, month, day));
    }
  }

  final parsed = DateTime.tryParse(raw.replaceFirst(' ', 'T'));
  if (parsed == null) return raw;
  return _formatDayMonthYear(parsed);
}

String _formatDayMonthYear(DateTime value) {
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
  final day = value.day;
  final suffix = switch (day) {
    11 || 12 || 13 => 'th',
    _ when day % 10 == 1 => 'st',
    _ when day % 10 == 2 => 'nd',
    _ when day % 10 == 3 => 'rd',
    _ => 'th',
  };
  return '$day$suffix ${months[value.month - 1]} ${value.year}';
}

String _titleCase(String value) {
  final normalized = value.trim().replaceAll('_', ' ').toLowerCase();
  if (normalized.isEmpty) return 'Not provided';
  return normalized
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}

Map<String, dynamic> _map(dynamic value) =>
    value is Map<String, dynamic> ? value : const <String, dynamic>{};

List<dynamic> _list(dynamic value) => value is List ? value : const [];

String _value(Map<String, dynamic> source, List<String> keys) {
  for (final key in keys) {
    final value = source[key];
    if (value != null && value.toString().trim().isNotEmpty) {
      return value.toString().trim();
    }
  }
  return '';
}

String _nestedValue(dynamic source, List<String> keys) {
  if (source is Map<String, dynamic>) return _value(source, keys);
  if (source == null) return '';
  return source.toString().trim();
}

String _field(
  Map<String, dynamic> source,
  List<String> keys, [
  String fallback = 'Not provided',
]) {
  final value = _value(source, keys);
  return value.isEmpty ? fallback : value;
}

String _objectField(
  dynamic source, {
  List<String> valueKeys = const ['name'],
  String fallback = 'Not provided',
}) {
  final value = _nestedValue(source, valueKeys);
  return value.isEmpty ? fallback : value;
}

List<String> _contactRows(dynamic source, {required List<String> valueKeys}) {
  return _list(source)
      .map((item) {
        final contact = _map(item);
        final number = _value(contact, valueKeys);
        final type = _value(contact, const ['type']);
        if (number.isEmpty) return '';
        return type.isEmpty ? number : '$number ($type)';
      })
      .where((value) => value.isNotEmpty)
      .toList();
}

List<String> _socialMediaRows(dynamic source) {
  return _list(source)
      .map((item) {
        final media = _map(item);
        final platform = _nestedValue(media['platform'], const ['name']);
        final handle = _value(media, const ['handle', 'url']);
        if (platform.isEmpty && handle.isEmpty) return '';
        if (platform.isEmpty) return handle;
        if (handle.isEmpty) return platform;
        return '$platform: $handle';
      })
      .where((value) => value.isNotEmpty)
      .toList();
}

String _dateField(dynamic value) {
  if (value == null) return 'Not provided';
  if (value is List && value.length >= 3) {
    final year = int.tryParse('${value[0]}');
    final month = int.tryParse('${value[1]}');
    final day = int.tryParse('${value[2]}');
    if (year != null && month != null && day != null) {
      return _formatDayMonthYear(DateTime(year, month, day));
    }
  }
  if (value is Map) {
    final year = int.tryParse('${value['year']}');
    final month = int.tryParse('${value['month']}');
    final day = int.tryParse('${value['day']}');
    if (year != null && month != null && day != null) {
      return _formatDayMonthYear(DateTime(year, month, day));
    }
  }
  return _formatReadableDate(value.toString());
}

String _dateRange(dynamic start, dynamic end) {
  final startText = _dateField(start);
  final endText = _dateField(end);
  if (startText == 'Not provided' && endText == 'Not provided') {
    return 'Date not provided';
  }
  if (startText == endText || endText == 'Not provided') return startText;
  if (startText == 'Not provided') return endText;
  return '$startText - $endText';
}

String _timeRange(dynamic start, dynamic end) {
  final startText = _timeField(start);
  final endText = _timeField(end);
  if (startText == 'Not provided' && endText == 'Not provided') {
    return 'Time not provided';
  }
  if (startText == endText || endText == 'Not provided') return startText;
  if (startText == 'Not provided') return endText;
  return '$startText - $endText';
}

String _timeField(dynamic value) {
  final parsed = _parseHourMinute(value);
  if (parsed == null) return 'Not provided';
  final hour = parsed.$1;
  final minute = parsed.$2;
  final period = hour >= 12 ? 'PM' : 'AM';
  final displayHour = hour % 12 == 0 ? 12 : hour % 12;
  final displayMinute = minute.toString().padLeft(2, '0');
  return '$displayHour:$displayMinute $period';
}

(int, int)? _parseHourMinute(dynamic value) {
  if (value == null) return null;
  if (value is List && value.length >= 2) {
    final hour = int.tryParse('${value[0]}');
    final minute = int.tryParse('${value[1]}');
    if (hour != null && minute != null) return (hour, minute);
  }
  if (value is Map) {
    final hour = int.tryParse('${value['hour']}');
    final minute = int.tryParse('${value['minute']}');
    if (hour != null && minute != null) return (hour, minute);
  }
  final raw = value.toString().trim();
  if (raw.isEmpty) return null;
  final array = RegExp(r'^\[(\d{1,2}),\s*(\d{1,2})').firstMatch(raw);
  if (array != null) {
    final hour = int.tryParse(array.group(1)!);
    final minute = int.tryParse(array.group(2)!);
    if (hour != null && minute != null) return (hour, minute);
  }
  final parts = raw.split(':');
  if (parts.length >= 2) {
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour != null && minute != null) return (hour, minute);
  }
  return null;
}

String _actionError(Object error) {
  final text = error
      .toString()
      .replaceFirst('ClientException: ', '')
      .replaceFirst('Exception: ', '')
      .trim();
  if (text.isEmpty) {
    return 'Please try again.';
  }
  return text.endsWith('.') ? text : '$text.';
}

Map<String, List<SchoolGradeLevelInfo>> _groupGradeLevels(
  List<SchoolGradeLevelInfo> grades,
) {
  final grouped = <String, List<SchoolGradeLevelInfo>>{};
  for (final grade in grades) {
    final group = _gradeGroupLabel(grade.gradeLevelName);
    grouped.putIfAbsent(group, () => []).add(grade);
  }
  const order = [
    'Early Childhood',
    'Primary School',
    'Junior High School',
    'Senior High School',
    'Other Levels',
  ];
  return {
    for (final key in order)
      if (grouped.containsKey(key)) key: grouped[key]!,
    for (final entry in grouped.entries)
      if (!order.contains(entry.key)) entry.key: entry.value,
  };
}

String _gradeGroupLabel(String gradeName) {
  final value = gradeName.trim().toUpperCase();
  if (value.contains('CRECHE') ||
      value.contains('NURSERY') ||
      value.contains('KINDER') ||
      value.contains('KG')) {
    return 'Early Childhood';
  }
  if (value.contains('JHS') ||
      value.contains('JUNIOR HIGH') ||
      value.contains('BASIC 7') ||
      value.contains('BASIC 8') ||
      value.contains('BASIC 9')) {
    return 'Junior High School';
  }
  if (value.contains('SHS') ||
      value.contains('SENIOR HIGH') ||
      value.contains('FORM ')) {
    return 'Senior High School';
  }
  if (value.contains('PRIMARY') ||
      RegExp(r'\bP[1-6]\b').hasMatch(value) ||
      RegExp(r'\bBASIC [1-6]\b').hasMatch(value)) {
    return 'Primary School';
  }
  return 'Other Levels';
}
