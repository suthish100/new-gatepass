import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'core/constants.dart';
import 'models/app_user.dart';
import 'services/auth_service.dart';
import 'services/classroom_service.dart';
import 'services/delegation_service.dart';
import 'services/gate_pass_service.dart';
import 'theme/app_theme.dart';
import 'ui/screens/hod_dashboard.dart';
import 'ui/screens/join_class_screen.dart';
import 'ui/screens/role_auth_screen.dart';
import 'ui/screens/staff_dashboard.dart';
import 'ui/screens/student_dashboard.dart';
import 'ui/screens/welcome_screen.dart';

class GatePassApp extends StatefulWidget {
  const GatePassApp({super.key});

  @override
  State<GatePassApp> createState() => _GatePassAppState();
}

class _GatePassAppState extends State<GatePassApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final AuthService _authService = AuthService();
  final ClassroomService _classroomService = ClassroomService();
  final DelegationService _delegationService = DelegationService();
  late final GatePassService _gatePassService = GatePassService(
    delegationService: _delegationService,
  );

  AppLinks? _appLinks;
  StreamSubscription<Uri>? _deepLinkSub;

  AppUser? _currentUser;
  String? _selectedRole;
  String? _pendingJoinCode;
  String? _prefillYearOrSection;
  bool _authStartInRegisterMode = false;
  int _dashboardVersion = 0;
  bool _joinFlowOpen = false;
  bool _joinFlowScheduled = false;
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  @override
  void dispose() {
    _deepLinkSub?.cancel();
    super.dispose();
  }

  Future<void> _initDeepLinks() async {
    if (kIsWeb) {
      _captureJoinCodeFromUri(Uri.base);
      return;
    }

    _appLinks = AppLinks();
    try {
      final initialUri = await _appLinks!.getInitialLink();
      _captureJoinCodeFromUri(initialUri);
    } catch (error) {
      debugPrint('Failed to read initial deep link: $error');
    }

    _deepLinkSub = _appLinks!.uriLinkStream.listen(
      _captureJoinCodeFromUri,
      onError: (Object error) {
        debugPrint('Deep link stream error: $error');
      },
    );
  }

  void _captureJoinCodeFromUri(Uri? uri) {
    if (uri == null) {
      return;
    }

    final inviteRole = _extractInviteRole(uri);
    if (inviteRole != null) {
      final section = _extractInviteSection(uri);
      if (_currentUser != null) {
        _showSnackBar('Logout first to accept invite as $inviteRole.');
        return;
      }
      debugPrint('Staff invite link received: $uri');
      setState(() {
        _selectedRole = inviteRole;
        _prefillYearOrSection = section;
        _authStartInRegisterMode = true;
      });
      return;
    }

    final code = _extractJoinCode(uri);
    if (code == null) {
      return;
    }

    debugPrint('Invite link received: $uri');
    setState(() => _pendingJoinCode = code);
    _scheduleJoinScreenFromLink();
  }

  String? _extractJoinCode(Uri uri) {
    final isJoinPath =
        uri.path.toLowerCase().contains('/join') ||
        uri.fragment.toLowerCase().contains('/join') ||
        (uri.scheme.toLowerCase() == 'egatepass' &&
            uri.host.toLowerCase() == 'join');
    if (!isJoinPath) {
      return null;
    }

    String? code = uri.queryParameters['code'];
    if ((code ?? '').trim().isEmpty && uri.fragment.contains('?')) {
      final queryPart = uri.fragment.split('?').skip(1).join('?');
      if (queryPart.isNotEmpty) {
        code = Uri.splitQueryString(queryPart)['code'];
      }
    }

    final normalizedCode = code?.trim().toUpperCase();
    if ((normalizedCode ?? '').isEmpty) {
      return null;
    }
    return normalizedCode;
  }

  String? _extractInviteRole(Uri uri) {
    final isInvitePath =
        uri.path.toLowerCase().contains('/invite') ||
        uri.fragment.toLowerCase().contains('/invite') ||
        (uri.scheme.toLowerCase() == 'egatepass' &&
            uri.host.toLowerCase() == 'invite');
    if (!isInvitePath) {
      return null;
    }

    String? role = uri.queryParameters['role'];
    if ((role ?? '').trim().isEmpty && uri.fragment.contains('?')) {
      final queryPart = uri.fragment.split('?').skip(1).join('?');
      if (queryPart.isNotEmpty) {
        role = Uri.splitQueryString(queryPart)['role'];
      }
    }

    final normalized = role?.trim().toLowerCase();
    if (normalized == AppRoles.teacher.toLowerCase()) {
      return AppRoles.teacher;
    }
    if (normalized == AppRoles.student.toLowerCase()) {
      return AppRoles.student;
    }
    return null;
  }

  String? _extractInviteSection(Uri uri) {
    String? section = uri.queryParameters['section'];
    if ((section ?? '').trim().isEmpty && uri.fragment.contains('?')) {
      final queryPart = uri.fragment.split('?').skip(1).join('?');
      if (queryPart.isNotEmpty) {
        section = Uri.splitQueryString(queryPart)['section'];
      }
    }

    final normalized = section?.trim();
    final isKnownSection =
        classSections.contains(normalized) || classYears.contains(normalized);
    if ((normalized ?? '').isEmpty || !isKnownSection) {
      return null;
    }
    return normalized;
  }

  void _onSelectRole(String role) {
    setState(() {
      _selectedRole = role;
      _prefillYearOrSection = null;
      _authStartInRegisterMode = false;
    });
  }

  void _onAuthenticated(AppUser user) {
    setState(() {
      _currentUser = user;
      _selectedRole = null;
      _prefillYearOrSection = null;
      _authStartInRegisterMode = false;
      _isDarkMode = user.themeMode == 'dark';
    });
    _scheduleJoinScreenFromLink();
  }

  void _onUserUpdated(AppUser user) {
    setState(() => _currentUser = user);
  }

  void _onThemeChanged(bool isDarkMode) {
    setState(() => _isDarkMode = isDarkMode);
  }

  Future<void> _logout() async {
    await _authService.logout();
    setState(() => _currentUser = null);
  }

  void _scheduleJoinScreenFromLink() {
    if (_joinFlowOpen ||
        _joinFlowScheduled ||
        _pendingJoinCode == null ||
        _currentUser == null) {
      return;
    }
    _joinFlowScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _joinFlowScheduled = false;
      _openPendingJoinIfPossible();
    });
  }

  Future<void> _openPendingJoinIfPossible() async {
    if (!mounted ||
        _joinFlowOpen ||
        _pendingJoinCode == null ||
        _currentUser == null) {
      return;
    }

    final navigator = _navigatorKey.currentState;
    if (navigator == null) {
      return;
    }

    final code = _pendingJoinCode!;
    _pendingJoinCode = null;
    setState(() => _joinFlowOpen = true);
    await navigator.push(
      MaterialPageRoute<void>(
        builder: (_) =>
            JoinClassScreen(initialCode: code, onJoin: _joinUsingInviteCode),
      ),
    );
    if (!mounted) {
      return;
    }
    setState(() => _joinFlowOpen = false);
    _scheduleJoinScreenFromLink();
  }

  Future<bool> _joinUsingInviteCode(String code) async {
    final user = _currentUser;
    if (user == null) {
      _showSnackBar('Please login to join class.');
      return false;
    }

    try {
      final room = await _classroomService.joinClassroom(
        student: user,
        code: code,
      );
      if (!mounted) {
        return true;
      }
      final joinedCode = user.role == AppRoles.teacher
          ? room.staffCode
          : (room.studentCode.isEmpty ? room.code : room.studentCode);
      setState(() => _dashboardVersion++);
      _showSnackBar('Joined ${room.section} ($joinedCode)');
      return true;
    } catch (error) {
      _showSnackBar(error.toString());
      return false;
    }
  }

  void _showSnackBar(String message) {
    final currentContext = _navigatorKey.currentContext;
    if (currentContext == null) {
      return;
    }
    ScaffoldMessenger.of(
      currentContext,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'E-Gate Pass System',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.classicBlueTheme,
      darkTheme: AppTheme.classicDarkTheme,
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        child: _buildCurrentPage(),
      ),
    );
  }

  Widget _buildCurrentPage() {
    if (_currentUser != null) {
      return _buildDashboard(_currentUser!);
    }
    if (_selectedRole != null) {
      return RoleAuthScreen(
        key: ValueKey<String>('auth_${_selectedRole!}'),
        role: _selectedRole!,
        authService: _authService,
        initialYearOrSection: _prefillYearOrSection,
        startInRegisterMode: _authStartInRegisterMode,
        onBack: () {
          setState(() {
            _selectedRole = null;
            _prefillYearOrSection = null;
            _authStartInRegisterMode = false;
          });
        },
        onAuthenticated: _onAuthenticated,
      );
    }
    return WelcomeScreen(
      key: const ValueKey<String>('welcome'),
      onSelectRole: _onSelectRole,
      gatePassService: _gatePassService,
    );
  }

  Widget _buildDashboard(AppUser user) {
    switch (user.role) {
      case AppRoles.hod:
        return HodDashboard(
          key: ValueKey<String>('hod_dash_$_dashboardVersion'),
          user: user,
          classroomService: _classroomService,
          authService: _authService,
          delegationService: _delegationService,
          gatePassService: _gatePassService,
          onLogout: _logout,
          isDarkMode: _isDarkMode,
          onThemeChanged: _onThemeChanged,
          onUserUpdated: _onUserUpdated,
        );
      case AppRoles.teacher:
        return TeacherDashboard(
          key: ValueKey<String>('teacher_dash_$_dashboardVersion'),
          user: user,
          authService: _authService,
          classroomService: _classroomService,
          gatePassService: _gatePassService,
          onLogout: _logout,
          isDarkMode: _isDarkMode,
          onThemeChanged: _onThemeChanged,
          onUserUpdated: _onUserUpdated,
        );
      case AppRoles.student:
      default:
        return StudentDashboard(
          key: ValueKey<String>('student_dash_$_dashboardVersion'),
          user: user,
          authService: _authService,
          classroomService: _classroomService,
          gatePassService: _gatePassService,
          onLogout: _logout,
          isDarkMode: _isDarkMode,
          onThemeChanged: _onThemeChanged,
          onUserUpdated: _onUserUpdated,
        );
    }
  }
}
