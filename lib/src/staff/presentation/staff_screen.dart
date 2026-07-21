import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../data/staff_api_client.dart';
import '../../theme/app_theme.dart';

class StaffScreen extends StatefulWidget {
  const StaffScreen({
    super.key,
    this.openAddStaffOnLoad = false,
    this.onAddStaffRequestConsumed,
    this.customSchoolId,
    this.accessToken,
    this.onRefreshAccessToken,
  });

  final bool openAddStaffOnLoad;
  final VoidCallback? onAddStaffRequestConsumed;
  final String? customSchoolId;
  final String? accessToken;
  final Future<String?> Function()? onRefreshAccessToken;

  @override
  State<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends State<StaffScreen> {
  final List<_StaffMember> _localEduHireDrafts = [];
  List<_StaffMember> _staff = [];
  _StaffTab _tab = _StaffTab.staffList;
  _StaffMember? _selectedStaff;
  String _query = '';
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
        onBack: () => setState(() => _selectedStaff = null),
      );
    }

    final visibleStaff = _filteredStaff;
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
                staff: visibleStaff
                    .where((member) => member.status != _StaffStatus.draft)
                    .toList(),
                query: _query,
                onQueryChanged: (value) => setState(() => _query = value),
                onOpenStaff: (member) =>
                    setState(() => _selectedStaff = member),
              ),
              _StaffTab.onboarding => _OnboardingPanel(
                staff: visibleStaff
                    .where((member) => member.status == _StaffStatus.draft)
                    .toList(),
                query: _query,
                onQueryChanged: (value) => setState(() => _query = value),
                onOpenStaff: (member) =>
                    setState(() => _selectedStaff = member),
              ),
            },
          ],
        ],
      ),
    );
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
      final users = await StaffApiClient(
        accessToken: accessToken,
        onRefreshAccessToken: widget.onRefreshAccessToken,
      ).getSchoolStaffUsers(customSchoolId: customSchoolId);
      final nextStaff = [
        ...users.map(_staffFromUserRecord),
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
        apiClient: StaffApiClient(
          accessToken: widget.accessToken,
          onRefreshAccessToken: widget.onRefreshAccessToken,
        ),
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

  _StaffMember _staffFromUserRecord(StaffUserRecord user) {
    final firstName = _clean(user.firstName).isEmpty
        ? _fallbackFirstName(user)
        : _clean(user.firstName);
    final lastName = _clean(user.lastName);
    final role = _formatRole(user.role);
    final status = _statusFromAccountStatus(user.accountStatus);
    final category = _categoryForRole(user.role);
    return _StaffMember(
      id: user.id.isEmpty ? user.userName : user.id,
      firstName: firstName,
      lastName: lastName.isEmpty ? '' : lastName,
      role: role,
      department: 'Not configured',
      category: category,
      employmentType: 'Not configured',
      contractType: 'Not configured',
      email: _display(user.email),
      phone: _display(user.phoneNumber),
      dateOfBirth: _formatDate(user.dateOfBirth),
      address: 'Not configured',
      emergencyName: 'Not configured',
      emergencyRelationship: 'Not configured',
      emergencyPhone: 'Not configured',
      startDate: _formatDate(user.createdAt),
      status: status,
      sourceLabel: 'School user',
      sourceReference: _display(user.userName),
      color: _colorForRole(user.role),
      checks: [
        if (user.mustChangePassword) 'Awaiting first password change',
        if (!user.mustChangePassword) 'Login setup complete',
        'Employment profile can be completed from onboarding',
      ],
      assignments: const [],
    );
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

String _formatRole(String role) {
  final clean = _clean(role);
  if (clean.isEmpty) return 'Staff';
  return clean
      .split('_')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0]}${part.substring(1).toLowerCase()}')
      .join(' ');
}

_StaffStatus _statusFromAccountStatus(String status) {
  return switch (_clean(status).toUpperCase()) {
    'ACTIVE' => _StaffStatus.active,
    'INVITED' => _StaffStatus.invited,
    'PENDING' ||
    'PENDING_REVIEW' ||
    'PENDING_APPROVAL' => _StaffStatus.pendingReview,
    'SUSPENDED' || 'INACTIVE' || 'DELETED' => _StaffStatus.suspended,
    _ => _StaffStatus.draft,
  };
}

