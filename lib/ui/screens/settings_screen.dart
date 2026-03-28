import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.isDarkMode,
    required this.onThemeChanged,
    required this.onLogout,
  });

  final bool isDarkMode;
  final ValueChanged<bool> onThemeChanged;
  final Future<void> Function() onLogout;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _pinCodeKey = 'pin_lock_code';

  bool _pinLockEnabled = false;
  String? _pinCode;

  @override
  void initState() {
    super.initState();
    _loadPinState();
  }

  Future<void> _loadPinState() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_pinCodeKey);
    if (!mounted) return;
    setState(() {
      _pinCode = code;
      _pinLockEnabled = code != null && code.isNotEmpty;
    });
  }

  Future<void> _setPin() async {
    final controller = TextEditingController(text: _pinCode ?? '');

    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Set PIN Lock'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Enter 4-digit PIN',
              hintText: '1234',
            ),
            maxLength: 6,
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final clean = controller.text.trim();
                if (clean.length < 4) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Enter at least 4 digits.')),
                  );
                  return;
                }
                Navigator.pop(context, clean);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (result == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pinCodeKey, result);
    if (!mounted) return;
    setState(() {
      _pinCode = result;
      _pinLockEnabled = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('PIN lock enabled.')),
    );
  }

  Future<void> _disablePin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pinCodeKey);
    if (!mounted) return;
    setState(() {
      _pinCode = null;
      _pinLockEnabled = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('PIN lock disabled.')),
    );
  }

  Future<void> _togglePinLock(bool value) async {
    if (value) {
      await _setPin();
      return;
    }
    await _disablePin();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        children: <Widget>[
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Column(
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.color_lens_outlined),
                  title: const Text('Theme'),
                  subtitle: Text(widget.isDarkMode ? 'Dark mode' : 'Light mode'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () async {
                    final toggled = !widget.isDarkMode;
                    widget.onThemeChanged(toggled);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Theme set to ${toggled ? 'Dark' : 'Light'}')),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.pin_outlined),
                  title: const Text('PIN lock'),
                  subtitle: Text(_pinLockEnabled ? 'Enabled' : 'Disabled'),
                  trailing: Switch(
                    value: _pinLockEnabled,
                    onChanged: _togglePinLock,
                  ),
                  onTap: () async {
                    if (_pinLockEnabled) {
                      await _disablePin();
                    } else {
                      await _setPin();
                    }
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.logout_outlined),
                  title: const Text('Logout'),
                  onTap: () async {
                    await widget.onLogout();
                    if (!mounted) return;
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
