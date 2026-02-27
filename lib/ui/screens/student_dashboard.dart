import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../../models/app_user.dart';
import '../../models/classroom.dart';
import '../../models/gate_pass_request.dart';
import '../../services/auth_service.dart';
import '../../services/classroom_service.dart';
import '../../services/gate_pass_service.dart';
import '../widgets/join_class_shortcut_box.dart';
import '../widgets/pass_status_card.dart';
import 'approved_pass_screen.dart';
import 'create_pass_screen.dart';
import 'join_class_screen.dart';
import 'profile_screen.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({
    super.key,
    required this.user,
    required this.authService,
    required this.classroomService,
    required this.gatePassService,
    required this.onLogout,
    required this.isDarkMode,
    required this.onThemeChanged,
    required this.onUserUpdated,
  });

  final AppUser user;
  final AuthService authService;
  final ClassroomService classroomService;
  final GatePassService gatePassService;
  final VoidCallback onLogout;
  final bool isDarkMode;
  final ValueChanged<bool> onThemeChanged;
  final ValueChanged<AppUser> onUserUpdated;

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  bool _loading = true;
  int _tabIndex = 0;
  List<Classroom> _joinedClassrooms = <Classroom>[];
  List<GatePassRequest> _requests = <GatePassRequest>[];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final classrooms = await widget.classroomService
          .fetchClassroomsForStudent(widget.user.id);
      final requests = await widget.gatePassService.fetchStudentRequests(
        widget.user.id,
      );
      if (!mounted) return;
      setState(() {
        _joinedClassrooms = classrooms;
        _requests = requests;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openJoinClassScreen() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => JoinClassScreen(onJoin: _joinUsingCode),
      ),
    );
  }

  Future<bool> _joinUsingCode(String code) async {
    try {
      final room = await widget.classroomService.joinClassroomAsStudent(
        student: widget.user,
        code: code,
      );
      await _loadData();
      if (!mounted) return true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Joined ${room.section} (${room.studentCode})')),
      );
      return true;
    } catch (error) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
      return false;
    }
  }

  Future<void> _openCreatePass() async {
    if (_joinedClassrooms.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Join a class before creating a pass.')),
      );
      return;
    }

    final submitted = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => CreatePassScreen(
          student: widget.user,
          classrooms: _joinedClassrooms,
          gatePassService: widget.gatePassService,
        ),
      ),
    );

    if (submitted == true) {
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Pass request submitted to Class Incharge!'),
        ),
      );
      // Switch to status tab
      setState(() => _tabIndex = 1);
    }
  }

  void _openApprovedPass(GatePassRequest request) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ApprovedPassScreen(request: request),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasClass = _joinedClassrooms.isNotEmpty;
    final activeRequests = _requests
        .where(
          (r) =>
              r.status == RequestStatus.pendingTeacher ||
              r.status == RequestStatus.forwardedToHod,
        )
        .toList();
    final historyRequests = _requests
        .where(
          (r) =>
              r.status == RequestStatus.approved ||
              r.status == RequestStatus.rejectedByTeacher ||
              r.status == RequestStatus.rejectedByHod,
        )
        .toList();

    return Scaffold(
      drawer: Drawer(
        child: ListView(
          children: <Widget>[
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (_profileImageBytes != null)
                    CircleAvatar(
                      radius: 20,
                      backgroundImage: MemoryImage(_profileImageBytes!),
                    )
                  else
                    const Icon(Icons.account_circle, color: Colors.white, size: 40),
                  const SizedBox(height: 8),
                  Text(
                    widget.user.name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold),
                  ),
                  Text(
                    widget.user.department,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard_outlined),
              title: const Text('Dashboard'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text('Refresh'),
              onTap: () {
                Navigator.pop(context);
                _loadData();
              },
            ),
            
          ],
        ),
      ),
      appBar: AppBar(
        title: const Text('Student Dashboard'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Profile',
            onPressed: _openProfile,
            icon: _buildProfileActionIcon(),
          ),
        ],
      ),
      body: SafeArea(
        child: Row(
          children: <Widget>[
            if (!hasClass)
              SizedBox(
                width: 74,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: JoinClassShortcutBox(onTap: _openJoinClassScreen),
                  ),
                ),
              ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadData,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(12, 10, 16, 16),
                  children: <Widget>[
                    _welcomeCard(),
                    const SizedBox(height: 12),

                    // Active pass banner
                    if (activeRequests.isNotEmpty)
                      _activeBanner(activeRequests.first),

                    if (!hasClass)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline,
                                  color: Colors.orange),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Join your class first using the unique code from your Class Incharge.',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Text(
                        '📚 ${_joinedClassrooms.map((c) => c.section).join(', ')}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey.shade600,
                            ),
                      ),

                    const SizedBox(height: 12),

                    // Tab switcher
                    SegmentedButton<int>(
                      segments: <ButtonSegment<int>>[
                        const ButtonSegment<int>(
                          value: 0,
                          label: Text('New Pass'),
                          icon: Icon(Icons.add_card_outlined),
                        ),
                        ButtonSegment<int>(
                          value: 1,
                          label: Text(
                            activeRequests.isEmpty
                                ? 'Status'
                                : 'Status (${activeRequests.length})',
                          ),
                          icon: const Icon(Icons.schedule_outlined),
                        ),
                        ButtonSegment<int>(
                          value: 2,
                          label: Text(
                            historyRequests.isEmpty
                                ? 'History'
                                : 'History (${historyRequests.length})',
                          ),
                          icon: const Icon(Icons.history),
                        ),
                      ],
                      selected: <int>{_tabIndex},
                      onSelectionChanged: (selection) {
                        setState(() => _tabIndex = selection.first);
                      },
                    ),
                    const SizedBox(height: 14),
                    if (_loading)
                      const Center(child: CircularProgressIndicator())
                    else if (_tabIndex == 0)
                      _buildCreateSection(hasClass)
                    else if (_tabIndex == 1)
                      _buildStatusSection(activeRequests)
                    else
                      _buildHistorySection(historyRequests),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _activeBanner(GatePassRequest request) {
    Color bgColor;
    String message;
    if (request.status == RequestStatus.pendingTeacher) {
      bgColor = Colors.orange.shade100;
      message = '⏳ Pass pending Class Incharge approval';
    } else {
      bgColor = Colors.blue.shade100;
      message = '⏳ Pass pending HOD approval';
    }
    return GestureDetector(
      onTap: () => setState(() => _tabIndex = 1),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Icon(Icons.access_time, size: 16),
            const SizedBox(width: 8),
            Expanded(child: Text(message, style: const TextStyle(fontSize: 13))),
            const Icon(Icons.chevron_right, size: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _openProfile() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProfileScreen(
          user: widget.user,
          authService: widget.authService,
          isDarkMode: widget.isDarkMode,
          onUserUpdated: widget.onUserUpdated,
          onThemeChanged: widget.onThemeChanged,
          onLogout: () async => widget.onLogout(),
        ),
      ),
    );
  }

  Uint8List? get _profileImageBytes {
    final encoded = widget.user.profileImageBase64;
    if ((encoded ?? '').isEmpty) {
      return null;
    }
    try {
      return base64Decode(encoded!);
    } catch (_) {
      return null;
    }
  }

  Widget _buildProfileActionIcon() {
    final bytes = _profileImageBytes;
    if (bytes == null) {
      return const Icon(Icons.account_circle_outlined);
    }
    return CircleAvatar(
      radius: 14,
      backgroundImage: MemoryImage(bytes),
    );
  }

  Widget _buildCreateSection(bool hasClass) {
    if (!hasClass) return const SizedBox.shrink();

    return Column(
      children: [
        _actionCard(
          icon: Icons.login_outlined,
          color: Colors.blue,
          title: 'Outing Pass',
          subtitle: 'Evening / Sunday outing within the day',
          onTap: () async {
            if (_joinedClassrooms.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Join a class before creating a pass.')),
              );
              return;
            }
            final submitted = await Navigator.of(context).push<bool>(
              MaterialPageRoute<bool>(
                builder: (_) => CreatePassScreen(
                  student: widget.user,
                  classrooms: _joinedClassrooms,
                  gatePassService: widget.gatePassService,
                  initialPassType: PassType.outing,
                ),
              ),
            );
            if (submitted == true) {
              await _loadData();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content:
                        Text('✅ Pass request submitted to Class Incharge!')),
              );
              setState(() => _tabIndex = 1);
            }
          },
        ),
        const SizedBox(height: 12),
        _actionCard(
          icon: Icons.home_outlined,
          color: Colors.orange,
          title: 'Leave / Native Pass',
          subtitle: 'Going home or native place for holiday',
          onTap: () async {
            if (_joinedClassrooms.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Join a class before creating a pass.')),
              );
              return;
            }
            final submitted = await Navigator.of(context).push<bool>(
              MaterialPageRoute<bool>(
                builder: (_) => CreatePassScreen(
                  student: widget.user,
                  classrooms: _joinedClassrooms,
                  gatePassService: widget.gatePassService,
                  initialPassType: PassType.leave,
                ),
              ),
            );
            if (submitted == true) {
              await _loadData();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content:
                        Text('✅ Leave request submitted to Class Incharge!')),
              );
              setState(() => _tabIndex = 1);
            }
          },
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                const Icon(Icons.route_outlined, color: Colors.grey),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Request flow: You → Class Incharge → HOD → Approved Digital Pass',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.grey.shade600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _actionCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 12)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusSection(List<GatePassRequest> active) {
    if (active.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(Icons.check_circle_outline,
                  color: Colors.green.shade400, size: 48),
              const SizedBox(height: 12),
              const Text(
                'No active pass requests.',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              Text(
                'Create a new pass from the "New Pass" tab.',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: active.map((request) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: PassStatusCard(
            request: request,
            onViewPass: () => _openApprovedPass(request),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildHistorySection(List<GatePassRequest> history) {
    if (history.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(Icons.history_outlined,
                  color: Colors.grey.shade400, size: 48),
              const SizedBox(height: 12),
              const Text('No pass history yet.'),
            ],
          ),
        ),
      );
    }

    return Column(
      children: history.map((request) {
        final isApproved = request.status == RequestStatus.approved;
        final isRejected = request.status == RequestStatus.rejectedByTeacher ||
            request.status == RequestStatus.rejectedByHod;

        Color statusColor =
            isApproved ? Colors.green : (isRejected ? Colors.red : Colors.grey);

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: statusColor.withAlpha(30),
                child: Icon(
                  isApproved
                      ? Icons.check
                      : (isRejected ? Icons.close : Icons.schedule),
                  color: statusColor,
                  size: 18,
                ),
              ),
              title: Text(
                '${request.passType} — ${request.classroomSection}',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                '${DateFormat('dd MMM yyyy').format(request.date)}${request.isLeavePass && request.destination != null ? " → ${request.destination}" : ""}\n${request.status}',
              ),
              isThreeLine: true,
              trailing: const Icon(Icons.chevron_right),
              onTap: isApproved ? () => _openApprovedPass(request) : null,
            ),
          ),
        );
      }).toList(),
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
                    '${widget.user.department}${widget.user.year != null ? " • ${widget.user.year}" : ""}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const Icon(Icons.badge_outlined, size: 30),
          ],
        ),
      ),
    );
  }
}
