import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../data/platform_api_client.dart';
import '../data/platform_repository.dart';
import '../domain/platform_models.dart';
import 'account_managers_screen.dart';
import 'school_creation_screen.dart';
import 'school_detail_screen.dart';

enum PlatformPage { overview, schools, onboarding, attention, accountManagers }

class PlatformAdminShell extends StatefulWidget {
  const PlatformAdminShell({
    super.key,
    required this.accessToken,
    required this.userDisplayName,
    required this.onRefreshAccessToken,
    required this.repository,
    required this.dashboardFuture,
    required this.cachedDashboard,
    required this.onRefreshDashboard,
    required this.initialPage,
    required this.createSchool,
    required this.resumeOnboarding,
    required this.schoolCode,
    required this.onNavigatePath,
    required this.onOpenSchoolAdministrator,
    required this.onLogout,
  });

  final String? accessToken;
  final String userDisplayName;
  final Future<String?> Function() onRefreshAccessToken;
  final PlatformRepository repository;
  final Future<AccountManagerSnapshot> dashboardFuture;
  final AccountManagerSnapshot? cachedDashboard;
  final VoidCallback onRefreshDashboard;
  final PlatformPage initialPage;
  final bool createSchool;
  final bool resumeOnboarding;
  final String? schoolCode;
  final ValueChanged<String> onNavigatePath;
  final VoidCallback onOpenSchoolAdministrator;
  final VoidCallback onLogout;

  @override
  State<PlatformAdminShell> createState() => _PlatformAdminShellState();
}

class _PlatformAdminShellState extends State<PlatformAdminShell> {
  final PlatformRole _currentRole = PlatformRole.superAccountManager;
  AccountManagerProfile? _selectedManager;
  ManagedSchool? _routeSchoolCache;
  Future<SchoolCreationLookups>? _schoolLookupFuture;
  SchoolCreationLookups? _schoolLookupCache;

  Future<SchoolCreationLookups> _loadSchoolLookups() {
    final cached = _schoolLookupCache;
    if (cached != null) return Future.value(cached);
    return _schoolLookupFuture ??=
        PlatformApiClient(
          accessToken: widget.accessToken,
          onRefreshAccessToken: widget.onRefreshAccessToken,
        ).getSchoolCreationLookups().then((lookups) {
          if (mounted) {
            setState(() => _schoolLookupCache = lookups);
          } else {
            _schoolLookupCache = lookups;
          }
          return lookups;
        });
  }

  void _openPage(PlatformPage page) {
    setState(() {
      _selectedManager = null;
      _routeSchoolCache = null;
    });
    widget.onNavigatePath(_pathForPage(page));
  }

  void _openCreateSchool() {
    setState(() {
      _selectedManager = null;
      _routeSchoolCache = null;
    });
    widget.onNavigatePath('/super-admin/schools/new');
  }

  void _resumeSchoolOnboarding(ManagedSchool school) {
    setState(() => _selectedManager = null);
    widget.onNavigatePath(
      '/super-admin/onboarding/${Uri.encodeComponent(school.code)}',
    );
  }

  void _openSchool(ManagedSchool school) {
    setState(() {
      _selectedManager = null;
      _routeSchoolCache = school;
    });
    if (_shouldResumeOnboarding(school)) {
      _resumeSchoolOnboarding(school);
      return;
    }
    widget.onNavigatePath(
      '/super-admin/schools/${Uri.encodeComponent(school.code)}',
    );
  }

  void _openManager(AccountManagerProfile manager) {
    setState(() {
      _selectedManager = manager;
    });
  }

  bool _shouldResumeOnboarding(ManagedSchool school) {
    return school.status.canResumeOnboarding;
  }

  ManagedSchool? _schoolForRoute(List<ManagedSchool> schools) {
    final code = widget.schoolCode;
    if (code == null || code.isEmpty) return null;
    final decoded = Uri.decodeComponent(code);
    final cached = _routeSchoolCache;
    if (cached != null && cached.code == decoded) return cached;
    return schools.cast<ManagedSchool?>().firstWhere(
      (school) => school?.code == decoded,
      orElse: () => null,
    );
  }

  String _pathForPage(PlatformPage page) {
    return switch (page) {
      PlatformPage.overview => '/super-admin',
      PlatformPage.schools => '/super-admin/schools',
      PlatformPage.onboarding => '/super-admin/onboarding',
      PlatformPage.attention => '/super-admin/attention',
      PlatformPage.accountManagers => '/super-admin/account-managers',
    };
  }

