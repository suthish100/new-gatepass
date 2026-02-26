import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/classroom.dart';
import '../../models/classroom_member.dart';
import '../../services/classroom_service.dart';

class ClassroomDetailScreen extends StatefulWidget {
  const ClassroomDetailScreen({
    super.key,
    required this.classroom,
    required this.classroomService,
  });

  final Classroom classroom;
  final ClassroomService classroomService;

  @override
  State<ClassroomDetailScreen> createState() => _ClassroomDetailScreenState();
}

class _ClassroomDetailScreenState extends State<ClassroomDetailScreen> {
  bool _loading = true;
  String? _error;
  List<ClassroomMember> _students = <ClassroomMember>[];

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final students = await widget.classroomService.fetchStudentsForClassroom(
        widget.classroom.id,
      );
      if (!mounted) {
        return;
      }
      setState(() => _students = students);
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

  @override
  Widget build(BuildContext context) {
    final room = widget.classroom;
    final hasStaff = room.teacherId.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: Text(room.section)),
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
                        'Class Staff',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      if (hasStaff) ...<Widget>[
                        Text(
                          room.teacherName,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 2),
                        Text(room.teacherEmail),
                      ] else
                        const Text('No staff assigned yet.'),
                      const SizedBox(height: 10),
                      Text(
                        'Created: ${DateFormat('dd MMM yyyy').format(room.createdAt)}',
                      ),
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
                            title: Text(student.studentName),
                            subtitle: Text(student.studentEmail),
                            trailing: Text(
                              DateFormat('dd MMM').format(student.joinedAt),
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
