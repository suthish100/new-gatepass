import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants.dart';
import '../../models/app_notification.dart';
import '../../models/app_user.dart';
import '../../models/classroom.dart';
import '../../models/classroom_member.dart';
import '../../models/gate_pass_request.dart';
import '../../services/auth_service.dart';
import '../../services/classroom_service.dart';
import '../../services/delegation_service.dart';
import '../../services/gate_pass_service.dart';
import '../../services/notification_service.dart';
import '../widgets/dashboard_drawer.dart';
import '../widgets/join_class_shortcut_box.dart';
import 'classroom_detail_screen.dart';
import 'join_class_screen.dart';
import 'profile_screen.dart';
import 'request_collection_screen.dart';
import 'request_detail_screen.dart';
import 'settings_screen.dart';

class TeacherDashboard extends StatefulWidget {
  const TeacherDashboard({
    super.key,
    required this.user,
    required this.authService,
    required this.classroomService,
    required this.delegationService,
    required this.gatePassService,
    required this.notificationService,
    required this.onLogout,
    required this.isDarkMode,
    required this.onThemeChanged,
    required this.onUserUpdated,
  });

  final AppUser user;
  final AuthService authService;
  final ClassroomService classroomService;
  final DelegationService delegationService;
  final GatePassService gatePassService;
  final NotificationService notificationService;
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
  List<AppNotification> _notifications = <AppNotification>[];
  int _unreadNotifications = 0;
  String? _selectedClassroomId;

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
      final requests = await widget.gatePassService
          .fetchTeacherActionableRequests(teacher: widget.user);

      _membersByClassroom.clear();
      for (final room in classrooms) {
        _membersByClassroom[room.id] = await widget.classroomService
            .fetchStudentsForClassroom(room.id);
      }
      final notifications = await widget.notificationService
          .fetchNotificationsForUser(widget.user.id);

