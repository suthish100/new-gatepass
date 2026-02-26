import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/constants.dart';
import '../models/app_user.dart';
import 'firebase_bootstrap.dart';

class AuthService {
  AuthService() {
    _seedLocalUsers();
  }

  final Map<String, _LocalUserRecord> _localUsers =
      <String, _LocalUserRecord>{};
  AppUser? _localSession;

  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  Future<AppUser> register({
    required String name,
    required String email,
    required String role,
    required String department,
    String? year,
    String? hodType,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();

    if (FirebaseBootstrap.isReady) {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );
      final uid = credential.user!.uid;
      final user = AppUser(
        id: uid,
        name: name.trim(),
        email: normalizedEmail,
        role: role,
        department: department,
        year: year,
        hodType: hodType,
      );
      await _firestore.collection('users').doc(uid).set(user.toMap());
      return user;
    }

    if (_localUsers.containsKey(normalizedEmail)) {
      throw AuthException('User already exists with this email.');
    }

    final localUser = AppUser(
      id: 'local_${DateTime.now().microsecondsSinceEpoch}',
      name: name.trim(),
      email: normalizedEmail,
      role: role,
      department: department,
      year: year,
      hodType: hodType,
    );
    _localUsers[normalizedEmail] = _LocalUserRecord(
      user: localUser,
      password: password,
    );
    _localSession = localUser;
    return localUser;
  }

  Future<AppUser> login({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();

    if (FirebaseBootstrap.isReady) {
      final credential = await _auth.signInWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );
      final uid = credential.user!.uid;
      final snapshot = await _firestore.collection('users').doc(uid).get();
      final data = snapshot.data();
      if (data == null) {
        throw AuthException(
          'User profile not found. Please complete registration first.',
        );
      }
      return AppUser.fromMap(data, uid);
    }

    final local = _localUsers[normalizedEmail];
    if (local == null || local.password != password) {
      throw AuthException('Invalid email or password.');
    }
    _localSession = local.user;
    return local.user;
  }

  Future<AppUser> loginForRole({
    required String email,
    required String password,
    required String role,
  }) async {
    final user = await login(email: email, password: password);
    if (user.role != role) {
      throw AuthException('Use $role login for this account.');
    }
    return user;
  }

  Future<void> logout() async {
    if (FirebaseBootstrap.isReady) {
      await _auth.signOut();
      return;
    }
    _localSession = null;
  }

  Future<List<AppUser>> fetchStudentsByDepartment(String department) async {
    if (FirebaseBootstrap.isReady) {
      final snapshot = await _firestore
          .collection('users')
          .where('department', isEqualTo: department)
          .where('role', isEqualTo: 'Student')
          .get();
      return snapshot.docs.map((
        QueryDocumentSnapshot<Map<String, dynamic>> doc,
      ) {
        return AppUser.fromMap(doc.data(), doc.id);
      }).toList();
    }

    return _localUsers.values
        .map((record) => record.user)
        .where(
          (user) => user.role == 'Student' && user.department == department,
        )
        .toList();
  }

  AppUser? get localSession => _localSession;

  void _seedLocalUsers() {
    if (FirebaseBootstrap.isReady || _localUsers.isNotEmpty) {
      return;
    }
    final seedUsers = <_LocalUserRecord>[
      _LocalUserRecord(
        user: const AppUser(
          id: 'seed_hod_1',
          name: 'HOD Admin',
          email: 'hod@egatepass.com',
          role: 'HOD',
          department: 'AI&DS',
          hodType: HodType.senior,
        ),
        password: '123456',
      ),
      _LocalUserRecord(
        user: const AppUser(
          id: 'seed_teacher_1',
          name: 'Class Incharge',
          email: 'teacher@egatepass.com',
          role: 'Teacher',
          department: 'AI&DS',
          year: '3rd Year',
        ),
        password: '123456',
      ),
      _LocalUserRecord(
        user: const AppUser(
          id: 'seed_student_1',
          name: 'Alice Smith',
          email: 'student@egatepass.com',
          role: 'Student',
          department: 'AI&DS',
          year: '3rd Year',
        ),
        password: '123456',
      ),
    ];

    for (final record in seedUsers) {
      _localUsers[record.user.email] = record;
    }
  }
}

class AuthException implements Exception {
  AuthException(this.message);
  final String message;

  @override
  String toString() => message;
}

class _LocalUserRecord {
  const _LocalUserRecord({required this.user, required this.password});

  final AppUser user;
  final String password;
}
