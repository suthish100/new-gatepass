import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants.dart';
import '../../models/app_user.dart';
import '../../models/classroom.dart';
import '../../models/classroom_member.dart';
import '../../models/gate_pass_request.dart';
import '../../services/auth_service.dart';
import '../../services/classroom_service.dart';
import '../../services/gate_pass_service.dart';
import '../widgets/join_class_shortcut_box.dart';
import 'join_class_screen.dart';
import 'profile_screen.dart';
import 'request_detail_screen.dart';

class TeacherDashboard extends StatefulWidget {
  const TeacherDashboard({
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
  State<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends State<TeacherDashboard> {
  bool _loading = true;
  List<Classroom> _classrooms = <Classroom>[];
  List<GatePassRequest> _requests = <GatePassRequest>[];
  final Map<String, List<ClassroomMember>> _membersByClassroom =
      <String, List<ClassroomMember>>{};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final classrooms = await widget.classroomService
          .fetchClassroomsForTeacher(widget.user.id);
      final requests = await widget.gatePassService.fetchTeacherActionableRequests(
        teacher: widget.user,
      );

      _membersByClassroom.clear();
      for (final room in classrooms) {
        _membersByClassroom[room.id] = await widget.classroomService
            .fetchStudentsForClassroom(room.id);
      }

      if (!mounted) {
        return;
      }
      setState(() {
        _classrooms = classrooms;
        _requests = requests;
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
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
      final room = await widget.classroomService.joinClassroomAsStaff(
        staff: widget.user,
        code: code,
      );
      await _loadData();
      if (!mounted) {
        return true;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Joined ${room.section}. Student code ready.')),
      );
      return true;
    } catch (error) {
      if (!mounted) {
        return false;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
      return false;
    }
  }

  Future<void> _reviewRequest({
    required GatePassRequest request,
    required bool approve,
  }) async {
    final reasonController = TextEditingController();
    String? reason;

    if (!approve) {
      final result = await showDialog<String>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Reject Request'),
            content: TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Reason (optional)'),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, reasonController.text),
                child: const Text('Reject'),
              ),
            ],
          );
        },
      );
      if (!mounted || result == null) {
        return;
      }
      reason = result;
    }

