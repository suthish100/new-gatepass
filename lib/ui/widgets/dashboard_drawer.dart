import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../models/app_user.dart';

class DashboardDrawer extends StatelessWidget {
  const DashboardDrawer({
    super.key,
    required this.user,
    required this.title,
    required this.onProfile,
    required this.onLogout,
    required this.onSettings,
    this.footerNote,
  });

  final AppUser user;
  final String title;
  final VoidCallback onProfile;
  final VoidCallback onLogout;
  final VoidCallback onSettings;
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
        padding: EdgeInsets.zero,
        children: <Widget>[
          DrawerHeader(
            margin: EdgeInsets.zero,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.secondary,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: LayoutBuilder(
              builder: (_, constraints) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (imageBytes != null)
                      CircleAvatar(
                        radius: 22,
                        backgroundImage: MemoryImage(imageBytes),
                      )
                    else
                      const CircleAvatar(
                        radius: 22,
                        child: Icon(Icons.person_outline, size: 22),
                      ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: constraints.maxWidth,
                      child: Text(
                        user.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${user.department} • ${user.role}',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('Settings'),
            onTap: () {
              Navigator.pop(context);
              onSettings();
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
          ListTile(
            leading: const Icon(Icons.exit_to_app_outlined),
            title: const Text('Logout'),
            onTap: () {
              Navigator.pop(context);
              onLogout();
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
