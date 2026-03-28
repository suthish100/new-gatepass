import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/app_user.dart';
import '../../models/classroom.dart';
import '../../models/classroom_member.dart';
import '../../services/auth_service.dart';
import '../../services/classroom_service.dart';
import 'student_profile_view_screen.dart';

class ClassroomDetailScreen extends StatefulWidget {
  const ClassroomDetailScreen({
    super.key,
    required this.classroom,
    required this.classroomService,
    required this.currentUser,
    required this.authService,
    this.onInviteStudent,
    this.onPermissionSettings,
  });

  final Classroom classroom;
  final ClassroomService classroomService;
  final AppUser currentUser;
  final AuthService authService;
  final Future<void> Function(Classroom classroom)? onInviteStudent;
  final Future<void> Function(Classroom classroom)? onPermissionSettings;

  @override
  State<ClassroomDetailScreen> createState() => _ClassroomDetailScreenState();
}

class _ClassroomDetailScreenState extends State<ClassroomDetailScreen> {
  bool _loading = true;
  String? _error;
  List<ClassroomMember> _students = <ClassroomMember>[];
  late Classroom _classroom;

  @override
  void initState() {
    super.initState();
    _classroom = widget.classroom;
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final latestRoom = await widget.classroomService.fetchClassroomById(
        _classroom.id,
      );
      final students = await widget.classroomService.fetchStudentsForClassroom(
        _classroom.id,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        if (latestRoom != null) {
          _classroom = latestRoom;
        }
        _students = students;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _openStudentProfile(ClassroomMember student) async {
    final profile = await widget.authService.getUserById(student.studentId);
    if (!mounted || profile == null) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StudentProfileViewScreen(student: profile),
      ),
    );
  }

  Future<void> _removeStudent(ClassroomMember student) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Remove Student'),
          content: Text(
            'Remove ${student.studentName} from ${_classroom.section}? This action cannot be undone.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await widget.classroomService.removeStudentFromClassroom(
        classroomId: _classroom.id,
        studentId: student.studentId,
        remover: widget.currentUser,
      );

      await _loadStudents();
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${student.studentName} removed from class.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to remove student: $error')),
      );
    }
  }

  Future<void> _openInviteStudent() async {
    final action = widget.onInviteStudent;
    if (action == null) {
      return;
    }
    await action(_classroom);
    await _loadStudents();
  }

  Future<void> _openPermissionSettings() async {
    final action = widget.onPermissionSettings;
    if (action == null) {
      return;
    }
    await action(_classroom);
    await _loadStudents();
  }

  @override
  Widget build(BuildContext context) {
    final room = _classroom;
    final hasStaff = room.teacherId.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(room.section),
        actions: widget.onInviteStudent == null
            ? null
            : <Widget>[
                IconButton(
                  tooltip: 'Class Invite',
                  onPressed: hasStaff ? _openInviteStudent : null,
                  icon: const Icon(Icons.share_outlined),
                ),
              ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadStudents,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        room.year,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 6),
                      Text('Department: ${room.department}'),
                      const SizedBox(height: 4),
                      Text(
                        hasStaff
                            ? 'Assigned to: ${room.teacherName}'
                            : 'Assigned to: Not assigned yet',
                      ),
                      if (hasStaff && room.teacherEmail.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 2),
                        Text(room.teacherEmail),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        'Created: ${DateFormat('dd MMM yyyy').format(room.createdAt)}',
                      ),
                      if (widget.onPermissionSettings != null) ...<Widget>[
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: hasStaff ? _openPermissionSettings : null,
                            icon: const Icon(Icons.admin_panel_settings_outlined),
                            label: const Text('Permission Settings'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Students (${_students.length})',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      if (_loading)
                        const Center(child: CircularProgressIndicator())
                      else if (_error != null)
                        Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        )
                      else if (_students.isEmpty)
                        const Text('No students joined this class yet.')
                      else
                        ..._students.map((student) {
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const CircleAvatar(
                              child: Icon(Icons.person_outline),
                            ),
                            onTap: () => _openStudentProfile(student),
                            title: Text(
                              student.studentName,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(student.studentEmail),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Text(
                                  DateFormat('dd MMM').format(student.joinedAt),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline),
                                  color: Colors.red,
                                  onPressed: () => _removeStudent(student),
                                  tooltip: 'Remove student',
                                ),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