  Future<void> _openManagerByName(String name) async {
    final managers = await widget.repository.searchAccountManagers(
      searchTerm: name,
      userStatuses: const [],
      size: 10,
    );
    if (!mounted) return;
    final manager = managers.cast<AccountManagerProfile?>().firstWhere(
      (manager) => manager?.name == name,
      orElse: () => null,
    );
    if (manager != null) _openManager(manager);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AccountManagerSnapshot>(
      future: widget.dashboardFuture,
      initialData: widget.cachedDashboard,
      builder: (context, snapshot) {
        if (snapshot.hasError && !snapshot.hasData) {
          return Scaffold(
            body: _ApiErrorState(
              title: 'Unable to load Super Admin data',
              message:
                  'The dashboard could not load from the server. Check your connection or sign in again.',
              onRetry: widget.onRefreshDashboard,
            ),
          );
        }
        if (!snapshot.hasData) {
          return _PlatformLoadingShell(
            page: widget.initialPage,
            role: _currentRole,
            onPageSelected: _openPage,
            onCreateSchool: _openCreateSchool,
            onOpenSchoolAdministrator: widget.onOpenSchoolAdministrator,
            onLogout: widget.onLogout,
          );
        }
        if (_schoolLookupCache == null && _schoolLookupFuture == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _loadSchoolLookups();
          });
        }
        final data = snapshot.requireData;
        return LayoutBuilder(
          builder: (context, constraints) {
            final desktop = constraints.maxWidth >= 980;
            final routeSchool = _schoolForRoute(data.schools);
            final creatingSchool =
                widget.createSchool ||
                (widget.resumeOnboarding && routeSchool != null);
            final page = widget.initialPage;
            final content = creatingSchool
                ? SchoolCreationScreen(
                    accessToken: widget.accessToken,
                    onRefreshAccessToken: widget.onRefreshAccessToken,
                    repository: widget.repository,
                    initialLookups: _schoolLookupCache,
                    lookupLoader: _loadSchoolLookups,
                    existingSchool: widget.resumeOnboarding
                        ? routeSchool
                        : null,
                    initialStep: widget.resumeOnboarding && routeSchool != null
                        ? _onboardingStepIndex(routeSchool)
                        : null,
                    onBack: () => widget.onNavigatePath(
                      widget.resumeOnboarding
                          ? '/super-admin/onboarding'
                          : '/super-admin/schools',
                    ),
                    onCreated: () {
                      widget.onRefreshDashboard();
                      widget.onNavigatePath('/super-admin/schools');
                    },
                    onViewCreated: (schoolId) {
                      widget.onRefreshDashboard();
                      widget.onNavigatePath(
                        '/super-admin/schools/${Uri.encodeComponent(schoolId)}',
                      );
                    },
                  )
                : routeSchool != null
                ? SchoolDetailScreen(
                    school: routeSchool,
                    repository: widget.repository,
                    accessToken: widget.accessToken,
                    onRefreshAccessToken: widget.onRefreshAccessToken,
                    onSchoolUpdated: () {
                      setState(() => _routeSchoolCache = null);
                      widget.onRefreshDashboard();
                    },
                    onBack: () => widget.onNavigatePath('/super-admin/schools'),
                    onViewAccountManager: _openManagerByName,
                  )
                : _selectedManager != null
                ? AccountManagerDetailScreen(
                    manager: _selectedManager!,
                    schools: data.schools,
                    onBack: () => setState(() => _selectedManager = null),
                    onViewSchool: _openSchool,
                  )
                : switch (page) {
                    PlatformPage.overview => _AccountManagerOverview(
                      data: data,
                      onCreateSchool: _openCreateSchool,
                      onViewSchools: () => _openPage(PlatformPage.schools),
                      onViewOnboarding: () => _openPage(PlatformPage.schools),
                      onViewAttention: () => _openPage(PlatformPage.attention),
                      onViewSchool: _openSchool,
                    ),
                    PlatformPage.schools => _SchoolsScreen(
                      repository: widget.repository,
                      accessToken: widget.accessToken,
                      onRefreshAccessToken: widget.onRefreshAccessToken,
                      schools: data.schools,
                      onCreateSchool: _openCreateSchool,
                      onViewSchool: _openSchool,
                    ),
                    PlatformPage.onboarding => _SchoolsScreen(
                      repository: widget.repository,
                      accessToken: widget.accessToken,
                      onRefreshAccessToken: widget.onRefreshAccessToken,
                      schools: data.schools,
                      onCreateSchool: _openCreateSchool,
                      onViewSchool: _openSchool,
                    ),
                    PlatformPage.attention => _AttentionSchoolsScreen(
                      repository: widget.repository,
                      schools: data.schools,
                      pendingAccountManagerApprovals: data.pendingApprovals,
                      onViewSchool: _openSchool,
                      onResumeOnboarding: _resumeSchoolOnboarding,
                      onViewManager: _openManager,
                    ),
                    PlatformPage.accountManagers => AccountManagersScreen(
                      repository: widget.repository,
                      schools: data.schools,
                      onViewManager: _openManager,
                    ),
                  };

            final workspace = _PlatformWorkspace(
              title: creatingSchool
                  ? (routeSchool == null ? 'Create school' : routeSchool.name)
                  : routeSchool != null
                  ? routeSchool.name
                  : _selectedManager != null
                  ? _selectedManager!.name
                  : switch (page) {
                      PlatformPage.overview => 'Overview',
                      PlatformPage.schools => 'Schools',
                      PlatformPage.onboarding => 'Onboarding',
                      PlatformPage.attention => 'Needs attention',
                      PlatformPage.accountManagers => 'Account Managers',
                    },
              subtitle: creatingSchool
                  ? (routeSchool == null
                        ? 'Start a new school onboarding'
                        : 'Continue school onboarding')
                  : routeSchool != null
                  ? 'School details and operations'
                  : _selectedManager != null
                  ? 'Account manager details'
                  : switch (page) {
                      PlatformPage.overview => 'Your portfolio at a glance',
                      PlatformPage.schools =>
                        'All schools with approval and account manager filters',
                      PlatformPage.onboarding => 'Schools completing setup',
                      PlatformPage.attention => 'Schools requiring action',
                      PlatformPage.accountManagers =>
                        'Manage your platform team',
                    },
              managerName: data.managerName,
              showMenu: !desktop,
              onLogout: widget.onLogout,
              child: content,
            );

            if (!desktop) {
              return Scaffold(
                drawer: Drawer(
                  width: 270,
                  child: _PlatformSidebar(
                    page: page,
                    creatingSchool: creatingSchool,
                    onPageSelected: _openPage,
                    onCreateSchool: _openCreateSchool,
                    onOpenSchoolAdministrator: widget.onOpenSchoolAdministrator,
                    schoolCount: data.schools.length,
                    attentionCount: data.needsAttentionCount,
                    role: _currentRole,
                  ),
                ),
                body: workspace,
              );
            }

            return Scaffold(
              body: Row(
                children: [
                  _PlatformSidebar(
                    page: page,
                    creatingSchool: creatingSchool,
                    onPageSelected: _openPage,
                    onCreateSchool: _openCreateSchool,
                    onOpenSchoolAdministrator: widget.onOpenSchoolAdministrator,
                    schoolCount: data.schools.length,
                    attentionCount: data.needsAttentionCount,
                    role: _currentRole,
                  ),
                  Expanded(child: workspace),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _ApiErrorState extends StatelessWidget {
  const _ApiErrorState({
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final String title;
  final String message;
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
                  Icons.cloud_off_rounded,
                  size: 44,
                  color: AppColors.red,
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.muted, height: 1.4),
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
      ),
    );
  }
}

class _PlatformLoadingShell extends StatelessWidget {
  const _PlatformLoadingShell({
    required this.page,
    required this.role,
    required this.onPageSelected,
    required this.onCreateSchool,
    required this.onOpenSchoolAdministrator,
    required this.onLogout,
  });

  final PlatformPage page;
  final PlatformRole role;
  final ValueChanged<PlatformPage> onPageSelected;
  final VoidCallback onCreateSchool;
  final VoidCallback onOpenSchoolAdministrator;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 980;
        final content = _PlatformWorkspace(
          title: _titleForPage(page),
          subtitle: _subtitleForPage(page),
          managerName: 'Loading...',
          showMenu: !desktop,
          onLogout: onLogout,
          child: const _DashboardSkeletonContent(),
        );

        if (!desktop) {
          return Scaffold(
            drawer: Drawer(
              width: 270,
              child: _PlatformSidebar(
                page: page,
                creatingSchool: false,
                onPageSelected: onPageSelected,
                onCreateSchool: onCreateSchool,
                onOpenSchoolAdministrator: onOpenSchoolAdministrator,
                schoolCount: 0,
                attentionCount: 0,
                role: role,
              ),
            ),
            body: content,
          );
        }

        return Scaffold(
          body: Row(
            children: [
              _PlatformSidebar(
                page: page,
                creatingSchool: false,
                onPageSelected: onPageSelected,
                onCreateSchool: onCreateSchool,
                onOpenSchoolAdministrator: onOpenSchoolAdministrator,
                schoolCount: 0,
                attentionCount: 0,
                role: role,
              ),
              Expanded(child: content),
            ],
          ),
        );
      },
    );
  }

  String _titleForPage(PlatformPage page) => switch (page) {
    PlatformPage.overview => 'Overview',
    PlatformPage.schools => 'Schools',
    PlatformPage.onboarding => 'Onboarding',
    PlatformPage.attention => 'Needs attention',
    PlatformPage.accountManagers => 'Account Managers',
  };

  String _subtitleForPage(PlatformPage page) => switch (page) {
    PlatformPage.overview => 'Your portfolio at a glance',
    PlatformPage.schools =>
      'All schools with approval and account manager filters',
    PlatformPage.onboarding => 'Schools completing setup',
    PlatformPage.attention => 'Schools requiring action',
    PlatformPage.accountManagers => 'Manage your platform team',
  };
}

class _DashboardSkeletonContent extends StatelessWidget {
  const _DashboardSkeletonContent();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 980 ? 4 : 2;
              return GridView.count(
                crossAxisCount: columns,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: columns == 4 ? 2.8 : 2.4,
                children: List.generate(
                  4,
                  (_) => const _SkeletonCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SkeletonBox(width: 120, height: 10),
                        Spacer(),
                        _SkeletonBox(width: 72, height: 26),
                        SizedBox(height: 10),
                        _SkeletonBox(width: 130, height: 11),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final desktop = constraints.maxWidth >= 980;
              final left = Column(
                children: [
                  _SkeletonPanel(rows: desktop ? 5 : 4),
                  const SizedBox(height: 16),
                  const _SkeletonPanel(rows: 4),
                ],
              );
              final right = Column(
                children: [
                  const _SkeletonPanel(rows: 3),
                  const SizedBox(height: 16),
                  const _SkeletonPanel(rows: 3),
                ],
              );
              if (!desktop) {
                return Column(
                  children: [left, const SizedBox(height: 16), right],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 2, child: left),
                  const SizedBox(width: 16),
                  Expanded(child: right),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SkeletonPanel extends StatelessWidget {
  const _SkeletonPanel({required this.rows});

  final int rows;

  @override
  Widget build(BuildContext context) {
    return _SkeletonCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SkeletonBox(width: 180, height: 18),
          const SizedBox(height: 18),
          ...List.generate(
            rows,
            (index) => Padding(
              padding: EdgeInsets.only(bottom: index == rows - 1 ? 0 : 16),
              child: Row(
                children: [
                  const _SkeletonBox(width: 38, height: 38, radius: 12),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        _SkeletonBox(width: double.infinity, height: 12),
                        SizedBox(height: 8),
                        _SkeletonBox(width: 160, height: 10),
                      ],
                    ),
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

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(padding: const EdgeInsets.all(18), child: child),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({
    required this.width,
    required this.height,
    this.radius = 8,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return _Shimmer(
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

class _Shimmer extends StatefulWidget {
  const _Shimmer({required this.child});

  final Widget child;

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer>
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
              transform: _SlidingGradientTransform(percent: _controller.value),
            ).createShader(bounds);
          },
          child: child,
        );
      },
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  const _SlidingGradientTransform({required this.percent});

  final double percent;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * (percent * 2 - 1), 0, 0);
  }
}

class _PlatformWorkspace extends StatelessWidget {
  const _PlatformWorkspace({
    required this.title,
    required this.subtitle,
    required this.managerName,
    required this.child,
    required this.showMenu,
    required this.onLogout,
  });

  final String title;
  final String subtitle;
  final String managerName;
  final Widget child;
  final bool showMenu;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              if (showMenu) ...[
                IconButton(
                  tooltip: 'Open menu',
                  onPressed: () => Scaffold.of(context).openDrawer(),
                  icon: const Icon(Icons.menu_rounded),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (MediaQuery.sizeOf(context).width >= 650) ...[
                      const SizedBox(width: 10),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Notifications',
                onPressed: () {},
                icon: const Badge(
                  smallSize: 7,
                  child: Icon(Icons.notifications_none_rounded),
                ),
              ),
              const SizedBox(width: 6),
              CircleAvatar(
                radius: 17,
                backgroundColor: AppColors.greenSoft,
                child: Text(
                  _initialsForName(managerName),
                  style: const TextStyle(
                    color: AppColors.green,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                tooltip: 'Log out',
                onPressed: onLogout,
                icon: const Icon(Icons.logout_rounded),
              ),
            ],
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}

class _AccountManagerOverview extends StatelessWidget {
  const _AccountManagerOverview({
    required this.data,
    required this.onCreateSchool,
    required this.onViewSchools,
    required this.onViewOnboarding,
    required this.onViewAttention,
    required this.onViewSchool,
  });

  final AccountManagerSnapshot data;
  final VoidCallback onCreateSchool;
  final VoidCallback onViewSchools;
  final VoidCallback onViewOnboarding;
  final VoidCallback onViewAttention;
  final ValueChanged<ManagedSchool> onViewSchool;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _WelcomePanel(name: data.managerName, onCreateSchool: onCreateSchool),
          const SizedBox(height: 20),
          _PlatformStats(data: data),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 800) {
                return Column(
                  children: [
                    _PendingApprovalPanel(
                      schools: data.schools,
                      onViewAll: onViewOnboarding,
                      onViewSchool: onViewSchool,
                    ),
                    const SizedBox(height: 16),
                    _PortfolioAlerts(data: data, onViewAll: onViewAttention),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 6,
                    child: _PendingApprovalPanel(
                      schools: data.schools,
                      onViewAll: onViewOnboarding,
                      onViewSchool: onViewSchool,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 4,
                    child: _PortfolioAlerts(
                      data: data,
                      onViewAll: onViewAttention,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          _RecentActivitiesPanel(
            schools: data.schools,
            onViewAll: onViewSchools,
            onViewSchool: onViewSchool,
          ),
        ],
      ),
    );
  }
}

class _WelcomePanel extends StatelessWidget {
  const _WelcomePanel({required this.name, required this.onCreateSchool});
  final String name;
  final VoidCallback onCreateSchool;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF00695C),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Wrap(
        spacing: 20,
        runSpacing: 16,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome back, ${name.split(' ').first}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Review school approvals, account managers, and platform activity.',
                style: TextStyle(color: Color(0xFFD0E9E5), fontSize: 13),
              ),
            ],
          ),
          FilledButton.icon(
            onPressed: onCreateSchool,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF00695C),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
            ),
            icon: const Icon(Icons.add_business_rounded, size: 19),
            label: const Text('Create school'),
          ),
        ],
      ),
    );
  }
}

class _PlatformStats extends StatelessWidget {
  const _PlatformStats({required this.data});
  final AccountManagerSnapshot data;

