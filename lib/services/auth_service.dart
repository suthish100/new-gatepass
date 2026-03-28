import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  static const String _localSessionKey = 'auth_local_session_v1';

  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  Future<AppUser> register({
    required String name,
    required String email,
    required String role,
    required String department,
    String? year,
    String? hodType,
    String? gender,
    String? roomNumber,
    String? parentPhoneNumber,
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
        gender: gender?.trim(),
        roomNumber: roomNumber?.trim(),
        parentPhoneNumber: parentPhoneNumber?.trim(),
      );
      await _firestore.collection('users').doc(uid).set(user.toMap());
      _localSession = user;
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
      gender: gender?.trim(),
      roomNumber: roomNumber?.trim(),
      parentPhoneNumber: parentPhoneNumber?.trim(),
    );
    _localUsers[normalizedEmail] = _LocalUserRecord(
      user: localUser,
      password: password,
    );
    _localSession = localUser;
    await _persistLocalSession(localUser);
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
      await _ensureStudentProfileFields(uid: uid, data: data);
      final user = AppUser.fromMap(data, uid);
      _localSession = user;
      return user;
    }

    final local = _localUsers[normalizedEmail];
    if (local == null || local.password != password) {
      throw AuthException('Invalid email or password.');
    }
    _localSession = local.user;
    await _persistLocalSession(local.user);
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
    }
    _localSession = null;
    await _clearPersistedSession();
  }

  Future<AppUser?> restoreSession() async {
    if (FirebaseBootstrap.isReady) {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        _localSession = null;
        return null;
      }
      final snapshot = await _firestore.collection('users').doc(currentUser.uid).get();
      final data = snapshot.data();
      if (data == null) {
        await _auth.signOut();
        _localSession = null;
        return null;
      }
      await _ensureStudentProfileFields(uid: currentUser.uid, data: data);
      final user = AppUser.fromMap(data, currentUser.uid);
      _localSession = user;
      return user;
    }

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_localSessionKey);
    if ((raw ?? '').trim().isEmpty) {
      return _localSession;
    }

    try {
      final data = jsonDecode(raw!) as Map<String, dynamic>;
      final user = AppUser.fromMap(data, data['id'] as String? ?? '');
      _localSession = user;
      return user;
    } catch (_) {
      await prefs.remove(_localSessionKey);
      _localSession = null;
      return null;
    }
  }

  Future<List<AppUser>> fetchStudentsByDepartment(String department) async {
    if (FirebaseBootstrap.isReady) {
      final snapshot = await _firestore
          .collection('users')
          .where('department', isEqualTo: department)
          .get();
      return snapshot.docs
          .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
            return AppUser.fromMap(doc.data(), doc.id);
          })
          .where((user) => user.role == AppRoles.student)
          .toList();
    }

    return _localUsers.values
        .map((record) => record.user)
        .where(
          (user) =>
              user.role == AppRoles.student && user.department == department,
        )
        .toList();
  }

  Future<List<AppUser>> fetchTeachersByDepartment(
    String department, {
    String? orgId,
    Set<String> excludeUserIds = const <String>{},
  }) async {
    Iterable<AppUser> teachers;

    if (FirebaseBootstrap.isReady) {
      final snapshot = await _firestore
          .collection('users')
          .where('department', isEqualTo: department)
          .get();
      teachers = snapshot.docs
          .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
            return AppUser.fromMap(doc.data(), doc.id);
          })
          .where((user) => user.role == AppRoles.teacher);
    } else {
      teachers = _localUsers.values
          .map((record) => record.user)
          .where(
            (user) =>
                user.role == AppRoles.teacher && user.department == department,
          );
    }

    return teachers
        .where((user) => (orgId ?? '').isEmpty || user.orgId == orgId)
        .where((user) => !excludeUserIds.contains(user.id))
        .toList();
  }

  Future<AppUser?> getUserById(String userId) async {
    if (FirebaseBootstrap.isReady) {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return AppUser.fromMap(doc.data()!, doc.id);
      }
      return null;
    }

    return _localUsers.values
        .where((record) => record.user.id == userId)
        .map((record) => record.user)
        .firstOrNull;
  }

  Future<AppUser> updateProfile({
    required AppUser user,
    String? name,
    String? gender,
    String? roomNumber,
    String? phoneNumber,
    String? parentPhoneNumber,
    String? profileImageBase64,
    String? themeMode,
    String? orgId,
  }) async {
    final updatedUser = user.copyWith(
      name: name?.trim().isNotEmpty == true ? name!.trim() : user.name,
      gender: gender?.trim(),
      roomNumber: roomNumber?.trim(),
      phoneNumber: phoneNumber?.trim(),
      parentPhoneNumber: parentPhoneNumber?.trim(),
      profileImageBase64: profileImageBase64,
      themeMode: themeMode,
      orgId: orgId,
    );

    if (FirebaseBootstrap.isReady) {
      await _firestore
          .collection('users')
          .doc(user.id)
          .update(<String, dynamic>{
            'name': updatedUser.name,
            'gender': updatedUser.gender,
            'roomNumber': updatedUser.roomNumber,
            'phoneNumber': updatedUser.phoneNumber,
            'parentPhoneNumber': updatedUser.parentPhoneNumber,
            'profileImageBase64': updatedUser.profileImageBase64,
            'themeMode': updatedUser.themeMode,
            'orgId': updatedUser.orgId,
          });
      return updatedUser;
    }

    final localRecord = _localUsers[user.email];
    if (localRecord != null) {
      _localUsers[user.email] = _LocalUserRecord(
        user: updatedUser,
        password: localRecord.password,
      );
    }
    if (_localSession?.id == user.id) {
      _localSession = updatedUser;
      if (!FirebaseBootstrap.isReady) {
        await _persistLocalSession(updatedUser);
      }
    }
    return updatedUser;
  }

  AppUser? get localSession => _localSession;

  Future<void> _persistLocalSession(AppUser user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localSessionKey, jsonEncode(user.toMap()));
  }

  Future<void> _clearPersistedSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_localSessionKey);
  }

  Future<void> _ensureStudentProfileFields({
    required String uid,
    required Map<String, dynamic> data,
  }) async {
    if (data['role'] != AppRoles.student) {
      return;
    }
    final patch = <String, dynamic>{};
    if (!data.containsKey('gender')) {
      patch['gender'] = null;
      data['gender'] = null;
    }
    if (!data.containsKey('roomNumber')) {
      patch['roomNumber'] = data['registerNumber'];
      data['roomNumber'] = data['registerNumber'];
    }
    if (patch.isEmpty) {
      return;
    }
    await _firestore.collection('users').doc(uid).update(patch);
  }

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
          roomNumber: 'A-101',
          gender: 'Female',
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
