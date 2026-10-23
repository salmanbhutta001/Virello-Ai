import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/virello_ui.dart';
import '../../main.dart';

/// Full terms URL (public page; also linked from the store listing).
/// The short terms below are bundled in-app in EN/UR/AR; their numbers
/// mirror ~/workspace/virello/store_listing/rewards_terms.html.
const String kRewardsTermsUrl = 'https://virelloai.online/rewards-terms.html';

/// Rewards Terms screen: the short in-app terms in EN/UR/AR plus a
/// "View full terms" link to the public page. Reachable from the Wallet
/// screen's Terms link (Play Store compliance).
class RewardsTermsScreen extends StatelessWidget {
  const RewardsTermsScreen({super.key});

  Future<void> _openFull() async {
    final uri = Uri.tryParse(kRewardsTermsUrl);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings(appState.localeCode);
    final sections = <(String, String)>[
      (s.rtEligibilityT, s.rtEligibility),
      (s.rtPointsT, s.rtPoints),
      (s.rtCashT, s.rtCash),
      (s.rtContestsT, s.rtContests),
      (s.rtWithdrawT, s.rtWithdraw),
      (s.rtFairPlayT, s.rtFairPlay),
      (s.rtChangesT, s.rtChanges),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(s.rewardsTerms)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          VCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.stars_outlined, color: VirelloColors.pink),
                    SizedBox(width: 8),
                    Text(
                      'Virello Rewards',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  s.rtSummary,
                  style: const TextStyle(
                    fontSize: 14,
                    color: VirelloColors.muted,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          for (final (title, body) in sections)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: VCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: VirelloColors.pink,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      body,
                      style: const TextStyle(fontSize: 14, height: 1.65),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 4),
          Center(
            child: TextButton.icon(
              onPressed: _openFull,
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: Text(s.viewFullTerms),
              style: TextButton.styleFrom(
                foregroundColor: VirelloColors.pink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
