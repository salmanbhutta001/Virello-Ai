import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/strings.dart';
import '../../main.dart';
import '../../services/rewards_api.dart';

/// Share-to-earn: product share via a tracked personal link.
///
/// Flow per contract:
/// 1. POST /api/v1/rewards/share-link {asin} -> {share_url, code, asin}
/// 2. SharePlus.instance.share(share_url) — the OS share sheet.
///
/// NOTE (2026-09-30 pivot): the old POST /api/v1/rewards/share auto-credit
/// is REMOVED (410) — share rewards are proof-based now (screenshot upload
/// + claim + admin approval, see share_proof_flow.dart). This helper no
/// longer credits anything; it just runs the share sheet and reports
/// whether it completed.
class ShareEarn {
  ShareEarn._();

  static final _asinRe = RegExp(r'/dp/([A-Z0-9]{10})');

  /// Extract a 10-char Amazon ASIN from an affiliate URL, if present.
  static String? asinOf(Map<String, dynamic> p) {
    final url = '${p['affiliate_url'] ?? ''}';
    final m = _asinRe.firstMatch(url);
    return m?.group(1);
  }

  /// Run the share flow for a product card.
  ///
  /// Returns true when the OS share sheet completed, false when the product
  /// has no trackable ASIN, the share link failed, or the share did not
  /// complete. No cash is credited here — the proof-based claim flow
  /// (share_proof_flow.dart) handles earnings.
  static Future<bool> shareProduct(
    BuildContext context, {
    required Map<String, dynamic> product,
    String? title,
  }) async {
    final s = AppStrings(appState.localeCode);
    final asin = asinOf(product);
    final name = title ?? '${product['title'] ?? ''}';
    if (asin == null) {
      // Not trackable: no share-link possible. Return false so the caller
      // can fall back to its own behavior (e.g. copy the link); no earnings.
      return false;
    }

    final api = RewardsApi(apiClient);
    String shareUrl;
    try {
      final link = await api.shareLink(asin);
      shareUrl = '${link['share_url'] ?? ''}';
      if (shareUrl.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(s.shareFailed)),
          );
        }
        return false;
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.shareFailed)),
        );
      }
      return false;
    }

    final text = '$name\n$shareUrl\n\nvia Virello';
    final ShareResult result;
    try {
      result = await SharePlus.instance
          .share(ShareParams(text: text, subject: name));
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.shareFailed)),
        );
      }
      return false;
    }

    // The old auto-credit endpoint (POST /api/v1/rewards/share) is 410 —
    // rewards are proof-based now. Only a completed share counts as a real
    // share; callers route the user to the screenshot-proof claim flow.
    // Nothing is credited here, and no earnings snackbar is shown we
    // can't confirm.
    return result.status == ShareResultStatus.success;
  }
}
