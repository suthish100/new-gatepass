import 'package:flutter/material.dart';

class ChangeThemeScreen extends StatefulWidget {
  const ChangeThemeScreen({
    super.key,
    required this.isDarkMode,
    required this.onThemeChanged,
  });

  final bool isDarkMode;
  final ValueChanged<bool> onThemeChanged;

  @override
  State<ChangeThemeScreen> createState() => _ChangeThemeScreenState();
}

class _ChangeThemeScreenState extends State<ChangeThemeScreen> {
  late bool _isDarkMode;

  @override
  void initState() {
    super.initState();
    _isDarkMode = widget.isDarkMode;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Change Theme')),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const <Widget>[
                Text(
                  'Light',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 38),
                ),
                Text(
                  'Dark',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 38),
                ),
              ],
            ),
            const SizedBox(height: 30),
            Center(
              child: Transform.scale(
                scale: 2,
                child: Switch(
                  value: _isDarkMode,
                  onChanged: (value) {
                    setState(() => _isDarkMode = value);
                    widget.onThemeChanged(value);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
