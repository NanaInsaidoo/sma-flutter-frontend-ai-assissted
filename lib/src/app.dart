import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'auth/data/auth_api_client.dart';
import 'auth/data/session_store.dart';
import 'auth/presentation/auth_screen.dart';
import 'dashboard/data/mock_dashboard_repository.dart';
import 'dashboard/presentation/administrator_dashboard.dart';
import 'platform/data/live_platform_repository.dart';
import 'platform/data/mock_platform_repository.dart';
import 'platform/data/platform_repository.dart';
import 'platform/domain/platform_models.dart';
import 'platform/presentation/platform_admin_shell.dart';
import 'theme/app_theme.dart';

class SchoolManagementApp extends StatefulWidget {
  const SchoolManagementApp({super.key});

  @override
  State<SchoolManagementApp> createState() => _SchoolManagementAppState();
}

class _PlatformRouteConfig {
  const _PlatformRouteConfig({
    required this.page,
    this.createSchool = false,
    this.resumeOnboarding = false,
    this.schoolCode,
  });

  final PlatformPage page;
  final bool createSchool;
  final bool resumeOnboarding;
  final String? schoolCode;
}

class _SchoolManagementAppState extends State<SchoolManagementApp> {
  static const bool _useE2eMocks = bool.fromEnvironment('SMA_E2E_MOCKS');

  bool _showSchoolAdministrator = false;
  AuthSession? _session;
  final AuthApiClient _authApi = AuthApiClient();
  final SessionStore _sessionStore = SessionStore();
  late final GoRouter _router;
  PlatformRepository? _platformRepository;
  Future<AccountManagerSnapshot>? _platformSnapshot;
  AccountManagerSnapshot? _platformSnapshotData;

