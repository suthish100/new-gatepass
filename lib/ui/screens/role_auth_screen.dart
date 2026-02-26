import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../models/app_user.dart';
import '../../services/auth_service.dart';

class RoleAuthScreen extends StatefulWidget {
  const RoleAuthScreen({
    super.key,
    required this.role,
    required this.authService,
    required this.onBack,
    required this.onAuthenticated,
    this.initialYearOrSection,
    this.startInRegisterMode = false,
  });

  final String role;
  final AuthService authService;
  final VoidCallback onBack;
  final ValueChanged<AppUser> onAuthenticated;
  final String? initialYearOrSection;
  final bool startInRegisterMode;

  @override
  State<RoleAuthScreen> createState() => _RoleAuthScreenState();
}

class _RoleAuthScreenState extends State<RoleAuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _isLoginMode = true;
  bool _submitting = false;
  String _department = departments.first;
  String _yearOrSection = classSections.first;
  String _hodType = HodType.firstYear;

  @override
  void initState() {
    super.initState();
    _isLoginMode = !widget.startInRegisterMode;
    final prefill = widget.initialYearOrSection?.trim();
    if ((prefill ?? '').isNotEmpty && classSections.contains(prefill)) {
      _yearOrSection = prefill!;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (!_isLoginMode &&
        _passwordController.text.trim() != _confirmController.text.trim()) {
      _showMessage('Password and confirm password must match.');
      return;
    }

    setState(() => _submitting = true);
    try {
      final AppUser user;
      if (_isLoginMode) {
        user = await widget.authService.loginForRole(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          role: widget.role,
        );
      } else {
        user = await widget.authService.register(
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          role: widget.role,
          department: _department,
          year: widget.role == AppRoles.hod ? null : _yearOrSection,
          hodType: widget.role == AppRoles.hod ? _hodType : null,
          password: _passwordController.text.trim(),
        );
      }
      if (!mounted) {
        return;
      }
      widget.onAuthenticated(user);
    } catch (error) {
      _showMessage(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: widget.onBack,
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text(_isLoginMode ? 'Login' : 'Register'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          '${roleDisplayName(widget.role)} Access',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Use your role account to continue.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 18),
                        _modeSwitch(),
                        const SizedBox(height: 16),
                        if (!_isLoginMode) ...<Widget>[
                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Name',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            validator: _required,
                          ),
                          const SizedBox(height: 12),
                        ],
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                          validator: _required,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Password',
                            prefixIcon: Icon(Icons.lock_outline),
                          ),
                          validator: _required,
                        ),
                        if (!_isLoginMode) ...<Widget>[
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _confirmController,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'Confirm Password',
                              prefixIcon: Icon(Icons.lock_reset_outlined),
                            ),
                            validator: _required,
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: _department,
                            decoration: const InputDecoration(
                              labelText: 'Department',
                              prefixIcon: Icon(Icons.school_outlined),
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
                              setState(() => _department = value);
                            },
                          ),
                          if (widget.role == AppRoles.hod) ...<Widget>[
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              value: _hodType,
                              decoration: const InputDecoration(
                                labelText: 'HOD Type',
                                prefixIcon: Icon(Icons.badge_outlined),
                              ),
                              items: HodType.all.map((type) {
                                return DropdownMenuItem<String>(
                                  value: type,
                                  child: Text(type),
                                );
                              }).toList(),
                              onChanged: (value) {
                                if (value == null) {
                                  return;
                                }
                                setState(() => _hodType = value);
                              },
                            ),
                          ],
                          if (widget.role != AppRoles.hod) ...<Widget>[
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              value: _yearOrSection,
                              decoration: InputDecoration(
                                labelText: widget.role == AppRoles.teacher
                                    ? 'Class Section'
                                    : 'Year',
                                prefixIcon: const Icon(Icons.class_outlined),
                              ),
                              items: classSections.map((section) {
                                return DropdownMenuItem<String>(
                                  value: section,
                                  child: Text(section),
                                );
                              }).toList(),
                              onChanged: (value) {
                                if (value == null) {
                                  return;
                                }
                                setState(() => _yearOrSection = value);
                              },
                            ),
                          ],
                        ],
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _submitting ? null : _submit,
                            child: Text(
                              _submitting
                                  ? 'Please wait...'
                                  : (_isLoginMode ? 'Login' : 'Create Account'),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_isLoginMode)
                          Text(
                            'Demo: hod@egatepass.com, teacher@egatepass.com, student@egatepass.com (password: 123456)',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _modeSwitch() {
    return Row(
      children: <Widget>[
        Expanded(
          child: ChoiceChip(
            label: const Text('Login'),
            selected: _isLoginMode,
            onSelected: (_) => setState(() => _isLoginMode = true),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ChoiceChip(
            label: const Text('Register'),
            selected: !_isLoginMode,
            onSelected: (_) => setState(() => _isLoginMode = false),
          ),
        ),
      ],
    );
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Required';
    }
    return null;
  }
}
