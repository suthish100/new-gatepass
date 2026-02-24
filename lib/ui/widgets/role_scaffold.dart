import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/app_user.dart';
import 'glass_card.dart';
import 'neon_background.dart';

class SidebarItem {
  const SidebarItem({required this.label, required this.icon});

  final String label;
  final IconData icon;
}

class RoleScaffold extends StatelessWidget {
  const RoleScaffold({
    super.key,
    required this.title,
    required this.user,
    required this.sidebarItems,
    required this.selectedIndex,
    required this.onSelectSidebar,
    required this.onLogout,
    required this.body,
  });

  final String title;
  final AppUser user;
  final List<SidebarItem> sidebarItems;
  final int selectedIndex;
  final ValueChanged<int> onSelectSidebar;
  final VoidCallback onLogout;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return NeonBackground(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900;
          if (isWide) {
            return Scaffold(
              backgroundColor: Colors.transparent,
              body: SafeArea(
                child: Row(
                  children: <Widget>[
                    SizedBox(
                      width: 265,
                      child: _Sidebar(
                        title: title,
                        user: user,
                        sidebarItems: sidebarItems,
                        selectedIndex: selectedIndex,
                        onSelectSidebar: onSelectSidebar,
                        onLogout: onLogout,
                      ),
                    ),
                    Expanded(
                      child: _Content(title: title, body: body),
                    ),
                  ],
                ),
              ),
            );
          }

          return Scaffold(
            backgroundColor: Colors.transparent,
            drawer: Drawer(
              backgroundColor: const Color(0xDD050912),
              child: SafeArea(
                child: _Sidebar(
                  title: title,
                  user: user,
                  sidebarItems: sidebarItems,
                  selectedIndex: selectedIndex,
                  onSelectSidebar: (index) {
                    onSelectSidebar(index);
                    Navigator.pop(context);
                  },
                  onLogout: onLogout,
                ),
              ),
            ),
            body: SafeArea(
              child: _Content(
                title: title,
                body: body,
                mobileMenu: Builder(
                  builder: (context) {
                    return IconButton(
                      onPressed: () => Scaffold.of(context).openDrawer(),
                      icon: const Icon(Icons.menu),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.title,
    required this.user,
    required this.sidebarItems,
    required this.selectedIndex,
    required this.onSelectSidebar,
    required this.onLogout,
  });

  final String title;
  final AppUser user;
  final List<SidebarItem> sidebarItems;
  final int selectedIndex;
  final ValueChanged<int> onSelectSidebar;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'E-GatePass',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: 20),
            _UserMiniCard(user: user),
            const SizedBox(height: 14),
            ...sidebarItems.indexed.map((entry) {
              final index = entry.$1;
              final item = entry.$2;
              final selected = index == selectedIndex;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  selected: selected,
                  selectedColor: const Color(0xFF16F5C6),
                  selectedTileColor: Colors.white.withValues(alpha: 0.10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  onTap: () => onSelectSidebar(index),
                  leading: Icon(item.icon),
                  title: Text(item.label),
                ),
              );
            }),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onLogout,
                icon: const Icon(Icons.logout),
                label: const Text('Logout'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserMiniCard extends StatelessWidget {
  const _UserMiniCard({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withValues(alpha: 0.08),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: <Color>[Color(0xFF2D7BFF), Color(0xFF16F5C6)],
              ),
            ),
            child: const Icon(Icons.person, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  user.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  '${user.department} • ${user.role}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.title, required this.body, this.mobileMenu});

  final String title;
  final Widget body;
  final Widget? mobileMenu;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        children: <Widget>[
          GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: <Widget>[
                if (mobileMenu != null) ...<Widget>[
                  mobileMenu!,
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Notifications',
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('No new notifications')),
                    );
                  },
                  icon: const Icon(Icons.notifications_active_outlined),
                ),
                IconButton(
                  tooltip: 'Sound',
                  onPressed: () {
                    SystemSound.play(SystemSoundType.click);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Click sound played')),
                    );
                  },
                  icon: const Icon(Icons.graphic_eq_outlined),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Expanded(child: body),
        ],
      ),
    );
  }
}
