import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/app_user.dart';
import '../../services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.user,
    required this.authService,
    required this.isDarkMode,
    required this.onUserUpdated,
    required this.onThemeChanged,
    required this.onLogout,
  });

  final AppUser user;
  final AuthService authService;
  final bool isDarkMode;
  final ValueChanged<AppUser> onUserUpdated;
  final ValueChanged<bool> onThemeChanged;
  final Future<void> Function() onLogout;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late AppUser _user;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _user = widget.user;
  }

  Future<void> _chooseImageSource() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Camera'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Gallery'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        );
      },
    );

    if (source == null) {
      return;
    }

    try {
      final image = await _picker.pickImage(source: source, imageQuality: 75);
      if (image == null) {
        return;
      }
      final bytes = await image.readAsBytes();
      final encoded = base64Encode(bytes);
      final updated = await widget.authService.updateProfile(
        user: _user,
        profileImageBase64: encoded,
      );
      if (!mounted) {
        return;
      }
      setState(() => _user = updated);
      widget.onUserUpdated(updated);
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to pick image right now.')),
      );
    }
  }

  Future<void> _openEditProfile() async {
    final updated = await Navigator.of(context).push<AppUser>(
      MaterialPageRoute<AppUser>(
        builder: (_) =>
            EditProfileScreen(user: _user, authService: widget.authService),
      ),
    );

    if (updated == null || !mounted) {
      return;
    }
    setState(() => _user = updated);
    widget.onUserUpdated(updated);
  }

  Future<void> _logout() async {
    await widget.onLogout();
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  Uint8List? get _profileBytes {
    final encoded = _user.profileImageBase64;
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
    final avatarBytes = _profileBytes;
    final showParentPhone = _user.role == 'Student';

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
        children: <Widget>[
          Center(
            child: InkWell(
              onTap: _chooseImageSource,
              borderRadius: BorderRadius.circular(60),
              child: Column(
                children: <Widget>[
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.grey.shade200,
                    backgroundImage: avatarBytes != null
                        ? MemoryImage(avatarBytes)
                        : null,
                    child: avatarBytes == null
                        ? const Icon(Icons.camera_alt_outlined, size: 30)
                        : null,
                  ),
                  const SizedBox(height: 6),
                  const Text('Tap to Upload Photo'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          _profileRow('name', _user.name),
          _profileRow('Department', _user.department),
          if (showParentPhone) _profileRow('Room no', _user.roomNumber ?? '-'),
          if (showParentPhone) _profileRow('Gender', _user.gender ?? '-'),
          _profileRow('phone no', _user.phoneNumber ?? '-'),
          if (showParentPhone)
            _profileRow('parents phone no', _user.parentPhoneNumber ?? '-'),
          const SizedBox(height: 20),
          _menuButton(label: 'Edit profile', onPressed: _openEditProfile),
          const SizedBox(height: 10),
          _menuButton(label: 'Log-out', onPressed: _logout),
        ],
      ),
    );
  }

  Widget _menuButton({required String label, required VoidCallback onPressed}) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(onPressed: onPressed, child: Text(label)),
    );
  }

  Widget _profileRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
            ),
          ),
          const Text(': ', style: TextStyle(fontWeight: FontWeight.w700)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
            ),
          ),
        ],
      ),
    );
  }
}

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({
    super.key,
    required this.user,
    required this.authService,
  });

  final AppUser user;
  final AuthService authService;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  static const List<String> _studentGenders = <String>[
    'Male',
    'Female',
    'Other',
  ];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _parentPhoneController;
  late final TextEditingController _roomNumberController;
  String? _gender;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.name);
    _phoneController = TextEditingController(
      text: widget.user.phoneNumber ?? '',
    );
    _parentPhoneController = TextEditingController(
      text: widget.user.parentPhoneNumber ?? '',
    );
    _roomNumberController = TextEditingController(
      text: widget.user.roomNumber ?? '',
    );
    _gender = widget.user.gender;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _parentPhoneController.dispose();
    _roomNumberController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final showParentPhone = widget.user.role == 'Student';
    setState(() => _saving = true);
    try {
      final updated = await widget.authService.updateProfile(
        user: widget.user,
        name: _nameController.text,
        gender: showParentPhone ? _gender : widget.user.gender,
        roomNumber: showParentPhone ? _roomNumberController.text : widget.user.roomNumber,
        phoneNumber: _phoneController.text,
        parentPhoneNumber: showParentPhone
            ? _parentPhoneController.text
            : widget.user.parentPhoneNumber,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(updated);
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to save profile now.')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final showParentPhone = widget.user.role == 'Student';
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name'),
              validator: (value) {
                if ((value ?? '').trim().isEmpty) {
                  return 'Name is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: widget.user.department,
              readOnly: true,
              decoration: const InputDecoration(labelText: 'Department'),
            ),
            if (showParentPhone) ...<Widget>[
              const SizedBox(height: 12),
              TextFormField(
                controller: _roomNumberController,
                decoration: const InputDecoration(labelText: 'Room Number'),
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return 'Room number is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _gender,
                decoration: const InputDecoration(labelText: 'Gender'),
                items: _studentGenders.map((gender) {
                  return DropdownMenuItem<String>(
                    value: gender,
                    child: Text(gender),
                  );
                }).toList(),
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return 'Gender is required';
                  }
                  return null;
                },
                onChanged: (value) {
                  setState(() => _gender = value);
                },
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone Number'),
            ),
            if (showParentPhone) ...<Widget>[
              const SizedBox(height: 12),
              TextFormField(
                controller: _parentPhoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Parent Phone Number',
                ),
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return 'Parent phone number is required';
                  }
                  return null;
                },
              ),
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Saving...' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }
}
