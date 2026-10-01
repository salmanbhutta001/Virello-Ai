import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../main.dart';

/// Shown when an account is not authorized for admin access.
class AdminDeniedScreen extends StatelessWidget {
  final String reason;

  const AdminDeniedScreen({super.key, required this.reason});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings(appState.localeCode);
    return Scaffold(
      appBar: AppBar(
        title: Text(s.adminPanel),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_outline,
                  size: 64,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                s.accessDenied,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                reason,
                style: TextStyle(
                  fontSize: 15,
                  color: VTheme.textSec(context),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(s.goBack),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
