import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../data/platform_repository.dart';
import '../domain/platform_models.dart';

class AccountManagersScreen extends StatefulWidget {
  const AccountManagersScreen({
    super.key,
    required this.repository,
    required this.schools,
    required this.onViewManager,
  });
  final PlatformRepository repository;
  final List<ManagedSchool> schools;
  final ValueChanged<AccountManagerProfile> onViewManager;

  @override
  State<AccountManagersScreen> createState() => _AccountManagersScreenState();
}

class _AccountManagersScreenState extends State<AccountManagersScreen> {
  static const _pageSize = 20;

  late Future<AccountManagerPage> _managers;
  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  AccountManagerStatus? _filter;
  int _page = 0;
  String _searchTerm = '';

  @override
  void initState() {
    super.initState();
    _managers = _loadManagers();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<AccountManagerPage> _loadManagers() {
    return widget.repository.getAccountManagerPage(
      searchTerm: _searchTerm,
      userStatuses: _statusesFor(_filter),
      page: _page,
      size: _pageSize,
    );
  }

  void _reload() {
    setState(() => _managers = _loadManagers());
  }

  void _goToPage(int page) {
    setState(() {
      _page = page;
      _managers = _loadManagers();
    });
  }

  void _selectFilter(AccountManagerStatus? status) {
    setState(() {
      _filter = status;
      _page = 0;
      _managers = _loadManagers();
    });
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        _searchTerm = value.trim();
        _page = 0;
        _managers = _loadManagers();
      });
    });
  }

  Future<void> _openCreateDialog() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (context) =>
          _CreateAccountManagerDialog(repository: widget.repository),
    );
    if (created == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AccountManagerPage>(
      key: ValueKey('$_filter|$_page|$_searchTerm'),
      future: _managers,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _AccountManagersError(onRetry: _reload);
        }
        if (!snapshot.hasData) {
          return const _AccountManagersLoading();
        }
        final page = snapshot.requireData;
        final managers = page.managers;
        final pageStart = page.totalElements == 0
            ? 0
            : page.currentPage * page.pageSize + 1;
        final pageEnd = (page.currentPage * page.pageSize + managers.length)
            .clamp(0, page.totalElements);
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
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
                          'Account Managers',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          page.totalElements == 0
                              ? 'No account managers found'
                              : 'Showing $pageStart-$pageEnd of ${page.totalElements} account managers',
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _openCreateDialog,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('New Account Manager'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _StatusTabs(selected: _filter, onSelected: _selectFilter),
              const SizedBox(height: 18),
              Card(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: TextField(
                        controller: _searchController,
                        onChanged: _onSearchChanged,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search_rounded),
                          hintText: 'Search by name, email, phone, or region',
                          suffixIcon: _searchController.text.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Clear search',
                                  onPressed: () {
                                    _searchController.clear();
                                    _onSearchChanged('');
                                  },
                                  icon: const Icon(Icons.close_rounded),
                                ),
                          filled: true,
                          fillColor: AppColors.background,
                          border: OutlineInputBorder(
                            borderSide: BorderSide.none,
                            borderRadius: BorderRadius.circular(9),
                          ),
                        ),
                      ),
                    ),
                    const Divider(height: 1, color: AppColors.border),
                    if (MediaQuery.sizeOf(context).width >= 850)
                      const _ManagerHeader(),
                    ...managers.map(
                      (manager) => _ManagerRow(
                        manager: manager,
                        onViewManager: widget.onViewManager,
                      ),
                    ),
                    if (managers.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(30),
                        child: Text(
                          _searchTerm.isEmpty
                              ? 'No account managers match this status.'
                              : 'No account managers match “$_searchTerm”.',
                        ),
                      ),
                    if (managers.isNotEmpty)
                      _AccountManagerPagination(
                        page: page,
                        onPrevious: page.hasPrevious
                            ? () => _goToPage(page.currentPage - 1)
                            : null,
                        onNext: page.hasNext
                            ? () => _goToPage(page.currentPage + 1)
                            : null,
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

List<String> _statusesFor(AccountManagerStatus? status) {
  return switch (status) {
    null => const [],
    AccountManagerStatus.active => const ['ACTIVE'],
    AccountManagerStatus.pendingApproval => const ['PENDING'],
    AccountManagerStatus.invited => const ['PENDING'],
    AccountManagerStatus.suspended => const ['SUSPENDED'],
  };
}

class _StatusTabs extends StatelessWidget {
  const _StatusTabs({required this.selected, required this.onSelected});

  final AccountManagerStatus? selected;
  final ValueChanged<AccountManagerStatus?> onSelected;

  @override
  Widget build(BuildContext context) {
    const tabs = <(String, AccountManagerStatus?)>[
      ('All', null),
      ('Active', AccountManagerStatus.active),
      ('Pending approval', AccountManagerStatus.pendingApproval),
      ('Suspended', AccountManagerStatus.suspended),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: tabs.map((tab) {
          final active = selected == tab.$2;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              selected: active,
              onSelected: (_) => onSelected(tab.$2),
              label: Text(tab.$1),
              selectedColor: AppColors.greenSoft,
              side: BorderSide(
                color: active ? AppColors.green : AppColors.border,
              ),
              labelStyle: TextStyle(
                color: active ? AppColors.green : AppColors.muted,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ManagerHeader extends StatelessWidget {
  const _ManagerHeader();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      color: AppColors.muted,
      fontSize: 9.5,
      fontWeight: FontWeight.w700,
      letterSpacing: .7,
    );
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
      child: const Row(
        children: [
          Expanded(flex: 3, child: Text('ACCOUNT MANAGER', style: style)),
          SizedBox(width: 130, child: Text('VERIFICATION', style: style)),
          SizedBox(width: 90, child: Text('SCHOOLS', style: style)),
          SizedBox(width: 130, child: Text('STATUS', style: style)),
          SizedBox(width: 130, child: Text('LAST ACTIVE', style: style)),
          SizedBox(width: 90, child: Text('ACTIONS', style: style)),
        ],
      ),
    );
  }
}

class _ManagerRow extends StatelessWidget {
  const _ManagerRow({required this.manager, required this.onViewManager});
  final AccountManagerProfile manager;
  final ValueChanged<AccountManagerProfile> onViewManager;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 850;
    final status = switch (manager.status) {
      AccountManagerStatus.active => ('Active', const Color(0xFF059669)),
      AccountManagerStatus.pendingApproval => (
        'Pending approval',
        AppColors.amber,
      ),
      AccountManagerStatus.invited => ('Invited', AppColors.blue),
      AccountManagerStatus.suspended => ('Suspended', AppColors.red),
    };
    return InkWell(
      onTap: () => onViewManager(manager),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    manager.name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${manager.email} · ${manager.phone}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ),
            if (wide) ...[
              SizedBox(
                width: 130,
                child: _Tag(
                  label: manager.verified ? 'Verified' : 'Unverified',
                  color: manager.verified ? AppColors.green : AppColors.amber,
                ),
              ),
              SizedBox(width: 90, child: Text('${manager.schoolCount}')),
              SizedBox(
                width: 130,
                child: _Tag(label: status.$1, color: status.$2),
              ),
              SizedBox(
                width: 130,
                child: Text(
                  manager.lastActive,
                  style: const TextStyle(fontSize: 11.5),
                ),
              ),
            ] else ...[
              _Tag(label: status.$1, color: status.$2),
              const SizedBox(width: 8),
            ],
            SizedBox(
              width: 90,
              child: OutlinedButton(
                onPressed: () => onViewManager(manager),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                ),
                child: const Text('View →', style: TextStyle(fontSize: 10.5)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          '● $label',
          style: TextStyle(
            color: color,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _AccountManagerPagination extends StatelessWidget {
  const _AccountManagerPagination({
    required this.page,
    required this.onPrevious,
    required this.onNext,
  });

  final AccountManagerPage page;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Page ${page.currentPage + 1} of ${page.totalPages == 0 ? 1 : page.totalPages}',
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ),
          OutlinedButton.icon(
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left_rounded),
            label: const Text('Previous'),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right_rounded),
            label: const Text('Next'),
          ),
        ],
      ),
    );
  }
}

class _AccountManagersLoading extends StatelessWidget {
  const _AccountManagersLoading();

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 850;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _AccountManagerSkeletonBox(width: 220, height: 26),
                    SizedBox(height: 8),
                    _AccountManagerSkeletonBox(width: 320, height: 12),
                  ],
                ),
              ),
              _AccountManagerSkeletonBox(width: 190, height: 40, radius: 12),
            ],
          ),
          const SizedBox(height: 20),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _AccountManagerSkeletonBox(width: 80, height: 34, radius: 18),
              _AccountManagerSkeletonBox(width: 92, height: 34, radius: 18),
              _AccountManagerSkeletonBox(width: 150, height: 34, radius: 18),
              _AccountManagerSkeletonBox(width: 112, height: 34, radius: 18),
            ],
          ),
          const SizedBox(height: 18),
          Card(
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(14),
                  child: _AccountManagerSkeletonBox(
                    width: double.infinity,
                    height: 46,
                    radius: 10,
                  ),
                ),
                const Divider(height: 1, color: AppColors.border),
                if (wide)
                  Container(
                    color: AppColors.background,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    child: const Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: _AccountManagerSkeletonBox(
                            width: 140,
                            height: 10,
                          ),
                        ),
                        _AccountManagerSkeletonBox(width: 90, height: 10),
                        SizedBox(width: 40),
                        _AccountManagerSkeletonBox(width: 60, height: 10),
                        SizedBox(width: 40),
                        _AccountManagerSkeletonBox(width: 80, height: 10),
                        SizedBox(width: 50),
                        _AccountManagerSkeletonBox(width: 90, height: 10),
                      ],
                    ),
                  ),
                ...List.generate(7, (_) => const _AccountManagerSkeletonRow()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountManagerSkeletonRow extends StatelessWidget {
  const _AccountManagerSkeletonRow();

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 850;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          const _AccountManagerSkeletonBox(width: 42, height: 42, radius: 12),
          const SizedBox(width: 12),
          const Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AccountManagerSkeletonBox(width: 160, height: 14),
                SizedBox(height: 8),
                _AccountManagerSkeletonBox(width: 240, height: 10),
              ],
            ),
          ),
          if (wide) ...[
            const SizedBox(width: 18),
            const _AccountManagerSkeletonBox(width: 100, height: 26, radius: 8),
            const SizedBox(width: 30),
            const _AccountManagerSkeletonBox(width: 36, height: 14),
            const SizedBox(width: 56),
            const _AccountManagerSkeletonBox(width: 88, height: 26, radius: 8),
            const SizedBox(width: 42),
            const _AccountManagerSkeletonBox(width: 88, height: 12),
          ] else ...[
            const SizedBox(width: 10),
            const _AccountManagerSkeletonBox(width: 72, height: 26, radius: 8),
          ],
        ],
      ),
    );
  }
}

