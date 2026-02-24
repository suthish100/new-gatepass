import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../../models/app_user.dart';
import '../../models/staff_invite.dart';
import '../../services/classroom_service.dart';

class HodDashboard extends StatefulWidget {
  const HodDashboard({
    super.key,
    required this.user,
    required this.classroomService,
    required this.onLogout,
  });

  final AppUser user;
  final ClassroomService classroomService;
  final VoidCallback onLogout;

  @override
  State<HodDashboard> createState() => _HodDashboardState();
}

class _HodDashboardState extends State<HodDashboard> {
  bool _loading = true;
  List<StaffInvite> _invites = <StaffInvite>[];

  @override
  void initState() {
    super.initState();
    _loadInvites();
  }

  Future<void> _loadInvites() async {
    setState(() => _loading = true);
    try {
      _invites = await widget.classroomService.fetchInvitesForHod(
        widget.user.id,
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _openAddStaffDialog(String section) async {
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Add Staff - $section'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              hintText: 'Enter staff email',
              prefixIcon: Icon(Icons.email_outlined),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final email = controller.text.trim();
                if (email.isEmpty) {
                  return;
                }
                Navigator.pop(context);
                await _sendInvite(section: section, email: email);
              },
              child: const Text('Send Invite'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _sendInvite({
    required String section,
    required String email,
  }) async {
    try {
      final invite = await widget.classroomService.sendStaffInvitation(
        hodId: widget.user.id,
        section: section,
        staffEmail: email,
      );
      await _loadInvites();
      if (!mounted) {
        return;
      }
      await Clipboard.setData(ClipboardData(text: invite.inviteLink));
      if (!mounted) {
        return;
      }
      showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Invitation Link Created'),
            content: SelectableText(
              'Invitation link copied.\n\n${invite.inviteLink}',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('home'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Logout',
            onPressed: widget.onLogout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadInvites,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            children: <Widget>[
              _welcomeCard(),
              const SizedBox(height: 14),
              Text(
                'Predefined Class Sections',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              ...classSections.map((section) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _sectionCard(section),
                );
              }),
              const SizedBox(height: 14),
              Text(
                'Sent Invitations',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              Card(
                child: _loading
                    ? const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : _invites.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(18),
                        child: Text('No invitation sent yet.'),
                      )
                    : ListView.separated(
                        itemCount: _invites.length,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final invite = _invites[index];
                          return ListTile(
                            title: Text(invite.staffEmail),
                            subtitle: Text(
                              '${invite.section} • ${DateFormat('dd MMM, hh:mm a').format(invite.createdAt)}',
                            ),
                            trailing: IconButton(
                              tooltip: 'Copy link',
                              onPressed: () async {
                                await Clipboard.setData(
                                  ClipboardData(text: invite.inviteLink),
                                );
                                if (!context.mounted) {
                                  return;
                                }
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Invitation link copied'),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.link),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _welcomeCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Welcome, ${widget.user.name}!',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'HOD control panel ready',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF2DAF64),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.check_circle_outline,
              color: Color(0xFF2DAF64),
              size: 34,
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard(String section) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(section, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 3),
                  Text(
                    'Invite class incharge by email',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => _openAddStaffDialog(section),
              icon: const Icon(Icons.person_add_alt_1, size: 18),
              label: const Text('Add Staff'),
            ),
          ],
        ),
      ),
    );
  }
}
