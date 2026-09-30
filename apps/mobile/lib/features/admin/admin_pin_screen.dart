import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../main.dart';
import '../../services/admin_api.dart';
import '../../services/api_client.dart';

/// Hidden admin entry: numeric PIN pad. A correct PIN elevates the signed-in
/// user to admin server-side (POST /api/v1/admin/unlock); on success this
/// screen pops with `true` so the caller can refresh the profile and open
/// the admin dashboard. The PIN is never stored on the device.
class AdminPinScreen extends StatefulWidget {
  const AdminPinScreen({super.key});

  @override
  State<AdminPinScreen> createState() => _AdminPinScreenState();
}

class _AdminPinScreenState extends State<AdminPinScreen>
    with SingleTickerProviderStateMixin {
  String _pin = '';
  String? _error;
  bool _busy = false;
  late final AnimationController _shake;

  @override
  void initState() {
    super.initState();
    _shake = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  void _onDigit(String d) {
    if (_busy || _pin.length >= 4) return;
    HapticFeedback.lightImpact();
    setState(() {
      _pin += d;
      _error = null;
    });
    if (_pin.length == 4) _submit();
  }

  void _onBackspace() {
    if (_busy || _pin.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _submit() async {
    final s = AppStrings(appState.localeCode);
    setState(() => _busy = true);
    try {
      await AdminApi(apiClient).unlock(_pin);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on AdminForbiddenException catch (e) {
      if (!mounted) return;
      _fail(e.detail.contains('not authorized')
          ? s.adminPinNotAllowed
          : s.adminPinWrong);
    } on ApiException catch (e) {
      if (!mounted) return;
      _fail(e.status == 429 ? s.adminPinLocked : s.tryAgain);
    } catch (_) {
      if (!mounted) return;
      _fail(s.tryAgain);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _fail(String message) {
    _shake.forward(from: 0);
    setState(() {
      _pin = '';
      _error = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings(appState.localeCode);
    return Scaffold(
      appBar: AppBar(title: Text(s.adminPinTitle)),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 36),
            const Icon(
              Icons.admin_panel_settings_outlined,
              size: 44,
              color: VirelloColors.pink,
            ),
            const SizedBox(height: 16),
            Text(
              s.adminPinHint,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 28),
            AnimatedBuilder(
              animation: _shake,
              builder: (_, child) {
                final dx = _shake.value == 0
                    ? 0.0
                    : 14 *
                        (1 - _shake.value) *
                        sin(_shake.value * pi * 4);
                return Transform.translate(
                    offset: Offset(dx, 0), child: child);
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  4,
                  (i) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i < _pin.length
                          ? VirelloColors.pink
                          : VTheme.divider(context),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 24,
              child: _error == null
                  ? null
                  : Text(
                      _error!,
                      style: const TextStyle(
                        color: VirelloColors.danger,
                        fontSize: 13,
                      ),
                    ),
            ),
            const Spacer(),
            _KeyRow(
              digits: const ['1', '2', '3'],
              onDigit: _onDigit,
            ),
            _KeyRow(
              digits: const ['4', '5', '6'],
              onDigit: _onDigit,
            ),
            _KeyRow(
              digits: const ['7', '8', '9'],
              onDigit: _onDigit,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(width: 88),
                _KeyButton(digit: '0', onTap: () => _onDigit('0')),
                _KeyButton(
                  icon: Icons.backspace_outlined,
                  onTap: _onBackspace,
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _KeyRow extends StatelessWidget {
  final List<String> digits;
  final void Function(String) onDigit;
  const _KeyRow({required this.digits, required this.onDigit});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final d in digits) _KeyButton(digit: d, onTap: () => onDigit(d)),
      ],
    );
  }
}

class _KeyButton extends StatelessWidget {
  final String? digit;
  final IconData? icon;
  final VoidCallback onTap;
  const _KeyButton({this.digit, this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 88,
      height: 72,
      alignment: Alignment.center,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(44),
          child: Container(
            width: 68,
            height: 68,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: VTheme.divider(context)),
            ),
            child: digit != null
                ? Text(
                    digit!,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                : Icon(icon, size: 24, color: VirelloColors.muted),
          ),
        ),
      ),
    );
  }
}
