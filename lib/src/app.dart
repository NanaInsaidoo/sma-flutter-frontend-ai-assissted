import 'dart:async';

import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'auth/data/auth_api_client.dart';
import 'auth/data/session_store.dart';
import 'auth/presentation/auth_screen.dart';
import 'account_access/presentation/account_activation_screen.dart';
import 'account_access/presentation/account_recovery_screen.dart';
import 'dashboard/data/api_dashboard_repository.dart';
import 'dashboard/presentation/administrator_dashboard.dart';
import 'guardian/data/guardian_portal_api_client.dart';
import 'guardian/presentation/guardian_portal_screen.dart';
import 'platform/data/live_platform_repository.dart';
import 'platform/data/platform_repository.dart';
import 'platform/domain/platform_models.dart';
import 'platform/presentation/platform_admin_shell.dart';
import 'theme/app_theme.dart';
import 'readiness/data/school_readiness_repository.dart';

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

class _SchoolManagementAppState extends State<SchoolManagementApp>
    with WidgetsBindingObserver {
  static const _roleRefreshInterval = Duration(minutes: 5);

  bool _showSchoolAdministrator = false;
  AuthSession? _session;
  final AuthApiClient _authApi = AuthApiClient();
  final SessionStore _sessionStore = SessionStore();
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();
  late final GoRouter _router;
  Future<String?>? _refreshInFlight;
  Timer? _roleRefreshTimer;
  PlatformRepository? _platformRepository;
  Future<AccountManagerSnapshot>? _platformSnapshot;
  AccountManagerSnapshot? _platformSnapshotData;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
        final publicAccountFlow =
            state.matchedLocation.startsWith('/activate/') ||
            state.matchedLocation == '/recover-username' ||
            state.matchedLocation == '/reset-password';
        if (!signedIn && !onLogin && !publicAccountFlow) return '/login';
        if (publicAccountFlow) return null;
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
        if (signedIn && _session != null && _session!.isGuardianRole) {
          if (state.matchedLocation != '/guardian') return '/guardian';
        } else if (signedIn && state.matchedLocation == '/guardian') {
          return _routeForSession(_session);
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
            onForgotUsername: () => _router.go('/recover-username'),
            onForgotPassword: () => _router.go('/reset-password'),
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
              _restartRoleRefreshTimer();
              _router.go(_routeForSession(session));
            },
          ),
        ),
        GoRoute(
          path: '/activate/:token',
          builder: (context, state) {
            final token = state.pathParameters['token'] ?? '';
            return AccountActivationScreen(
              key: ValueKey(token),
              token: token,
              onGoToLogin: () => _router.go('/login'),
            );
          },
        ),
        GoRoute(
          path: '/recover-username',
          builder: (context, state) => AccountRecoveryScreen(
            kind: AccountRecoveryKind.username,
            onBackToLogin: () => _router.go('/login'),
          ),
        ),
        GoRoute(
          path: '/reset-password',
          builder: (context, state) => AccountRecoveryScreen(
            kind: AccountRecoveryKind.password,
            onBackToLogin: () => _router.go('/login'),
          ),
        ),
        GoRoute(
          path: '/school-admin',
          builder: (context, state) => _schoolStaffDashboard(),
        ),
        GoRoute(
          path: '/guardian',
          builder: (context, state) => _guardianPortal(),
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
    _restartRoleRefreshTimer();
  }

  @override
  void dispose() {
    _roleRefreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _session != null) {
      unawaited(_refreshAccessToken());
    }
  }

  void _restartRoleRefreshTimer() {
    _roleRefreshTimer?.cancel();
    if (_session == null) return;
    _roleRefreshTimer = Timer.periodic(_roleRefreshInterval, (_) {
      if (_session != null) unawaited(_refreshAccessToken());
    });
  }

  String _routeForSession(AuthSession? session) {
    if (session == null) return '/login';
    if (session.isGuardianRole) return '/guardian';
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
      repository: ApiDashboardRepository(
        accessToken: session?.accessToken,
        administratorName: session?.displayName ?? '',
        schoolName: session?.schoolName,
        onRefreshAccessToken: _refreshAccessToken,
      ),
      schoolId: session?.customSchoolId,
      schoolName: session?.schoolName,
      userDisplayName: session?.displayName,
      role: session?.role,
      roles: session?.effectiveRoles ?? const [],
      userId: session?.userId,
      accessToken: session?.accessToken,
      onRefreshAccessToken: _refreshAccessToken,
      onLogout: _logout,
      readinessRepository: ApiSchoolReadinessRepository(
        accessToken: session?.accessToken,
        onRefreshAccessToken: _refreshAccessToken,
      ),
    );
  }

  Widget _guardianPortal() {
    final session = _session;
    return GuardianPortalScreen(
      api: GuardianPortalApiClient(
        accessToken: session?.accessToken,
        onRefreshAccessToken: _refreshAccessToken,
      ),
      schoolMemberships: session?.schoolMemberships ?? const [],
      onLogout: _logout,
    );
  }

  void _logout() {
    _roleRefreshTimer?.cancel();
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

  Future<String?> _refreshAccessToken() {
    final current = _refreshInFlight;
    if (current != null) return current;
    final refresh = _refreshAccessTokenInternal();
    _refreshInFlight = refresh;
    refresh.whenComplete(() {
      if (identical(_refreshInFlight, refresh)) _refreshInFlight = null;
    });
    return refresh;
  }

  Future<String?> _refreshAccessTokenInternal() async {
    final refreshToken = _session?.refreshToken;
    if (refreshToken == null ||
        refreshToken.isEmpty ||
        refreshToken == 'preview') {
      return _session?.accessToken;
    }
    try {
      final previousSession = _session!;
      final refreshed = await _authApi.refreshSession(
        refreshToken: refreshToken,
      );
      if (!mounted) return refreshed.accessToken;
      final nextSession = previousSession.mergeRefresh(refreshed);
      if (nextSession.isBlockedFromLogin) {
        _roleRefreshTimer?.cancel();
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
      _notifyIfRolesChanged(previousSession, nextSession);
      return nextSession.accessToken;
    } on AuthException {
      _roleRefreshTimer?.cancel();
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

  void _notifyIfRolesChanged(AuthSession previous, AuthSession next) {
    final previousRoles = previous.effectiveRoles.toSet();
    final nextRoles = next.effectiveRoles.toSet();
    final primaryChanged =
        previous.role.trim().toUpperCase() != next.role.trim().toUpperCase();
    if (setEquals(previousRoles, nextRoles) && !primaryChanged) return;

    final removed = previousRoles.difference(nextRoles);
    final added = nextRoles.difference(previousRoles);
    final detail = removed.isNotEmpty
        ? 'A workspace is no longer available.'
        : added.isNotEmpty
        ? 'A new workspace is now available.'
        : 'Your primary workspace was changed.';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final messenger = _scaffoldMessengerKey.currentState;
      if (messenger == null) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Your access roles were changed by an administrator. $detail',
            ),
          ),
        );
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'SMA Ghana',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      scaffoldMessengerKey: _scaffoldMessengerKey,
      routerConfig: _router,
    );
  }
}