String _categoryForRole(String role) {
  return switch (_clean(role).toUpperCase()) {
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
  final date = DateTime.tryParse(clean.replaceFirst(' ', 'T'));
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
    final teaching = staff.where((item) => item.category == 'Teaching');
    final nonTeaching = staff.where((item) => item.category == 'Support');
    final drafts = staff.where((item) => item.status == _StaffStatus.draft);
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
        'Onboarding drafts',
        drafts.length.toString(),
        'Imported or manually created',
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
  const _StaffTabs({required this.selected, required this.onChanged});

  final _StaffTab selected;
  final ValueChanged<_StaffTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      children: [
        _TabButton(
          label: 'Staff List',
          icon: Icons.groups_rounded,
          selected: selected == _StaffTab.staffList,
          onTap: () => onChanged(_StaffTab.staffList),
        ),
        _TabButton(
          label: 'Onboarding',
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
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(selected ? Icons.check_rounded : icon, size: 18),
      label: Text(label),
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
  });

  final List<_StaffMember> staff;
  final String query;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<_StaffMember> onOpenStaff;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          _PanelSearch(
            value: query,
            hint: 'Search staff by name, role, department, email, or phone',
            onChanged: onQueryChanged,
          ),
          const Divider(height: 1, color: AppColors.border),
          const _StaffTableHeader(showSource: false),
          if (staff.isEmpty)
            const _EmptyPanel(
              icon: Icons.group_off_rounded,
              title: 'No staff found',
              body: 'Try a different search term or add a staff member.',
            )
          else
            ...staff.map(
              (member) => _StaffRow(
                staff: member,
                showSource: false,
                onTap: () => onOpenStaff(member),
              ),
            ),
        ],
      ),
    );
  }
}

class _OnboardingPanel extends StatelessWidget {
  const _OnboardingPanel({
    required this.staff,
    required this.query,
    required this.onQueryChanged,
    required this.onOpenStaff,
  });

  final List<_StaffMember> staff;
  final String query;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<_StaffMember> onOpenStaff;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          _PanelSearch(
            value: query,
            hint: 'Search onboarding drafts',
            onChanged: onQueryChanged,
          ),
          const Divider(height: 1, color: AppColors.border),
          const _StaffTableHeader(showSource: true),
          if (staff.isEmpty)
            const _EmptyPanel(
              icon: Icons.assignment_late_outlined,
              title: 'No onboarding drafts',
              body: 'Manual drafts and EduHire imports will appear here.',
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
  });

  final String value;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: TextEditingController(text: value)
          ..selection = TextSelection.collapsed(offset: value.length),
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(Icons.search_rounded),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 16,
          ),
        ),
      ),
    );
  }
}

class _StaffTableHeader extends StatelessWidget {
  const _StaffTableHeader({required this.showSource});

  final bool showSource;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF7F9F9),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
      child: Row(
        children: [
          const Expanded(flex: 3, child: _HeaderLabel('Staff member')),
          const Expanded(flex: 2, child: _HeaderLabel('Role')),
          const Expanded(flex: 2, child: _HeaderLabel('Department')),
          if (showSource) const Expanded(child: _HeaderLabel('Source')),
          const Expanded(child: _HeaderLabel('Status')),
          const Expanded(child: _HeaderLabel('Start date')),
          const SizedBox(width: 88, child: _HeaderLabel('Actions')),
        ],
      ),
    );
  }
}

