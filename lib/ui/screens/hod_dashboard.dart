import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants.dart';
import '../../models/app_user.dart';
import '../../models/classroom.dart';
import '../../models/gate_pass_request.dart';
import '../../services/classroom_service.dart';
import '../../services/delegation_service.dart';
import '../../services/auth_service.dart';
import '../../services/gate_pass_service.dart';
import 'classroom_detail_screen.dart';
import 'profile_screen.dart';
import 'request_detail_screen.dart';

class HodDashboard extends StatefulWidget {
  const HodDashboard({
    super.key,
    required this.user,
    required this.classroomService,
    required this.authService,
    required this.delegationService,
    required this.gatePassService,
    required this.onLogout,
    required this.isDarkMode,
    required this.onThemeChanged,
    required this.onUserUpdated,
  });

  final AppUser user;
  final ClassroomService classroomService;
  final AuthService authService;
  final DelegationService delegationService;
  final GatePassService gatePassService;
  final VoidCallback onLogout;
  final bool isDarkMode;
  final ValueChanged<bool> onThemeChanged;
  final ValueChanged<AppUser> onUserUpdated;

  @override
  State<HodDashboard> createState() => _HodDashboardState();
}

class _HodDashboardState extends State<HodDashboard> {
  bool _loading = true;
  String? _errorMessage;
  List<Classroom> _classrooms = <Classroom>[];
  List<GatePassRequest> _requests = <GatePassRequest>[];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      String? fetchError;

      try {
        final classrooms = await widget.classroomService.fetchClassroomsForHod(
          widget.user.id,
        );
        if (mounted) {
          setState(() => _classrooms = classrooms);
        }
      } catch (error) {
        fetchError = 'Classes: $error';
      }

      try {
        final requests = await widget.gatePassService.fetchHodRequests(
          hodId: widget.user.id,
        );
        if (mounted) {
          setState(() => _requests = requests);
        }
      } catch (error) {
        final requestError = 'Queue: $error';
        fetchError = fetchError == null
            ? requestError
            : '$fetchError | $requestError';
      }

