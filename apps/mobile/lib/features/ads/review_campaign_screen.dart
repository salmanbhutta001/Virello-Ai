import 'package:flutter/material.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/virello_ui.dart';
import '../../services/api_client.dart';
import '../../data/ads_models.dart';
import '../../main.dart';
import 'campaign_setup_screen.dart';

/// 69 · Connect — "Review Campaign" board screen.
///
/// Rows with icon + fields for the REAL campaign settings (budget, duration,
/// objective — all PATCHed through the real endpoint), the promoted content,
/// and the approval-gated "Go Live" flow:
///
/// draft → submit for approval → approve → launch.
///
/// Nothing launches without explicit approval, and Paid Boost additionally
/// requires a completed payment transaction (verified payment gate).
class ReviewCampaignScreen extends StatefulWidget {
  final String? campaignId;
  const ReviewCampaignScreen({super.key, this.campaignId});

  @override
  State<ReviewCampaignScreen> createState() => _ReviewCampaignScreenState();
}

class _ReviewCampaignScreenState extends State<ReviewCampaignScreen> {
  AppStrings get s => AppStrings(appState.localeCode);

  AdCampaign? _campaign;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  final _budgetCtrl = TextEditingController();
  final _durationCtrl = TextEditingController();
  String _objective = 'views';

  static const _objectives = ['views', 'clicks', 'leads', 'sales'];

  @override
  void initState() {
    super.initState();
    if (widget.campaignId != null) {
      _load(widget.campaignId!);
    } else {
      _loading = false;
    }
  }

  @override
  void dispose() {
    _budgetCtrl.dispose();
    _durationCtrl.dispose();
    super.dispose();
  }

  Future<void> _load(String id) async {
    try {
      final c = await apiClient.getAdCampaign(id);
      if (!mounted) return;
      setState(() {
        _campaign = c;
        _budgetCtrl.text = c.budget.toStringAsFixed(0);
        _durationCtrl.text = '${c.durationDays}';
        _objective = c.objective;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _patch(Map<String, dynamic> patch) async {
    final c = _campaign;
    if (c == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final updated = await apiClient.patchAdCampaign(c.id, patch);
      if (!mounted) return;
      setState(() {
        _campaign = updated;
        _busy = false;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.p10CampaignSubmitted)));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = s.growFailed;
      });
    }
  }

  Future<bool> _paidGateOk() async {
    final c = _campaign;
    if (c == null || c.plan != 'paid') return true;
    try {
      final j = await apiClient.myTransactions();
      final txs = (j['transactions'] as List? ?? []).whereType<Map>().toList();
      final ok = txs.any((t) =>
          '${t['status']}'.toLowerCase() == 'completed' &&
          (t['amount'] as num? ?? 0) > 0);
      return ok;
    } catch (_) {
      return false;
    }
  }

  Future<void> _goLive() async {
    final c = _campaign;
    if (c == null || _busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: VirelloColors.boardSurface,
        title: Text(s.p10GoLive, style: const TextStyle(color: Colors.white)),
        content: Text(s.p10ConfirmGoLive,
            style: const TextStyle(
                color: VirelloColors.boardTextSec, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(s.p10Cancel,
                style: const TextStyle(color: VirelloColors.boardTextSec)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: VirelloColors.pink),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(s.p10Confirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      var campaign = c;
      if (campaign.status == 'draft') {
        campaign = await apiClient
            .patchAdCampaign(campaign.id, {'status': 'pending_approval'});
      }
      if (campaign.status == 'pending_approval') {
        if (!await _paidGateOk()) {
          if (!mounted) return;
          setState(() {
            _busy = false;
            _error = s.p10PaidNeedsPayment;
          });
          return;
        }
        await apiClient.approveAdCampaign(campaign.id);
        campaign = await apiClient.getAdCampaign(campaign.id);
      }
      if (campaign.status == 'approved') {
        if (!await _paidGateOk()) {
          if (!mounted) return;
          setState(() {
            _busy = false;
            _error = s.p10PaidNeedsPayment;
          });
          return;
        }
        await apiClient.launchAdCampaign(campaign.id);
        campaign = await apiClient.getAdCampaign(campaign.id);
      }
      if (!mounted) return;
      setState(() {
        _campaign = campaign;
        _busy = false;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.p10Launched)));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e is ApiException ? 'Error ${e.status}' : s.growFailed;
      });
    }
  }

  String get _goLiveLabel {
    final st = _campaign?.status;
    return switch (st) {
      'draft' => s.p10SubmitApproval,
      'pending_approval' => s.p10ApproveAndLaunch,
      'approved' => s.p10GoLive,
      'active' => s.p10Launched,
      _ => s.p10GoLive,
    };
  }

  bool get _goLiveEnabled {
    final st = _campaign?.status;
    return st == 'draft' || st == 'pending_approval' || st == 'approved';
  }

  Color _statusColor(String st) => switch (st) {
        'active' => const Color(0xFF22C55E),
        'approved' => const Color(0xFF60A5FA),
        'pending_approval' => const Color(0xFFF59E0B),
        'rejected' => VirelloColors.danger,
        _ => VirelloColors.boardTextSec,
      };

  String _statusLabel(String st) {
    return switch (st) {
      'draft' => s.p10Draft,
      'pending_approval' => s.p10PendingApproval,
      'approved' => s.p10Approved,
      'active' => s.p10Active,
      _ => st,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(s.p10ReviewCampaign,
            style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: VirelloColors.pink))
          : _campaign == null
              ? _empty()
              : _review(),
    );
  }

