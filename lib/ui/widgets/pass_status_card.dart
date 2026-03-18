import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../../models/gate_pass_request.dart';

/// Shows the live status timeline of a gate pass request.
/// Used in the "Pass Status" tab of the student dashboard.
class PassStatusCard extends StatelessWidget {
  const PassStatusCard({
    super.key,
    required this.request,
    required this.onViewPass,
  });

  final GatePassRequest request;
  final VoidCallback onViewPass;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('dd MMM yyyy');

    final isPendingTeacher = request.status == RequestStatus.pendingTeacher;
    final isForwardedHod = request.status == RequestStatus.forwardedToHod;
    final isApproved = request.status == RequestStatus.approved;
    final isRejectedByTeacher =
        request.status == RequestStatus.rejectedByTeacher;
    final isRejectedByHod = request.status == RequestStatus.rejectedByHod;
    final isRejected = isRejectedByTeacher || isRejectedByHod;

    Color statusColor = Colors.orange;
    if (isApproved) statusColor = Colors.green;
    if (isRejected) statusColor = Colors.red;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Pass header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha(25),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withAlpha(100)),
                  ),
                  child: Text(
                    request.status,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: request.isLeavePass
                        ? Colors.orange.shade50
                        : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    request.passType,
                    style: TextStyle(
                      color: request.isLeavePass
                          ? Colors.orange.shade700
                          : Colors.blue.shade700,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              request.isLeavePass
                  ? 'Leave: ${request.fromDate != null ? dateFormat.format(request.fromDate!) : "—"} → ${request.toDate != null ? dateFormat.format(request.toDate!) : "—"}'
                  : '${dateFormat.format(request.date)}  •  ${request.outTime} – ${request.inTime}',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              request.reason,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 16),

            // Status Timeline
            _timelineStep(
              context,
              label: 'Submitted',
              subLabel: DateFormat('dd MMM, hh:mm a').format(request.createdAt),
              state: _StepState.done,
            ),
            _timelineLine(),
            _timelineStep(
              context,
              label: 'Class Incharge Review',
              subLabel: isRejectedByTeacher
                  ? 'Rejected${request.cancelReason != null ? ": ${request.cancelReason}" : ""}'
                  : request.teacherActionAt != null
                  ? 'Approved — ${DateFormat('dd MMM, hh:mm a').format(request.teacherActionAt!)}'
                  : 'Awaiting review…',
              state: isRejectedByTeacher
                  ? _StepState.rejected
                  : request.teacherActionAt != null
                  ? _StepState.done
                  : _StepState.pending,
            ),
            _timelineLine(),
            _timelineStep(
              context,
              label: 'HOD Final Approval',
              subLabel: isRejectedByHod
                  ? 'Rejected${request.cancelReason != null ? ": ${request.cancelReason}" : ""}'
                  : isApproved
                  ? 'Approved — ${request.hodActionAt != null ? DateFormat('dd MMM, hh:mm a').format(request.hodActionAt!) : ""}'
                  : isPendingTeacher
                  ? 'Waiting for class incharge…'
                  : isForwardedHod
                  ? 'Awaiting HOD review…'
                  : '—',
              state: isRejectedByHod
                  ? _StepState.rejected
                  : isApproved
                  ? _StepState.done
                  : _StepState.pending,
            ),

            if (isApproved) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.qr_code),
                  label: const Text('View Gate Pass'),
                  onPressed: onViewPass,
                ),
              ),
            ],

            if (isRejected && request.cancelReason != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.cancel_outlined,
                      color: Colors.red.shade700,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Rejection Reason: ${request.cancelReason}',
                        style: TextStyle(
                          color: Colors.red.shade800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _timelineStep(
    BuildContext context, {
    required String label,
    required String subLabel,
    required _StepState state,
  }) {
    Color dotColor = Colors.grey.shade300;
    Widget dotContent = const SizedBox();
    if (state == _StepState.done) {
      dotColor = Colors.green.shade400;
      dotContent = const Icon(Icons.check, color: Colors.white, size: 12);
    } else if (state == _StepState.rejected) {
      dotColor = Colors.red.shade400;
      dotContent = const Icon(Icons.close, color: Colors.white, size: 12);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          child: Center(child: dotContent),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              Text(
                subLabel,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _timelineLine() {
    return Padding(
      padding: const EdgeInsets.only(left: 10, top: 3, bottom: 3),
      child: Container(width: 2, height: 20, color: Colors.grey.shade300),
    );
  }
}

enum _StepState { pending, done, rejected }
