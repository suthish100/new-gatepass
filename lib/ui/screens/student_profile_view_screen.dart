import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../models/app_user.dart';

class StudentProfileViewScreen extends StatelessWidget {
  const StudentProfileViewScreen({super.key, required this.student});

  final AppUser student;

  Uint8List? get _profileImageBytes {
    final encoded = student.profileImageBase64;
    if ((encoded ?? '').isEmpty) {
      return null;
    }
    try {
      return base64Decode(encoded!);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageBytes = _profileImageBytes;

    return Scaffold(
      appBar: AppBar(title: const Text('Student Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                colors: <Color>[
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.secondary,
                ],
              ),
            ),
            child: Column(
              children: <Widget>[
                CircleAvatar(
                  radius: 42,
                  backgroundImage: imageBytes == null ? null : MemoryImage(imageBytes),
                  child: imageBytes == null
                      ? const Icon(Icons.person_outline, size: 38)
                      : null,
                ),
                const SizedBox(height: 12),
                Text(
                  student.name,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  student.email,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _infoTile(context, 'Department', student.department),
          _infoTile(context, 'Year', student.year ?? '-'),
          _infoTile(context, 'Gender', student.gender ?? '-'),
          _infoTile(context, 'Room No', student.roomNumber ?? '-'),
          _infoTile(context, 'Phone', student.phoneNumber ?? '-'),
          _infoTile(context, 'Parent Phone', student.parentPhoneNumber ?? '-'),
          _infoTile(context, 'Organization', student.orgId ?? '-'),
        ],
      ),
    );
  }

  Widget _infoTile(BuildContext context, String label, String value) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        title: Text(label),
        subtitle: Text(value),
      ),
    );
  }
}
