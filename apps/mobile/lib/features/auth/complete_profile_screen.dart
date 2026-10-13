import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/virello_ui.dart';
import '../../main.dart';

/// Post-signup profile completion: Hafiz 2026-10-13.
/// Asks for name, profile picture, and cover photo right after signup.
/// ALL OPTIONAL — user can skip entirely or fill partially.
/// Each saves independently via PATCH /api/v1/users/me.
class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key});
  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _picker = ImagePicker();
  File? _avatarFile;
  File? _coverFile;
  bool _saving = false;

  AppStrings get s => AppStrings(appState.localeCode);

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(bool isAvatar) async {
    try {
      final x = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (x == null) return;
      setState(() {
        if (isAvatar) {
          _avatarFile = File(x.path);
        } else {
          _coverFile = File(x.path);
        }
      });
    } catch (_) {}
  }

  /// Save whatever the user provided (name/avatar/cover independently),
  /// then finish. Skipping saves nothing.
  Future<void> _done({required bool skip}) async {
    if (skip) {
      _finish();
      return;
    }
    final name = _nameCtrl.text.trim();
    if (name.isEmpty && _avatarFile == null && _coverFile == null) {
      _finish();
      return;
    }
    setState(() => _saving = true);
    try {
      if (name.isNotEmpty) {
        await apiClient.updateName(name);
      }
      if (_avatarFile != null) {
        try {
          final up = await apiClient.uploadFile(_avatarFile!.path);
          final url = up['url'] as String?;
          if (url != null && url.isNotEmpty) {
            await apiClient.updateAvatar(url);
          }
        } catch (_) {}
      }
      if (_coverFile != null) {
        try {
          final up = await apiClient.uploadFile(_coverFile!.path);
          final url = up['url'] as String?;
          if (url != null && url.isNotEmpty) {
            await apiClient.updateCover(url);
          }
        } catch (_) {}
      }
      try {
        final me = await apiClient.me();
        if (mounted) authStore.refreshProfile(me);
      } catch (_) {}
    } catch (_) {
      // Profile completion is best-effort; never block the user.
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    _finish();
  }

  void _finish() {
    // AuthStore notifies; main.dart swaps to the app shell.
    // This screen was pushed on top; pop back to let the shell take over.
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(s.completeProfileTitle),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => _done(skip: true),
            child: Text(s.skip),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            Text(
              s.completeProfileHint,
              style: TextStyle(
                fontSize: 14,
                color: VTheme.textSec(context),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            // Cover photo picker
            GestureDetector(
              onTap: _saving ? null : () => _pickImage(false),
              child: Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: VTheme.card(context),
                  border: Border.all(color: VTheme.divider(context)),
                ),
                child: _coverFile != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.file(_coverFile!, fit: BoxFit.cover),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_outlined,
                              color: VTheme.textSec(context), size: 28),
                          const SizedBox(height: 6),
                          Text(s.changeCoverPhoto,
                              style: TextStyle(
                                  color: VTheme.textSec(context),
                                  fontSize: 13)),
                          Text(s.optional,
                              style: TextStyle(
                                  color: VTheme.textSec(context),
                                  fontSize: 11)),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 20),
            // Avatar picker
            Center(
              child: GestureDetector(
                onTap: _saving ? null : () => _pickImage(true),
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 48,
                      backgroundColor:
                          VirelloColors.pink.withValues(alpha: 0.14),
                      backgroundImage: _avatarFile != null
                          ? FileImage(_avatarFile!)
                          : null,
                      child: _avatarFile == null
                          ? Icon(Icons.person_add_alt_outlined,
                              size: 36, color: VTheme.textSec(context))
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: VirelloColors.pink,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.camera_alt,
                            size: 16, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: Text(s.addProfilePhoto,
                  style: TextStyle(
                      color: VTheme.textSec(context), fontSize: 12)),
            ),
            const SizedBox(height: 20),
            // Name field
            TextField(
              controller: _nameCtrl,
              enabled: !_saving,
              decoration: InputDecoration(
                labelText: '${s.nameLabel} (${s.optional})',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _done(skip: false),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: VPinkButton(
                label: s.done,
                onPressed: _saving ? null : () => _done(skip: false),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
