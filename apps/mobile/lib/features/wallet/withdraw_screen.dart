import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/virello_ui.dart';
import '../../main.dart';
import '../../services/api_client.dart';
import '../../services/rewards_api.dart';

/// Cash withdrawal flow.
///
/// - Amount in $ (cents sent to the server).
/// - Bank-details form: bank_name / account_title / iban.
/// - REQUIRED 18+ checkbox — POST is blocked until checked and the server
///   receives age_confirmed:true.
/// - Server 422 errors are surfaced honestly: below_minimum,
///   age_not_confirmed, ineligible (+ reasons), pending_exists,
///   insufficient_balance, invalid_method.
class WithdrawScreen extends StatefulWidget {
  /// Server balance display, e.g. "$12.40".
  final String balanceDisplay;

  /// Balance in cents, to cap the amount input.
  final int balanceCents;

  /// Pending withdrawal (if any), for the status banner.
  final Map<String, dynamic>? pending;

  const WithdrawScreen({
    super.key,
    required this.balanceDisplay,
    required this.balanceCents,
    this.pending,
  });

  @override
  State<WithdrawScreen> createState() => _WithdrawScreenState();
}

class _WithdrawScreenState extends State<WithdrawScreen> {
  RewardsApi get _api => RewardsApi(apiClient);
  AppStrings get s => AppStrings(appState.localeCode);

  final _amountCtrl = TextEditingController();
  final _bankCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  final _ibanCtrl = TextEditingController();

  bool _ageConfirmed = false;
  bool _submitting = false;
  Map<String, dynamic>? _submitted;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _bankCtrl.dispose();
    _titleCtrl.dispose();
    _ibanCtrl.dispose();
    super.dispose();
  }

  double get _maxDollars => widget.balanceCents / 100;

  Future<void> _submit() async {
    if (_submitting) return;
    final amount =
        (double.tryParse(_amountCtrl.text.trim()) ?? 0);
    final bank = _bankCtrl.text.trim();
    final title = _titleCtrl.text.trim();
    final iban = _ibanCtrl.text.trim().replaceAll(' ', '');

    String? problem;
    if (amount <= 0) problem = s.withdrawAmount;
    if (amount > _maxDollars + 1e-9) problem = s.errInsufficientCash;
    if (bank.isEmpty) problem = s.bankName;
    if (title.isEmpty) problem = s.accountTitle;
    if (iban.length < 10) problem = s.iban;
    if (!_ageConfirmed) problem = s.errAgeNotConfirmed;
    if (problem != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.errWithdraw(problem))),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final r = await _api.withdraw(
        amountCents: (amount * 100).round(),
        bankName: bank,
        accountTitle: title,
        iban: iban,
        ageConfirmed: true,
      );
      if (!mounted) return;
      setState(() => _submitted = r['withdrawal'] as Map<String, dynamic>?);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.withdrawalSubmitted)),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.errWithdraw(_withdrawError(e)))),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.errWithdraw(s.shareFailed))),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// Map the server's 422 {error, reasons?} to readable strings.
  /// Falls back to the server's own body text, never invented amounts.
  String _withdrawError(ApiException e) {
    if (e.status == 422) {
      // _postJson throws with the decoded body; try to extract error.
      final m = RegExp(r'"error"\s*:\s*"([^"]+)"').firstMatch(e.body);
      final err = m?.group(1) ?? '';
      switch (err) {
        case 'below_minimum':
          return s.errBelowMinimum;
        case 'age_not_confirmed':
          return s.errAgeNotConfirmed;
        case 'pending_exists':
          return s.errPendingExists;
        case 'insufficient_balance':
          return s.errInsufficientCash;
        case 'invalid_method':
          return s.errInvalidMethod;
        case 'ineligible':
          return _ineligibleReasons(e.body);
      }
      if (err.isNotEmpty) return err;
    }
    final detail = e.body.trim();
    return detail.isNotEmpty ? detail : s.withdrawCash;
  }

  String _ineligibleReasons(String body) {
    final found = <String>[];
    for (final key in ['email_not_verified', 'account_too_new', 'profile_incomplete']) {
      if (body.contains(key)) found.add(key);
    }
    if (found.isEmpty) return s.withdrawCash;
    final mapped = found.map((k) {
      switch (k) {
        case 'email_not_verified':
          return s.errEmailNotVerified;
        case 'account_too_new':
          return s.errAccountTooNew;
        default:
          return s.errProfileIncomplete;
      }
    });
    return mapped.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    if (_submitted != null) return _successBody();
    return Scaffold(
      appBar: AppBar(title: Text(s.withdrawCash)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          VCard(
            child: Row(
              children: [
                const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: VirelloColors.pink,
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.cashBalance,
                      style: const TextStyle(
                        fontSize: 12,
                        color: VirelloColors.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      widget.balanceDisplay,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (widget.pending != null) _pendingBanner(widget.pending!),
          if (widget.pending != null) const SizedBox(height: 16),
          _field(
            controller: _amountCtrl,
            label: s.withdrawAmount,
            hint: '10.00',
            keyboard: const TextInputType.numberWithOptions(decimal: true),
            formatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              s.minWithdrawalNote,
              style: const TextStyle(
                fontSize: 12,
                color: VirelloColors.muted,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _field(controller: _bankCtrl, label: s.bankName),
          const SizedBox(height: 12),
          _field(controller: _titleCtrl, label: s.accountTitle),
          const SizedBox(height: 12),
          _field(
            controller: _ibanCtrl,
            label: s.iban,
            hint: 'PK36…',
            formatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
          ),
          const SizedBox(height: 8),
          VCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: _ageConfirmed,
                  activeColor: VirelloColors.pink,
                  onChanged: (v) =>
                      setState(() => _ageConfirmed = v ?? false),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      s.ageConfirmLabel,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              s.withdrawalReviewNote,
              style: const TextStyle(
                fontSize: 12,
                color: VirelloColors.muted,
              ),
            ),
          ),
          const SizedBox(height: 16),
          VGradientButton(
            label: _submitting ? '…' : s.submitWithdrawal,
            onPressed: (_submitting || widget.pending != null)
                ? null
                : _submit,
          ),
        ],
      ),
    );
  }

  Widget _pendingBanner(Map<String, dynamic> p) {
    return VCard(
      child: Row(
        children: [
          const Icon(Icons.hourglass_bottom_outlined,
              color: Color(0xFFB8860B)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.pendingWithdrawal,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  '${p['amount_display'] ?? ''} · ${p['status'] ?? ''}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: VirelloColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _successBody() {
    final w = _submitted!;
    return Scaffold(
      appBar: AppBar(title: Text(s.withdrawCash)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle_outline,
                size: 64,
                color: Colors.green,
              ),
              const SizedBox(height: 16),
              Text(
                '${w['amount_display'] ?? ''}',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                s.withdrawalSubmitted,
                textAlign: TextAlign.center,
                style: const TextStyle(color: VirelloColors.muted),
              ),
              const SizedBox(height: 24),
              VGradientButton(
                label: s.wallet,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType keyboard = TextInputType.text,
    List<TextInputFormatter>? formatters,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      inputFormatters: formatters,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }
}
