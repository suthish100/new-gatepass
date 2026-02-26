import 'package:flutter/material.dart';

class JoinClassScreen extends StatefulWidget {
  const JoinClassScreen({super.key, required this.onJoin, this.initialCode});

  final Future<bool> Function(String code) onJoin;
  final String? initialCode;

  @override
  State<JoinClassScreen> createState() => _JoinClassScreenState();
}

class _JoinClassScreenState extends State<JoinClassScreen> {
  final TextEditingController _codeController = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    if ((widget.initialCode ?? '').trim().isNotEmpty) {
      _codeController.text = widget.initialCode!.trim();
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) {
      return;
    }

    final code = _codeController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a class code.')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final joined = await widget.onJoin(code);
      if (!mounted) {
        return;
      }
      if (joined) {
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'join class',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontSize: 30,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF232831),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
        children: <Widget>[
          const SizedBox(height: 16),
          const Text(
            'Enter the unique class code shared by your class incharge or HOD.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF7A7F87),
              fontSize: 16,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _codeController,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(hintText: 'eg. xyc-huhd-vdh'),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 16),
          const Text(
            'Staff must use HOD staff code.\nStudents must use teacher student code.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF8D939A),
              fontSize: 13,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 36),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('join class'),
            ),
          ),
        ],
      ),
    );
  }
}