class _AccountManagerSkeletonBox extends StatelessWidget {
  const _AccountManagerSkeletonBox({
    required this.width,
    required this.height,
    this.radius = 8,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return _AccountManagerShimmer(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.border,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

class _AccountManagerShimmer extends StatefulWidget {
  const _AccountManagerShimmer({required this.child});

  final Widget child;

  @override
  State<_AccountManagerShimmer> createState() => _AccountManagerShimmerState();
}

class _AccountManagerShimmerState extends State<_AccountManagerShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const base = Color(0xFFE7ECEB);
    const highlight = Color(0xFFF7FAF9);
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [base, highlight, base],
              stops: const [0.18, 0.5, 0.82],
              transform: _AccountManagerSlidingGradient(
                percent: _controller.value,
              ),
            ).createShader(bounds);
          },
          child: child,
        );
      },
    );
  }
}

class _AccountManagerSlidingGradient extends GradientTransform {
  const _AccountManagerSlidingGradient({required this.percent});

  final double percent;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * (percent * 2 - 1), 0, 0);
  }
}

class _AccountManagersError extends StatelessWidget {
  const _AccountManagersError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        margin: const EdgeInsets.all(24),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.manage_accounts_outlined,
                  color: AppColors.red,
                  size: 42,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Unable to load account managers',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                const Text(
                  'The account manager list could not load from the API.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CreateAccountManagerDialog extends StatefulWidget {
  const _CreateAccountManagerDialog({required this.repository});
  final PlatformRepository repository;

