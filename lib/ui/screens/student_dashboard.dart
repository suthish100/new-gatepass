import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/app_user.dart';
import '../../models/classroom.dart';
import '../../services/classroom_service.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({
    super.key,
    required this.user,
    required this.classroomService,
    required this.onLogout,
  });

  final AppUser user;
  final ClassroomService classroomService;
  final VoidCallback onLogout;

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  bool _loading = true;
  List<Classroom> _joinedClassrooms = <Classroom>[];

  @override
  void initState() {
    super.initState();
    _loadClassrooms();
  }

  Future<void> _loadClassrooms() async {
    setState(() => _loading = true);
    try {
      _joinedClassrooms = await widget.classroomService
          .fetchClassroomsForStudent(widget.user.id);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _joinClass() async {
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Join Class'),
          content: TextField(
            controller: controller,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              hintText: 'Enter unique class joining code',
              prefixIcon: Icon(Icons.pin_outlined),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final code = controller.text.trim();
                Navigator.pop(context);
                await _joinUsingCode(code);
              },
              child: const Text('Join'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _joinUsingCode(String code) async {
    try {
      final room = await widget.classroomService.joinClassroom(
        student: widget.user,
        code: code,
      );
      await _loadClassrooms();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Joined ${room.section} (${room.code})')),
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
          onRefresh: _loadClassrooms,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            children: <Widget>[
              _welcomeCard(),
              const SizedBox(height: 14),
              _joinClassCard(),
              const SizedBox(height: 14),
              Text(
                'Joined Classes',
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
              else if (_joinedClassrooms.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'No class joined yet. Tap join class and enter unique code.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                )
              else
                ..._joinedClassrooms.map((room) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFD1E4FB),
                          child: Icon(
                            Icons.class_outlined,
                            color: Color(0xFF1B84F2),
                          ),
                        ),
                        title: Text('${room.section} • ${room.code}'),
                        subtitle: Text(
                          'Teacher: ${room.teacherName}\nJoined via code • ${DateFormat('dd MMM').format(room.createdAt)}',
                        ),
                        isThreeLine: true,
                      ),
                    ),
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
                    'All Clear',
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

  Widget _joinClassCard() {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: _joinClass,
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
                    'join class',
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
}