  @override
  Widget build(BuildContext context) {
    final items = [
      _StatItem(
        'Total schools',
        '${data.totalSchools}',
        data.totalSchoolsCaption.isEmpty
            ? 'Loaded from school records'
            : data.totalSchoolsCaption,
        Icons.apartment_rounded,
        AppColors.green,
      ),
      _StatItem(
        'Active schools',
        '${data.activeSchools}',
        data.activeSchoolsCaption.isEmpty
            ? 'Approved or active schools'
            : data.activeSchoolsCaption,
        Icons.verified_rounded,
        const Color(0xFF059669),
      ),
      _StatItem(
        'Account managers',
        '${data.accountManagers}',
        data.accountManagersCaption.isEmpty
            ? 'Loaded from account managers'
            : data.accountManagersCaption,
        Icons.manage_accounts_rounded,
        AppColors.blue,
      ),
      _StatItem(
        'Needs attention',
        '${data.needsAttentionCount}',
        'Grouped action items',
        Icons.pending_actions_rounded,
        AppColors.red,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 880
            ? 4
            : constraints.maxWidth >= 520
            ? 2
            : 1;
        const gap = 14.0;
        final width = (constraints.maxWidth - (columns - 1) * gap) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: items
              .map(
                (item) => SizedBox(
                  width: width,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.label.toUpperCase(),
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 10.5,
                                    letterSpacing: .6,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: item.color.withValues(alpha: .1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  item.icon,
                                  color: item.color,
                                  size: 18,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            item.value,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            item.caption,
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _StatItem {
  const _StatItem(this.label, this.value, this.caption, this.icon, this.color);
  final String label;
  final String value;
  final String caption;
  final IconData icon;
  final Color color;
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.child,
    this.action,
    this.onAction,
  });

  final String title;
  final Widget child;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (action != null)
                  TextButton(
                    onPressed: onAction,
                    child: Text(action!, style: const TextStyle(fontSize: 12)),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          child,
        ],
      ),
    );
  }
}

class _PendingApprovalPanel extends StatelessWidget {
  const _PendingApprovalPanel({
    required this.schools,
    required this.onViewAll,
    required this.onViewSchool,
  });
  final List<ManagedSchool> schools;
  final VoidCallback onViewAll;
  final ValueChanged<ManagedSchool> onViewSchool;

  @override
  Widget build(BuildContext context) {
    final pending = schools.where(_isSchoolPendingApproval).toList();
    return _Panel(
      title: 'Schools pending approval (${pending.length})',
      action: pending.length > 5 ? 'View all →' : null,
      onAction: onViewAll,
      child: pending.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No schools are currently pending approval.'),
            )
          : Column(
              children: [
                ...pending
                    .take(5)
                    .map(
                      (school) => InkWell(
                        onTap: () => onViewSchool(school),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 14,
                          ),
                          child: Row(
                            children: [
                              _SchoolAvatar(name: school.name),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            school.name,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          _approvalStatusLabel(school),
                                          style: const TextStyle(
                                            color: AppColors.amber,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '${school.town}, ${school.region} · Awaiting Super Admin review',
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: AppColors.muted,
                                        fontSize: 10.5,
                                      ),
                                    ),
                                    const SizedBox(height: 9),
                                    LinearProgressIndicator(
                                      value: school.progress,
                                      minHeight: 6,
                                      color: AppColors.amber,
                                      backgroundColor: AppColors.amber
                                          .withValues(alpha: .14),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: AppColors.muted,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                if (pending.length > 5)
                  InkWell(
                    onTap: onViewAll,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.amber.withValues(alpha: .14),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '+${pending.length - 5}',
                              style: const TextStyle(
                                color: AppColors.amber,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '${pending.length - 5} more schools pending approval',
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: AppColors.muted,
                            size: 18,
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

class _OnboardingSchoolsScreen extends StatefulWidget {
  const _OnboardingSchoolsScreen({
    required this.schools,
    required this.onViewSchool,
  });
  final List<ManagedSchool> schools;
  final ValueChanged<ManagedSchool> onViewSchool;

  @override
  State<_OnboardingSchoolsScreen> createState() =>
      _OnboardingSchoolsScreenState();
}

class _OnboardingSchoolsScreenState extends State<_OnboardingSchoolsScreen> {
  static const _pageSize = 10;
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final onboarding = widget.schools
        .where((school) => school.status.isOnboarding)
        .toList();
    final pageCount = onboarding.isEmpty
        ? 1
        : ((onboarding.length - 1) ~/ _pageSize) + 1;
    if (_page >= pageCount) _page = pageCount - 1;
    final start = _page * _pageSize;
    final end = (start + _pageSize).clamp(0, onboarding.length);
    final visible = onboarding.sublist(start, end);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Onboarding schools (${onboarding.length})',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            'Schools that have been created but have not completed setup.',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 18),
          Card(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              size: 19,
                            ),
                            hintText: 'Search onboarding schools',
                            isDense: true,
                            filled: true,
                            fillColor: AppColors.background,
                            border: OutlineInputBorder(
                              borderSide: BorderSide.none,
                              borderRadius: BorderRadius.circular(9),
                            ),
                          ),
                        ),
                      ),
                      if (MediaQuery.sizeOf(context).width >= 650) ...[
                        const SizedBox(width: 10),
                        OutlinedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.filter_list_rounded, size: 18),
                          label: const Text('Filter by stage'),
                        ),
                      ],
                    ],
                  ),
                ),
                const Divider(height: 1, color: AppColors.border),
                if (visible.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(28),
                    child: Text('No schools are currently onboarding.'),
                  )
                else
                  ...visible.map(
                    (school) => _OnboardingSchoolRow(
                      school: school,
                      onViewSchool: widget.onViewSchool,
                    ),
                  ),
                if (onboarding.length > _pageSize) ...[
                  const Divider(height: 1, color: AppColors.border),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Showing ${start + 1}-$end of ${onboarding.length}',
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        OutlinedButton(
                          onPressed: _page == 0
                              ? null
                              : () => setState(() => _page--),
                          child: const Text('Previous'),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${_page + 1} / $pageCount',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: _page >= pageCount - 1
                              ? null
                              : () => setState(() => _page++),
                          child: const Text('Next'),
                        ),
                      ],
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

class _OnboardingSchoolRow extends StatelessWidget {
  const _OnboardingSchoolRow({
    required this.school,
    required this.onViewSchool,
  });
  final ManagedSchool school;
  final ValueChanged<ManagedSchool> onViewSchool;

  @override
  Widget build(BuildContext context) {
    final stage = _stageForProgress(school.progress);
    return InkWell(
      onTap: () => onViewSchool(school),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          children: [
            _SchoolAvatar(name: school.name),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    school.name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${school.code} · ${school.town}, ${school.region}',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ),
            if (MediaQuery.sizeOf(context).width >= 700)
              Expanded(
                child: Text(stage, style: const TextStyle(fontSize: 12)),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${(school.progress * 100).round()}%',
                    style: const TextStyle(
                      color: AppColors.green,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: school.progress,
                    minHeight: 5,
                    color: AppColors.green,
                    backgroundColor: AppColors.greenSoft,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}

class _AttentionSchoolsScreen extends StatefulWidget {
  const _AttentionSchoolsScreen({
    required this.repository,
    required this.schools,
    required this.pendingAccountManagerApprovals,
    required this.onViewSchool,
    required this.onResumeOnboarding,
    required this.onViewManager,
  });
  final PlatformRepository repository;
  final List<ManagedSchool> schools;
  final int pendingAccountManagerApprovals;
  final ValueChanged<ManagedSchool> onViewSchool;
  final ValueChanged<ManagedSchool> onResumeOnboarding;
  final ValueChanged<AccountManagerProfile> onViewManager;

  @override
  State<_AttentionSchoolsScreen> createState() =>
      _AttentionSchoolsScreenState();
}

class _AttentionSchoolsScreenState extends State<_AttentionSchoolsScreen> {
  static const _pageSize = 8;
  int _selectedIndex = 0;
  int _page = 0;
  String _query = '';
  String? _openingItemId;
  Future<NeedsAttentionSummary>? _summaryFuture;
  Future<NeedsAttentionPage>? _itemsFuture;
  NeedsAttentionSummary? _summary;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _summaryFuture = _loadSummary();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<NeedsAttentionSummary> _loadSummary() async {
    final summary = await widget.repository.getNeedsAttentionSummary();
    if (mounted) {
      setState(() {
        _summary = summary;
        _selectedIndex = _selectedIndex.clamp(
          0,
          summary.categories.isEmpty ? 0 : summary.categories.length - 1,
        );
        _itemsFuture = summary.categories.isEmpty ? null : _loadItems();
      });
    } else {
      _summary = summary;
      _itemsFuture = summary.categories.isEmpty ? null : _loadItems();
    }
    return summary;
  }

  Future<NeedsAttentionPage> _loadItems() {
    final summary = _summary;
    if (summary == null || summary.categories.isEmpty) {
      return Future.value(
        NeedsAttentionPage(
          items: const [],
          totalElements: 0,
          totalPages: 1,
          currentPage: _page,
          pageSize: _pageSize,
        ),
      );
    }
    final category = summary
        .categories[_selectedIndex.clamp(0, summary.categories.length - 1)];
    return widget.repository.getNeedsAttentionItems(
      category: category.category,
      searchTerm: _query,
      page: _page,
      size: _pageSize,
    );
  }

  void _selectGroup(int index) {
    setState(() {
      _selectedIndex = index;
      _page = 0;
      _query = '';
      _itemsFuture = _loadItems();
    });
  }

  void _refreshItems() {
    setState(() => _itemsFuture = _loadItems());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<NeedsAttentionSummary>(
      future: _summaryFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const _AttentionLoadingState();
        }
        if (snapshot.hasError && !snapshot.hasData) {
          return _AttentionErrorState(
            title: 'Could not load Needs attention',
            message: snapshot.error.toString(),
            onRetry: () => setState(() => _summaryFuture = _loadSummary()),
          );
        }

        final summary = snapshot.data ?? _summary;
        final categories =
            summary?.categories ?? const <NeedsAttentionCategory>[];
        final selectedCategory = categories.isEmpty
            ? null
            : categories[_selectedIndex.clamp(0, categories.length - 1)];
        final selectedGroup = selectedCategory == null
            ? null
            : _attentionGroupForCategory(selectedCategory);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Needs attention (${summary?.total ?? 0})',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Grouped by the action Super Admin needs to take.',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
              const SizedBox(height: 18),
              if (categories.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No current attention items.',
                      style: TextStyle(color: AppColors.muted),
                    ),
                  ),
                )
              else ...[
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (var index = 0; index < categories.length; index++)
                      SizedBox(
                        width: 250,
                        child: _AttentionSummaryCard(
                          group: _attentionGroupForCategory(categories[index]),
                          selected: index == _selectedIndex,
                          onTap: () => _selectGroup(index),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                if (selectedGroup != null)
                  FutureBuilder<NeedsAttentionPage>(
                    key: ValueKey('${selectedGroup.category}|$_page|$_query'),
                    future: _itemsFuture,
                    builder: (context, itemSnapshot) {
                      final loading =
                          itemSnapshot.connectionState ==
                              ConnectionState.waiting &&
                          !itemSnapshot.hasData;
                      if (itemSnapshot.hasError && !itemSnapshot.hasData) {
                        return _AttentionErrorState(
                          title: 'Could not load ${selectedGroup.title}',
                          message: itemSnapshot.error.toString(),
                          onRetry: _refreshItems,
                        );
                      }
                      final page =
                          itemSnapshot.data ??
                          NeedsAttentionPage(
                            items: const [],
                            totalElements: 0,
                            totalPages: 1,
                            currentPage: _page,
                            pageSize: _pageSize,
                          );
                      return _AttentionListPanel(
                        group: selectedGroup,
                        query: _query,
                        visibleItems: page.items,
                        totalItems: page.totalElements,
                        page: page.currentPage,
                        totalPages: page.totalPages,
                        loading: loading,
                        openingItemId: _openingItemId,
                        onQueryChanged: _onQueryChanged,
                        onPrevious: page.hasPrevious
                            ? () => setState(() {
                                _page = page.currentPage - 1;
                                _itemsFuture = _loadItems();
                              })
                            : null,
                        onNext: page.hasNext
                            ? () => setState(() {
                                _page = page.currentPage + 1;
                                _itemsFuture = _loadItems();
                              })
                            : null,
                        onItemTap: _openItem,
                      );
                    },
                  ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _onQueryChanged(String value) {
    _searchDebounce?.cancel();
    setState(() {
      _query = value;
      _page = 0;
    });
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) _refreshItems();
    });
  }

  Future<void> _openItem(NeedsAttentionItem item) async {
    setState(() => _openingItemId = item.id);
    try {
      switch (item.actionTarget) {
        case 'ACCOUNT_MANAGER_DETAIL':
          final page = await widget.repository.getAccountManagerPage(
            searchTerm: item.title,
            userStatuses: const ['PENDING'],
            size: 10,
          );
          final manager = page.managers
              .cast<AccountManagerProfile?>()
              .firstWhere(
                (manager) => manager?.id == item.entityId,
                orElse: () =>
                    page.managers.isEmpty ? null : page.managers.first,
              );
          if (manager != null) {
            widget.onViewManager(manager);
            return;
          }
          break;
        case 'SCHOOL_ONBOARDING_FORM':
          final school = await _schoolForAttentionItem(item);
          if (school != null) {
            widget.onResumeOnboarding(school);
            return;
          }
          break;
        case 'SCHOOL_REVIEW':
        case 'SCHOOL_COMPLIANCE_SECTION':
          final school = await _schoolForAttentionItem(item);
          if (school != null) {
            widget.onViewSchool(school);
            return;
          }
          break;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open ${item.title}.')),
        );
      }
    } finally {
      if (mounted) setState(() => _openingItemId = null);
    }
  }

  Future<ManagedSchool?> _schoolForAttentionItem(
    NeedsAttentionItem item,
  ) async {
    final local = widget.schools.cast<ManagedSchool?>().firstWhere(
      (school) => school?.code == item.entityId,
      orElse: () => null,
    );
    if (local != null) return local;
    final page = await widget.repository.getSchools(
      searchTerm: item.entityId.isEmpty ? item.title : item.entityId,
      size: 10,
    );
    return page.schools.cast<ManagedSchool?>().firstWhere(
      (school) => school?.code == item.entityId,
      orElse: () => page.schools.isEmpty ? null : page.schools.first,
    );
  }
}

class _AttentionSummaryCard extends StatelessWidget {
  const _AttentionSummaryCard({
    required this.group,
    required this.selected,
    required this.onTap,
  });

  final _AttentionGroup group;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: selected ? group.color.withValues(alpha: .08) : Colors.white,
            border: Border.all(
              color: selected ? group.color : AppColors.border,
              width: selected ? 1.4 : 1,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: group.color.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(group.icon, color: group.color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${group.count}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        group.title,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  Icon(
                    Icons.check_circle_rounded,
                    color: group.color,
                    size: 18,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AttentionLoadingState extends StatelessWidget {
  const _AttentionLoadingState();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Needs attention',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            'Loading action items from the platform.',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: List.generate(
              4,
              (_) => const SizedBox(
                width: 250,
                child: _SkeletonCard(
                  child: Row(
                    children: [
                      _SkeletonBox(width: 38, height: 38, radius: 12),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SkeletonBox(width: 48, height: 20),
                            SizedBox(height: 8),
                            _SkeletonBox(width: 150, height: 10),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Column(
                children: [
                  Row(
                    children: [
                      _SkeletonBox(width: 36, height: 36, radius: 11),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SkeletonBox(width: 180, height: 14),
                            SizedBox(height: 8),
                            _SkeletonBox(width: 260, height: 10),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 14),
                  _AttentionRowsLoading(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttentionErrorState extends StatelessWidget {
  const _AttentionErrorState({
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.red.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: AppColors.red,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    message,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Retry'),
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

class _AttentionListPanel extends StatelessWidget {
  const _AttentionListPanel({
    required this.group,
    required this.query,
    required this.visibleItems,
    required this.totalItems,
    required this.page,
    required this.totalPages,
    required this.loading,
    required this.openingItemId,
    required this.onQueryChanged,
    required this.onPrevious,
    required this.onNext,
    required this.onItemTap,
  });

  final _AttentionGroup group;
  final String query;
  final List<NeedsAttentionItem> visibleItems;
  final int totalItems;
  final int page;
  final int totalPages;
  final bool loading;
  final String? openingItemId;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final ValueChanged<NeedsAttentionItem> onItemTap;

  @override
  Widget build(BuildContext context) {
    final showingFrom = totalItems == 0
        ? 0
        : page * _AttentionSchoolsScreenState._pageSize + 1;
    final showingTo = totalItems == 0
        ? 0
        : (page * _AttentionSchoolsScreenState._pageSize + visibleItems.length);

    return Card(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: group.color.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(group.icon, color: group.color, size: 19),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${group.title} ($totalItems)',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        group.description,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: group.color.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    group.actionLabel,
                    style: TextStyle(
                      color: group.color,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: onQueryChanged,
              decoration: InputDecoration(
                hintText: 'Search ${group.title.toLowerCase()}...',
                prefixIcon: const Icon(Icons.search_rounded, size: 18),
              ),
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          if (loading)
            const _AttentionRowsLoading()
          else if (visibleItems.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No matching attention items.',
                style: TextStyle(color: AppColors.muted),
              ),
            )
          else
            ...visibleItems.map(
              (item) => _AttentionActionRow(
                item: item,
                color: group.color,
                opening: openingItemId == item.id,
                onTap: () => onItemTap(item),
              ),
            ),
          const Divider(height: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Showing $showingFrom-$showingTo of $totalItems',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                OutlinedButton(
                  onPressed: onPrevious,
                  child: const Text('Previous'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(onPressed: onNext, child: const Text('Next')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AttentionRowsLoading extends StatelessWidget {
  const _AttentionRowsLoading();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        6,
        (_) => const Padding(
          padding: EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            children: [
              _SkeletonBox(width: 40, height: 40, radius: 12),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SkeletonBox(width: 180, height: 13),
                    SizedBox(height: 8),
                    _SkeletonBox(width: 280, height: 10),
                  ],
                ),
              ),
              SizedBox(width: 12),
              _SkeletonBox(width: 64, height: 24, radius: 999),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttentionActionRow extends StatelessWidget {
  const _AttentionActionRow({
    required this.item,
    required this.color,
    required this.opening,
    required this.onTap,
  });

  final NeedsAttentionItem item;
  final Color color;
  final bool opening;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.greenSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _initialsForName(item.title),
                style: const TextStyle(
                  color: AppColors.green,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.description,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (opening)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (_attentionItemMeta(item).isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _attentionItemMeta(item),
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}

class _AttentionGroup {
  const _AttentionGroup({
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.icon,
    required this.color,
    required this.category,
    required this.count,
  });

  final String title;
  final String description;
  final String actionLabel;
  final IconData icon;
  final Color color;
  final String category;
  final int count;
}

_AttentionGroup _attentionGroupForCategory(NeedsAttentionCategory category) {
  return switch (category.category) {
    'ACCOUNT_MANAGER_APPROVALS' => _AttentionGroup(
      title: category.label.isEmpty
          ? 'Account manager approvals'
          : category.label,
      description: 'Registrations waiting for Super Admin approval.',
      actionLabel: 'Open list',
      icon: Icons.manage_accounts_rounded,
      color: AppColors.red,
      category: category.category,
      count: category.count,
    ),
    'SCHOOL_APPROVALS' => _AttentionGroup(
      title: category.label.isEmpty ? 'School approvals' : category.label,
      description: 'Schools submitted and waiting for review.',
      actionLabel: 'Review',
      icon: Icons.rule_folder_rounded,
      color: AppColors.amber,
      category: category.category,
      count: category.count,
    ),
    'ONBOARDING_STALLED' => _AttentionGroup(
      title: category.label.isEmpty ? 'Onboarding stalled' : category.label,
      description:
          'Schools have not moved to the next setup step after 5 days.',
      actionLabel: 'Continue',
      icon: Icons.timeline_rounded,
      color: AppColors.blue,
      category: category.category,
      count: category.count,
    ),
    'COMPLIANCE_MISSING' => _AttentionGroup(
      title: category.label.isEmpty ? 'Compliance missing' : category.label,
      description: 'Registration or compliance information needs follow-up.',
      actionLabel: 'Fix record',
      icon: Icons.fact_check_rounded,
      color: AppColors.purple,
      category: category.category,
      count: category.count,
    ),
    _ => _AttentionGroup(
      title: category.label.isEmpty ? category.category : category.label,
      description: 'Items requiring Super Admin action.',
      actionLabel: 'Open',
      icon: Icons.pending_actions_rounded,
      color: AppColors.green,
      category: category.category,
      count: category.count,
    ),
  };
}

String _attentionItemMeta(NeedsAttentionItem item) {
  final age = item.ageInDays;
  if (age != null) return age == 1 ? '1 day' : '$age days';
  return item.status;
}

String _stageForProgress(double progress) {
  if (progress < .5) return 'School profile';
  if (progress < .75) return 'Academic setup';
  return 'Administrator invitation';
}

int _onboardingStepIndex(ManagedSchool school) {
  final normalized = school.progress.isNaN
      ? 0.0
      : school.progress.clamp(0.0, 1.0);
  final step = (normalized * 9).floor();
  return step.clamp(0, 8);
}

String _initialsForName(String value) {
  final letters = value
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty && RegExp(r'[A-Za-z]').hasMatch(part[0]))
      .take(2)
      .map((part) => part[0].toUpperCase())
      .join();
  return letters.isEmpty ? 'SA' : letters;
}

bool _isSchoolPendingApproval(ManagedSchool school) {
  return school.status == SchoolStatus.pendingApproval ||
      school.status == SchoolStatus.completed;
}

String _approvalStatusLabel(ManagedSchool school) {
  if (school.progress >= 1) return 'Ready';
  return '${(school.progress * 100).round()}%';
}

({String detail, IconData icon, Color color}) _activityForSchool(
  ManagedSchool school,
) {
  if (_isSchoolPendingApproval(school)) {
    return (
      detail: 'School submitted or still waiting for approval',
      icon: Icons.rule_folder_outlined,
      color: AppColors.amber,
    );
  }
  if (school.status.isApproved) {
    return (
      detail: 'School profile is active',
      icon: Icons.verified_outlined,
      color: AppColors.green,
    );
  }
  return (
    detail: school.needsAttentionReasons.isEmpty
        ? 'School record was updated'
        : school.needsAttentionReasons.first,
    icon: Icons.warning_amber_rounded,
    color: AppColors.red,
  );
}

class _PortfolioAlerts extends StatelessWidget {
  const _PortfolioAlerts({required this.data, required this.onViewAll});

  final AccountManagerSnapshot data;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final summary = data.needsAttentionSummary;
    final groups =
        summary?.categories
            .map(_attentionGroupForCategory)
            .where((group) => group.count > 0)
            .toList() ??
        const <_AttentionGroup>[];
    final totalCount = summary?.total ?? 0;
    final previewItems = groups
        .map(
          (group) => (
            color: group.color,
            title: group.count == 1
                ? group.title
                : '${group.count} ${group.title.toLowerCase()}',
            detail: group.description,
          ),
        )
        .toList();
    final visible = previewItems.take(3).toList();

    return _Panel(
      title: 'Needs your attention ($totalCount)',
      action: totalCount > 3 ? 'View all' : null,
      onAction: onViewAll,
      child: totalCount == 0
          ? const Padding(
              padding: EdgeInsets.all(18),
              child: Text(
                'No attention items right now.',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            )
          : Column(
              children: [
                ...visible.map(
                  (item) => _AlertRow(
                    color: item.color,
                    title: item.title,
                    detail: item.detail,
                    onTap: onViewAll,
                  ),
                ),
                if (totalCount > visible.length)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 4, 18, 14),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: onViewAll,
                        child: Text('+${totalCount - visible.length} more'),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _AlertRow extends StatelessWidget {
  const _AlertRow({
    required this.color,
    required this.title,
    required this.detail,
    this.onTap,
  });

  final Color color;
  final String title;
  final String detail;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    detail,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppColors.muted,
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentActivitiesPanel extends StatelessWidget {
  const _RecentActivitiesPanel({
    required this.schools,
    required this.onViewAll,
    required this.onViewSchool,
  });
  final List<ManagedSchool> schools;
  final VoidCallback onViewAll;
  final ValueChanged<ManagedSchool> onViewSchool;

  @override
  Widget build(BuildContext context) {
    final activities = schools.take(5).toList();
    return _Panel(
      title: 'Recent activities',
      action: activities.isEmpty ? null : 'View schools →',
      onAction: onViewAll,
      child: activities.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No recent school activity yet.'),
            )
          : Column(
              children: activities
                  .map(
                    (school) => _ActivityRow(
                      school: school,
                      onViewSchool: onViewSchool,
                    ),
                  )
                  .toList(),
            ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.school, required this.onViewSchool});

  final ManagedSchool school;
  final ValueChanged<ManagedSchool> onViewSchool;

  @override
  Widget build(BuildContext context) {
    final activity = _activityForSchool(school);
    return InkWell(
      onTap: () => onViewSchool(school),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: activity.color.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(activity.icon, size: 18, color: activity.color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    school.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    activity.detail,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              school.lastActive,
              style: const TextStyle(color: AppColors.muted, fontSize: 10.5),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}

class _SchoolsScreen extends StatefulWidget {
  const _SchoolsScreen({
    required this.repository,
    required this.accessToken,
    required this.onRefreshAccessToken,
    required this.schools,
    required this.onCreateSchool,
    required this.onViewSchool,
  });
  final PlatformRepository repository;
  final String? accessToken;
  final Future<String?> Function() onRefreshAccessToken;
  final List<ManagedSchool> schools;
  final VoidCallback onCreateSchool;
  final ValueChanged<ManagedSchool> onViewSchool;

  @override
  State<_SchoolsScreen> createState() => _SchoolsScreenState();
}

class _SchoolsScreenState extends State<_SchoolsScreen> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  final _searchLayerLink = LayerLink();
  OverlayEntry? _searchOverlay;
  double _searchOverlayWidth = 340;
  String _region = 'All Regions';
  String _district = 'All Districts';
  String _status = 'Approved';
  List<String> _lookupRegions = const [];
  Map<String, int> _lookupRegionIds = const {};
  List<String> _lookupDistricts = const [];
  bool _loadingRegions = true;
  bool _loadingDistricts = false;
  String? _lookupError;
  static const int _pageSize = 10;
  int _page = 0;
  Timer? _globalSearchDebounce;
  late Future<ManagedSchoolPage> _schoolsFuture;
  ManagedSchoolPage? _loadedSchoolsPage;
  bool _searchPanelOpen = false;
  bool _searchingSchools = false;
  String? _searchError;
  List<ManagedSchool> _globalSearchResults = const [];

  @override
  void initState() {
    super.initState();
    _schoolsFuture = _loadSchools();
    _loadRegionLookups();
    _searchFocusNode.addListener(() {
      if (_searchFocusNode.hasFocus && !_searchPanelOpen) {
        _openSearchPanel();
      }
    });
  }

  @override
  void dispose() {
    _removeSearchOverlay();
    _globalSearchDebounce?.cancel();
    _searchFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fallbackPage = _fallbackPage();
    final regions = _lookupRegions.isNotEmpty
        ? ['All Regions', ..._lookupRegions]
        : [
            'All Regions',
            ..._filterSourceSchools()
                .map((school) => school.region)
                .where((region) => region.trim().isNotEmpty)
                .toSet()
                .toList()
              ..sort(),
          ];
    final canSelectDistrict = _region != 'All Regions';
    final districts = ['All Districts', ..._lookupDistricts];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Schools',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Browse schools by name, approval status, region, and district.',
                      style: TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: widget.onCreateSchool,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Create school'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Card(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 820;
                      final searchWidth = compact
                          ? constraints.maxWidth
                          : (constraints.maxWidth - 560).clamp(360.0, 520.0);
                      _searchOverlayWidth = searchWidth;
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        crossAxisAlignment: WrapCrossAlignment.end,
                        children: [
                          CompositedTransformTarget(
                            link: _searchLayerLink,
                            child: _SchoolSearchField(
                              width: searchWidth,
                              controller: _searchController,
                              focusNode: _searchFocusNode,
                              onTap: _openSearchPanel,
                              onChanged: _handleSearchChanged,
                              onSubmitted: (_) => _openFirstSearchResult(),
                            ),
                          ),
                          _SchoolFilterDropdown(
                            label: 'Region',
                            width: compact ? constraints.maxWidth : 170,
                            value: _region,
                            values: regions,
                            disabledHint: _loadingRegions
                                ? 'Loading regions...'
                                : 'All Regions',
                            onChanged: (value) => _setRegion(value),
                          ),
                          _SchoolFilterDropdown(
                            label: 'District',
                            width: compact ? constraints.maxWidth : 180,
                            value:
                                canSelectDistrict &&
                                    districts.contains(_district)
                                ? _district
                                : 'All Districts',
                            values: districts,
                            enabled: canSelectDistrict && !_loadingDistricts,
                            disabledHint: _loadingDistricts
                                ? 'Loading districts...'
                                : 'Select region first',
                            onChanged: (value) => _setDistrict(value),
                          ),
                          _SchoolFilterDropdown(
                            label: 'Status',
                            width: compact ? constraints.maxWidth : 160,
                            value: _status,
                            values: const [
                              'All Statuses',
                              'Approved',
                              'Completed',
                              'Pending Approval',
                              'In Progress',
                              'Needs Revision',
                              'Rejected',
                              'Suspended',
                              'Inactive',
                              'Deleted',
                            ],
                            onChanged: (value) => _setStatus(value),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const Divider(height: 1, color: AppColors.border),
                if (_lookupError != null)
                  _SchoolFilterLookupNotice(
                    message:
                        'Could not load all region filters. Showing available school regions.',
                    onRetry: _loadRegionLookups,
                  ),
                if (MediaQuery.sizeOf(context).width >= 800)
                  const _SchoolTableHeader(),
                FutureBuilder<ManagedSchoolPage>(
                  key: ValueKey('$_region|$_district|$_status|$_page'),
                  future: _schoolsFuture,
                  builder: (context, snapshot) {
                    final schoolPage = snapshot.data;
                    final loading =
                        snapshot.connectionState == ConnectionState.waiting;
                    if (loading && schoolPage == null) {
                      return const _SchoolListSkeletonRows();
                    }
                    if (snapshot.hasError && schoolPage == null) {
                      return _SchoolListError(onRetry: _refreshSchools);
                    }
                    final visiblePage = schoolPage ?? fallbackPage;
                    final schools = visiblePage.schools;
                    if (snapshot.hasError && schools.isEmpty) {
                      return _SchoolListError(onRetry: _refreshSchools);
                    }
                    return Column(
                      children: [
                        if (loading && schools.isEmpty)
                          const _SchoolListSkeletonRows()
                        else if (loading)
                          const _SchoolListLoadingBar(),
                        if (!loading && schools.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(28),
                            child: Text('No schools match these filters.'),
                          )
                        else
                          ...schools.map(
                            (school) => _SchoolListRow(
                              school: school,
                              onViewSchool: widget.onViewSchool,
                            ),
                          ),
                        _SchoolPaginationBar(
                          page: visiblePage,
                          loading: loading,
                          onPrevious: visiblePage.hasPrevious
                              ? () => _goToPage(_page - 1)
                              : null,
                          onNext: visiblePage.hasNext
                              ? () => _goToPage(_page + 1)
                              : null,
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openSearchPanel() {
    if (!mounted) return;
    setState(() => _searchPanelOpen = true);
    if (_searchOverlay != null) {
      _searchOverlay!.markNeedsBuild();
      return;
    }
    _searchOverlay = OverlayEntry(
      builder: (context) {
        return Positioned.fill(
          child: IgnorePointer(
            ignoring: false,
            child: Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _closeSearchPanel,
                  ),
                ),
                CompositedTransformFollower(
                  link: _searchLayerLink,
                  showWhenUnlinked: false,
                  offset: const Offset(0, 74),
                  child: SizedBox(
                    width: _searchOverlayWidth,
                    child: _GlobalSchoolSearchPanel(
                      query: _searchController.text,
                      searching: _searchingSchools,
                      error: _searchError,
                      results: _globalSearchResults,
                      onCreateSchool: () {
                        _closeSearchPanel();
                        widget.onCreateSchool();
                      },
                      onSelectSchool: _openSearchResult,
                      onClose: _closeSearchPanel,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    Overlay.of(context).insert(_searchOverlay!);
  }

  void _closeSearchPanel() {
    if (!mounted) return;
    setState(() => _searchPanelOpen = false);
    _searchFocusNode.unfocus();
    _removeSearchOverlay();
  }

  void _removeSearchOverlay() {
    _searchOverlay?.remove();
    _searchOverlay = null;
  }

  void _refreshSearchOverlay() {
    if (_searchPanelOpen) _searchOverlay?.markNeedsBuild();
  }

  Future<ManagedSchoolPage> _loadSchools() async {
    final page = await widget.repository.getSchools(
      region: _region,
      district: _district,
      status: _status,
      page: _page,
      size: _pageSize,
    );
    if (mounted) setState(() => _loadedSchoolsPage = page);
    return page;
  }

  void _refreshSchools() {
    setState(() => _schoolsFuture = _loadSchools());
  }

  void _handleSearchChanged(String value) {
    _scheduleGlobalSearch(value);
  }

  void _scheduleGlobalSearch(String value) {
    final query = value.trim();
    _globalSearchDebounce?.cancel();
    setState(() {
      _searchPanelOpen = true;
      _searchError = null;
      if (query.isEmpty) {
        _searchingSchools = false;
        _globalSearchResults = const [];
      } else {
        _searchingSchools = true;
      }
    });
    _openSearchPanel();
    _refreshSearchOverlay();
    if (query.isEmpty) return;

    _globalSearchDebounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        final result = await widget.repository.getSchools(
          searchTerm: query,
          page: 0,
          size: 8,
        );
        if (!mounted || _searchController.text.trim() != query) return;
        setState(() {
          _globalSearchResults = result.schools;
          _searchingSchools = false;
          _searchError = null;
        });
        _refreshSearchOverlay();
      } catch (_) {
        if (!mounted || _searchController.text.trim() != query) return;
        setState(() {
          _globalSearchResults = const [];
          _searchingSchools = false;
          _searchError = 'Could not search schools. Try again.';
        });
        _refreshSearchOverlay();
      }
    });
  }

  void _openFirstSearchResult() {
    if (_globalSearchResults.isEmpty) return;
    _openSearchResult(_globalSearchResults.first);
  }

  void _openSearchResult(ManagedSchool school) {
    _closeSearchPanel();
    widget.onViewSchool(school);
  }

  Future<void> _loadRegionLookups() async {
    setState(() {
      _loadingRegions = true;
      _lookupError = null;
    });
    try {
      final lookups = await PlatformApiClient(
        accessToken: widget.accessToken,
        onRefreshAccessToken: widget.onRefreshAccessToken,
      ).getSchoolCreationLookups();
      if (!mounted) return;
      setState(() {
        _lookupRegions = lookups.regions;
        _lookupRegionIds = lookups.regionIds;
        _loadingRegions = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _lookupRegions = const [];
        _lookupRegionIds = const {};
        _loadingRegions = false;
        _lookupError = 'regions';
      });
    }
  }

  Future<void> _loadDistrictLookups(String region) async {
    final regionId = _lookupRegionIds[region];
    if (regionId == null || regionId <= 0) {
      setState(() {
        _lookupDistricts = const [];
        _loadingDistricts = false;
      });
      return;
    }
    setState(() {
      _lookupDistricts = const [];
      _loadingDistricts = true;
    });
    try {
      final lookups = await PlatformApiClient(
        accessToken: widget.accessToken,
        onRefreshAccessToken: widget.onRefreshAccessToken,
      ).getDistrictLookups(regionId);
      if (!mounted || _region != region) return;
      setState(() {
        _lookupDistricts = lookups.districts;
        _loadingDistricts = false;
      });
    } catch (_) {
      if (!mounted || _region != region) return;
      setState(() {
        _lookupDistricts = const [];
        _loadingDistricts = false;
      });
    }
  }

  void _setRegion(String value) {
    setState(() {
      _region = value;
      _district = 'All Districts';
      _lookupDistricts = const [];
      _page = 0;
      _schoolsFuture = _loadSchools();
    });
    if (value != 'All Regions') {
      _loadDistrictLookups(value);
    }
  }

  void _setDistrict(String value) {
    setState(() {
      _district = value;
      _page = 0;
      _schoolsFuture = _loadSchools();
    });
  }

  void _setStatus(String value) {
    setState(() {
      _status = value;
      _page = 0;
      _schoolsFuture = _loadSchools();
    });
  }

  void _goToPage(int page) {
    setState(() {
      _page = page < 0 ? 0 : page;
      _schoolsFuture = _loadSchools();
    });
  }

  ManagedSchoolPage _fallbackPage() {
    final schools = widget.schools.where((school) {
      final matchesDistrict =
          _district == 'All Districts' || school.district == _district;
      final matchesRegion =
          _region == 'All Regions' || school.region == _region;
      final matchesStatus =
          _status == 'All Statuses' || school.status.label == _status;
      return matchesRegion && matchesDistrict && matchesStatus;
    }).toList();
    return ManagedSchoolPage(
      schools: schools.take(_pageSize).toList(),
      totalElements: schools.length,
      totalPages: schools.isEmpty ? 1 : (schools.length / _pageSize).ceil(),
      currentPage: _page,
      pageSize: _pageSize,
    );
  }

  List<ManagedSchool> _filterSourceSchools() {
    final schoolsByCode = <String, ManagedSchool>{};
    for (final school in widget.schools) {
      schoolsByCode[school.code] = school;
    }
    for (final school
        in _loadedSchoolsPage?.schools ?? const <ManagedSchool>[]) {
      schoolsByCode[school.code] = school;
    }
    return schoolsByCode.values.toList();
  }
}

class _SchoolListLoadingBar extends StatelessWidget {
  const _SchoolListLoadingBar();

  @override
  Widget build(BuildContext context) {
    return const LinearProgressIndicator(minHeight: 2);
  }
}

class _SchoolListSkeletonRows extends StatelessWidget {
  const _SchoolListSkeletonRows();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        8,
        (_) => const Padding(
          padding: EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            children: [
              _SkeletonBox(width: 42, height: 42, radius: 12),
              SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SkeletonBox(width: 170, height: 13),
                    SizedBox(height: 8),
                    _SkeletonBox(width: 120, height: 10),
                  ],
                ),
              ),
              SizedBox(width: 18),
              Expanded(child: _SkeletonBox(width: double.infinity, height: 12)),
              SizedBox(width: 18),
              Expanded(child: _SkeletonBox(width: double.infinity, height: 12)),
              SizedBox(width: 18),
              _SkeletonBox(width: 74, height: 24, radius: 999),
            ],
          ),
        ),
      ),
    );
  }
}

class _SchoolListError extends StatelessWidget {
  const _SchoolListError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Text('Unable to load schools from the API.'),
          const SizedBox(height: 10),
          OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}

class _SchoolFilterLookupNotice extends StatelessWidget {
  const _SchoolFilterLookupNotice({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
      color: AppColors.amber.withValues(alpha: .08),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: AppColors.amber,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _SchoolPaginationBar extends StatelessWidget {
  const _SchoolPaginationBar({
    required this.page,
    required this.loading,
    required this.onPrevious,
    required this.onNext,
  });

  final ManagedSchoolPage page;
  final bool loading;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final start = page.totalElements == 0
        ? 0
        : (page.currentPage * page.pageSize) + 1;
    final end = page.totalElements == 0
        ? 0
        : (start + page.schools.length - 1).clamp(start, page.totalElements);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Showing $start-$end of ${page.totalElements} schools',
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ),
          OutlinedButton(
            onPressed: loading ? null : onPrevious,
            child: const Text('Previous'),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: loading ? null : onNext,
            child: const Text('Next'),
          ),
        ],
      ),
    );
  }
}

class _SchoolFilterDropdown extends StatelessWidget {
  const _SchoolFilterDropdown({
    required this.label,
    required this.width,
    required this.value,
    required this.values,
    required this.onChanged,
    this.enabled = true,
    this.disabledHint,
  });

  final String label;
  final double width;
  final String value;
  final List<String> values;
  final ValueChanged<String> onChanged;
  final bool enabled;
  final String? disabledHint;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FilterLabel(label),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: enabled
                ? (values.contains(value) ? value : values.first)
                : null,
            disabledHint: Text(disabledHint ?? ''),
            isDense: true,
            decoration: InputDecoration(
              hintText: disabledHint,
              filled: true,
              fillColor: enabled ? Colors.white : const Color(0xFFF3F6F6),
              enabledBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: AppColors.border),
                borderRadius: BorderRadius.circular(10),
              ),
              disabledBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: AppColors.border),
                borderRadius: BorderRadius.circular(10),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: AppColors.green),
                borderRadius: BorderRadius.circular(10),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 11,
              ),
            ),
            items: values
                .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                .toList(),
            onChanged: enabled
                ? (value) {
                    if (value != null) onChanged(value);
                  }
                : null,
          ),
        ],
      ),
    );
  }
}

class _SchoolSearchField extends StatelessWidget {
  const _SchoolSearchField({
    required this.width,
    required this.controller,
    required this.focusNode,
    required this.onTap,
    required this.onChanged,
    required this.onSubmitted,
  });

  final double width;
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onTap;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _FilterLabel('Search'),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            focusNode: focusNode,
            onTap: onTap,
            onChanged: onChanged,
            onSubmitted: onSubmitted,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded, size: 19),
              hintText: 'Search schools...',
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              enabledBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: AppColors.border),
                borderRadius: BorderRadius.circular(10),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: AppColors.green),
                borderRadius: BorderRadius.circular(10),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlobalSchoolSearchPanel extends StatelessWidget {
  const _GlobalSchoolSearchPanel({
    required this.query,
    required this.searching,
    required this.error,
    required this.results,
    required this.onCreateSchool,
    required this.onSelectSchool,
    required this.onClose,
  });

  final String query;
  final bool searching;
  final String? error;
  final List<ManagedSchool> results;
  final VoidCallback onCreateSchool;
  final ValueChanged<ManagedSchool> onSelectSchool;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final cleanQuery = query.trim();
    return Material(
      elevation: 12,
      shadowColor: Colors.black.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(14),
      color: Colors.white,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(14),
        ),
        constraints: const BoxConstraints(maxHeight: 360),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 10, 6),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Global school search',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: onClose,
                        icon: const Icon(Icons.close_rounded, size: 18),
                      ),
                    ],
                  ),
                ),
                if (cleanQuery.isEmpty) ...[
                  _SearchActionRow(
                    icon: Icons.add_business_rounded,
                    title: 'Create new school',
                    subtitle: 'Start a new school onboarding',
                    onTap: onCreateSchool,
                  ),
                  const Divider(height: 1, color: AppColors.border),
                  const Padding(
                    padding: EdgeInsets.all(14),
                    child: Text(
                      'Type a school name or custom school ID to search across all schools.',
                      style: TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                  ),
                ] else if (searching) ...[
                  const LinearProgressIndicator(minHeight: 2),
                  const Padding(
                    padding: EdgeInsets.all(14),
                    child: Text(
                      'Searching all schools...',
                      style: TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                  ),
                ] else if (error != null) ...[
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(
                      error!,
                      style: const TextStyle(
                        color: AppColors.red,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ] else if (results.isEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.all(14),
                    child: Text(
                      'No schools found.',
                      style: TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                  ),
                  _SearchActionRow(
                    icon: Icons.add_business_rounded,
                    title: 'Create new school',
                    subtitle: 'No match? Start onboarding instead',
                    onTap: onCreateSchool,
                  ),
                ] else ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                    child: Text(
                      '${results.length} result${results.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  ...results.map(
                    (school) => _GlobalSchoolSearchResult(
                      school: school,
                      onTap: () => onSelectSchool(school),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GlobalSchoolSearchResult extends StatelessWidget {
  const _GlobalSchoolSearchResult({required this.school, required this.onTap});

  final ManagedSchool school;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final location = [
      school.region,
      if (school.district.trim().isNotEmpty) school.district,
    ].where((value) => value.trim().isNotEmpty).join(' · ');
    final status = _schoolStatusPresentation(school.status);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            _SchoolAvatar(name: school.name),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    school.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${school.code}${location.isEmpty ? '' : ' · $location'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: status.$2.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                status.$1,
                style: TextStyle(
                  color: status.$2,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

(String, Color) _schoolStatusPresentation(SchoolStatus status) => (
  status.label,
  switch (status) {
    SchoolStatus.approved => AppColors.green,
    SchoolStatus.inProgress ||
    SchoolStatus.completed ||
    SchoolStatus.pendingApproval => AppColors.amber,
    SchoolStatus.needsRevision => AppColors.blue,
    SchoolStatus.rejected ||
    SchoolStatus.suspended ||
    SchoolStatus.deleted => AppColors.red,
    SchoolStatus.inactive => AppColors.muted,
  },
);

class _SearchActionRow extends StatelessWidget {
  const _SearchActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            Icon(icon, color: AppColors.green, size: 19),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}

class _FilterLabel extends StatelessWidget {
  const _FilterLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: AppColors.muted,
        fontSize: 9.5,
        fontWeight: FontWeight.w800,
        letterSpacing: .55,
      ),
    );
  }
}

class _SchoolTableHeader extends StatelessWidget {
  const _SchoolTableHeader();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      color: AppColors.muted,
      fontSize: 9.5,
      fontWeight: FontWeight.w700,
      letterSpacing: .7,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      color: AppColors.background,
      child: const Row(
        children: [
          SizedBox(width: 40),
          SizedBox(width: 12),
          Expanded(flex: 3, child: Text('SCHOOL NAME', style: style)),
          SizedBox(width: 125, child: Text('REGION', style: style)),
          SizedBox(width: 145, child: Text('DISTRICT', style: style)),
          SizedBox(width: 165, child: Text('ACCOUNT MANAGER', style: style)),
          SizedBox(width: 95, child: Text('STUDENTS', style: style)),
          SizedBox(width: 115, child: Text('STATUS', style: style)),
          SizedBox(width: 24),
        ],
      ),
    );
  }
}

class _SchoolListRow extends StatelessWidget {
  const _SchoolListRow({required this.school, required this.onViewSchool});
  final ManagedSchool school;
  final ValueChanged<ManagedSchool> onViewSchool;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 800;
    final status = _schoolStatusPresentation(school.status);
    return InkWell(
      onTap: () => onViewSchool(school),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        child: Row(
          children: [
            _SchoolAvatar(name: school.name),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    school.name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${school.code} · ${school.town}',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ),
            if (wide)
              SizedBox(
                width: 125,
                child: Text(
                  school.region,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            if (wide)
              SizedBox(
                width: 145,
                child: Text(
                  school.district.trim().isEmpty ? '-' : school.district,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            if (wide)
              SizedBox(
                width: 165,
                child: Text(
                  school.accountManager == 'Not assigned'
                      ? '-'
                      : school.accountManager,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            if (wide)
              SizedBox(
                width: 95,
                child: Text(
                  '${school.students}',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            SizedBox(
              width: wide ? 115 : null,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: status.$2.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    status.$1,
                    style: TextStyle(
                      color: status.$2,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}

class _SchoolAvatar extends StatelessWidget {
  const _SchoolAvatar({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.greenSoft,
        borderRadius: BorderRadius.circular(9),
      ),
      alignment: Alignment.center,
      child: Text(
        name.split(' ').take(2).map((word) => word[0]).join(),
        style: const TextStyle(
          color: AppColors.green,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _PlatformSidebar extends StatelessWidget {
  const _PlatformSidebar({
    required this.page,
    required this.creatingSchool,
    required this.onPageSelected,
    required this.onCreateSchool,
    required this.onOpenSchoolAdministrator,
    required this.schoolCount,
    required this.attentionCount,
    required this.role,
  });

  final PlatformPage page;
  final bool creatingSchool;
  final ValueChanged<PlatformPage> onPageSelected;
  final VoidCallback onCreateSchool;
  final VoidCallback onOpenSchoolAdministrator;
  final int schoolCount;
  final int attentionCount;
  final PlatformRole role;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      color: const Color(0xFF00695C),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 17),
              child: Row(
                children: [
                  const _PlatformLogo(),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'SMA Ghana',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          role.label.toUpperCase(),
                          style: TextStyle(
                            color: Color(0xFFD1E7E3),
                            fontSize: 9,
                            letterSpacing: .7,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0x33FFFFFF)),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 14, 10, 2),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onCreateSchool,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF00695C),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text(
                    'Create school',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(10),
                children: [
                  const _NavLabel('OVERVIEW'),
                  _PlatformNavItem(
                    icon: Icons.home_rounded,
                    label: 'Dashboard',
                    active: !creatingSchool && page == PlatformPage.overview,
                    onTap: () => onPageSelected(PlatformPage.overview),
                  ),
                  const _NavLabel('SCHOOL MANAGEMENT'),
                  _PlatformNavItem(
                    icon: Icons.apartment_rounded,
                    label: 'Schools',
                    active: !creatingSchool && page == PlatformPage.schools,
                    badge: '$schoolCount',
                    onTap: () => onPageSelected(PlatformPage.schools),
                  ),
                  _PlatformNavItem(
                    icon: Icons.warning_amber_rounded,
                    label: 'Needs attention',
                    badge: '$attentionCount',
                    active: !creatingSchool && page == PlatformPage.attention,
                    onTap: () => onPageSelected(PlatformPage.attention),
                  ),
                  if (role.canManageAccountManagers) ...[
                    const _NavLabel('TEAM MANAGEMENT'),
                    _PlatformNavItem(
                      icon: Icons.manage_accounts_rounded,
                      label: 'Account managers',
                      active:
                          !creatingSchool &&
                          page == PlatformPage.accountManagers,
                      onTap: () => onPageSelected(PlatformPage.accountManagers),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                children: [
                  Material(
                    color: const Color(0x22FFFFFF),
                    borderRadius: BorderRadius.circular(9),
                    child: InkWell(
                      onTap: onOpenSchoolAdministrator,
                      borderRadius: BorderRadius.circular(9),
                      child: const Padding(
                        padding: EdgeInsets.all(10),
                        child: Row(
                          children: [
                            Icon(
                              Icons.swap_horiz_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Preview school admin',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 17,
                        backgroundColor: AppColors.green,
                        child: Text(
                          'AM',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Abena Mensah',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              role.label,
                              style: const TextStyle(
                                color: Color(0xFFB7D7D2),
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.more_horiz_rounded,
                        color: Colors.white70,
                        size: 18,
                      ),
                    ],
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

class _PlatformLogo extends StatelessWidget {
  const _PlatformLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: const Color(0x33FFFFFF),
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: const Text(
        'SM',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _NavLabel extends StatelessWidget {
  const _NavLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 7),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0x88FFFFFF),
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _PlatformNavItem extends StatelessWidget {
  const _PlatformNavItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.badge,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Material(
        color: active ? const Color(0x2FFFFFFF) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: active ? Colors.white : const Color(0xBFFFFFFF),
                  size: 17,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: active ? Colors.white : const Color(0xCFFFFFFF),
                      fontSize: 12.5,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0x33FFFFFF),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      badge!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