  @override
  State<_CreateAccountManagerDialog> createState() =>
      _CreateAccountManagerDialogState();
}

class _CreateAccountManagerDialogState
    extends State<_CreateAccountManagerDialog> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  DateTime? _dateOfBirth;
  String? _inviteMethod;
  bool _submitting = false;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_dateOfBirth == null || _inviteMethod == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select a date of birth and invitation method.'),
        ),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await widget.repository.createAccountManager(
        AccountManagerDraft(
          firstName: _firstName.text.trim(),
          lastName: _lastName.text.trim(),
          email: _email.text.trim(),
          phone: _phone.text.trim(),
          dateOfBirth: _dateOfBirth!,
          inviteMethod: _inviteMethod!,
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not invite account manager from the server.'),
        ),
      );
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      titlePadding: const EdgeInsets.fromLTRB(34, 30, 34, 0),
      contentPadding: const EdgeInsets.fromLTRB(34, 18, 34, 10),
      actionsPadding: const EdgeInsets.fromLTRB(34, 8, 34, 26),
      title: const Text(
        'Invite New Account Manager',
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
      ),
      content: SizedBox(
        width: 680,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Send an invitation to a new account manager.',
                    style: TextStyle(color: AppColors.muted, fontSize: 14),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _DialogField(
                        label: 'First name',
                        hint: 'e.g. John',
                        controller: _firstName,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DialogField(
                        label: 'Last name',
                        hint: 'e.g. Doe',
                        controller: _lastName,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _DialogField(
                  label: 'Email',
                  hint: 'e.g. john.doe@example.com',
                  controller: _email,
                ),
                const SizedBox(height: 14),
                _DialogField(
                  label: 'Phone',
                  hint: 'e.g. +233 24 123 4567',
                  controller: _phone,
                ),
                const SizedBox(height: 14),
                _LabeledControl(
                  label: 'Date of birth',
                  child: InkWell(
                    onTap: () async {
                      final selected = await showDatePicker(
                        context: context,
                        firstDate: DateTime(1940),
                        lastDate: DateTime.now().subtract(
                          const Duration(days: 365 * 18),
                        ),
                        initialDate: DateTime(1990),
                      );
                      if (selected != null) {
                        setState(() => _dateOfBirth = selected);
                      }
                    },
                    borderRadius: BorderRadius.circular(9),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        suffixIcon: Icon(Icons.calendar_month_outlined),
                        border: OutlineInputBorder(),
                      ),
                      child: Text(
                        _dateOfBirth == null
                            ? 'Select date of birth'
                            : '${_dateOfBirth!.day.toString().padLeft(2, '0')}-${_dateOfBirth!.month.toString().padLeft(2, '0')}-${_dateOfBirth!.year}',
                        style: TextStyle(
                          color: _dateOfBirth == null
                              ? AppColors.muted
                              : AppColors.text,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _LabeledControl(
                  label: 'Invite method',
                  child: DropdownButtonFormField<String>(
                    value: _inviteMethod,
                    hint: const Text('Select invite method'),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                    items: const ['Email', 'SMS', 'Email and SMS']
                        .map(
                          (method) => DropdownMenuItem(
                            value: method,
                            child: Text(method),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _inviteMethod = value),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: Text(_submitting ? 'Sending...' : 'Send Invitation'),
        ),
      ],
    );
  }
}

class _DialogField extends StatelessWidget {
  const _DialogField({
    required this.label,
    required this.controller,
    required this.hint,
  });
  final String label;
  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return _LabeledControl(
      label: label,
      child: TextFormField(
        controller: controller,
        validator: (value) => value == null || value.trim().isEmpty
            ? 'This field is required'
            : null,
        decoration: InputDecoration(
          hintText: hint,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}

class _LabeledControl extends StatelessWidget {
  const _LabeledControl({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.text,
            fontWeight: FontWeight.w600,
            letterSpacing: .5,
          ),
        ),
        const SizedBox(height: 7),
        child,
      ],
    );
  }
}
