import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants.dart';
import '../../models/app_user.dart';
import '../../models/classroom.dart';
import '../../models/gate_pass_request.dart';
import '../../services/classroom_service.dart';
import '../../services/gate_pass_service.dart';

class HodDashboard extends StatefulWidget {
  const HodDashboard({
    super.key,
    required this.user,
    required this.classroomService,
    required this.gatePassService,
    required this.onLogout,
  });

  final AppUser user;
  final ClassroomService classroomService;
  final GatePassService gatePassService;
  final VoidCallback onLogout;

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

  Future<void> _openClassroomDetails(Classroom room) async {
    final pageContext = context;
    final status = room.teacherId.isEmpty
        ? 'Staff not assigned yet'
        : 'Assigned to ${room.teacherName}';
    final staffJoinLink = widget.classroomService.buildStaffJoinLink(
      room.staffCode,
    );

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(room.section),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                SelectableText(
                  'Class ID: ${room.id}\n'
                  'Status: $status\n'
                  'Staff Join Code: ${room.staffCode}\n'
                  'Staff Join Link: $staffJoinLink\n'
                  'Student Code: ${room.studentCode.isEmpty ? 'Generated after staff join' : room.studentCode}',
                ),
                const SizedBox(height: 16),
                const Text('Staff Code QR:'),
                QrImageView(data: room.staffCode, size: 150),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () async {
                final shouldDelete = await showDialog<bool>(
                  context: dialogContext,
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

                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
                await _deleteClassroom(room);
              },
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(dialogContext).colorScheme.error,
              ),
              child: const Text('Delete'),
            ),
            TextButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(pageContext);
                await Clipboard.setData(ClipboardData(text: room.staffCode));
                if (!mounted) {
                  return;
                }
                messenger.showSnackBar(
                  const SnackBar(content: Text('Staff code copied')),
                );
              },
              child: const Text('Copy Code'),
            ),
            TextButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(pageContext);
                await Clipboard.setData(ClipboardData(text: staffJoinLink));
                if (!mounted) {
                  return;
                }
                messenger.showSnackBar(
                  const SnackBar(content: Text('Staff join link copied')),
                );
              },
              child: const Text('Copy Link'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                await _inviteStaff(room);
              },
              child: const Text('Add Staff'),
            ),
          ],
        );
      },
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

  void _showProfile() {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                widget.user.name,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text('Role: ${widget.user.role}'),
              Text('Email: ${widget.user.email}'),
              Text('Department: ${widget.user.department}'),
              Text('HOD Type: ${hodTypeDisplayName(widget.user.hodType)}'),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final pending = _requests
        .where((request) => request.status == RequestStatus.forwardedToHod)
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
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: widget.onLogout,
            ),
          ],
        ),
      ),
      appBar: AppBar(
        title: const Text('HOD Dashboard'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Profile',
            onPressed: _showProfile,
            icon: const Icon(Icons.account_circle_outlined),
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
                              '${request.classroomSection}\n${DateFormat('dd MMM').format(request.date)} | ${request.outTime} - ${request.inTime}',
                            ),
                            isThreeLine: true,
                            trailing: Wrap(
                              spacing: 6,
                              children: <Widget>[
                                OutlinedButton(
                                  onPressed: () => _reviewRequest(
                                    request: request,
                                    approve: false,
                                  ),
                                  child: const Text('Reject'),
                                ),
                                ElevatedButton(
                                  onPressed: () => _reviewRequest(
                                    request: request,
                                    approve: true,
                                  ),
                                  child: const Text('Approve'),
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
