import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../models/app_user.dart';
import '../../services/auth_service.dart';
import '../widgets/glass_card.dart';
import '../widgets/neon_background.dart';
import '../widgets/neon_button.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    required this.authService,
    required this.onAuthenticated,
  });

  final AuthService authService;
  final ValueChanged<AppUser> onAuthenticated;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _loginFormKey = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();

  final TextEditingController _loginEmailController = TextEditingController();
  final TextEditingController _loginPasswordController =
      TextEditingController();

  final TextEditingController _registerNameController = TextEditingController();
  final TextEditingController _registerEmailController =
      TextEditingController();
  final TextEditingController _registerPasswordController =
      TextEditingController();
  final TextEditingController _registerConfirmPasswordController =
      TextEditingController();

  bool _isLogin = true;
  bool _submitting = false;
  String _selectedRole = AppRoles.student;
  String _selectedDepartment = departments.first;
  String _selectedYear = classYears.first;

  @override
  void dispose() {
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _registerNameController.dispose();
    _registerEmailController.dispose();
    _registerPasswordController.dispose();
    _registerConfirmPasswordController.dispose();
    super.dispose();
  }

  bool get _yearRequired => _selectedRole != AppRoles.hod;

  Future<void> _handleLogin() async {
    if (!_loginFormKey.currentState!.validate()) {
      return;
    }

    setState(() => _submitting = true);
    try {
      final user = await widget.authService.login(
        email: _loginEmailController.text,
        password: _loginPasswordController.text,
      );
      widget.onAuthenticated(user);
    } catch (error) {
      _showError(error.toString());
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _handleRegister() async {
    if (!_registerFormKey.currentState!.validate()) {
      return;
    }

    if (_registerPasswordController.text !=
        _registerConfirmPasswordController.text) {
      _showError('Password and confirm password do not match.');
      return;
    }

    setState(() => _submitting = true);
    try {
      final user = await widget.authService.register(
        name: _registerNameController.text,
        email: _registerEmailController.text,
        role: _selectedRole,
        department: _selectedDepartment,
        year: _yearRequired ? _selectedYear : null,
        password: _registerPasswordController.text,
      );
      widget.onAuthenticated(user);
    } catch (error) {
      _showError(error.toString());
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message.replaceFirst('Exception: ', ''))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return NeonBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'College Gate Pass',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Modern role-based app UI • Flutter + Firebase',
                        style: TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 18),
                      _ModeSwitcher(
                        isLogin: _isLogin,
                        onChanged: (value) {
                          setState(() => _isLogin = value);
                        },
                      ),
                      const SizedBox(height: 18),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 260),
                        child: _isLogin
                            ? _buildLoginForm()
                            : _buildRegisterForm(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return Form(
      key: _loginFormKey,
      child: Column(
        key: const ValueKey<String>('login_form'),
        children: <Widget>[
          TextFormField(
            controller: _loginEmailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: _requiredValidator,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _loginPasswordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Password',
              prefixIcon: Icon(Icons.lock_outline),
            ),
            validator: _requiredValidator,
          ),
          const SizedBox(height: 16),
          NeonButton(
            label: _submitting ? 'Signing In...' : 'Login',
            icon: Icons.login,
            onPressed: _submitting ? null : _handleLogin,
          ),
          const SizedBox(height: 10),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Login: HOD/Staff/Student -> Email + Password',
              style: TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterForm() {
    return Form(
      key: _registerFormKey,
      child: Column(
        key: const ValueKey<String>('register_form'),
        children: <Widget>[
          TextFormField(
            controller: _registerNameController,
            decoration: const InputDecoration(
              labelText: 'Name',
              prefixIcon: Icon(Icons.person_outline),
            ),
            validator: _requiredValidator,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _registerEmailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: _requiredValidator,
          ),
          const SizedBox(height: 14),
          _RoleSelector(
            selectedRole: _selectedRole,
            onRoleSelected: (role) {
              setState(() => _selectedRole = role);
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _selectedDepartment,
            decoration: const InputDecoration(
              labelText: 'Department',
              prefixIcon: Icon(Icons.apartment_outlined),
            ),
            items: departments.map((department) {
              return DropdownMenuItem<String>(
                value: department,
                child: Text(department),
              );
            }).toList(),
            onChanged: (value) {
              if (value == null) {
                return;
              }
              setState(() => _selectedDepartment = value);
            },
          ),
          if (_yearRequired) ...<Widget>[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedYear,
              decoration: const InputDecoration(
                labelText: 'Class / Year',
                prefixIcon: Icon(Icons.class_outlined),
              ),
              items: classYears.map((year) {
                return DropdownMenuItem<String>(value: year, child: Text(year));
              }).toList(),
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() => _selectedYear = value);
              },
            ),
          ],
          const SizedBox(height: 12),
          TextFormField(
            controller: _registerPasswordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Password',
              prefixIcon: Icon(Icons.lock_outline),
            ),
            validator: _requiredValidator,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _registerConfirmPasswordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Confirm Password',
              prefixIcon: Icon(Icons.lock_reset_outlined),
            ),
            validator: _requiredValidator,
          ),
          const SizedBox(height: 16),
          NeonButton(
            label: _submitting ? 'Creating Account...' : 'Register',
            icon: Icons.app_registration,
            onPressed: _submitting ? null : _handleRegister,
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _registerHint,
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'This field is required';
    }
    return null;
  }

  String get _registerHint {
    switch (_selectedRole) {
      case AppRoles.hod:
        return 'HOD registration: Name, Email, Role, Department, Password, Confirm Password';
      case AppRoles.staff:
        return 'Staff registration: Name, Email, Role, Department, Year, Password, Confirm Password';
      default:
        return 'Student registration: Name, Email, Role, Department, Year, Password, Confirm Password';
    }
  }
}

class _ModeSwitcher extends StatelessWidget {
  const _ModeSwitcher({required this.isLogin, required this.onChanged});

  final bool isLogin;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _ModeButton(
            label: 'Login',
            selected: isLogin,
            onTap: () => onChanged(true),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ModeButton(
            label: 'Register',
            selected: !isLogin,
            onTap: () => onChanged(false),
          ),
        ),
      ],
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: selected
            ? const LinearGradient(
                colors: <Color>[Color(0xFF2D7BFF), Color(0xFF16F5C6)],
              )
            : null,
        color: selected ? null : Colors.white.withValues(alpha: 0.10),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleSelector extends StatelessWidget {
  const _RoleSelector({
    required this.selectedRole,
    required this.onRoleSelected,
  });

  final String selectedRole;
  final ValueChanged<String> onRoleSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Align(
          alignment: Alignment.centerLeft,
          child: Text('Role', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: AppRoles.all.map((role) {
            final selected = selectedRole == role;
            return ChoiceChip(
              label: Text(role),
              selected: selected,
              onSelected: (_) => onRoleSelected(role),
              selectedColor: const Color(0xFF2D7BFF).withValues(alpha: 0.45),
              backgroundColor: Colors.white.withValues(alpha: 0.09),
              labelStyle: TextStyle(
                color: selected ? Colors.white : Colors.white70,
                fontWeight: FontWeight.w700,
              ),
              side: BorderSide(
                color: selected
                    ? const Color(0xFF16F5C6)
                    : Colors.white.withValues(alpha: 0.20),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