  @override
  void initState() {
    super.initState();
    _session = _sessionStore.load();
    if (_session?.isBlockedFromLogin ?? false) {
      _sessionStore.clear();
      _session = null;
    }
    _router = GoRouter(
      initialLocation: _session == null ? '/login' : _routeForSession(_session),
      overridePlatformDefaultLocation: false,
      redirect: (context, state) {
        final signedIn = _session != null;
        final onLogin = state.matchedLocation == '/login';
        if (!signedIn && !onLogin) return '/login';
        if (signedIn && onLogin) return _routeForSession(_session);
        if (state.matchedLocation == '/') {
          return signedIn ? _routeForSession(_session) : '/login';
        }
        if (signedIn && _session != null && _isPlatformRole(_session!)) {
          final expectedBase = _platformBasePathForSession(_session!);
          final currentBase = _platformBaseFromPath(state.uri.path);
          if (currentBase != null && currentBase != expectedBase) {
            final suffix = state.uri.path.substring(currentBase.length);
            return '$expectedBase$suffix';
          }
        }
        return null;
      },
      routes: [
        GoRoute(
          path: '/',
          redirect: (context, state) =>
              _session == null ? '/login' : _routeForSession(_session),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => AuthScreen(
            onAuthenticated: (session) {
              if (session.isBlockedFromLogin) {
                _sessionStore.clear();
                _session = null;
                _router.go('/login');
                return;
              }
              _sessionStore.save(session);
              setState(() {
                _session = session;
                _platformRepository = null;
                _platformSnapshot = null;
                _platformSnapshotData = null;
              });
              _router.go(_routeForSession(session));
            },
          ),
        ),
        GoRoute(
          path: '/school-admin',
          builder: (context, state) => _schoolStaffDashboard(),
        ),
        ShellRoute(
          builder: (context, state, child) {
            final route = _platformRouteFromPath(state.uri.path);
            return _platformShell(
              route.page,
              createSchool: route.createSchool,
              resumeOnboarding: route.resumeOnboarding,
              schoolCode: route.schoolCode,
            );
          },
          routes: [
            _platformRouteGroup('/super-admin'),
            _platformRouteGroup('/super-account-manager'),
            _platformRouteGroup('/account-manager'),
          ],
        ),
      ],
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final currentPath = _router.routeInformationProvider.value.uri.path;
      if (currentPath == '/') {
        _router.go(_session == null ? '/login' : _routeForSession(_session));
      }
    });
  }

  String _routeForSession(AuthSession? session) {
    if (session == null) return '/login';
    return _isPlatformRole(session)
        ? _platformBasePathForSession(session)
        : '/school-admin';
  }

  GoRoute _platformRouteGroup(String basePath) {
    return GoRoute(
      path: basePath,
      builder: (context, state) => const SizedBox.shrink(),
      routes: [
        GoRoute(
          path: 'schools',
          builder: (context, state) => const SizedBox.shrink(),
          routes: [
            GoRoute(
              path: 'new',
              builder: (context, state) => const SizedBox.shrink(),
            ),
            GoRoute(
              path: ':schoolCode',
              builder: (context, state) => const SizedBox.shrink(),
            ),
          ],
        ),
        GoRoute(
          path: 'onboarding',
          builder: (context, state) => const SizedBox.shrink(),
          routes: [
            GoRoute(
              path: ':schoolCode',
              builder: (context, state) => const SizedBox.shrink(),
            ),
          ],
        ),
        GoRoute(
          path: 'attention',
          builder: (context, state) => const SizedBox.shrink(),
        ),
        GoRoute(
          path: 'account-managers',
          builder: (context, state) => const SizedBox.shrink(),
        ),
      ],
    );
  }

  String _platformBasePathForSession(AuthSession session) {
    return switch (platformRoleFromApiRole(
      session.role,
      isAccountManager: session.isAccountManager,
    )) {
      PlatformRole.superAdmin => '/super-admin',
      PlatformRole.superAccountManager => '/super-account-manager',
      PlatformRole.accountManager => '/account-manager',
    };
  }

  String? _platformBaseFromPath(String path) {
    for (final basePath in const [
      '/super-admin',
      '/super-account-manager',
      '/account-manager',
    ]) {
      if (path == basePath || path.startsWith('$basePath/')) {
        return basePath;
      }
    }
    return null;
  }

  bool _isPlatformRole(AuthSession session) {
    final role = session.role.toUpperCase();
    return role == 'SUPER_ADMIN' ||
        role == 'SUPER_ACCOUNT_MANAGER' ||
        role == 'ACCOUNT_MANAGER' ||
        role == 'ACCOUNT_MANAGER_UNVERIFIED' ||
        role == 'ACCOUNT_MANAGER_VERIFIED_STAFF' ||
        session.isAccountManager;
  }

  _PlatformRouteConfig _platformRouteFromPath(String path) {
    final segments = Uri.parse(path).pathSegments;
    if (segments.length >= 2 && segments[1] == 'schools') {
      if (segments.length >= 3 && segments[2] == 'new') {
        return const _PlatformRouteConfig(
          page: PlatformPage.schools,
          createSchool: true,
        );
      }
      return _PlatformRouteConfig(
        page: PlatformPage.schools,
        schoolCode: segments.length >= 3 ? segments[2] : null,
      );
    }
    if (segments.length >= 2 && segments[1] == 'onboarding') {
      return _PlatformRouteConfig(
        page: PlatformPage.onboarding,
        resumeOnboarding: segments.length >= 3,
        schoolCode: segments.length >= 3 ? segments[2] : null,
      );
    }
    if (segments.length >= 2 && segments[1] == 'attention') {
      return const _PlatformRouteConfig(page: PlatformPage.attention);
    }
    if (segments.length >= 2 && segments[1] == 'account-managers') {
      return const _PlatformRouteConfig(page: PlatformPage.accountManagers);
    }
    return const _PlatformRouteConfig(page: PlatformPage.overview);
  }

  Widget _platformShell(
    PlatformPage page, {
    bool createSchool = false,
    bool resumeOnboarding = false,
    String? schoolCode,
  }) {
    if (_showSchoolAdministrator) {
      return _schoolStaffDashboard();
    }
    return PlatformAdminShell(
      accessToken: _session?.accessToken,
      userDisplayName: _session?.displayName ?? 'Super Admin',
      role: platformRoleFromApiRole(
        _session?.role,
        isAccountManager: _session?.isAccountManager ?? false,
      ),
      basePath: _session == null
          ? '/account-manager'
          : _platformBasePathForSession(_session!),
      onRefreshAccessToken: _refreshAccessToken,
      repository: _currentPlatformRepository,
      dashboardFuture: _currentPlatformSnapshot,
      cachedDashboard: _platformSnapshotData,
      onRefreshDashboard: _refreshPlatformSnapshot,
      initialPage: page,
      createSchool: createSchool,
      resumeOnboarding: resumeOnboarding,
      schoolCode: schoolCode,
      onNavigatePath: _router.go,
      onLogout: _logout,
      onOpenSchoolAdministrator: () {
        setState(() => _showSchoolAdministrator = true);
        _router.go('/school-admin');
      },
    );
  }

  Widget _schoolStaffDashboard() {
    final session = _session;
    return AdministratorDashboard(
      repository: MockDashboardRepository(),
      schoolId: session?.customSchoolId,
      schoolName: session?.schoolName,
      userDisplayName: session?.displayName,
      role: session?.role,
      onLogout: _logout,
    );
  }

  void _logout() {
    _sessionStore.clear();
    setState(() {
      _session = null;
      _showSchoolAdministrator = false;
      _platformRepository = null;
      _platformSnapshot = null;
      _platformSnapshotData = null;
    });
    _router.go('/login');
  }

  PlatformRepository get _currentPlatformRepository {
    if (_useE2eMocks) {
      return _platformRepository ??= MockPlatformRepository();
    }
    return _platformRepository ??= LivePlatformRepository(
      accessToken: _session?.accessToken,
      userDisplayName: _session?.displayName ?? 'Super Admin',
      role: platformRoleFromApiRole(
        _session?.role,
        isAccountManager: _session?.isAccountManager ?? false,
      ),
      onRefreshAccessToken: _refreshAccessToken,
    );
  }

  Future<AccountManagerSnapshot> get _currentPlatformSnapshot {
    return _platformSnapshot ??= _loadPlatformSnapshot();
  }

  Future<AccountManagerSnapshot> _loadPlatformSnapshot() async {
    final snapshot = await _currentPlatformRepository
        .getAccountManagerDashboard();
    if (mounted) {
      setState(() => _platformSnapshotData = snapshot);
    } else {
      _platformSnapshotData = snapshot;
    }
    return snapshot;
  }

  void _refreshPlatformSnapshot() {
    setState(() {
      _platformSnapshotData = null;
      _platformSnapshot = _loadPlatformSnapshot();
    });
  }

  Future<String?> _refreshAccessToken() async {
    final refreshToken = _session?.refreshToken;
    if (refreshToken == null ||
        refreshToken.isEmpty ||
        refreshToken == 'preview') {
      return _session?.accessToken;
    }
    try {
      final refreshed = await _authApi.refreshSession(
        refreshToken: refreshToken,
      );
      if (!mounted) return refreshed.accessToken;
      final nextSession = _session!.mergeRefresh(refreshed);
      if (nextSession.isBlockedFromLogin) {
        _sessionStore.clear();
        setState(() {
          _session = null;
          _platformRepository = null;
          _platformSnapshot = null;
          _platformSnapshotData = null;
        });
        _router.go('/login');
        return null;
      }
      _sessionStore.save(nextSession);
      setState(() => _session = nextSession);
      return nextSession.accessToken;
    } on AuthException {
      _sessionStore.clear();
      if (mounted) {
        setState(() {
          _session = null;
          _platformRepository = null;
          _platformSnapshot = null;
          _platformSnapshotData = null;
        });
        _router.go('/login');
      }
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'SMA Ghana',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: _router,
    );
  }
}
