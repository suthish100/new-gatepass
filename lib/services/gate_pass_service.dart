import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants.dart';
import '../models/gate_pass_request.dart';
import 'firebase_bootstrap.dart';

class GatePassService {
  final List<GatePassRequest> _localRequests = <GatePassRequest>[
    GatePassRequest(
      id: 'seed_1',
      studentId: 'demo_student',
      name: 'Demo Student',
      registerNumber: '23CS001',
      studentClass: 'III Year',
      department: 'CSC',
      date: DateTime.now(),
      inTime: '09:00 AM',
      outTime: '12:00 PM',
      place: 'City Hospital',
      reason: 'Medical checkup',
      status: RequestStatus.pending,
      createdAt: DateTime.now().subtract(const Duration(hours: 4)),
    ),
  ];

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  Future<GatePassRequest> createRequest(GatePassRequest request) async {
    if (FirebaseBootstrap.isReady) {
      final doc = _firestore.collection('gate_pass_requests').doc();
      final newRequest = request.copyWith(id: doc.id);
      await doc.set(newRequest.toMap());
      return newRequest;
    }

    final local = request.copyWith(
      id: 'local_${DateTime.now().microsecondsSinceEpoch}',
    );
    _localRequests.insert(0, local);
    return local;
  }

  Future<List<GatePassRequest>> fetchStudentRequests(String studentId) async {
    if (FirebaseBootstrap.isReady) {
      final snapshot = await _firestore
          .collection('gate_pass_requests')
          .where('studentId', isEqualTo: studentId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((
        QueryDocumentSnapshot<Map<String, dynamic>> doc,
      ) {
        return GatePassRequest.fromMap(doc.data(), doc.id);
      }).toList();
    }

    return _localRequests
        .where((request) => request.studentId == studentId)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<List<GatePassRequest>> fetchDepartmentRequests(
    String department,
  ) async {
    if (FirebaseBootstrap.isReady) {
      final snapshot = await _firestore
          .collection('gate_pass_requests')
          .where('department', isEqualTo: department)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((
        QueryDocumentSnapshot<Map<String, dynamic>> doc,
      ) {
        return GatePassRequest.fromMap(doc.data(), doc.id);
      }).toList();
    }

    return _localRequests
        .where((request) => request.department == department)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> updateStatus({
    required String requestId,
    required String status,
    required String actedBy,
  }) async {
    if (FirebaseBootstrap.isReady) {
      await _firestore.collection('gate_pass_requests').doc(requestId).update(
        <String, dynamic>{'status': status, 'lastActionBy': actedBy},
      );
      return;
    }

    final index = _localRequests.indexWhere(
      (request) => request.id == requestId,
    );
    if (index == -1) {
      return;
    }
    _localRequests[index] = _localRequests[index].copyWith(
      status: status,
      lastActionBy: actedBy,
    );
  }
}
