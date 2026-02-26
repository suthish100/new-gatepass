import 'package:flutter/material.dart';

import '../../core/constants.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case RequestStatus.approved:
        color = const Color(0xFF1DE9B6);
      case RequestStatus.rejectedByTeacher:
      case RequestStatus.rejectedByHod:
        color = const Color(0xFFFF5A7A);
      case RequestStatus.forwardedToHod:
        color = const Color(0xFFFFD166);
      default:
        color = const Color(0xFF7C9EFF);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: 0.20),
        border: Border.all(color: color.withValues(alpha: 0.75)),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}