  Widget _empty() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 48, 16, 24),
      children: [
        VBoardCard(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
          child: Column(
            children: [
              const Icon(Icons.rate_review_outlined,
                  size: 40, color: VirelloColors.boardTextSec),
              const SizedBox(height: 12),
              Text(s.p10NoCampaignToReview,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 13,
                      color: VirelloColors.boardTextSec,
                      height: 1.5)),
            ],
          ),
        ),
        const SizedBox(height: 18),
        VPinkButton(
          label: s.p10CampaignSetup,
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const CampaignSetupScreen(),
          )),
        ),
      ],
    );
  }

  Widget _review() {
    final c = _campaign!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        // Board row 1: avatar/icon + promoted content.
        _fieldRow(
          icon: Icons.shopping_bag_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.p10SelectProducts,
                  style: const TextStyle(
                      fontSize: 11.5, color: VirelloColors.boardTextSec)),
              const SizedBox(height: 2),
              Text(
                c.contentRef.isEmpty ? '—' : c.contentRef,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white),
              ),
            ],
          ),
          trailing: IconButton(
            icon: const Icon(Icons.edit_outlined,
                size: 18, color: VirelloColors.boardTextSec),
            tooltip: s.p10CampaignSetup,
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const CampaignSetupScreen(),
            )),
          ),
        ),
        const SizedBox(height: 10),
        // Board row 2: ad set name (editable label kept local to the review;
        // the backend names the campaign from its content).
        _fieldRow(
          icon: Icons.label_outline,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.p10AdSetName,
                  style: const TextStyle(
                      fontSize: 11.5, color: VirelloColors.boardTextSec)),
              const SizedBox(height: 2),
              Text(
                c.contentRef.isEmpty ? '—' : c.contentRef,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // Real editable rows: budget, duration, objective.
        _fieldRow(
          icon: Icons.account_balance_wallet_outlined,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.p10Budget,
                        style: const TextStyle(
                            fontSize: 11.5, color: VirelloColors.boardTextSec)),
                    TextField(
                      controller: _budgetCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600),
                      decoration: const InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        prefixText: '\$ ',
                        prefixStyle: TextStyle(color: Colors.white),
                      ),
                      onSubmitted: (v) {
                        final b = double.tryParse(v);
                        if (b != null && b >= 0) {
                          _patch({'budget': b});
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _fieldRow(
          icon: Icons.schedule_outlined,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.p10Duration,
                        style: const TextStyle(
                            fontSize: 11.5, color: VirelloColors.boardTextSec)),
                    TextField(
                      controller: _durationCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        suffixText: s.p10Days,
                        suffixStyle:
                            const TextStyle(color: VirelloColors.boardTextSec),
                      ),
                      onSubmitted: (v) {
                        final d = int.tryParse(v);
                        if (d != null && d > 0) {
                          _patch({'duration_days': d});
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _fieldRow(
          icon: Icons.track_changes_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.objective,
                  style: const TextStyle(
                      fontSize: 11.5, color: VirelloColors.boardTextSec)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _objectives.map((o) => _objChip(o)).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // Status + estimate rows.
        VBoardCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(s.p10Status,
                      style: const TextStyle(
                          fontSize: 13, color: VirelloColors.boardTextSec)),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _statusColor(c.status).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(_statusLabel(c.status),
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _statusColor(c.status))),
                  ),
                ],
              ),
              if (c.estimate != null) ...[
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(s.p10EstimatedReach,
                        style: const TextStyle(
                            fontSize: 13, color: VirelloColors.boardTextSec)),
                    Text(
                      '${c.estimate!.low}–${c.estimate!.high}',
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(s.p10EstimateNote,
                    style: const TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: VirelloColors.boardTextSec)),
              ],
              if (c.dev)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(s.p10DevHeuristicNote,
                      style: const TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: VirelloColors.boardTextSec)),
                ),
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: const TextStyle(color: VirelloColors.danger)),
        ],
        const SizedBox(height: 20),
        VPinkButton(
          label: _goLiveLabel,
          onPressed: _goLiveEnabled && !_busy ? _goLive : null,
          loading: _busy,
        ),
        const SizedBox(height: 10),
        Text(s.p10ApprovalNote,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 11, color: VirelloColors.boardTextSec)),
      ],
    );
  }

  Widget _fieldRow(
      {required IconData icon, required Widget child, Widget? trailing}) {
    return VBoardCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: VirelloColors.pink.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: VirelloColors.pink, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(child: child),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _objChip(String o) {
    final active = _objective == o;
    return GestureDetector(
      onTap: () {
        setState(() => _objective = o);
        _patch({'objective': o});
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active ? VirelloColors.pink : VirelloColors.boardField,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
              color: active ? VirelloColors.pink : VirelloColors.boardBorder),
        ),
        child: Text(o,
            style: TextStyle(
                color: active ? Colors.white : VirelloColors.boardTextSec,
                fontWeight: FontWeight.w700,
                fontSize: 12)),
      ),
    );
  }
}
