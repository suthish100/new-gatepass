import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants.dart';
import '../../models/app_notification.dart';
import '../../models/app_user.dart';
import '../../models/classroom.dart';
import '../../models/gate_pass_request.dart';
import '../../services/auth_service.dart';
import '../../services/classroom_service.dart';
import '../../services/delegation_service.dart';
import '../../services/gate_pass_service.dart';
import '../../services/notification_service.dart';
import '../widgets/dashboard_drawer.dart';
import 'classroom_detail_screen.dart';
import 'profile_screen.dart';
import 'request_collection_screen.dart';
import 'request_detail_screen.dart';
import 'settings_screen.dart';

class HodDashboard extends StatefulWidget {
  const HodDashboard({
    super.key,
    required this.user,
    required this.classroomService,
    required this.authService,
    required this.delegationService,
    required this.gatePassService,
    required this.notificationService,
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
  final NotificationService notificationService;
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
  List<AppNotification> _notifications = <AppNotification>[];
  int _unreadNotifications = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      String? fetchError;
      List<Classroom> classrooms = <Classroom>[];
      List<GatePassRequest> requests = <GatePassRequest>[];

      try {
        classrooms = await widget.classroomService.fetchClassroomsForHod(
          widget.user.id,
        );
      } catch (error) {
        fetchError = 'Classes: $error';
      }

      try {
        requests = await widget.gatePassService.fetchHodRequests(
          hodId: widget.user.id,
        );
      } catch (error) {
        final requestError = 'Queue: $error';
        fetchError = fetchError == null
            ? requestError
            : '$fetchError | $requestError';
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
        _errorMessage = fetchError == null ? null : 'Fetch Error: $fetchError';
      });
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

  bool get _canCreateMoreClasses {
    for (final year in _allowedYears) {
      final count = _classrooms.where((room) => room.year == year).length;
      if (count < 3) {
        return true;
      }
    }
    return false;
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
                    initialValue: selectedYear,
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
                      if (value != null) {
                        setModalState(() => selectedYear = value);
                      }
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
          currentUser: widget.user,
          authService: widget.authService,
          onInviteStudent: _showClassInviteDialog,
          onPermissionSettings: _openHodPermissionSettings,
        ),
      ),
    );
    await _loadData();
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
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
    await _loadData();
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
  Future<void> _showClassInviteDialog(Classroom room) async {
    if (room.teacherId.isEmpty || room.studentCode.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Assign a class incharge first to generate student invite details.'),
        ),
      );
      return;
    }

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
                            'Class Invite',
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

  Future<void> _openHodPermissionSettings(Classroom room) async {
    if (room.teacherId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Assign a class incharge first to manage permissions.'),
        ),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final activeDelegationFuture = widget.delegationService
            .findActiveDelegationForClassroom(
              ownerTeacherId: room.teacherId,
              classroomId: room.id,
            );
        return FutureBuilder(
          future: activeDelegationFuture,
          builder: (context, snapshot) {
            final hasDelegation = snapshot.data != null;
            return AlertDialog(
              title: const Text('Permission Settings'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.swap_horiz_outlined),
                    title: Text(hasDelegation ? 'Revoke Delegate' : 'Delegate'),
                    subtitle: Text(
                      hasDelegation
                          ? 'Pull back delegated class approval access immediately.'
                          : 'Allow another staff member in your department to act for this class.',
                    ),
                    onTap: () async {
                      Navigator.pop(dialogContext);
                      await _toggleHodDelegation(room);
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.admin_panel_settings_outlined),
                    title: Text(
                      room.hasActiveHodDelegation
                          ? 'Revoke Single Approver'
                          : 'Single Approver',
                    ),
                    subtitle: Text(
                      room.hasActiveHodDelegation
                          ? 'Return final approval back to HOD.'
                          : 'Make the class incharge the final approver for a limited time.',
                    ),
                    onTap: () async {
                      Navigator.pop(dialogContext);
                      await _toggleHodSingleApprover(room);
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _toggleHodDelegation(Classroom room) async {
    final activeDelegation = await widget.delegationService
        .findActiveDelegationForClassroom(
          ownerTeacherId: room.teacherId,
          classroomId: room.id,
        );
    if (activeDelegation != null) {
      final confirmed = await _confirmRevokeAccess('delegate access');
      if (!confirmed) {
        return;
      }
      await widget.delegationService.revokeDelegation(
        delegation: activeDelegation,
      );
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
            'Single approver is already active for this class, so delegation cannot be enabled now.',
          ),
        ),
      );
      return;
    }

    final candidates = await widget.authService.fetchTeachersByDepartment(
      room.department,
      orgId: widget.user.orgId,
      excludeUserIds: <String>{room.teacherId},
    );
    if (!mounted) {
      return;
    }
    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No eligible staff found in this department and organization.'),
        ),
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
              title: const Text('Delegate Approval Access'),
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
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
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
      await widget.delegationService.upsertTeacherDelegation(
        ownerTeacherId: room.teacherId,
        ownerTeacherName: room.teacherName,
        delegateTeacherId: delegate.id,
        delegateTeacherName: delegate.name,
        classroomId: room.id,
        classroomSection: room.section,
        hodId: room.hodId,
        reason: reason,
        startAt: startAt,
        endAt: endAt,
      );
      await widget.notificationService.createNotification(
        toUserId: delegate.id,
        fromUserId: widget.user.id,
        fromUserName: widget.user.name,
        title: 'Delegated Class Approval',
        message: 'HOD assigned you to handle ${room.section} until ${DateFormat('dd MMM yyyy').format(endAt)}.',
        type: 'hod_delegate',
        classroomId: room.id,
      );
      await widget.notificationService.createNotification(
        toUserId: room.teacherId,
        fromUserId: widget.user.id,
        fromUserName: widget.user.name,
        title: 'Delegation Updated',
        message: '${delegate.name} can now handle ${room.section} until ${DateFormat('dd MMM yyyy').format(endAt)}.',
        type: 'hod_delegate_info',
        classroomId: room.id,
      );
      await _loadData();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Delegation activated until ${DateFormat('dd MMM yyyy').format(endAt)}.',
          ),
        ),
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

  Future<void> _toggleHodSingleApprover(Classroom room) async {
    if (room.hasActiveHodDelegation) {
      final confirmed = await _confirmRevokeAccess('single approver');
      if (!confirmed) {
        return;
      }
      await widget.classroomService.clearTeacherAsHodDelegate(
        hod: widget.user,
        classroom: room,
      );
      await widget.notificationService.createNotification(
        toUserId: room.teacherId,
        fromUserId: widget.user.id,
        fromUserName: widget.user.name,
        title: 'Single Approver Revoked',
        message: 'HOD revoked your final approval access for ${room.section}.',
        type: 'hod_single_approver_revoked',
        classroomId: room.id,
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

    final activeDelegation = await widget.delegationService
        .findActiveDelegationForClassroom(
          ownerTeacherId: room.teacherId,
          classroomId: room.id,
        );
    if (activeDelegation != null) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Delegation is already active for this class, so single approver cannot be enabled now.',
          ),
        ),
      );
      return;
    }
    if (room.hasActiveTeacherDelegation) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Class incharge already routed new passes directly to HOD, so this single approver setting cannot be changed now.',
          ),
        ),
      );
      return;
    }

    final reasonController = TextEditingController(text: 'Class incharge handles final approval');
    final durationController = TextEditingController(text: '1');
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Enable Single Approver'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text(
                'During this period, once the class incharge approves a pass, it becomes finally approved.',
              ),
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
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
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
      final endAt = DateTime.now().add(Duration(days: days));
      await widget.classroomService.setHodAsSingleApprover(
        hod: widget.user,
        classroom: room,
        durationDays: days,
        reason: reason,
      );
      await widget.notificationService.createNotification(
        toUserId: room.teacherId,
        fromUserId: widget.user.id,
        fromUserName: widget.user.name,
        title: 'Single Approver Enabled',
        message: 'You are the final approver for ${room.section} until ${DateFormat('dd MMM yyyy').format(endAt)}.',
        type: 'hod_single_approver',
        classroomId: room.id,
      );
      await _loadData();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Class incharge can now fully approve passes until ${DateFormat('dd MMM yyyy').format(endAt)}.',
          ),
        ),
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

  Future<void> _joinOrganization() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Join Organization'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Enter College ID',
              hintText: 'e.g. MEPCO2024',
            ),
            textCapitalization: TextCapitalization.characters,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final id = controller.text.trim().toUpperCase();
                if (id.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a college ID.')),
                  );
                  return;
                }
                if (!colleges.containsKey(id)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invalid college ID.')),
                  );
                  return;
                }
                Navigator.pop(context, id);
              },
              child: const Text('Next'),
            ),
          ],
        );
      },
    );

    if (result == null) {
      return;
    }

    final collegeName = colleges[result]!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirm Organization'),
          content: Text('Join "$collegeName"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Join'),
            ),
          ],
        );
      },
    );

    if (confirm != true) {
      return;
    }

    try {
      final updatedUser = await widget.authService.updateProfile(
        user: widget.user,
        orgId: result,
      );
      if (!mounted) {
        return;
      }
      widget.onUserUpdated(updatedUser);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Joined $collegeName')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to join: $error')),
      );
    }
  }

  Future<bool> _confirmRevokeAccess(String label) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Revoke $label'),
          content: Text('Are you sure you want to revoke $label immediately?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Revoke'),
            ),
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
                      Text(
                        'Notifications',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
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
                              leading: Icon(
                                item.isRead
                                    ? Icons.notifications_none_outlined
                                    : Icons.notifications_active_outlined,
                                color: item.isRead ? null : Colors.orange.shade700,
                              ),
                              title: Text(item.title),
                              subtitle: Text(
                                '${item.message}\n${DateFormat('dd MMM, hh:mm a').format(item.createdAt)}',
                              ),
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
      drawer: DashboardDrawer(
        user: widget.user,
        title: 'HOD Dashboard',
        onProfile: _openProfile,
        onLogout: widget.onLogout,
        onSettings: _openSettings,
        footerNote: _canCreateMoreClasses
            ? null
            : 'Maximum class limit reached for your allowed years.',
      ),
      appBar: AppBar(
        title: _dashboardTitle('HOD Dashboard'),
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
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
      floatingActionButton: _canCreateMoreClasses
          ? FloatingActionButton.large(
              onPressed: _createClassroom,
              tooltip: 'Create Class',
              child: const Icon(Icons.add, size: 40),
            )
          : null,
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
                    _canCreateMoreClasses
                        ? 'Department: ${widget.user.department}\nUse + button to create classes.'
                        : 'Department: ${widget.user.department}\nMaximum class limit reached.',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (widget.user.orgId == null)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.business_outlined),
                    title: const Text('Join Organization'),
                    subtitle: const Text('Connect your department to a college organization.'),
                    trailing: ElevatedButton(
                      onPressed: _joinOrganization,
                      child: const Text('Join'),
                    ),
                  ),
                )
              else
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.business_outlined),
                    title: const Text('Organization'),
                    subtitle: Text('Connected to: ${colleges[widget.user.orgId] ?? widget.user.orgId}'),
                  ),
                ),
              const SizedBox(height: 12),
              _buildClassesCompactSection(),
              const SizedBox(height: 12),
              _buildPendingSummaryCard(pending),
              const SizedBox(height: 12),
              _buildHistorySummaryCard(history),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dashboardTitle(String text) {
    final isCompact = MediaQuery.of(context).size.width < 400;
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context)
          .appBarTheme
          .titleTextStyle
          ?.copyWith(fontSize: isCompact ? 21 : 24),
    );
  }

  Widget _buildClassesCompactSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Classes', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_classrooms.isEmpty)
              Text(_errorMessage ?? 'No classes found. Tap + to create your first class.')
            else
              _buildClassSelectorStrip(_classrooms),
          ],
        ),
      ),
    );
  }

  Widget _buildClassSelectorStrip(List<Classroom> rooms) {
    final sortedRooms = <Classroom>[...rooms]
      ..sort(
        (a, b) => classYears.indexOf(a.year).compareTo(classYears.indexOf(b.year)),
      );
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = sortedRooms.length.clamp(1, 3);
        final width = (constraints.maxWidth - ((count - 1) * 8)) / count;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: sortedRooms.map((room) {
            return SizedBox(
              width: width,
              child: _flatSelectionButton(
                label: room.year,
                onPressed: () => _openClassroomDetails(room),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildPendingSummaryCard(List<GatePassRequest> pending) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.pending_actions_outlined),
        title: const Text('Final Approval Queue'),
        subtitle: Text(
          pending.isEmpty
              ? 'No requests are waiting for final approval.'
              : '${pending.length} request${pending.length == 1 ? '' : 's'} waiting. Tap to view by year.',
        ),
        trailing: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          children: <Widget>[
            if (pending.isNotEmpty)
              CircleAvatar(
                radius: 12,
                backgroundColor: pending.length > 3 ? Colors.red : Colors.orange,
                child: Text(
                  '${pending.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: () => _openRequestCollectionPage(
          title: 'Final Approval Queue',
          requests: pending,
          emptyMessage: 'No requests waiting for HOD approval.',
          allowActions: true,
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
              ? 'No completed pass history yet.'
              : 'Tap to browse approved and rejected passes by year.',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _openRequestCollectionPage(
          title: 'Pass History',
          requests: history,
          emptyMessage: 'No completed pass history yet.',
          allowActions: false,
          showHistoryStyle: true,
        ),
      ),
    );
  }

  Widget _flatSelectionButton({
    required String label,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: Colors.grey.shade400),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.black87),
      ),
    );
  }
}
