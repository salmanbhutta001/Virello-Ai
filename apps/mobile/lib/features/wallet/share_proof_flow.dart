import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/virello_ui.dart';
import '../../data/discovery_models.dart';
import '../../main.dart';
import '../../services/api_client.dart';
import '../../services/rewards_api.dart';

/// Proof-based share rewards (backend pivot 2026-09-30).
///
/// Flow:
/// 1. Small green cash badge on a post card (per-post `reward_display` from
///    the feed — never invented locally).
/// 2. Tap -> confirm dialog "Share to earn $X.XX" -> system share sheet.
/// 3. When the share completes -> bottom sheet "Upload proof to earn $X.XX":
///    pick a screenshot (file picker), POST /api/v1/uploads/proof, then
///    POST /api/v1/rewards/claim {claim_type:"share", post_id, proof_url}.
/// 4. States: uploading -> submitted ("Under review") or error.
///    409 already_claimed -> "Already claimed for this post".
///
/// No emojis, no "AI" labels — plain text status chips.
class ShareProofFlow {
  ShareProofFlow._();

  /// Entry point: confirm dialog, system share sheet, then the proof sheet.
  /// Does nothing when the post carries no claimable reward.
  static Future<void> start(BuildContext context, DiscoveryItem item) async {
    if (!item.hasShareReward) return;
    final s = AppStrings(appState.localeCode);
    final go = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(s.shareToEarn(item.rewardDisplay)),
        content: Text(
          s.shareToEarnDesc,
          style: const TextStyle(fontSize: 14, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: Text(s.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(c).pop(true),
            child: Text(
              s.shareNow,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
    if (go != true || !context.mounted) return;

    final url = item.postUrl.isNotEmpty ? item.postUrl : item.title;
    final title = item.title.isEmpty ? url : item.title;
    final ShareResult result;
    try {
      result = await SharePlus.instance.share(
        ShareParams(text: '$title\n$url\n\nvia Virello', subject: title),
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.shareFailed)),
        );
      }
      return;
    }

    // Proof sheet only when the OS share sheet actually completed.
    if (result.status != ShareResultStatus.success || !context.mounted) {
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _ProofSheet(item: item),
    );
  }
}

/// Small green cash badge: shows the post's reward_display
/// (e.g. "+$0.05"), tapped -> the share-to-earn flow.
class ShareRewardBadge extends StatelessWidget {
  final DiscoveryItem item;
  final VoidCallback onTap;
  const ShareRewardBadge({super.key, required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (!item.hasShareReward) return const SizedBox.shrink();
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.green.withValues(alpha: 0.45)),
        ),
        child: Text(
          item.rewardDisplay,
          style: const TextStyle(
            color: Colors.green,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet: pick a screenshot, upload it, file the claim.
class _ProofSheet extends StatefulWidget {
  final DiscoveryItem item;
  const _ProofSheet({required this.item});

  @override
  State<_ProofSheet> createState() => _ProofSheetState();
}

class _ProofSheetState extends State<_ProofSheet> {
  AppStrings get s => AppStrings(appState.localeCode);
  RewardsApi get _api => RewardsApi(apiClient);

  String? _pickedPath;
  String? _pickedName;
  bool _busy = false;
  String? _error;
  String? _doneMessage;
  String? _doneStatus; // pending | approved

  static const int _maxBytes = 5 * 1024 * 1024; // backend limit: 5MB

  Future<void> _pick() async {
    if (_busy) return;
    setState(() {
      _error = null;
    });
    try {
      final picked = await FilePicker.pickFile(type: FileType.image);
      final path = picked?.path;
      if (path == null) return; // user cancelled
      final size = await File(path).length();
      if (size > _maxBytes) {
        setState(() => _error = s.proofTooBig);
        return;
      }
      setState(() {
        _pickedPath = path;
        _pickedName = picked?.name ?? path.split('/').last;
        _error = null;
      });
    } catch (_) {
      if (mounted) setState(() => _error = s.noProofPicked);
    }
  }

  Future<void> _submit() async {
    final path = _pickedPath;
    if (_busy) return;
    if (path == null) {
      // We require an image before POSTing the claim, so the server's
      // 422 proof_required should never fire — kept as an honest fallback.
      setState(() => _error = s.noProofPicked);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final up = await _api.uploadProof(path);
      final proofUrl = '${up['url'] ?? ''}';
      if (proofUrl.isEmpty) throw ApiException(500, 'empty proof url');
      final claim = await _api.claimShare(
        postId: widget.item.placementId,
        proofUrl: proofUrl,
      );
      if (!mounted) return;
      final status = '${claim['status'] ?? 'pending'}';
      final msg = '${claim['message'] ?? ''}';
      setState(() {
        _doneStatus = status;
        _doneMessage = msg.isNotEmpty ? msg : s.underReview;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      final body = e.body;
      String msg;
      if (e.status == 409 || body.contains('already_claimed')) {
        msg = s.alreadyClaimedPost;
      } else if (e.status == 422 && body.contains('proof_required')) {
        msg = s.proofRequiredMsg; // shouldn't happen — image required first
      } else if (e.status == 400) {
        msg = s.proofInvalidType;
      } else {
        msg = body.trim().isNotEmpty ? body.trim() : s.claimFailedMsg;
      }
      setState(() => _error = msg);
    } catch (_) {
      if (mounted) setState(() => _error = s.claimFailedMsg);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final display = widget.item.rewardDisplay;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: VTheme.divider(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            if (_doneMessage != null) ...[
              _doneState(),
            ] else ...[
              Text(
                s.uploadProofToEarn(display),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                s.proofSheetHint,
                style: const TextStyle(
                  fontSize: 13.5,
                  color: VirelloColors.muted,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: _busy ? null : _pick,
                icon: const Icon(Icons.image_outlined, size: 18),
                label: Text(
                  _pickedName ?? s.pickScreenshot,
                  overflow: TextOverflow.ellipsis,
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: VirelloColors.pink,
                  side: const BorderSide(color: VirelloColors.pink),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: const TextStyle(
                    fontSize: 13,
                    color: VirelloColors.danger,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              VPinkButton(
                label: s.submitClaim,
                loading: _busy,
                onPressed: _busy ? null : _submit,
              ),
              const SizedBox(height: 6),
            ],
          ],
        ),
      ),
    );
  }

  Widget _doneState() {
    final approved = _doneStatus == 'approved';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 8),
        Icon(
          approved
              ? Icons.check_circle_outline_rounded
              : Icons.hourglass_bottom_outlined,
          size: 44,
          color: approved ? Colors.green : Colors.amber.shade700,
        ),
        const SizedBox(height: 12),
        Text(
          approved ? s.approved : s.underReview,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _doneMessage!,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13.5,
            color: VirelloColors.muted,
            height: 1.55,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: VPinkButton(
            label: s.done,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ],
    );
  }
}
