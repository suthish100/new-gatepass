import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../services/firebase_bootstrap.dart';
import '../../services/gate_pass_service.dart';
import 'scan_pass_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({
    super.key,
    required this.onSelectRole,
    required this.gatePassService,
  });

  final ValueChanged<String> onSelectRole;
  final GatePassService gatePassService;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 28,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFEFF1),
                  borderRadius: BorderRadius.circular(38),
                  border: Border.all(color: const Color(0xFF282449), width: 8),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (!FirebaseBootstrap.isReady) ...<Widget>[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFE5E5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE56E6E)),
                        ),
                        child: Text(
                          'Firebase not connected. App is running in local mode.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: const Color(0xFF8D2222),
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    const SizedBox(height: 66),
                    const Icon(
                      Icons.change_history_rounded,
                      size: 78,
                      color: Color(0xFF2C93F5),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      'E-Gate Pass System',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        fontSize: 36,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'AI & DS Department Presents',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: const Color(0xFF71767D),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 36),
                    _RoleButton(
                      label: 'Student',
                      onPressed: () => onSelectRole(AppRoles.student),
                    ),
                    const SizedBox(height: 16),
                    _RoleButton(
                      label: 'Class Incharge',
                      onPressed: () => onSelectRole(AppRoles.teacher),
                    ),
                    const SizedBox(height: 16),
                    _RoleButton(
                      label: 'HOD',
                      onPressed: () => onSelectRole(AppRoles.hod),
                    ),
                    const SizedBox(height: 28),
                    const Divider(),
                    const SizedBox(height: 12),
                    // Security Gate access — no login required
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.qr_code_scanner),
                        label: const Text('Security Gate Verification'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: const StadiumBorder(),
                          side: const BorderSide(color: Color(0xFF1B84F2)),
                          foregroundColor: const Color(0xFF1B84F2),
                        ),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => ScanPassScreen(
                                gatePassService: gatePassService,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleButton extends StatelessWidget {
  const _RoleButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 15),
          backgroundColor: const Color(0xFF1B84F2),
          shape: const StadiumBorder(),
        ),
        child: Text(label),
      ),
    );
  }
}