      if (mounted) {
        setState(
          () => _errorMessage = fetchError == null
              ? null
              : 'Fetch Error: $fetchError',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  List<String> get _allowedYears {
    if (isFirstYearHod(widget.user.hodType)) {
      return <String>[classYears.first];
    }
    return <String>['II Year', 'III Year', 'IV Year'];
  }

  Future<void> _createClassroom() async {
    String selectedYear = _allowedYears.first;
    final shouldCreate = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text('Create Class'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  DropdownButtonFormField<String>(
                    value: selectedYear,
                    decoration: const InputDecoration(
                      labelText: 'Year',
                      prefixIcon: Icon(Icons.calendar_view_month_outlined),
                    ),
                    items: _allowedYears.map((year) {
                      return DropdownMenuItem<String>(
                        value: year,
                        child: Text(year),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setModalState(() => selectedYear = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: widget.user.department,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Department',
                      prefixIcon: Icon(Icons.apartment_outlined),
                    ),
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );

    if (shouldCreate != true) {
      return;
    }

    try {
      await widget.classroomService.createClassroomByHod(
        hod: widget.user,
        year: selectedYear,
        department: widget.user.department,
      );
      await _loadData();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Class created successfully.')),
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

  Future<void> _inviteStaff(Classroom room) async {
    final emailController = TextEditingController();

    final sent = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Staff'),
          content: TextField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Staff Email'),
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
      final invite = await widget.classroomService.sendStaffInvitation(
        hodId: widget.user.id,
        section: room.section,
        staffEmail: emailController.text,
      );
      if (!mounted) {
        return;
      }

      final emailUri = Uri(
        scheme: 'mailto',
        path: invite.staffEmail,
        queryParameters: <String, String>{
          'subject': 'Class Invitation - ${room.section}',
          'body':
              'You are invited to join ${room.section}.\n\nUse this invitation link:\n${invite.inviteLink}\n\nOr use class code: ${room.staffCode}',
        },
      );

      final launched = await launchUrl(
        emailUri,
        mode: LaunchMode.externalApplication,
      );

      await Clipboard.setData(ClipboardData(text: invite.inviteLink));
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            launched
                ? 'Email compose opened. Invite link copied.'
                : 'Unable to open email app. Invite link copied.',
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

  Future<void> _assignDelegateForClass(Classroom room) async {
    if (room.teacherId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Assign class incharge before delegation.')),
      );
      return;
    }

    try {
      final teachers = await widget.authService.fetchTeachersByDepartment(
        widget.user.department,
      );
      final candidates = teachers
          .where((teacher) => teacher.id != room.teacherId)
          .toList();

      if (!mounted) {
        return;
      }

      if (candidates.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No eligible delegate teacher found.')),
        );
        return;
      }

      String selectedTeacherId = candidates.first.id;
      int selectedDays = 1;
      final reasonController = TextEditingController(
        text: 'Class incharge absent',
      );

      final shouldSave = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (dialogContext, setModalState) {
              return AlertDialog(
                title: const Text('Set Delegate'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    DropdownButtonFormField<String>(
                      value: selectedTeacherId,
                      decoration: const InputDecoration(
                        labelText: 'Delegate Teacher',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      items: candidates.map((teacher) {
                        return DropdownMenuItem<String>(
                          value: teacher.id,
                          child: Text('${teacher.name} (${teacher.email})'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        setModalState(() => selectedTeacherId = value);
                      },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int>(
                      value: selectedDays,
                      decoration: const InputDecoration(
                        labelText: 'Delegate Period',
                        prefixIcon: Icon(Icons.schedule_outlined),
                      ),
                      items: const <int>[1, 2, 3, 5, 7].map((days) {
                        return DropdownMenuItem<int>(
                          value: days,
                          child: Text('$days day${days > 1 ? 's' : ''}'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        setModalState(() => selectedDays = value);
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: reasonController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Reason',
                        hintText: 'Why is delegation allowed?',
                      ),
                    ),
                  ],
                ),
                actions: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: const Text('Save'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (shouldSave != true) {
        return;
      }

      final delegate = candidates.firstWhere(
        (teacher) => teacher.id == selectedTeacherId,
      );
      final now = DateTime.now();
      final endAt = now.add(Duration(days: selectedDays));

      await widget.delegationService.upsertTeacherDelegation(
        ownerTeacherId: room.teacherId,
        ownerTeacherName: room.teacherName,
        delegateTeacherId: delegate.id,
        delegateTeacherName: delegate.name,
        classroomId: room.id,
        classroomSection: room.section,
        hodId: widget.user.id,
        reason: reasonController.text,
        startAt: now,
        endAt: endAt,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Delegation active: ${delegate.name} can approve for ${room.teacherName} until ${DateFormat('dd MMM, hh:mm a').format(endAt)}.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  Future<void> _openClassroomDetails(Classroom room) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ClassroomDetailScreen(
          classroom: room,
          classroomService: widget.classroomService,
        ),
      ),
    );
  }

  Future<void> _deleteClassroom(Classroom room) async {
    try {
      await widget.classroomService.deleteClassroomByHod(
        hod: widget.user,
        classroomId: room.id,
      );
      if (!mounted) {
        return;
      }
      await _loadData();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Class deleted successfully.')),
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

  Future<void> _confirmDeleteClassroom(Classroom room) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (confirmContext) {
        return AlertDialog(
          title: const Text('Delete Class'),
          content: Text(
            'Delete ${room.section}?\n\nThis will remove all student memberships of this class.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(confirmContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(confirmContext, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }
    await _deleteClassroom(room);
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
      await widget.gatePassService.hodAction(
        request: request,
        hod: widget.user,
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
                ? 'Final approval completed. Student can use this gate pass.'
                : 'Request rejected by HOD.',
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

  @override
  Widget build(BuildContext context) {
    final pending = _requests
        .where((request) => request.status == RequestStatus.forwardedToHod)
        .toList();
    final history = _requests
        .where(
          (request) =>
              request.status == RequestStatus.approved ||
              request.status == RequestStatus.rejectedByHod,
        )
        .toList();

    return Scaffold(
      drawer: Drawer(
        child: ListView(
          children: <Widget>[
            const DrawerHeader(child: Text('HOD Navigation')),
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
        title: const Text('HOD Dashboard'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Profile',
            onPressed: _openProfile,
            icon: _buildProfileActionIcon(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.large(
        onPressed: _createClassroom,
        tooltip: 'Create Class',
        child: const Icon(Icons.add, size: 40),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            children: <Widget>[
              Card(
                child: ListTile(
                  leading: const Icon(Icons.school_outlined),
                  title: Text(
                    isFirstYearHod(widget.user.hodType)
                        ? 'Create classes for I Year'
                        : 'Create classes for II, III, IV Year',
                  ),
                  subtitle: Text(
                    'Department: ${widget.user.department}\nUse + button to create classes.',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text('Classes', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              if (_loading)
                const Center(child: CircularProgressIndicator())
              else if (_classrooms.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(
                      _errorMessage ??
                          'No classes found. Tap + to create your first class.',
                      style: TextStyle(
                        color: _errorMessage != null ? Colors.red : null,
                        fontWeight: _errorMessage != null
                            ? FontWeight.bold
                            : null,
                      ),
                    ),
                  ),
                )
              else
                ..._classrooms.map((room) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Card(
                      child: ListTile(
                        title: Text(room.section),
                        subtitle: Text(
                          room.teacherId.isEmpty
                              ? 'Class ID: ${room.id}\nStaff code: ${room.staffCode}\n${widget.classroomService.buildStaffJoinLink(room.staffCode)}'
                              : 'Class ID: ${room.id}\nAssigned: ${room.teacherName}\nStaff code: ${room.staffCode}\n${widget.classroomService.buildStaffJoinLink(room.staffCode)}',
                        ),
                        isThreeLine: true,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            IconButton(
                              tooltip: 'Add staff',
                              icon: const Icon(Icons.person_add_alt_1_outlined),
                              onPressed: () => _inviteStaff(room),
                            ),
                            IconButton(
                              tooltip: 'Set delegate',
                              icon: const Icon(Icons.swap_horiz_outlined),
                              onPressed: () => _assignDelegateForClass(room),
                            ),
                            IconButton(
                              tooltip: 'Delete class',
                              icon: Icon(
                                Icons.delete_outline,
                                color: Theme.of(context).colorScheme.error,
                              ),
                              onPressed: () => _confirmDeleteClassroom(room),
                            ),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                        onTap: () => _openClassroomDetails(room),
                      ),
                    ),
                  );
                }),
              const SizedBox(height: 14),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Final Approval Queue',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      if (pending.isEmpty)
                        const Text('No requests waiting for HOD approval.')
                      else
                        ...pending.map((request) {
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              '${request.studentName} - ${request.passType}',
                            ),
                            subtitle: Text(
                              '${request.classroomSection}\n${DateFormat('dd MMM').format(request.date)} | ${request.outTime} - ${request.inTime}'
                              '${(request.teacherActionActorName ?? '').isEmpty ? '' : '\nTeacher action: ${request.teacherActionActorName} as ${request.teacherRoleUsedName ?? '-'}'}',
                            ),
                            isThreeLine: true,
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _openRequestDetails(
                              request: request,
                              allowActions: true,
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _buildHistorySection(history),
            ],
          ),
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
              const Text('No completed pass history yet.')
            else
              ...history.map((request) {
                final isApproved = request.status == RequestStatus.approved;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    isApproved ? Icons.check_circle : Icons.cancel,
                    color: isApproved ? Colors.green : Colors.red,
                  ),
                  title: Text('${request.studentName} - ${request.passType}'),
                  subtitle: Text(
                    '${request.classroomSection}\n${DateFormat('dd MMM yyyy').format(request.date)} | ${request.status}',
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
}
