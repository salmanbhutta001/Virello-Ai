import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/virello_ui.dart';
import '../../main.dart';
import '../ads/campaign_builder_screen.dart';
import '../audience/audience_intelligence_screen.dart';
import '../collab/collab_screen.dart';
import '../ctr/ctr_audit_screen.dart';
import '../discovery/analyze_screen.dart';
import '../viral_lab/viral_lab_screen.dart';
import '../creator_studio/creator_studio_screen.dart';
import '../discovery/discovery_screen.dart';
import '../grow/grow_flow.dart';
import '../referrals/referral_screen.dart';
import '../seeding/seeding_screen.dart';
import '../transform/transform_screen.dart';
import 'upload_review_screen.dart';

/// Board screen "Create": the central action hub — Analyze, Upload, Find
/// Audience, Promote with AI, plus the "Let AI Grow Your Content" card.
class CreateHubScreen extends StatelessWidget {
  const CreateHubScreen({super.key});

  static const _cyan = Color(0xFF22B8CF);
  static const _orange = Color(0xFFF59E0B);

  void _openUploadStudio(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const UploadReviewScreen()),
    );
  }

  Widget _row({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String desc,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: VCard(
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: iconColor, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    desc,
                    style: const TextStyle(
                      fontSize: 13,
                      color: VirelloColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: VirelloColors.muted),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings(appState.localeCode);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          s.createTitle,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              s.whatToDoToday,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
          ),
          _row(
            context: context,
            icon: Icons.link,
            iconColor: VirelloColors.violet,
            title: s.analyzePost,
            desc: s.analyzePostDesc,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AnalyzeScreen()),
            ),
          ),
          _row(
            context: context,
            icon: Icons.science_outlined,
            iconColor: VirelloColors.violetDeep,
            title: s.viralLab,
            desc: s.viralLabDesc,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ViralLabScreen()),
            ),
          ),
          _row(
            context: context,
            icon: Icons.auto_awesome,
            iconColor: _cyan,
            title: s.creatorStudio,
            desc: s.creatorStudioDesc,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CreatorStudioScreen()),
            ),
          ),
          _row(
            context: context,
            icon: Icons.image_outlined,
            iconColor: _cyan,
            title: s.uploadContent,
            desc: s.uploadContentDesc,
            onTap: () => _openUploadStudio(context),
          ),
          _row(
            context: context,
            icon: Icons.track_changes,
            iconColor: _orange,
            title: s.findAudience,
            desc: s.findAudienceDesc,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AudienceIntelligenceScreen(),
              ),
            ),
          ),
          _row(
            context: context,
            icon: Icons.rocket_launch_outlined,
            iconColor: VirelloColors.violet,
            title: s.promoteWithAI,
            desc: s.promoteWithAIDesc,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CampaignBuilderScreen()),
            ),
          ),

          // Free Growth Tools section.
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Text(
              s.freeGrowthTools,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
          ),
          _row(
            context: context,
            icon: Icons.transform_outlined,
            iconColor: VirelloColors.violet,
            title: s.toolTransform,
            desc: s.toolTransformDesc,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    TransformScreen(localeCode: appState.localeCode),
              ),
            ),
          ),
          _row(
            context: context,
            icon: Icons.fact_check_outlined,
            iconColor: _cyan,
            title: s.toolCtrAudit,
            desc: s.toolCtrAuditDesc,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CtrAuditScreen()),
            ),
          ),
          _row(
            context: context,
            icon: Icons.groups_outlined,
            iconColor: _orange,
            title: s.toolSeeding,
            desc: s.toolSeedingDesc,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SeedingScreen()),
            ),
          ),
          _row(
            context: context,
            icon: Icons.handshake_outlined,
            iconColor: VirelloColors.violet,
            title: s.toolCollab,
            desc: s.toolCollabDesc,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CollabScreen()),
            ),
          ),
          _row(
            context: context,
            icon: Icons.card_giftcard_outlined,
            iconColor: _cyan,
            title: s.toolReferral,
            desc: s.toolReferralDesc,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ReferralScreen()),
            ),
          ),
          _row(
            context: context,
            icon: Icons.view_agenda_outlined,
            iconColor: _orange,
            title: s.toolLinkCards,
            desc: s.toolLinkCardsDesc,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DiscoveryScreen()),
            ),
          ),

          // Gradient "Let AI Grow Your Content" card.
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const GrowFlow()),
              ),
              borderRadius: BorderRadius.circular(20),
              child: Ink(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 22,
                ),
                decoration: BoxDecoration(
                  gradient: VirelloColors.brandGradient,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: VirelloColors.violet.withValues(alpha: 0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.asset(
                        'assets/icons/agent_3d.webp',
                        width: 58,
                        height: 58,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      s.letAiGrowContent,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      s.letAiGrowContentDesc,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12.5,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Footer strip.
          Padding(
            padding: const EdgeInsets.only(top: 28, bottom: 8),
            child: Column(
              children: [
                const Text(
                  'Virello AI',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: VirelloColors.violet,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${s.smartContent} • ${s.rightAudience} • ${s.realGrowth}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: VirelloColors.muted,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _badge(Icons.auto_awesome, s.aiPoweredIntelligence),
                    _badge(Icons.public, s.globalAudience),
                    _badge(Icons.translate, s.multiLanguageSupport),
                    _badge(Icons.verified_user, s.secureTransparent),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(IconData icon, String label) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: VirelloColors.violet.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: VirelloColors.violet, size: 20),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10.5,
              color: VirelloColors.muted,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
