import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../models/app_user.dart';

class DashboardDrawer extends StatelessWidget {
  const DashboardDrawer({
    super.key,
    required this.user,
    required this.title,
    required this.onRefresh,
    required this.onProfile,
    this.footerNote,
  });

  final AppUser user;
  final String title;
  final VoidCallback onRefresh;
  final VoidCallback onProfile;
  final String? footerNote;

  Uint8List? get _profileImageBytes {
    final encoded = user.profileImageBase64;
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

    return Drawer(
      child: ListView(
        children: <Widget>[
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                if (imageBytes != null)
                  CircleAvatar(
                    radius: 22,
                    backgroundImage: MemoryImage(imageBytes),
                  )
                else
                  const CircleAvatar(
                    radius: 22,
                    child: Icon(Icons.person_outline),
                  ),
                const SizedBox(height: 10),
                Text(
                  user.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${user.department} • ${user.role}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard_outlined),
            title: const Text('Dashboard'),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.refresh),
            title: const Text('Refresh'),
            onTap: () {
              Navigator.pop(context);
              onRefresh();
            },
          ),
          ListTile(
            leading: const Icon(Icons.account_circle_outlined),
            title: const Text('Profile'),
            onTap: () {
              Navigator.pop(context);
              onProfile();
            },
          ),
          if ((footerNote ?? '').trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(
                footerNote!,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
              ),
            ),
        ],
      ),
    );
  }
}
