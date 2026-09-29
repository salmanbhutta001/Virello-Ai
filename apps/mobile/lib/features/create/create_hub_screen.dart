import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/virello_ui.dart';
import '../../main.dart';
import '../ads/campaign_builder_screen.dart';
import '../audience/audience_intelligence_screen.dart';
import '../collab/collab_screen.dart';
import '../creator_studio/creator_studio_screen.dart';
import '../ctr/ctr_audit_screen.dart';
import '../discovery/analyze_screen.dart';
import '../discovery/discovery_screen.dart';
import '../entertain/entertain_screen.dart';
import '../grow/grow_flow.dart';
import '../referrals/referral_screen.dart';
import '../seeding/seeding_screen.dart';
import '../transform/transform_screen.dart';
import '../viral_lab/viral_lab_screen.dart';
import 'upload_review_screen.dart';

/// Board screens 21/22: "Create Hub" — "What do you want to create?"
///
/// Board menu: AI Image, AI Video, Write Script, AI Story, Upload Content,
/// Use Template → mapped to the real existing features. AI Image/Video have
/// no provider key configured, so they show an honest "coming soon" state —
/// never fake generation. Everything else routes to real screens.
class CreateHubScreen extends StatelessWidget {
  const CreateHubScreen({super.key});

  void _openUploadStudio(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const UploadReviewScreen()),
    );
  }

  /// Honest "coming soon" — AI Image/Video need a provider key.
  void _showProviderNeeded(BuildContext context, String title) {
    final s = AppStrings(appState.localeCode);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: VirelloColors.boardSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: VirelloColors.boardBorder),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          s.boardProviderKeyNeeded,
          style: const TextStyle(color: VirelloColors.boardTextSec),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'OK',
              style: TextStyle(color: VirelloColors.pink),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String desc,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: VBoardCard(
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: VirelloColors.pink.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: VirelloColors.pink, size: 26),
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
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    desc,
                    style: const TextStyle(
                      fontSize: 13,
                      color: VirelloColors.boardTextSec,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: VirelloColors.boardTextSec),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings(appState.localeCode);
    return Scaffold(
      backgroundColor: VirelloColors.boardBg,
      appBar: AppBar(
        backgroundColor: VirelloColors.boardBg,
        title: Text(
          s.createTitle,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // ── Board 21/22: "What do you want to create?" ──
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              s.boardWhatToCreate,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          _row(
            context: context,
            icon: Icons.image_outlined,
            title: s.boardAiImage,
            desc: s.boardAiImageDesc,
            onTap: () => _showProviderNeeded(context, s.boardAiImage),
          ),
          _row(
            context: context,
            icon: Icons.videocam_outlined,
            title: s.boardAiVideo,
            desc: s.boardAiVideoDesc,
            onTap: () => _showProviderNeeded(context, s.boardAiVideo),
          ),
          _row(
            context: context,
            icon: Icons.edit_note_outlined,
            title: s.boardWriteScript,
            desc: s.boardWriteScriptDesc,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CreatorStudioScreen()),
            ),
          ),
          _row(
            context: context,
            icon: Icons.auto_stories_outlined,
            title: s.boardAiStory,
            desc: s.boardAiStoryDesc,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EntertainScreen()),
            ),
          ),
          _row(
            context: context,
            icon: Icons.upload_outlined,
            title: s.boardUploadContent,
            desc: s.boardUploadContentDesc,
            onTap: () => _openUploadStudio(context),
          ),
          _row(
            context: context,
            icon: Icons.dashboard_customize_outlined,
            title: s.boardUseTemplate,
            desc: s.boardUseTemplateDesc,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CreatorStudioScreen()),
            ),
          ),

          // ── AI growth tools (existing features) ──
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Text(
              s.whatToDoToday,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          _row(
            context: context,
            icon: Icons.link,
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
            title: s.viralLab,
            desc: s.viralLabDesc,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ViralLabScreen()),
            ),
          ),
          _row(
            context: context,
            icon: Icons.track_changes,
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
            title: s.promoteWithAI,
            desc: s.promoteWithAIDesc,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CampaignBuilderScreen()),
            ),
          ),

          // ── Free Growth Tools ──
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Text(
              s.freeGrowthTools,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          _row(
            context: context,
            icon: Icons.transform_outlined,
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
            title: s.toolReferral,
            desc: s.toolReferralDesc,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ReferralScreen()),
            ),
          ),

          // Gradient "Let AI Grow Your Content" card — board pink.
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
                  gradient: const LinearGradient(
                    colors: [VirelloColors.pink, Color(0xFFC2274E)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: VirelloColors.pink.withValues(alpha: 0.35),
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
        ],
      ),
    );
  }
}