    try {
      await widget.gatePassService.teacherAction(
        request: request,
        teacher: widget.user,
        approve: approve,
        cancelReason: reason,
      );
      await _loadData();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approve
                ? 'Request forwarded to HOD.'
                : 'Request rejected and student notified.',
          ),
        ),
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

  Future<void> _openRequestDetails({
    required GatePassRequest request,
    required bool allowActions,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RequestDetailScreen(
          request: request,
          onApprove: allowActions
              ? () async {
                  await _reviewRequest(request: request, approve: true);
                }
              : null,
          onReject: allowActions
              ? () async {
                  await _reviewRequest(request: request, approve: false);
                }
              : null,
        ),
      ),
    );
  }

  Future<void> _inviteStudent(Classroom room) async {
    final emailController = TextEditingController();

    final sent = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Student'),
          content: TextField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Student Email'),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Send'),
            ),
          ],
        );
      },
    );

    if (sent != true) {
      return;
    }

    try {
      await widget.classroomService.sendStudentInvitation(
        classroom: room,
        studentEmail: emailController.text,
      );
      if (!mounted) {
        return;
      }

      final emailUri = Uri(
        scheme: 'mailto',
        path: emailController.text,
        queryParameters: <String, String>{
          'subject': 'Class Joining Invitation - ${room.section}',
          'body':
              'You are invited to join ${room.section}.\n\nUse this class code to join:\n${room.studentCode}\n\nOr use this link:\n${room.inviteLink}',
        },
      );

      final launched = await launchUrl(
        emailUri,
        mode: LaunchMode.externalApplication,
      );

      await Clipboard.setData(ClipboardData(text: room.studentCode));
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            launched
                ? 'Email compose opened. Student code copied.'
                : 'Unable to open email app. Student code copied.',
          ),
        ),
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
    final canJoin = _classrooms.isEmpty;
    final pending = _requests
        .where((request) => request.status == RequestStatus.pendingTeacher)
        .toList();
    final history = _requests
        .where((request) => request.status != RequestStatus.pendingTeacher)
        .toList();

    return Scaffold(
      drawer: Drawer(
        child: ListView(
          children: <Widget>[
            const DrawerHeader(child: Text('Class Incharge Navigation')),
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
        title: const Text('Class Incharge Dashboard'),
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
            if (canJoin)
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
                  padding: const EdgeInsets.fromLTRB(10, 10, 16, 16),
                  children: <Widget>[
                    _welcomeCard(canJoin: canJoin),
                    const SizedBox(height: 12),
                    _buildPendingSection(pending),
                    const SizedBox(height: 12),
                    _buildHistorySection(history),
                    const SizedBox(height: 12),
                    Text(
                      'Assigned Classes',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    if (_loading)
                      const Center(child: CircularProgressIndicator())
                    else if (_classrooms.isEmpty)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'No class assigned yet. Use HOD unique staff code.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      )
                    else
                      ..._classrooms.map((room) {
                        final members =
                            _membersByClassroom[room.id] ?? <ClassroomMember>[];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _classroomCard(room: room, members: members),
                        );
                      }),
                  ],
                ),
              ),
            ),
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

  Widget _buildPendingSection(List<GatePassRequest> pending) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Pass Requests Pending',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (pending.isEmpty)
              const Text('No pending pass requests.')
            else
              ...pending.map((request) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${request.studentName} - ${request.passType}'),
                    subtitle: Text(
                      '${request.classroomSection}\n${DateFormat('dd MMM').format(request.date)} | ${request.outTime} - ${request.inTime}'
                      '${request.teacherId != widget.user.id ? '\nDelegated approval access' : ''}',
                    ),
                    isThreeLine: true,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _openRequestDetails(
                      request: request,
                      allowActions: true,
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _welcomeCard({required bool canJoin}) {
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
                    canJoin
                        ? 'Use join class once. It will be hidden after joining.'
                        : 'Class joined. Share student code/link with your class.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const Icon(Icons.school_outlined, size: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildHistorySection(List<GatePassRequest> history) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Pass History',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (history.isEmpty)
              const Text('No pass history available yet.')
            else
              ...history.map((request) {
                final status = request.status;
                Color color = Colors.orange;
                IconData icon = Icons.forward_to_inbox_outlined;
                if (status == RequestStatus.approved) {
                  color = Colors.green;
                  icon = Icons.check_circle;
                } else if (status == RequestStatus.rejectedByTeacher ||
                    status == RequestStatus.rejectedByHod) {
                  color = Colors.red;
                  icon = Icons.cancel;
                }
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(icon, color: color),
                  title: Text('${request.studentName} - ${request.passType}'),
                  subtitle: Text(
                    '${request.classroomSection}\n${DateFormat('dd MMM yyyy').format(request.date)} | $status',
                  ),
                  isThreeLine: true,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openRequestDetails(
                    request: request,
                    allowActions: false,
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _classroomCard({
    required Classroom room,
    required List<ClassroomMember> members,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    room.section,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  DateFormat('dd MMM').format(room.createdAt),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Student Code: ${room.studentCode}'),
            const SizedBox(height: 8),
            const Text('Student Code QR:'),
            QrImageView(data: room.studentCode, size: 100),
            if (room.inviteLink.isNotEmpty) ...<Widget>[
              const SizedBox(height: 6),
              SelectableText(room.inviteLink),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed: () => _inviteStudent(room),
                  icon: const Icon(Icons.person_add),
                  label: const Text('Add Student'),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    await Clipboard.setData(
                      ClipboardData(text: room.studentCode),
                    );
                    if (!mounted) {
                      return;
                    }
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Student code copied')),
                    );
                  },
                  icon: const Icon(Icons.pin_outlined),
                  label: const Text('Copy Student Code'),
                ),
                if (room.inviteLink.isNotEmpty)
                  OutlinedButton.icon(
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      await Clipboard.setData(
                        ClipboardData(text: room.inviteLink),
                      );
                      if (!mounted) {
                        return;
                      }
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Invitation link copied')),
                      );
                    },
                    icon: const Icon(Icons.link),
                    label: const Text('Copy Link'),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text('Students Joined: ${members.length}'),
          ],
        ),
      ),
    );
  }
}