class _HeaderLabel extends StatelessWidget {
  const _HeaderLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: AppColors.muted,
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
    required this.onTap,
  });

  final _StaffMember staff;
  final bool showSource;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  _InitialsBadge(name: staff.fullName, color: staff.color),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          staff.fullName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppColors.text,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${staff.email} · ${staff.phone}',
                          overflow: TextOverflow.ellipsis,
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
            ),
            Expanded(flex: 2, child: Text(staff.role)),
            Expanded(
              flex: 2,
              child: Text(
                staff.department,
                style: const TextStyle(color: AppColors.muted),
              ),
            ),
            if (showSource)
              Expanded(child: _SourceBadge(source: staff.sourceLabel)),
            Expanded(child: _StatusBadge(status: staff.status)),
            Expanded(
              child: Text(
                staff.startDate,
                style: const TextStyle(color: AppColors.muted),
              ),
            ),
            SizedBox(
              width: 88,
              child: OutlinedButton(
                onPressed: onTap,
                child: const Text('View'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StaffProfilePage extends StatefulWidget {
  const _StaffProfilePage({required this.staff, required this.onBack});

  final _StaffMember staff;
  final VoidCallback onBack;

  @override
  State<_StaffProfilePage> createState() => _StaffProfilePageState();
}

class _StaffProfilePageState extends State<_StaffProfilePage> {
  _StaffProfileTab _tab = _StaffProfileTab.profile;

  @override
  Widget build(BuildContext context) {
    final staff = widget.staff;
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
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  _InitialsBadge(
                    name: staff.fullName,
                    color: staff.color,
                    size: 78,
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                staff.fullName,
                                style: const TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.text,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            _StatusBadge(status: staff.status),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${staff.role} · ${staff.department} · ${staff.employmentType}',
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.edit_rounded, size: 18),
                    label: const Text('Edit profile'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: staff.status == _StaffStatus.draft
                        ? () {}
                        : null,
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Approve draft'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.green,
                    ),
                  ),
                ],
              ),
            ),
          ),
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
      case _StaffProfileTab.payrollTax:
        return _PayrollTaxProfileTab(staff: staff);
      case _StaffProfileTab.documents:
        return _DocumentsTab(staff: staff);
      case _StaffProfileTab.leave:
        return _LeaveProfileTab(staff: staff);
      case _StaffProfileTab.activity:
        return _ActivityTab(staff: staff);
    }
  }
}

class _StaffProfileTabs extends StatelessWidget {
  const _StaffProfileTabs({required this.selected, required this.onChanged});

  final _StaffProfileTab selected;
  final ValueChanged<_StaffProfileTab> onChanged;

