import 'package:flutter/material.dart';

import 'core/constants.dart';
import 'models/app_user.dart';
import 'services/auth_service.dart';
import 'services/classroom_service.dart';
import 'theme/app_theme.dart';
import 'ui/screens/hod_dashboard.dart';
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
  final AuthService _authService = AuthService();
  final ClassroomService _classroomService = ClassroomService();

  AppUser? _currentUser;
  String? _selectedRole;

  void _onSelectRole(String role) {
    setState(() => _selectedRole = role);
  }

  void _onAuthenticated(AppUser user) {
    setState(() {
      _currentUser = user;
      _selectedRole = null;
    });
  }

  Future<void> _logout() async {
    await _authService.logout();
    setState(() => _currentUser = null);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'E-Gate Pass System',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.classicBlueTheme,
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
        onBack: () => setState(() => _selectedRole = null),
        onAuthenticated: _onAuthenticated,
      );
    }
    return WelcomeScreen(
      key: const ValueKey<String>('welcome'),
      onSelectRole: _onSelectRole,
    );
  }

  Widget _buildDashboard(AppUser user) {
    switch (user.role) {
      case AppRoles.hod:
        return HodDashboard(
          key: const ValueKey<String>('hod_dash'),
          user: user,
          classroomService: _classroomService,
          onLogout: _logout,
        );
      case AppRoles.teacher:
        return TeacherDashboard(
          key: const ValueKey<String>('teacher_dash'),
          user: user,
          classroomService: _classroomService,
          onLogout: _logout,
        );
      case AppRoles.student:
      default:
        return StudentDashboard(
          key: const ValueKey<String>('student_dash'),
          user: user,
          classroomService: _classroomService,
          onLogout: _logout,
        );
    }
  }
}
