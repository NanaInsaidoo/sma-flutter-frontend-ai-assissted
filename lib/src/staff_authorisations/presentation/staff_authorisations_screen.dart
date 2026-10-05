import 'package:flutter/material.dart';

import '../../common/display_formatters.dart';
import '../../theme/app_theme.dart';
import '../data/staff_authorisation_api_client.dart';

class StaffAuthorisationsScreen extends StatefulWidget {
  const StaffAuthorisationsScreen({
    super.key,
    required this.customSchoolId,
    this.accessToken,
    this.onRefreshAccessToken,
    this.onBack,
    this.apiClient,
  });

  final String customSchoolId;
  final String? accessToken;
  final Future<String?> Function()? onRefreshAccessToken;
  final VoidCallback? onBack;
  final StaffAuthorisationApiClient? apiClient;

  @override
  State<StaffAuthorisationsScreen> createState() =>
      _StaffAuthorisationsScreenState();
}

class _StaffAuthorisationsScreenState extends State<StaffAuthorisationsScreen>
    with SingleTickerProviderStateMixin {
  late final StaffAuthorisationApiClient _api;
  late final TabController _tabs;
  bool _loading = true;
  String? _error;
  AuthorisationCatalog? _catalog;
  List<JobTitleRecord> _titles = const [];
  List<AuthorityTemplateRecord> _authorities = const [];
  List<StaffAccessUser> _staff = const [];
  List<PermissionExceptionRecord> _pendingExceptions = const [];
  List<AuthorityAssignmentRecord> _pendingAssignments = const [];
  StaffAccessUser? _selectedStaff;
  EffectiveAccessRecord? _effectiveAccess;
  bool _loadingAccess = false;

  @override
  void initState() {
    super.initState();
    _api =
        widget.apiClient ??
        StaffAuthorisationApiClient(
          accessToken: widget.accessToken,
          onRefreshAccessToken: widget.onRefreshAccessToken,
        );
    _tabs = TabController(length: 4, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait<dynamic>([
        _api.getCatalog(widget.customSchoolId),
        _api.getAuthorities(widget.customSchoolId),
        _api.getJobTitles(widget.customSchoolId),
        _api.getStaffUsers(widget.customSchoolId),
        _api.getPendingExceptions(widget.customSchoolId),
        _api.getPendingAssignments(widget.customSchoolId),
      ]);
      if (!mounted) return;
      setState(() {
        _catalog = results[0] as AuthorisationCatalog;
        _authorities = results[1] as List<AuthorityTemplateRecord>;
        _titles = results[2] as List<JobTitleRecord>;
        _staff = results[3] as List<StaffAccessUser>;
        _pendingExceptions = results[4] as List<PermissionExceptionRecord>;
        _pendingAssignments = results[5] as List<AuthorityAssignmentRecord>;
        if (_selectedStaff != null) {
          _selectedStaff = _staff
              .where((item) => item.id == _selectedStaff!.id)
              .firstOrNull;
        }
        _loading = false;
      });
    } on StaffAuthorisationApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabs = TabBar(
      controller: _tabs,
      isScrollable: true,
      tabs: [
        const Tab(text: 'Job titles'),
        const Tab(text: 'Authority roles'),
        const Tab(text: 'Individual access'),
        Tab(
          text:
              'Approvals (${_pendingExceptions.length + _pendingAssignments.length})',
        ),
      ],
    );
    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) => [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
          sliver: SliverList.list(
            children: [
              Row(
                children: [
                  if (widget.onBack != null) ...[
                    IconButton(
                      tooltip: 'Back to settings',
                      onPressed: widget.onBack,
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const SizedBox(width: 8),
                  ],
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Staff roles & authorisations',
                          style: TextStyle(
                            color: AppColors.text,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 5),
                        Text(
                          'Job titles describe the person. Authority roles control what they can do.',
                          style: TextStyle(color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Refresh',
                    onPressed: _loading ? null : _load,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _SafetyBanner(
                pending: _pendingExceptions.length + _pendingAssignments.length,
              ),
              const SizedBox(height: 6),
            ],
          ),
        ),
        SliverPersistentHeader(
          pinned: true,
          delegate: _PinnedTabBarDelegate(
            tabBar: tabs,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          ),
        ),
      ],
      body: Padding(
        padding: const EdgeInsets.fromLTRB(28, 12, 28, 28),
        child: _body(),
      ),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return _ErrorState(message: _error!, onRetry: _load);
    }
    return TabBarView(
      controller: _tabs,
      children: [
        _jobTitlesTab(),
        _authoritiesTab(),
        _individualAccessTab(),
        _approvalsTab(),
      ],
    );
  }

  Widget _jobTitlesTab() {
    return _ScrollableTab(
      header: _TabHeader(
        title: 'School job titles',
        description:
            'Add the title used by the school and choose the existing authority it should inherit.',
        action: FilledButton.icon(
          key: const Key('add-job-title'),
          onPressed: _showAddJobTitle,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add job title'),
        ),
      ),
      children: _titles.map((title) {
        return _RecordCard(
          title: title.name,
          subtitle:
              'Same authority as ${title.authority.name} · ${displayRoleName(title.authority.baseRole)}',
          leading: Icons.badge_outlined,
          tags: [
            if (title.systemDefault) 'Standard',
            title.active ? 'Active' : 'Inactive',
          ],
          trailing: Switch(
            value: title.active,
            onChanged: (value) => _toggleTitle(title, value),
          ),
        );
      }).toList(),
    );
  }

  Widget _authoritiesTab() {
    return _ScrollableTab(
      header: _TabHeader(
        title: 'Authority roles',
        description:
            'Built-in roles are stable defaults. Create a school role by copying one and changing only the access you need.',
        action: FilledButton.icon(
          key: const Key('add-authority-role'),
          onPressed: _showAddAuthority,
          icon: const Icon(Icons.add_moderator_outlined),
          label: const Text('Create authority role'),
        ),
      ),
      children: _authorities.map((authority) {
        final rules = authority.permissionRules
            .map(
              (rule) =>
                  '${_label(rule.effect)} ${_label(rule.action)} · ${_label(rule.resource == '*' ? rule.module : rule.resource)}',
            )
            .toList();
        return _RecordCard(
          title: authority.name,
          subtitle: authority.description.isEmpty
              ? 'Based on ${displayRoleName(authority.baseRole)}'
              : authority.description,
          leading: authority.builtIn
              ? Icons.verified_user_outlined
              : Icons.admin_panel_settings_outlined,
          tags: [
            authority.builtIn ? 'Built in' : 'School role',
            '${authority.assignedUsers} assigned',
            if (rules.isNotEmpty) '${rules.length} custom rules',
          ],
          details: rules,
        );
      }).toList(),
    );
  }

  Widget _individualAccessTab() {
    return ListView(
      children: [
        _TabHeader(
          title: 'Individual access',
          description:
              'Grant or block one permission for one staff member without changing anyone else with the same job title.',
          action: const SizedBox.shrink(),
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<StaffAccessUser>(
                    key: const Key('staff-access-selector'),
                    value: _selectedStaff,
                    decoration: const InputDecoration(
                      labelText: 'Staff member',
                      prefixIcon: Icon(Icons.person_search_outlined),
                    ),
                    items: _staff
                        .map(
                          (user) => DropdownMenuItem(
                            value: user,
                            child: Text(
                              '${user.name} · ${displayRoleName(user.role)}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (user) {
                      setState(() {
                        _selectedStaff = user;
                        _effectiveAccess = null;
                      });
                      if (user != null) _loadEffectiveAccess();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _selectedStaff == null
                      ? null
                      : _showAssignAuthority,
                  icon: const Icon(Icons.add_moderator_outlined),
                  label: const Text('Assign authority'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  key: const Key('add-individual-rule'),
                  onPressed: _selectedStaff == null ? null : _showAddAccessRule,
                  icon: const Icon(Icons.rule_rounded),
                  label: const Text('Add access rule'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        if (_selectedStaff == null)
          const _EmptyState(
            icon: Icons.manage_accounts_outlined,
            title: 'Select a staff member',
            body:
                'You will see their roles, individual exceptions, and the final access decision for each permission.',
          )
        else if (_loadingAccess)
          const Padding(
            padding: EdgeInsets.all(48),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_effectiveAccess != null)
          _effectiveAccessView(_effectiveAccess!),
      ],
    );
  }

  Widget _effectiveAccessView(EffectiveAccessRecord access) {
    final importantDecisions = access.decisions
        .where((decision) => decision.allowed || decision.resource != '*')
        .toList();
    final roleLabels = <String>[];
    final seenRoleLabels = <String>{};
    for (final role in access.roles) {
      final label = displayRoleName(role).trim();
      if (label.isNotEmpty && seenRoleLabels.add(label.toLowerCase())) {
        roleLabels.add(label);
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  access.displayName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: roleLabels
                      .map((label) => Chip(label: Text(label)))
                      .toList(),
                ),
                if (access.authorities.isNotEmpty) ...[
                  const Divider(height: 28),
                  const Text(
                    'Authority assignments',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  ...access.authorities.map(
                    (assignment) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.admin_panel_settings_outlined),
                      title: Text(assignment.authorityName),
                      subtitle: Text(
                        '${_label(assignment.scopeType)} scope${assignment.scopeId.isEmpty ? '' : ' · ${assignment.scopeId}'} · ${_label(assignment.status)}',
                      ),
                      trailing: assignment.active
                          ? TextButton(
                              onPressed: () => _revokeAssignment(assignment),
                              child: const Text('Revoke'),
                            )
                          : null,
                    ),
                  ),
                ],
                if (access.exceptions.isNotEmpty) ...[
                  const Divider(height: 28),
                  const Text(
                    'Individual rules & history',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  ...access.exceptions.map(
                    (rule) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        rule.effect == 'DENY'
                            ? Icons.block_rounded
                            : Icons.check_circle_outline_rounded,
                        color: rule.effect == 'DENY'
                            ? AppColors.red
                            : AppColors.green,
                      ),
                      title: Text(
                        '${rule.effect == 'DENY' ? 'Block' : 'Allow'} ${_label(rule.action)} · ${_label(rule.resource == '*' ? rule.module : rule.resource)}',
                      ),
                      subtitle: Text('${rule.reason} · ${_label(rule.status)}'),
                      trailing:
                          rule.status == 'ACTIVE' || rule.status == 'PENDING'
                          ? TextButton(
                              onPressed: () => _revokeException(rule),
                              child: const Text('Revoke'),
                            )
                          : null,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Effective access',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                const Text(
                  'This is the final result after role defaults, scopes, individual grants, and blocks are combined.',
                  style: TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 12),
                ...importantDecisions.map(
                  (decision) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      decision.allowed
                          ? Icons.check_circle_rounded
                          : Icons.cancel_rounded,
                      color: decision.allowed ? AppColors.green : AppColors.red,
                    ),
                    title: Text(
                      '${_label(decision.action)} · ${_label(decision.resource == '*' ? decision.module : decision.resource)}',
                    ),
                    subtitle: Text(decision.source),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _approvalsTab() {
    final empty = _pendingExceptions.isEmpty && _pendingAssignments.isEmpty;
    return ListView(
      children: [
        const _TabHeader(
          title: 'Sensitive access approvals',
          description:
              'Administrator-level roles and sensitive actions require a different authorised person to approve them.',
          action: SizedBox.shrink(),
        ),
        const SizedBox(height: 14),
        if (empty)
          const _EmptyState(
            icon: Icons.verified_user_outlined,
            title: 'No approvals waiting',
            body:
                'Sensitive access changes will appear here for independent review.',
          ),
        ..._pendingAssignments.map(
          (assignment) => _ApprovalCard(
            title: 'Assign ${assignment.authorityName}',
            subtitle:
                'User ${assignment.userId} · requested by ${assignment.assignedBy} · ${_label(assignment.scopeType)} scope',
            onApprove: () => _approveAssignment(assignment),
            onReject: () => _revokePendingAssignment(assignment),
          ),
        ),
        ..._pendingExceptions.map(
          (rule) => _ApprovalCard(
            title:
                '${rule.effect == 'DENY' ? 'Block' : 'Allow'} ${_label(rule.action)} · ${_label(rule.resource == '*' ? rule.module : rule.resource)}',
            subtitle:
                '${rule.userName} · requested by ${rule.requestedBy}\nReason: ${rule.reason}',
            onApprove: () => _decideException(rule, true),
            onReject: () => _decideException(rule, false),
          ),
        ),
      ],
    );
  }

  Future<void> _loadEffectiveAccess() async {
    final user = _selectedStaff;
    if (user == null) return;
    setState(() => _loadingAccess = true);
    try {
      final value = await _api.getEffectiveAccess(
        schoolId: widget.customSchoolId,
        userId: user.id,
      );
      if (!mounted || _selectedStaff?.id != user.id) return;
      setState(() {
        _effectiveAccess = value;
        _loadingAccess = false;
      });
    } on StaffAuthorisationApiException catch (error) {
      if (!mounted) return;
      setState(() => _loadingAccess = false);
      _message(error.message, error: true);
    }
  }

  Future<void> _toggleTitle(JobTitleRecord title, bool active) async {
    try {
      await _api.updateJobTitle(
        schoolId: widget.customSchoolId,
        title: title,
        active: active,
      );
      await _load();
    } on StaffAuthorisationApiException catch (error) {
      _message(error.message, error: true);
    }
  }

  Future<void> _showAddJobTitle() async {
    final name = TextEditingController();
    final description = TextEditingController();
    AuthorityTemplateRecord? authority = _authorities.firstOrNull;
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add job title'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  key: const Key('job-title-name'),
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Job title *'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<AuthorityTemplateRecord>(
                  value: authority,
                  decoration: const InputDecoration(
                    labelText: 'Same authority as *',
                  ),
                  items: _authorities
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(item.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setDialogState(() => authority = value),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: description,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const Key('save-job-title'),
              onPressed: authority == null
                  ? null
                  : () => Navigator.pop(context, true),
              child: const Text('Add title'),
            ),
          ],
        ),
      ),
    );
    if (saved != true || authority == null) {
      name.dispose();
      description.dispose();
      return;
    }
    if (name.text.trim().isEmpty) {
      _message('Enter a job title.', error: true);
      name.dispose();
      description.dispose();
      return;
    }
    try {
      await _api.createJobTitle(
        schoolId: widget.customSchoolId,
        name: name.text.trim(),
        description: description.text.trim(),
        authorityTemplateId: authority!.id,
      );
      await _load();
      _message('Job title added.');
    } on StaffAuthorisationApiException catch (error) {
      _message(error.message, error: true);
    } finally {
      name.dispose();
      description.dispose();
    }
  }

  Future<void> _showAddAuthority() async {
    final catalog = _catalog;
    if (catalog == null || _authorities.isEmpty) return;
    final name = TextEditingController();
    final description = TextEditingController();
    AuthorityTemplateRecord base = _authorities.first;
    String? module;
    String? action;
    String resource = '*';
    String effect = 'DENY';
    String scope = 'SCHOOL';
    bool includeRule = false;
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create authority role'),
          content: SizedBox(
            width: 600,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Role name *'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<AuthorityTemplateRecord>(
                    value: base,
                    decoration: const InputDecoration(
                      labelText: 'Copy authority from *',
                    ),
                    items: _authorities
                        .map(
                          (item) => DropdownMenuItem(
                            value: item,
                            child: Text(item.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setDialogState(() => base = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: description,
                    decoration: const InputDecoration(labelText: 'Description'),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: includeRule,
                    title: const Text('Add one access difference now'),
                    subtitle: const Text(
                      'You can copy the role unchanged or add a precise allow/block rule.',
                    ),
                    onChanged: (value) =>
                        setDialogState(() => includeRule = value),
                  ),
                  if (includeRule) ...[
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: module,
                            decoration: const InputDecoration(
                              labelText: 'Area',
                            ),
                            items: catalog.modules
                                .map(
                                  (item) => DropdownMenuItem(
                                    value: item,
                                    child: Text(_label(item)),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) =>
                                setDialogState(() => module = value),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: action,
                            decoration: const InputDecoration(
                              labelText: 'Action',
                            ),
                            items: catalog.actions
                                .map(
                                  (item) => DropdownMenuItem(
                                    value: item,
                                    child: Text(_label(item)),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) =>
                                setDialogState(() => action = value),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: resource,
                            decoration: const InputDecoration(
                              labelText: 'Specific workflow',
                            ),
                            items: catalog.resources
                                .map(
                                  (item) => DropdownMenuItem(
                                    value: item,
                                    child: Text(
                                      item == '*' ? 'Whole area' : _label(item),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) => setDialogState(
                              () => resource = value ?? resource,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: effect,
                            decoration: const InputDecoration(
                              labelText: 'Effect',
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'DENY',
                                child: Text('Block'),
                              ),
                              DropdownMenuItem(
                                value: 'ALLOW',
                                child: Text('Allow'),
                              ),
                            ],
                            onChanged: (value) =>
                                setDialogState(() => effect = value ?? effect),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Create role'),
            ),
          ],
        ),
      ),
    );
    if (saved != true || name.text.trim().isEmpty) return;
    if (includeRule && (module == null || action == null)) {
      _message(
        'Choose an area and action for the access difference.',
        error: true,
      );
      return;
    }
    try {
      await _api.createAuthority(
        schoolId: widget.customSchoolId,
        name: name.text.trim(),
        description: description.text.trim(),
        baseTemplateId: base.id,
        rules: includeRule
            ? [
                PermissionRuleInput(
                  module: module!,
                  resource: resource,
                  action: action!,
                  effect: effect,
                  scopeType: scope,
                ),
              ]
            : const [],
      );
      await _load();
      _message('Authority role created.');
    } on StaffAuthorisationApiException catch (error) {
      _message(error.message, error: true);
    } finally {
      name.dispose();
      description.dispose();
    }
  }

  Future<void> _showAssignAuthority() async {
    final user = _selectedStaff;
    if (user == null || _authorities.isEmpty) return;
    AuthorityTemplateRecord authority = _authorities.first;
    String scope = 'SCHOOL';
    final scopeId = TextEditingController();
    final endDate = TextEditingController();
    bool primary = false;
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Assign authority to ${user.name}'),
          content: SizedBox(
            width: 540,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<AuthorityTemplateRecord>(
                  value: authority,
                  decoration: const InputDecoration(
                    labelText: 'Authority role',
                  ),
                  items: _authorities
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(item.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setDialogState(() => authority = value);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: scope,
                  decoration: const InputDecoration(labelText: 'Scope'),
                  items: (_catalog?.scopeTypes ?? const ['SCHOOL'])
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(_label(item)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setDialogState(() => scope = value ?? scope),
                ),
                if (scope != 'SCHOOL') ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: scopeId,
                    decoration: InputDecoration(
                      labelText: '${_label(scope)} identifier *',
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: endDate,
                  decoration: const InputDecoration(
                    labelText: 'End date (optional, YYYY-MM-DD)',
                  ),
                ),
                CheckboxListTile(
                  value: primary,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Make this the primary authority'),
                  onChanged: (value) =>
                      setDialogState(() => primary = value == true),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Assign'),
            ),
          ],
        ),
      ),
    );
    if (saved != true) return;
    if (scope != 'SCHOOL' && scopeId.text.trim().isEmpty) {
      _message(
        'Enter the ${_label(scope).toLowerCase()} identifier.',
        error: true,
      );
      return;
    }
    try {
      final result = await _api.assignAuthority(
        schoolId: widget.customSchoolId,
        userId: user.id,
        authorityTemplateId: authority.id,
        scopeType: scope,
        scopeId: scopeId.text,
        endsOn: endDate.text.trim().isEmpty ? null : endDate.text.trim(),
        primary: primary,
      );
      await _loadEffectiveAccess();
      await _load();
      _message(
        result.status == 'PENDING'
            ? 'Sensitive authority sent for independent approval.'
            : 'Authority assigned.',
      );
    } on StaffAuthorisationApiException catch (error) {
      _message(error.message, error: true);
    } finally {
      scopeId.dispose();
      endDate.dispose();
    }
  }

  Future<void> _showAddAccessRule() async {
    final user = _selectedStaff;
    final catalog = _catalog;
    if (user == null || catalog == null) return;
    String? module;
    String? action;
    String resource = '*';
    String effect = 'DENY';
    String scope = 'SCHOOL';
    final scopeId = TextEditingController();
    final reason = TextEditingController();
    final expiry = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Individual access for ${user.name}'),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.greenSoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'This changes only this person. It does not alter the default authority for other staff with the same title.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          key: const Key('individual-rule-effect'),
                          value: effect,
                          decoration: const InputDecoration(
                            labelText: 'Effect',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'DENY',
                              child: Text('Block'),
                            ),
                            DropdownMenuItem(
                              value: 'ALLOW',
                              child: Text('Allow'),
                            ),
                          ],
                          onChanged: (value) =>
                              setDialogState(() => effect = value ?? effect),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: module,
                          decoration: const InputDecoration(
                            labelText: 'Area *',
                          ),
                          items: catalog.modules
                              .map(
                                (item) => DropdownMenuItem(
                                  value: item,
                                  child: Text(_label(item)),
                                ),
                              )
                              .toList(),
                          onChanged: (value) =>
                              setDialogState(() => module = value),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: resource,
                          decoration: const InputDecoration(
                            labelText: 'Workflow',
                          ),
                          items: catalog.resources
                              .map(
                                (item) => DropdownMenuItem(
                                  value: item,
                                  child: Text(
                                    item == '*' ? 'Whole area' : _label(item),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) => setDialogState(
                            () => resource = value ?? resource,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: action,
                          decoration: const InputDecoration(
                            labelText: 'Action *',
                          ),
                          items: catalog.actions
                              .map(
                                (item) => DropdownMenuItem(
                                  value: item,
                                  child: Text(_label(item)),
                                ),
                              )
                              .toList(),
                          onChanged: (value) =>
                              setDialogState(() => action = value),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: scope,
                    decoration: const InputDecoration(labelText: 'Scope'),
                    items: catalog.scopeTypes
                        .map(
                          (item) => DropdownMenuItem(
                            value: item,
                            child: Text(_label(item)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setDialogState(() => scope = value ?? scope),
                  ),
                  if (scope != 'SCHOOL') ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: scopeId,
                      decoration: InputDecoration(
                        labelText: '${_label(scope)} identifier *',
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  TextField(
                    key: const Key('individual-rule-reason'),
                    controller: reason,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Business reason *',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: expiry,
                    decoration: const InputDecoration(
                      labelText: 'Expiry date (optional, YYYY-MM-DD)',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const Key('save-individual-rule'),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save access rule'),
            ),
          ],
        ),
      ),
    );
    if (saved != true) return;
    if (module == null || action == null || reason.text.trim().isEmpty) {
      _message('Choose an area and action, then enter a reason.', error: true);
      return;
    }
    if (scope != 'SCHOOL' && scopeId.text.trim().isEmpty) {
      _message(
        'Enter the ${_label(scope).toLowerCase()} identifier.',
        error: true,
      );
      return;
    }
    try {
      final result = await _api.createException(
        schoolId: widget.customSchoolId,
        userId: user.id,
        module: module!,
        resource: resource,
        action: action!,
        effect: effect,
        scopeType: scope,
        scopeId: scopeId.text,
        reason: reason.text.trim(),
        expiresOn: expiry.text.trim().isEmpty ? null : expiry.text.trim(),
      );
      await _loadEffectiveAccess();
      await _load();
      _message(
        result.status == 'PENDING'
            ? 'Sensitive change sent for independent approval.'
            : 'Individual access rule applied.',
      );
    } on StaffAuthorisationApiException catch (error) {
      _message(error.message, error: true);
    } finally {
      scopeId.dispose();
      reason.dispose();
      expiry.dispose();
    }
  }

  Future<void> _approveAssignment(AuthorityAssignmentRecord assignment) async {
    try {
      await _api.approveAssignment(
        schoolId: widget.customSchoolId,
        assignmentId: assignment.id,
      );
      await _load();
      _message('Authority assignment approved.');
    } on StaffAuthorisationApiException catch (error) {
      _message(error.message, error: true);
    }
  }

  Future<void> _revokePendingAssignment(
    AuthorityAssignmentRecord assignment,
  ) async {
    final reason = await _reasonDialog('Reject authority assignment');
    if (reason == null) return;
    try {
      await _api.revokeAssignment(
        schoolId: widget.customSchoolId,
        assignmentId: assignment.id,
        reason: reason,
      );
      await _load();
      _message('Authority assignment rejected.');
    } on StaffAuthorisationApiException catch (error) {
      _message(error.message, error: true);
    }
  }

  Future<void> _decideException(
    PermissionExceptionRecord rule,
    bool approve,
  ) async {
    final reason = approve ? '' : await _reasonDialog('Reject access change');
    if (!approve && reason == null) return;
    try {
      await _api.decideException(
        schoolId: widget.customSchoolId,
        exceptionId: rule.id,
        approve: approve,
        reason: reason ?? '',
      );
      await _load();
      _message(approve ? 'Access change approved.' : 'Access change rejected.');
    } on StaffAuthorisationApiException catch (error) {
      _message(error.message, error: true);
    }
  }

  Future<void> _revokeException(PermissionExceptionRecord rule) async {
    final reason = await _reasonDialog('Revoke individual access rule');
    if (reason == null) return;
    try {
      await _api.revokeException(
        schoolId: widget.customSchoolId,
        exceptionId: rule.id,
        reason: reason,
      );
      await _loadEffectiveAccess();
      _message('Access rule revoked.');
    } on StaffAuthorisationApiException catch (error) {
      _message(error.message, error: true);
    }
  }

  Future<void> _revokeAssignment(AuthorityAssignmentRecord assignment) async {
    final reason = await _reasonDialog('Revoke authority assignment');
    if (reason == null) return;
    try {
      await _api.revokeAssignment(
        schoolId: widget.customSchoolId,
        assignmentId: assignment.id,
        reason: reason,
      );
      await _loadEffectiveAccess();
      _message('Authority assignment revoked.');
    } on StaffAuthorisationApiException catch (error) {
      _message(error.message, error: true);
    }
  }

  Future<String?> _reasonDialog(String title) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Reason *'),
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
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  void _message(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? AppColors.red : null,
      ),
    );
  }
}

class _SafetyBanner extends StatelessWidget {
  const _SafetyBanner({required this.pending});
  final int pending;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.greenSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.green.withValues(alpha: .25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.shield_outlined, color: AppColors.green),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Safety controls are active: no self-grants, no granting beyond your own authority, independent approval for sensitive changes, expiry, and a full audit trail.',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          if (pending > 0) Chip(label: Text('$pending awaiting approval')),
        ],
      ),
    );
  }
}

class _PinnedTabBarDelegate extends SliverPersistentHeaderDelegate {
  const _PinnedTabBarDelegate({
    required this.tabBar,
    required this.backgroundColor,
  });

  final TabBar tabBar;
  final Color backgroundColor;

  @override
  double get minExtent => tabBar.preferredSize.height + 12;

  @override
  double get maxExtent => minExtent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Material(
      color: backgroundColor,
      elevation: overlapsContent ? 1 : 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 12, 28, 0),
        child: tabBar,
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _PinnedTabBarDelegate oldDelegate) =>
      oldDelegate.tabBar != tabBar ||
      oldDelegate.backgroundColor != backgroundColor;
}

class _ScrollableTab extends StatelessWidget {
  const _ScrollableTab({required this.header, required this.children});
  final Widget header;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: children.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) =>
          index == 0 ? header : children[index - 1],
    );
  }
}

class _TabHeader extends StatelessWidget {
  const _TabHeader({
    required this.title,
    required this.description,
    required this.action,
  });
  final String title;
  final String description;
  final Widget action;

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
                title,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(description, style: const TextStyle(color: AppColors.muted)),
            ],
          ),
        ),
        const SizedBox(width: 16),
        action,
      ],
    );
  }
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({
    required this.title,
    required this.subtitle,
    required this.leading,
    required this.tags,
    this.trailing,
    this.details = const [],
  });
  final String title;
  final String subtitle;
  final IconData leading;
  final List<String> tags;
  final Widget? trailing;
  final List<String> details;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.greenSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(leading, color: AppColors.green),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(color: AppColors.muted),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: tags
                        .map((tag) => Chip(label: Text(tag)))
                        .toList(),
                  ),
                  if (details.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ...details.map(
                      (detail) => Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text('• $detail'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

class _ApprovalCard extends StatelessWidget {
  const _ApprovalCard({
    required this.title,
    required this.subtitle,
    required this.onApprove,
    required this.onReject,
  });
  final String title;
  final String subtitle;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.approval_outlined, color: AppColors.amber),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              TextButton(onPressed: onReject, child: const Text('Reject')),
              const SizedBox(width: 8),
              FilledButton(onPressed: onApprove, child: const Text('Approve')),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });
  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: Center(
          child: Column(
            children: [
              Icon(icon, size: 42, color: AppColors.muted),
              const SizedBox(height: 12),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 5),
              Text(
                body,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted),
              ),
              if (action != null) ...[const SizedBox(height: 16), action!],
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _EmptyState(
      icon: Icons.lock_outline_rounded,
      title: 'Authorisations unavailable',
      body: message,
      action: OutlinedButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('Try again'),
      ),
    );
  }
}

String _label(String value) {
  final clean = value
      .replaceAll(RegExp(r'[_-]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      .toLowerCase();
  if (clean.isEmpty) return '';
  return '${clean[0].toUpperCase()}${clean.substring(1)}';
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