  @override
  Widget build(BuildContext context) {
    final tabs = [
      (_StaffProfileTab.profile, 'Profile'),
      (_StaffProfileTab.payrollTax, 'Payroll & Tax'),
      (_StaffProfileTab.documents, 'Documents'),
      (_StaffProfileTab.leave, 'Leave'),
      (_StaffProfileTab.activity, 'Activity'),
    ];
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: tabs
          .map(
            (tab) => _TabButton(
              label: tab.$2,
              icon: Icons.circle,
              selected: selected == tab.$1,
              onTap: () => onChanged(tab.$1),
            ),
          )
          .toList(),
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
    return _ProfileGrid(
      cards: [
        _InfoCard('Email', staff.email, Icons.mail_outline_rounded),
        _InfoCard('Phone', staff.phone, Icons.phone_rounded),
        _InfoCard('Date of birth', staff.dateOfBirth, Icons.cake_rounded),
        _InfoCard('Address', staff.address, Icons.location_on_outlined),
        _InfoCard(
          'Emergency contact',
          '${staff.emergencyName}\n${staff.emergencyRelationship} · ${staff.emergencyPhone}',
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
    );
  }
}

class _EmploymentTab extends StatelessWidget {
  const _EmploymentTab({required this.staff});

  final _StaffMember staff;

  @override
  Widget build(BuildContext context) {
    return _ProfileGrid(
      cards: [
        _InfoCard('Role', staff.role, Icons.work_outline_rounded),
        _InfoCard('Department', staff.department, Icons.apartment_rounded),
        _InfoCard('Employment type', staff.employmentType, Icons.badge_rounded),
        _InfoCard('Contract type', staff.contractType, Icons.description),
        _InfoCard('Expected start date', staff.startDate, Icons.event),
        _InfoCard('Category', staff.category, Icons.category_rounded),
      ],
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

class _PayrollTaxProfileTab extends StatelessWidget {
  const _PayrollTaxProfileTab({required this.staff});

  final _StaffMember staff;

  @override
  Widget build(BuildContext context) {
    return _ProfileGrid(
      cards: [
        _InfoCard('Staff member', staff.fullName, Icons.person_outline_rounded),
        _InfoCard('Basic salary', 'Not configured', Icons.payments_rounded),
        _InfoCard('Allowances', 'Not configured', Icons.add_card_rounded),
        _InfoCard(
          'Deductions',
          'Not configured',
          Icons.remove_circle_outline_rounded,
        ),
        _InfoCard('SSNIT number', 'Not provided', Icons.verified_user_rounded),
        _InfoCard('TIN / GRA', 'Not provided', Icons.receipt_long_rounded),
        _InfoCard(
          'Bank details',
          'Not configured',
          Icons.account_balance_rounded,
        ),
      ],
    );
  }
}

class _LeaveProfileTab extends StatelessWidget {
  const _LeaveProfileTab({required this.staff});

  final _StaffMember staff;

  @override
  Widget build(BuildContext context) {
    return _ProfileGrid(
      cards: [
        _InfoCard('Staff member', staff.fullName, Icons.person_outline_rounded),
        _InfoCard(
          'Leave balance',
          'Not configured',
          Icons.event_available_rounded,
        ),
        _InfoCard('Pending requests', '0', Icons.pending_actions_rounded),
        _InfoCard(
          'Approved this term',
          '0',
          Icons.check_circle_outline_rounded,
        ),
        _InfoCard('Last leave', 'No leave recorded', Icons.history_rounded),
      ],
    );
  }
}

class _DocumentsTab extends StatelessWidget {
  const _DocumentsTab({required this.staff});

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
              'Documents and checks',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            ...staff.checks.map(
              (check) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_outlined, color: AppColors.green),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        check,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const _SoftBadge(label: 'Verified', color: AppColors.green),
                  ],
                ),
              ),
            ),
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
    final activities = [
      '${staff.fullName} profile opened for review',
      '${staff.sourceLabel} staff draft created',
      'Contact details captured',
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Activity',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            ...activities.map(
              (activity) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.history_rounded),
                title: Text(activity),
                subtitle: const Text('Today'),
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
        final columns = constraints.maxWidth >= 980 ? 3 : 2;
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.green),
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
                  const SizedBox(height: 8),
                  Text(
                    value,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontWeight: FontWeight.w800,
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
  static const _roles = [
    ('ADMINISTRATOR', 'Administrator'),
    ('HEAD_TEACHER', 'Head teacher'),
    ('ASSISTANT_HEAD_TEACHER', 'Assistant head teacher'),
    ('CLASS_TEACHER', 'Class teacher'),
    ('SUBJECT_TEACHER', 'Subject teacher'),
    ('BURSAR', 'Bursar'),
    ('SECRETARY', 'Secretary'),
  ];

  final _firstName = TextEditingController();
  final _middleName = TextEditingController();
  final _lastName = TextEditingController();
  final _dateOfBirth = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _position = TextEditingController();
  final _startDate = TextEditingController();
  final _basicPay = TextEditingController();
  final _houseAllowance = TextEditingController();
  final _transportAllowance = TextEditingController();
  final _otherAllowances = TextEditingController();
  final _grossSalary = TextEditingController();
  final _ssnitNumber = TextEditingController();
  final _tinNumber = TextEditingController();
  final List<_ReferenceForm> _references = [_ReferenceForm(), _ReferenceForm()];

  int _step = 0;
  String _role = 'CLASS_TEACHER';
  String _employmentType = 'FULL_TIME';
  StaffLookupOption? _department;
  StaffLookupOption? _employmentStatus;
  CreatedSchoolUser? _createdUser;
  String? _staffId;
  bool _loadingLookups = true;
  bool _saving = false;
  String? _error;
  List<StaffLookupOption> _departments = const [];
  List<StaffLookupOption> _employmentStatuses = const [];
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
    _position.dispose();
    _startDate.dispose();
    _basicPay.dispose();
    _houseAllowance.dispose();
    _transportAllowance.dispose();
    _otherAllowances.dispose();
    _grossSalary.dispose();
    _ssnitNumber.dispose();
    _tinNumber.dispose();
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
      2 => _financeStep(),
      3 => _resumeStep(),
      _ => _referencesStep(),
    };
  }

  Widget _identityStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _DrawerSectionTitle('Staff login identity'),
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
          label: 'Date of birth *',
          onPick: () => _pickDate(_dateOfBirth, lastDate: DateTime.now()),
        ),
        Row(
          children: [
            Expanded(
              child: _DrawerField(
                controller: _email,
                label: 'Email *',
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
        DropdownButtonFormField<String>(
          value: _role,
          decoration: const InputDecoration(labelText: 'Staff role *'),
          items: _roles
              .map(
                (role) =>
                    DropdownMenuItem(value: role.$1, child: Text(role.$2)),
              )
              .toList(),
          onChanged: (value) => setState(() => _role = value ?? _role),
        ),
        const SizedBox(height: 12),
        const Text(
          'The backend will send invitation credentials and require this staff member to change password on first login.',
          style: TextStyle(color: AppColors.muted, height: 1.35),
        ),
      ],
    );
  }

  Widget _employmentStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_createdUser != null) ...[
          _CreatedUserBanner(user: _createdUser!),
          const SizedBox(height: 16),
        ],
        const _DrawerSectionTitle('Employment details'),
        _DrawerField(
          controller: _position,
          label: 'Position *',
          hint: 'e.g. Mathematics Teacher',
        ),
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
          decoration: const InputDecoration(labelText: 'Employment type *'),
          items: const [
            DropdownMenuItem(value: 'FULL_TIME', child: Text('Full-time')),
            DropdownMenuItem(value: 'PART_TIME', child: Text('Part-time')),
            DropdownMenuItem(value: 'CONTRACT', child: Text('Contract')),
            DropdownMenuItem(value: 'TEMPORARY', child: Text('Temporary')),
            DropdownMenuItem(value: 'CASUAL', child: Text('Casual')),
          ],
          onChanged: (value) =>
              setState(() => _employmentType = value ?? _employmentType),
        ),
        const SizedBox(height: 12),
        if (_employmentStatuses.isNotEmpty)
          DropdownButtonFormField<StaffLookupOption>(
            value: _employmentStatus,
            decoration: const InputDecoration(labelText: 'Employment status'),
            items: _employmentStatuses
                .map(
                  (status) =>
                      DropdownMenuItem(value: status, child: Text(status.name)),
                )
                .toList(),
            onChanged: (value) => setState(() => _employmentStatus = value),
          ),
        if (_employmentStatuses.isNotEmpty) const SizedBox(height: 12),
        _DateDrawerField(
          controller: _startDate,
          label: 'Expected start date *',
          onPick: () => _pickDate(_startDate),
        ),
      ],
    );
  }

  Widget _financeStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _DrawerSectionTitle('Payroll and tax'),
        Row(
          children: [
            Expanded(
              child: _DrawerField(
                controller: _basicPay,
                label: 'Basic pay (GH¢) *',
                hint: '2500',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _DrawerField(
                controller: _houseAllowance,
                label: 'House allowance',
                hint: '0',
              ),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: _DrawerField(
                controller: _transportAllowance,
                label: 'Transport allowance',
                hint: '0',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _DrawerField(
                controller: _otherAllowances,
                label: 'Other allowances',
                hint: '0',
              ),
            ),
          ],
        ),
        _DrawerField(
          controller: _grossSalary,
          label: 'Gross salary (GH¢)',
          hint: 'Leave blank to use pay + allowances',
        ),
        Row(
          children: [
            Expanded(
              child: _DrawerField(
                controller: _ssnitNumber,
                label: 'SSNIT number',
                hint: 'C123456789012',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _DrawerField(
                controller: _tinNumber,
                label: 'TIN number',
                hint: 'P1234567890',
              ),
            ),
          ],
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
          'Add at least two referees who can confirm this staff member’s employment history.',
          style: TextStyle(color: AppColors.muted),
        ),
        const SizedBox(height: 14),
        ...List.generate(
          _references.length,
          (index) => _ReferenceCard(
            index: index,
            reference: _references[index],
            canRemove: _references.length > 2,
            onRemove: () => setState(() => _references.removeAt(index)),
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
      final departments = await widget.apiClient.getDepartments(
        widget.customSchoolId,
      );
      List<StaffLookupOption> statuses = const [];
      try {
        statuses = await widget.apiClient.getEmploymentStatuses();
      } on StaffApiException {
        statuses = const [];
      }
      if (!mounted) return;
      setState(() {
        _departments = departments
            .where((item) => item.id.isNotEmpty && item.name.isNotEmpty)
            .toList();
        _employmentStatuses = statuses
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
          await _saveFinance();
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
          _dateOfBirth.text.trim().isEmpty ||
          _email.text.trim().isEmpty ||
          _phone.text.trim().isEmpty) {
        return 'Complete the required staff identity fields.';
      }
      if (!_email.text.contains('@')) return 'Enter a valid email address.';
      final digits = _phone.text.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.length < 10 || digits.length > 15) {
        return 'Enter a valid phone number with 10 to 15 digits.';
      }
    }
    if (_step == 1) {
      if (_createdUser == null) return 'Create the staff login first.';
      if (_position.text.trim().isEmpty ||
          _department == null ||
          _startDate.text.trim().isEmpty) {
        return 'Complete the employment details before continuing.';
      }
    }
    if (_step == 2) {
      if (_staffId == null) return 'Start staff onboarding first.';
      if (_numberValue(_basicPay) <= 0) {
        return 'Enter the basic pay before continuing.';
      }
    }
    if (_step == 3 && _resume == null) {
      return 'Upload the staff resume before continuing.';
    }
    if (_step == 4) {
      for (final reference in _references) {
        if (!reference.isComplete) {
          return 'Complete all reference fields before finishing.';
        }
      }
    }
    return null;
  }

  Future<void> _createUserIfNeeded() async {
    if (_createdUser != null) return;
    _createdUser = await widget.apiClient.createSchoolUser(
      customSchoolId: widget.customSchoolId,
      body: {
        'firstName': _firstName.text.trim(),
        if (_middleName.text.trim().isNotEmpty)
          'middleName': _middleName.text.trim(),
        'lastName': _lastName.text.trim(),
        'dateOfBirth': _dateOfBirth.text.trim(),
        'email': _email.text.trim(),
        'phoneNumber': _normalisePhone(_phone.text),
        'userType': 'STAFF',
        'role': _role,
        'emailDelivery': true,
        'smsDelivery': true,
        'printSlipDelivery': false,
      },
    );
    if (_createdUser!.userId.isEmpty) {
      throw const StaffApiException(
        'The staff user was created but the backend did not return a user ID.',
      );
    }
  }

  Future<void> _initiateStaffIfNeeded() async {
    if (_staffId != null && _staffId!.isNotEmpty) return;
    final result = await widget.apiClient.initiateOnboarding(
      body: {
        'userId': _createdUser!.userId,
        'position': _position.text.trim(),
        'departmentId': _department!.id,
        'employmentType': _employmentType,
        'startDate': _startDate.text.trim(),
      },
    );
    if (result.staffId.isEmpty) {
      throw const StaffApiException(
        'Staff onboarding started, but the backend did not return a staff ID.',
      );
    }
    _staffId = result.staffId;
  }

  Future<void> _saveFinance() async {
    await widget.apiClient.createFinance(
      staffId: _staffId!,
      body: {
        'basicPay': _numberValue(_basicPay),
        'houseAllowance': _numberValue(_houseAllowance),
        'transportAllowance': _numberValue(_transportAllowance),
        'otherAllowances': _numberValue(_otherAllowances),
        'grossSalary': _grossSalary.text.trim().isEmpty
            ? _calculatedGross
            : _numberValue(_grossSalary),
        if (_ssnitNumber.text.trim().isNotEmpty)
          'ssnitNumber': _ssnitNumber.text.trim(),
        if (_tinNumber.text.trim().isNotEmpty)
          'tinNumber': _tinNumber.text.trim(),
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
      staffId: _staffId!,
      bytes: bytes,
      fileName: file.name,
    );
  }

  Future<void> _saveReferencesAndFinish() async {
    for (final reference in _references) {
      await widget.apiClient.createEmploymentReference(
        staffId: _staffId!,
        body: reference.toJson(),
      );
    }
    if (!mounted) return;
    final roleLabel = _roles
        .firstWhere((role) => role.$1 == _role, orElse: () => (_role, _role))
        .$2;
    Navigator.pop(
      context,
      _StaffMember(
        id: _staffId!,
        firstName: _firstName.text.trim(),
        lastName: _lastName.text.trim(),
        role: roleLabel,
        department: _department?.name ?? 'Unassigned',
        category: _role.contains('TEACHER') ? 'Teaching' : 'Support',
        employmentType: _employmentTypeLabel,
        contractType: _employmentType == 'CONTRACT'
            ? 'Fixed term'
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
        sourceReference: _createdUser?.username.isNotEmpty == true
            ? _createdUser!.username
            : 'Manual staff user',
        color: AppColors.green,
        checks: const [
          'Login credentials sent',
          'Employment onboarding created',
          'Finance information captured',
          'Resume uploaded',
          'References captured',
        ],
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
      'Payroll and tax',
      'Resume upload',
      'References',
    ][step];
  }

  double get _calculatedGross =>
      _numberValue(_basicPay) +
      _numberValue(_houseAllowance) +
      _numberValue(_transportAllowance) +
      _numberValue(_otherAllowances);

  double _numberValue(TextEditingController controller) {
    return double.tryParse(controller.text.trim().replaceAll(',', '')) ?? 0;
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
      _ => _employmentType,
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
    'Payroll',
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

class _CreatedUserBanner extends StatelessWidget {
  const _CreatedUserBanner({required this.user});

  final CreatedSchoolUser user;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.greenSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.green.withValues(alpha: .22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: AppColors.green),
              SizedBox(width: 8),
              Text(
                'Staff login created',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (user.username.isNotEmpty)
            Text(
              'Username: ${user.username}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          if (user.temporaryPassword?.isNotEmpty == true) ...[
            const SizedBox(height: 4),
            Text(
              'Temporary password: ${user.temporaryPassword}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
          const SizedBox(height: 6),
          const Text(
            'Continue to attach employment, finance, resume, and references to the staff record.',
            style: TextStyle(color: AppColors.muted, height: 1.35),
          ),
        ],
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

  bool get isComplete {
    return referenceName.text.trim().isNotEmpty &&
        referenceJobTitle.text.trim().isNotEmpty &&
        referenceOrganization.text.trim().isNotEmpty &&
        referencePhoneNumber.text.trim().isNotEmpty &&
        referenceEmail.text.trim().contains('@') &&
        relationshipToApplicant.text.trim().isNotEmpty &&
        durationKnown.text.trim().isNotEmpty;
  }

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
      _StaffStatus.pendingReview => AppColors.amber,
      _StaffStatus.draft => AppColors.muted,
      _StaffStatus.suspended => AppColors.red,
    };
    final label = switch (status) {
      _StaffStatus.active => 'Active',
      _StaffStatus.invited => 'Invited',
      _StaffStatus.pendingReview => 'Pending review',
      _StaffStatus.draft => 'Draft',
      _StaffStatus.suspended => 'Suspended',
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 12,
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

enum _StaffProfileTab { profile, payrollTax, documents, leave, activity }

enum _AddStaffMode { manual, eduhire }

enum _StaffStatus { active, invited, pendingReview, draft, suspended }

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
    required this.checks,
    required this.assignments,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String role;
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
  final List<String> checks;
  final List<String> assignments;

  String get fullName => '$firstName $lastName';

  _StaffMember copyWith({String? id}) {
    return _StaffMember(
      id: id ?? this.id,
      firstName: firstName,
      lastName: lastName,
      role: role,
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
      checks: checks,
      assignments: assignments,
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
  checks: [
    'Criminal background clear',
    'Police clearance verified',
    'Medical clearance complete',
    'Certificate verification complete',
    'Reference checks completed',
  ],
  assignments: ['Pending class teacher assignment'],
);