      if (!mounted) {
        return;
      }
      setState(() {
        _classrooms = classrooms;
        _requests = requests;
        _notifications = notifications;
        _unreadNotifications = notifications.where((item) => !item.isRead).length;
        if (!_classrooms.any((room) => room.id == _selectedClassroomId)) {
          _selectedClassroomId = _classrooms.isEmpty ? null : _classrooms.first.id;
        }
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Classroom? get _selectedClassroom {
    for (final room in _classrooms) {
      if (room.id == _selectedClassroomId) {
        return room;
      }
    }
    return null;
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

      // Propagate orgId from HOD
      if (room.hodId.isNotEmpty) {
        final hod = await widget.authService.getUserById(room.hodId);
        if (hod != null && hod.orgId != null && widget.user.orgId != hod.orgId) {
          await widget.authService.updateProfile(
            user: widget.user,
            orgId: hod.orgId,
          );
          widget.onUserUpdated(widget.user.copyWith(orgId: hod.orgId));
        }
      }

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
      final nextStatus = await widget.gatePassService.teacherAction(
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
            !approve
                ? 'Request rejected and student notified.'
                : nextStatus == RequestStatus.approved
                ? 'Request approved using HOD single-approver delegation.'
                : approve
                ? 'Request forwarded to HOD.'
                : 'Request updated.',
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


  Future<void> _openRequestCollectionPage({
    required String title,
    required List<GatePassRequest> requests,
    required String emptyMessage,
    required bool allowActions,
    bool showHistoryStyle = false,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RequestCollectionScreen(
          title: title,
          requests: requests,
          emptyMessage: emptyMessage,
          showHistoryStyle: showHistoryStyle,
          onRequestTap: (request) => _openRequestDetails(
            request: request,
            allowActions: allowActions,
          ),
        ),
      ),
    );
    await _loadData();
  }

  Future<void> _inviteStudent(Classroom room) async {
    final messenger = ScaffoldMessenger.of(context);
    final inviteText = StringBuffer()
      ..writeln('Join ${room.section}')
      ..writeln()
      ..writeln('Student code: ${room.studentCode}');
    if (room.inviteLink.isNotEmpty) {
      inviteText
        ..writeln()
        ..writeln('Invite link: ${room.inviteLink}');
    }

    Future<void> copyValue(String label, String value) async {
      await Clipboard.setData(ClipboardData(text: value));
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(SnackBar(content: Text('$label copied')));
    }

    Future<void> shareInvite() async {
      await SharePlus.instance.share(
        ShareParams(
          title: 'Class Invitation',
          subject: 'Class Invitation - ${room.section}',
          text: inviteText.toString(),
        ),
      );
    }

    Widget inviteDetailTile({
      required String label,
      required String value,
      required IconData icon,
    }) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(icon, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    value,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Copy $label',
              onPressed: () => copyValue(label, value),
              icon: const Icon(Icons.copy_outlined),
            ),
          ],
        ),
      );
    }

    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            'Invite Student',
                            style: Theme.of(dialogContext).textTheme.titleLarge,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    Text(room.section),
                    const SizedBox(height: 16),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: QrImageView(data: room.studentCode, size: 150),
                      ),
                    ),
                    const SizedBox(height: 16),
                    inviteDetailTile(
                      label: 'Join Code',
                      value: room.studentCode,
                      icon: Icons.pin_outlined,
                    ),
                    if (room.inviteLink.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 12),
                      inviteDetailTile(
                        label: 'Invite Link',
                        value: room.inviteLink,
                        icon: Icons.link_outlined,
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: shareInvite,
                        icon: const Icon(Icons.share_outlined),
                        label: const Text('Share Invite'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _viewClassMembers(Classroom room) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ClassroomDetailScreen(
          classroom: room,
          classroomService: widget.classroomService,
          currentUser: widget.user,
          authService: widget.authService,
        ),
      ),
    );
  }

  Future<void> _delegateToTeacher(Classroom room) async {
    final activeDelegation = await widget.delegationService.findActiveDelegationForClassroom(
      ownerTeacherId: widget.user.id,
      classroomId: room.id,
    );
    if (activeDelegation != null) {
      final confirmed = await _confirmRevokeAccess('delegate access');
      if (!confirmed) {
        return;
      }
      await widget.delegationService.revokeDelegation(delegation: activeDelegation);
      await _loadData();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Delegation revoked.')),
      );
      return;
    }
    if (room.hasActiveHodDelegation || room.hasActiveTeacherDelegation) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Single approver is already active for this class, so delegation cannot be changed now.',
          ),
        ),
      );
      return;
    }

    final candidates = await widget.authService.fetchTeachersByDepartment(
      widget.user.department,
      orgId: widget.user.orgId,
      excludeUserIds: <String>{widget.user.id},
    );
    if (!mounted) {
      return;
    }
    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No eligible teacher found in your department and organization.')),
      );
      return;
    }

    String selectedTeacherId = candidates.first.id;
    final reasonController = TextEditingController(text: 'Class incharge absent');
    final durationController = TextEditingController(text: '1');
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text('Delegate Class Approval'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  DropdownButtonFormField<String>(
                    initialValue: selectedTeacherId,
                    items: candidates.map((teacher) {
                      return DropdownMenuItem<String>(
                        value: teacher.id,
                        child: Text('${teacher.name} (${teacher.email})'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setModalState(() => selectedTeacherId = value);
                      }
                    },
                    decoration: const InputDecoration(labelText: 'Delegate Teacher'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: durationController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Duration (days)'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: reasonController,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Reason'),
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, <String, dynamic>{
                    'days': int.tryParse(durationController.text) ?? 1,
                    'reason': reasonController.text,
                  }),
                  child: const Text('Delegate'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null) {
      return;
    }

    try {
      final days = result['days'] as int;
      final reason = result['reason'] as String? ?? '';
      final delegate = candidates.firstWhere((item) => item.id == selectedTeacherId);
      final startAt = DateTime.now();
      final endAt = startAt.add(Duration(days: days));
      await widget.delegationService.createTeacherSelfDelegation(
        teacherId: widget.user.id,
        teacherName: widget.user.name,
        classroomId: room.id,
        classroomSection: room.section,
        hodId: room.hodId,
        delegateTeacherId: delegate.id,
        delegateTeacherName: delegate.name,
        reason: reason,
        startAt: startAt,
        endAt: endAt,
      );
      await widget.notificationService.createNotification(
        toUserId: delegate.id,
        fromUserId: widget.user.id,
        fromUserName: widget.user.name,
        title: 'Delegated Class Approval',
        message: 'You are delegated to handle ${room.section} until ${DateFormat('dd MMM yyyy').format(endAt)}.',
        type: 'teacher_delegate',
        classroomId: room.id,
      );
      await widget.notificationService.createNotification(
        toUserId: room.hodId,
        fromUserId: widget.user.id,
        fromUserName: widget.user.name,
        title: 'Teacher Delegation Updated',
        message: '${widget.user.name} delegated ${room.section} to ${delegate.name}.',
        type: 'teacher_delegate_to_hod',
        classroomId: room.id,
      );
      await _loadData();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delegation activated until ${DateFormat('dd MMM yyyy').format(endAt)}.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delegate: $error')),
      );
    }
  }

  Future<void> _openTeacherPermissionSettings(Classroom room) async {
    final activeDelegation = await widget.delegationService.findActiveDelegationForClassroom(
      ownerTeacherId: widget.user.id,
      classroomId: room.id,
    );
    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Permission Settings'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.swap_horiz_outlined),
                title: Text(activeDelegation != null ? 'Revoke Delegate' : 'Delegate'),
                subtitle: const Text('Allow another teacher in your department to handle this class.'),
                onTap: () async {
                  Navigator.pop(dialogContext);
                  await _delegateToTeacher(room);
                },
              ),
              const Divider(height: 1),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.admin_panel_settings_outlined),
                title: Text(room.hasActiveTeacherDelegation ? 'Revoke Single Approver' : 'Single Approver'),
                subtitle: const Text('Route new passes directly to HOD for the chosen period.'),
                onTap: () async {
                  Navigator.pop(dialogContext);
                  await _setSingleApproverToHod(room);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _setSingleApproverToHod(Classroom room) async {
    if (room.hasActiveTeacherDelegation) {
      final confirmed = await _confirmRevokeAccess('single approver');
      if (!confirmed) {
        return;
      }
      await widget.classroomService.clearTeacherSingleApproverToHod(
        teacher: widget.user,
        classroom: room,
      );
      await _loadData();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Single approver revoked.')),
      );
      return;
    }
    if (room.hasActiveHodDelegation) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'HOD already enabled class incharge final approval, so HOD single approver cannot be enabled now.',
          ),
        ),
      );
      return;
    }

    final hod = await widget.authService.getUserById(room.hodId);
    if (!mounted || hod == null) {
      return;
    }

    final reasonController = TextEditingController(text: 'Class incharge unavailable');
    final durationController = TextEditingController(text: '1');
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Set HOD as Single Approver'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text('During this period, new passes from your class will go directly to HOD for final approval.'),
              const SizedBox(height: 12),
              TextField(
                controller: durationController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Duration (days)'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: reasonController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Reason'),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, <String, dynamic>{
                'days': int.tryParse(durationController.text) ?? 1,
                'reason': reasonController.text,
              }),
              child: const Text('Enable'),
            ),
          ],
        );
      },
    );

    if (result == null) {
      return;
    }

    try {
      final days = result['days'] as int;
      final reason = result['reason'] as String? ?? '';
      await widget.classroomService.setTeacherSingleApproverToHod(
        teacher: widget.user,
        classroom: room,
        durationDays: days,
        reason: reason,
        hodName: hod.name,
      );
      await widget.notificationService.createNotification(
        toUserId: room.hodId,
        fromUserId: widget.user.id,
        fromUserName: widget.user.name,
        title: 'HOD Final Approver Enabled',
        message: '${widget.user.name} routed new ${room.section} passes directly to you until ${DateFormat('dd MMM yyyy').format(DateTime.now().add(Duration(days: days)))}.',
        type: 'teacher_single_approver',
        classroomId: room.id,
      );
      await _loadData();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('New passes will go directly to HOD until ${DateFormat('dd MMM yyyy').format(DateTime.now().add(Duration(days: days)))}.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to enable single approver: $error')),
      );
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
      drawer: DashboardDrawer(
        user: widget.user,
        title: 'Class Incharge Dashboard',
        onProfile: _openProfile,
        onLogout: widget.onLogout,
        onSettings: _openSettings,
        footerNote: canJoin
            ? 'Use your HOD staff code once to claim a class.'
            : 'Assigned classes: ${_classrooms.length}',
      ),
      appBar: AppBar(
        title: _dashboardTitle('Class Incharge Dashboard'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Notifications',
            onPressed: _openNotifications,
            icon: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                const Icon(Icons.notifications_none_outlined),
                if (_unreadNotifications > 0)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        _unreadNotifications > 9 ? '9+' : '$_unreadNotifications',
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 6),
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
                    if (widget.user.orgId != null) ...[
                      Card(
                        color: Colors.green.shade50,
                        child: ListTile(
                          leading: const Icon(Icons.verified_user, color: Colors.green),
                          title: const Text('Connected Organization'),
                          subtitle: Text(
                            'You are connected with ${colleges[widget.user.orgId] ?? widget.user.orgId}.',
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    const SizedBox(height: 12),
                    _buildAssignedClassesCompactSection(),
                    const SizedBox(height: 12),
                    _buildPendingSummaryCard(pending),
                    const SizedBox(height: 12),
                    _buildHistorySummaryCard(history),
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

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsScreen(
          isDarkMode: widget.isDarkMode,
          onThemeChanged: widget.onThemeChanged,
          onLogout: () async {
            widget.onLogout();
          },
        ),
      ),
    );
  }


  Future<bool> _confirmRevokeAccess(String label) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Revoke $label'),
          content: Text('Are you sure you want to revoke $label immediately?'),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Revoke')),
          ],
        );
      },
    );
    return result == true;
  }

  Future<void> _openNotifications() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460, maxHeight: 520),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Text('Notifications', style: Theme.of(context).textTheme.titleLarge),
                      const Spacer(),
                      TextButton(
                        onPressed: () async {
                          await widget.notificationService.markAllAsRead(widget.user.id);
                          if (!mounted) {
                            return;
                          }
                          Navigator.pop(dialogContext);
                          await _loadData();
                        },
                        child: const Text('Mark all read'),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_notifications.isEmpty)
                    const Expanded(
                      child: Center(child: Text('No notifications yet.')),
                    )
                  else
                    Expanded(
                      child: ListView(
                        children: _notifications.map((item) {
                          return Card(
                            color: item.isRead ? null : Colors.orange.shade50,
                            child: ListTile(
                              title: Text(item.title),
                              subtitle: Text('''${item.message}
${DateFormat('dd MMM, hh:mm a').format(item.createdAt)}'''),
                              isThreeLine: true,
                              onTap: () async {
                                await widget.notificationService.markAsRead(
                                  notificationId: item.id,
                                  userId: widget.user.id,
                                );
                                if (!mounted) {
                                  return;
                                }
                                Navigator.pop(dialogContext);
                                await _loadData();
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _dashboardTitle(String text) {
    final isCompact = MediaQuery.of(context).size.width < 400;
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(
        context,
      ).appBarTheme.titleTextStyle?.copyWith(fontSize: isCompact ? 21 : 24),
    );
  }

  Widget _buildAssignedClassesCompactSection() {
    final room = _selectedClassroom;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Assigned Classes', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_classrooms.isEmpty)
              const Text('No class assigned yet. Use HOD unique staff code.')
            else ...<Widget>[
              _buildClassSelectorStrip(_classrooms, room?.id),
              if (room != null) ...<Widget>[
                const SizedBox(height: 12),
                _buildSelectedClassroomCard(room),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPendingSummaryCard(List<GatePassRequest> pending) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.pending_actions_outlined),
        title: const Text('Pass Requests Pending'),
        subtitle: Text(
          pending.isEmpty
              ? 'No pending pass requests.'
              : '${pending.length} request${pending.length == 1 ? '' : 's'} waiting. Tap to view by year.',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _openRequestCollectionPage(
          title: 'Pass Requests Pending',
          requests: pending,
          emptyMessage: 'No pending pass requests.',
          allowActions: true,
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

  Widget _buildHistorySummaryCard(List<GatePassRequest> history) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.history_outlined),
        title: const Text('Pass History'),
        subtitle: Text(
          history.isEmpty
              ? 'No pass history available yet.'
              : 'Tap to browse processed passes by year.',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _openRequestCollectionPage(
          title: 'Pass History',
          requests: history,
          emptyMessage: 'No pass history available yet.',
          allowActions: false,
          showHistoryStyle: true,
        ),
      ),
    );
  }

  Widget _buildClassSelectorStrip(List<Classroom> rooms, String? selectedId) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = rooms.length.clamp(1, 3);
        final width = (constraints.maxWidth - ((count - 1) * 8)) / count;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: rooms.map((room) {
            return SizedBox(
              width: width,
              child: _flatSelectionButton(
                label: '${room.year} - ${room.department}',
                selected: room.id == selectedId,
                onPressed: () => setState(() => _selectedClassroomId = room.id),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildSelectedClassroomCard(Classroom room) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(90),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('${room.year} - ${room.department}', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: _classroomActionButton(
                  icon: Icons.visibility_outlined,
                  label: 'View Class',
                  onPressed: () => _viewClassMembers(room),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _classroomActionButton(
                  icon: Icons.admin_panel_settings_outlined,
                  label: 'Permission Settings',
                  onPressed: () => _openTeacherPermissionSettings(room),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _classroomActionButton(
                  icon: Icons.person_add_alt_1_outlined,
                  label: 'Invite Student',
                  onPressed: () => _inviteStudent(room),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _classroomActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool highlighted = false,
    bool destructive = false,
  }) {
    final color = destructive ? Colors.red : highlighted ? Colors.green.shade700 : Theme.of(context).colorScheme.primary;
    return SizedBox(
      height: 48,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          backgroundColor: highlighted ? Colors.green.shade50 : null,
        ),
      ),
    );
  }


  Widget _flatSelectionButton({
    required String label,
    required bool selected,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: selected ? Colors.black12 : null,
        side: BorderSide(color: selected ? Colors.black54 : Colors.grey.shade400),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.black87),
      ),
    );
  }
}
