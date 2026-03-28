import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../../models/gate_pass_request.dart';

class RequestCollectionScreen extends StatefulWidget {
  const RequestCollectionScreen({
    super.key,
    required this.title,
    required this.requests,
    required this.emptyMessage,
    required this.onRequestTap,
    this.showHistoryStyle = false,
  });

  final String title;
  final List<GatePassRequest> requests;
  final String emptyMessage;
  final Future<void> Function(GatePassRequest request) onRequestTap;
  final bool showHistoryStyle;

  @override
  State<RequestCollectionScreen> createState() => _RequestCollectionScreenState();
}

class _RequestCollectionScreenState extends State<RequestCollectionScreen> {
  String? _selectedYear;

  @override
  void initState() {
    super.initState();
    final years = _yearsFromRequests(widget.requests);
    _selectedYear = years.isEmpty ? null : years.first;
  }

  @override
  Widget build(BuildContext context) {
    final years = _yearsFromRequests(widget.requests);
    final selectedYear = years.contains(_selectedYear)
        ? _selectedYear
        : (years.isEmpty ? null : years.first);
    final filtered = selectedYear == null
        ? widget.requests
        : widget.requests
              .where((item) => item.studentClass == selectedYear)
              .toList();

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        child: widget.requests.isEmpty
            ? Center(child: Text(widget.emptyMessage))
            : ListView(
                padding: const EdgeInsets.all(16),
                children: <Widget>[
                  Text(
                    'Browse by year',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: years.map((year) {
                      final selected = year == selectedYear;
                      return OutlinedButton(
                        onPressed: () => setState(() => _selectedYear = year),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: selected ? Colors.black12 : null,
                          side: BorderSide(
                            color: selected
                                ? Colors.black54
                                : Colors.grey.shade400,
                          ),
                        ),
                        child: Text(
                          year,
                          style: const TextStyle(color: Colors.black87),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  ...filtered.map(_buildRequestTile),
                ],
              ),
      ),
    );
  }

  Widget _buildRequestTile(GatePassRequest request) {
    final approved = request.status == RequestStatus.approved;
    final rejected = request.status == RequestStatus.rejectedByTeacher ||
        request.status == RequestStatus.rejectedByHod;

    final icon = !widget.showHistoryStyle
        ? Icons.pending_actions_outlined
        : approved
            ? Icons.check_circle
            : rejected
                ? Icons.cancel
                : Icons.forward_to_inbox_outlined;
    final iconColor = !widget.showHistoryStyle
        ? Colors.orange
        : approved
            ? Colors.green
            : rejected
                ? Colors.red
                : Colors.orange;

    final subtitle = widget.showHistoryStyle
        ? '${request.studentClass}\n'
            '${DateFormat('dd MMM yyyy').format(request.date)} | ${request.status}'
        : '${request.studentClass}\n'
            '${DateFormat('dd MMM').format(request.date)} | ${request.outTime} - ${request.inTime}';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(icon, color: iconColor),
        title: Text('${request.studentName} - ${request.passType}'),
        subtitle: Text(subtitle),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right),
        onTap: () => widget.onRequestTap(request),
      ),
    );
  }

  List<String> _yearsFromRequests(List<GatePassRequest> requests) {
    final present = requests.map((item) => item.studentClass).toSet();
    final ordered = classYears.where(present.contains).toList();
    for (final value in present) {
      if (!ordered.contains(value)) {
        ordered.add(value);
      }
    }
    return ordered;
  }
}
