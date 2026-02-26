import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../../models/app_user.dart';
import '../../models/classroom.dart';
import '../../services/gate_pass_service.dart';

/// Full-screen form for students to create a new gate pass request.
/// Supports both Outing Pass and Leave / Native Pass types.
class CreatePassScreen extends StatefulWidget {
  const CreatePassScreen({
    super.key,
    required this.student,
    required this.classrooms,
    required this.gatePassService,
    this.initialPassType,
  });

  final AppUser student;
  final List<Classroom> classrooms;
  final GatePassService gatePassService;
  final String? initialPassType;

  @override
  State<CreatePassScreen> createState() => _CreatePassScreenState();
}

class _CreatePassScreenState extends State<CreatePassScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _submitting = false;

  late Classroom _selectedClassroom;
  late String _selectedPassType;

  // Common fields
  final _reasonController = TextEditingController();
  final _registerController = TextEditingController();

  // Outing pass fields
  DateTime _outingDate = DateTime.now();
  String _outTime = '';
  String _inTime = '';

  // Leave pass fields
  DateTime _fromDate = DateTime.now();
  DateTime _toDate = DateTime.now().add(const Duration(days: 1));
  final _destinationController = TextEditingController();
  final _parentContactController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedClassroom = widget.classrooms.first;
    _selectedPassType = widget.initialPassType ?? PassType.outing;
    _registerController.text = widget.student.registerNumber ?? '';
    final now = TimeOfDay.now();
    _outTime = _formatTime(now);
    _inTime = _formatTime(TimeOfDay(
      hour: (now.hour + 2) % 24,
      minute: now.minute,
    ));
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _registerController.dispose();
    _destinationController.dispose();
    _parentContactController.dispose();
    super.dispose();
  }

  String _formatTime(TimeOfDay t) {
    final dt = DateTime(2000, 1, 1, t.hour, t.minute);
    return DateFormat('hh:mm a').format(dt);
  }

  Future<void> _pickOutingDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _outingDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 7)),
    );
    if (picked != null) setState(() => _outingDate = picked);
  }

  Future<void> _pickFromDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fromDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );
    if (picked == null) return;
    setState(() {
      _fromDate = picked;
      if (_toDate.isBefore(_fromDate)) {
        _toDate = _fromDate.add(const Duration(days: 1));
      }
    });
  }

  Future<void> _pickToDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _toDate.isAfter(_fromDate) ? _toDate : _fromDate,
      firstDate: _fromDate,
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );
    if (picked != null) setState(() => _toDate = picked);
  }

  Future<void> _pickTime({required bool isOut}) async {
    final initial = isOut ? TimeOfDay.now() : TimeOfDay.now();
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    final formatted = _formatTime(picked);
    setState(() {
      if (isOut) {
        _outTime = formatted;
      } else {
        _inTime = formatted;
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Extra validation for leave pass
    if (_selectedPassType == PassType.leave) {
      if (_destinationController.text.trim().isEmpty) {
        _showError('Please enter your destination.');
        return;
      }
    }

    setState(() => _submitting = true);
    try {
      await widget.gatePassService.createRequest(
        student: widget.student,
        classroom: _selectedClassroom,
        registerNumber: _registerController.text,
        passType: _selectedPassType,
        date: _selectedPassType == PassType.leave ? _fromDate : _outingDate,
        outTime: _selectedPassType == PassType.leave ? '' : _outTime,
        inTime: _selectedPassType == PassType.leave ? '' : _inTime,
        reason: _reasonController.text,
        fromDate: _selectedPassType == PassType.leave ? _fromDate : null,
        toDate: _selectedPassType == PassType.leave ? _toDate : null,
        destination: _selectedPassType == PassType.leave
            ? _destinationController.text
            : null,
        parentContact: _selectedPassType == PassType.leave
            ? _parentContactController.text
            : null,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('dd MMM yyyy');
    final isLeave = _selectedPassType == PassType.leave;

    return Scaffold(
      appBar: AppBar(title: const Text('Create Gate Pass Request')),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pass type selector
              Text('Pass Type', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment<String>(
                    value: PassType.outing,
                    label: Text('Outing Pass'),
                    icon: Icon(Icons.logout, size: 18),
                  ),
                  ButtonSegment<String>(
                    value: PassType.leave,
                    label: Text('Leave / Native'),
                    icon: Icon(Icons.home_outlined, size: 18),
                  ),
                ],
                selected: {_selectedPassType},
                onSelectionChanged: (s) =>
                    setState(() => _selectedPassType = s.first),
              ),

              const SizedBox(height: 20),

              // Class selector
              Text('Class', style: theme.textTheme.titleSmall),
              const SizedBox(height: 6),
              DropdownButtonFormField<Classroom>(
                value: _selectedClassroom,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                items: widget.classrooms.map((room) {
                  return DropdownMenuItem<Classroom>(
                    value: room,
                    child: Text(room.section),
                  );
                }).toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _selectedClassroom = v);
                },
              ),

              const SizedBox(height: 16),

              // Register number
              TextFormField(
                controller: _registerController,
                decoration: const InputDecoration(
                  labelText: 'Register Number *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),

              const SizedBox(height: 20),

              if (isLeave) ...[
                // ─── Leave Pass Fields ─────────────────────────────────────
                Text('Leave Dates', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _datePickerTile(
                        label: 'From Date',
                        value: dateFormat.format(_fromDate),
                        onTap: _pickFromDate,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _datePickerTile(
                        label: 'To Date',
                        value: dateFormat.format(_toDate),
                        onTap: _pickToDate,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Duration: ${_toDate.difference(_fromDate).inDays + 1} day(s)',
                    style: TextStyle(
                      color: Colors.orange.shade800,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                const SizedBox(height: 16),
                TextFormField(
                  controller: _destinationController,
                  decoration: const InputDecoration(
                    labelText: 'Destination / Native Place *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),

                const SizedBox(height: 14),
                TextFormField(
                  controller: _parentContactController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Parent / Guardian Contact',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone_outlined),
                    hintText: 'Optional but recommended',
                  ),
                ),
              ] else ...[
                // ─── Outing Pass Fields ────────────────────────────────────
                Text('Outing Date & Time', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                _datePickerTile(
                  label: 'Date',
                  value: dateFormat.format(_outingDate),
                  onTap: _pickOutingDate,
                  fullWidth: true,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _timePickerTile(
                        label: 'Out Time',
                        value: _outTime,
                        onTap: () => _pickTime(isOut: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _timePickerTile(
                        label: 'In Time',
                        value: _inTime,
                        onTap: () => _pickTime(isOut: false),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 16),

              // Reason
              TextFormField(
                controller: _reasonController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: isLeave
                      ? 'Reason for Leave *'
                      : 'Reason for Outing *',
                  border: const OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),

              const SizedBox(height: 24),

              // Info note
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: Colors.blue.shade700, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Your request will go to Class Incharge → HOD → You get the approved pass.',
                        style: TextStyle(
                          color: Colors.blue.shade900,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_outlined),
                  label: Text(
                    _submitting
                        ? 'Submitting...'
                        : 'Send to Class Incharge',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _datePickerTile({
    required String label,
    required String value,
    required VoidCallback onTap,
    bool fullWidth = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: fullWidth ? double.infinity : null,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(color: Colors.grey, fontSize: 11)),
            const SizedBox(height: 2),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 14),
                const SizedBox(width: 4),
                Text(value,
                    style: const TextStyle(fontWeight: FontWeight.w500)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _timePickerTile({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(color: Colors.grey, fontSize: 11)),
            const SizedBox(height: 2),
            Row(
              children: [
                const Icon(Icons.access_time, size: 14),
                const SizedBox(width: 4),
                Text(value,
                    style: const TextStyle(fontWeight: FontWeight.w500)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
