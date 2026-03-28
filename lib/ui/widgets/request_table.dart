import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/gate_pass_request.dart';
import 'status_badge.dart';

class RequestTable extends StatelessWidget {
  const RequestTable({
    super.key,
    required this.requests,
    this.actionsBuilder,
    this.emptyMessage = 'No requests found.',
  });

  final List<GatePassRequest> requests;
  final Widget Function(BuildContext context, GatePassRequest request)?
  actionsBuilder;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      return Center(
        child: Text(
          emptyMessage,
          style: const TextStyle(color: Colors.white70),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 18,
        headingTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
        dataTextStyle: const TextStyle(color: Colors.white),
        columns: const <DataColumn>[
          DataColumn(label: Text('Name')),
          DataColumn(label: Text('Room No')),
          DataColumn(label: Text('Class')),
          DataColumn(label: Text('Date')),
          DataColumn(label: Text('Out Time')),
          DataColumn(label: Text('Status')),
          DataColumn(label: Text('Actions')),
        ],
        rows: requests.map((request) {
          return DataRow(
            cells: <DataCell>[
              DataCell(
                SizedBox(
                  width: 120,
                  child: Text(
                    request.studentName,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              DataCell(Text(request.roomNumber)),
              DataCell(Text(request.studentClass)),
              DataCell(Text(DateFormat('dd MMM').format(request.date))),
              DataCell(Text(request.outTime)),
              DataCell(StatusBadge(status: request.status)),
              DataCell(
                actionsBuilder?.call(context, request) ?? const Text('-'),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}
