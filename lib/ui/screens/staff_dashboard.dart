import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../../models/app_user.dart';
import '../../models/classroom.dart';
import '../../models/classroom_member.dart';
import '../../services/classroom_service.dart';

class TeacherDashboard extends StatefulWidget {
  const TeacherDashboard({
    super.key,
    required this.user,
    required this.classroomService,
    required this.onLogout,
  });

  final AppUser user;
  final ClassroomService classroomService;
  final VoidCallback onLogout;

  @override
  State<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends State<TeacherDashboard> {
  bool _loading = true;
  List<Classroom> _classrooms = <Classroom>[];
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
      _classrooms = await widget.classroomService.fetchClassroomsForTeacher(
        widget.user.id,
      );

      _membersByClassroom.clear();
      for (final room in _classrooms) {
        _membersByClassroom[room.id] = await widget.classroomService
            .fetchStudentsForClassroom(room.id);
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _createClassroomFlow() async {
    String selectedSection = classSections.first;
    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Create Class Room'),
              content: DropdownButtonFormField<String>(
                value: selectedSection,
                decoration: const InputDecoration(
                  labelText: 'Section',
                  prefixIcon: Icon(Icons.class_outlined),
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
                  setDialogState(() => selectedSection = value);
                },
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await _createClassroom(selectedSection);
                  },
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _createClassroom(String section) async {
    try {
      final room = await widget.classroomService.createClassroom(
        section: section,
        teacher: widget.user,
      );
      await _loadData();
      if (!mounted) {
        return;
      }
      await Clipboard.setData(ClipboardData(text: room.inviteLink));
      if (!mounted) {
        return;
      }
      showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Class Room Created'),
            content: SelectableText(
              'Unique code: ${room.code}\n\nInvitation link copied.\n${room.inviteLink}',
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
          onRefresh: _loadData,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            children: <Widget>[
              _welcomeCard(),
              const SizedBox(height: 14),
              _createClassroomCard(),
              const SizedBox(height: 14),
              Text(
                'My Class Rooms',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              if (_loading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(22),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_classrooms.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'No classroom yet. Tap the + to create one.',
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
                    'Class incharge dashboard',
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

  Widget _createClassroomCard() {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: _createClassroomFlow,
        child: Container(
          height: 350,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: const Color(0xFFD1E4FB),
          ),
          child: Center(
            child: Container(
              width: 180,
              height: 180,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFA5C9F1),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(Icons.add, size: 56, color: Color(0xFF47678D)),
                  SizedBox(height: 8),
                  Text(
                    'create class',
                    style: TextStyle(
                      color: Color(0xFF203A5E),
                      fontWeight: FontWeight.w800,
                      fontSize: 23,
                    ),
                  ),
                ],
              ),
            ),
          ),
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
            SelectableText(
              'Code: ${room.code}',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: const Color(0xFF1B84F2),
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Invitation Link',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            SelectableText(
              room.inviteLink,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    await Clipboard.setData(ClipboardData(text: room.code));
                    if (!mounted) {
                      return;
                    }
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Class code copied')),
                    );
                  },
                  icon: const Icon(Icons.pin_outlined),
                  label: const Text('Copy Code'),
                ),
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
            Text(
              'Students Joined: ${members.length}',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            if (members.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              ...members.take(5).map((member) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: <Widget>[
                      const Icon(
                        Icons.person,
                        size: 18,
                        color: Color(0xFF3F4B56),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(member.studentName)),
                      Text(
                        DateFormat('dd MMM').format(member.joinedAt),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}
