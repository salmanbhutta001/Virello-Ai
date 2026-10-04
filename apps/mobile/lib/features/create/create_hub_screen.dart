import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/virello_ui.dart';
import '../../main.dart';
import '../../features/tour/app_tour.dart';
import 'ai_story_screen.dart';
import 'conversion_screen.dart';
import 'create_image_screen.dart';
import 'create_video_screen.dart';
import 'generate_captions_screen.dart';
import 'image_tools_screen.dart';
import 'story_video_screen.dart';
import 'teleprompter_screen.dart';
import 'templates_screen.dart';
import 'upload_content_screen.dart';
import 'voiceover_screen.dart';
import 'write_script_screen.dart';

/// Board screen 21: "Create Hub" — "What do you want to create?"
///
/// EXACT board menu: AI Image, AI Video, Write Script, AI Story,
/// Upload Content, Use Template → each opens its own board-faithful screen.
/// AI Image/Video have no provider key configured, so their screens show an
/// honest "coming soon" state — never fake generation.
///
/// Hafiz 2026-10-04: tools open INLINE within the Create tab (not via
/// Navigator.push) so the bottom nav tabs NEVER disappear. The system back
/// button / AppBar back returns to the hub grid, not out of the tab.
class CreateHubScreen extends StatefulWidget {
  const CreateHubScreen({super.key});

  @override
  State<CreateHubScreen> createState() => _CreateHubScreenState();
}

class _CreateHubScreenState extends State<CreateHubScreen> {
  /// The currently open tool, or null for the hub grid.
  Widget? _activeTool;

  void _openTool(Widget tool) => setState(() => _activeTool = tool);
  void _closeTool() => setState(() => _activeTool = null);

  Widget _row({
    required BuildContext context,
    Key? key,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String desc,
    required VoidCallback onTap,
  }) {
    return Padding(
      key: key,
      padding: const EdgeInsets.only(bottom: 12),
      child: VBoardCard(
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.14),
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
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: VTheme.text(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    desc,
                    style: TextStyle(
                      fontSize: 13,
                      color: VTheme.textSec(context),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: VTheme.textSec(context)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tool = _activeTool;
    if (tool != null) {
      // Hafiz 2026-10-04: tool open hai — bottom nav visible rehta hai.
      // Back button (AppBar ya system) dabane pe hub grid pe wapas,
      // tab se bahar nahi.
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _closeTool();
        },
        child: tool,
      );
    }
    final s = AppStrings(appState.localeCode);
    return Scaffold(
      appBar: AppBar(title: Text(s.boardCreateHub)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              s.boardWhatToCreate,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: VTheme.text(context),
              ),
            ),
          ),
          _row(
            context: context,
            key: TourTargets.createFirstTool,
            icon: Icons.image_outlined,
            iconColor: VirelloColors.pink,
            title: s.boardAiImage,
            desc: s.boardAiImageDesc,
            onTap: () => _openTool(const CreateImageScreen()),
          ),
          _row(
            context: context,
            icon: Icons.videocam_outlined,
            iconColor: const Color(0xFF8B5CF6),
            title: s.boardAiVideo,
            desc: s.boardAiVideoDesc,
            onTap: () => _openTool(const CreateVideoScreen()),
          ),
          _row(
            context: context,
            icon: Icons.edit_note_outlined,
            iconColor: const Color(0xFFF59E0B),
            title: s.boardWriteScript,
            desc: s.boardWriteScriptDesc,
            onTap: () => _openTool(const WriteScriptScreen()),
          ),
          _row(
            context: context,
            icon: Icons.auto_stories_outlined,
            iconColor: const Color(0xFF3B82F6),
            title: s.boardAiStory,
            desc: s.boardAiStoryDesc,
            onTap: () => _openTool(const AiStoryScreen()),
          ),
          // Phase B: assemble a 9:16 story video from photos on-device.
          _row(
            context: context,
            icon: Icons.movie_creation_outlined,
            iconColor: const Color(0xFF3B82F6),
            title: s.storyVideo,
            desc: s.storyVideoDesc,
            onTap: () => _openTool(const StoryVideoScreen()),
          ),
          _row(
            context: context,
            icon: Icons.upload_outlined,
            iconColor: const Color(0xFFF97316),
            title: s.boardUploadContent,
            desc: s.boardUploadContentDesc,
            onTap: () => _openTool(const UploadContentScreen()),
          ),
          _row(
            context: context,
            icon: Icons.dashboard_customize_outlined,
            iconColor: VirelloColors.pink,
            title: s.boardUseTemplate,
            desc: s.boardUseTemplateDesc,
            onTap: () => _openTool(const TemplatesScreen()),
          ),
          // Board extras reachable from hub: conversion + captions.
          _row(
            context: context,
            icon: Icons.transform_outlined,
            iconColor: const Color(0xFF10B981),
            title: s.boardConversion,
            desc: s.boardConvert,
            onTap: () => _openTool(const ConversionScreen()),
          ),
          _row(
            context: context,
            icon: Icons.closed_caption_outlined,
            iconColor: const Color(0xFF06B6D4),
            title: s.boardGenerateCaptions,
            desc: s.boardGenerateCaptions,
            onTap: () => _openTool(const GenerateCaptionsScreen()),
          ),
          // Phase A local tools: on-device, no account or setup needed.
          _row(
            context: context,
            icon: Icons.tune_outlined,
            iconColor: const Color(0xFFEC4899),
            title: s.imageTools,
            desc: s.imageToolsDesc,
            onTap: () => _openTool(const ImageToolsScreen()),
          ),
          _row(
            context: context,
            icon: Icons.speaker_notes_outlined,
            iconColor: const Color(0xFF14B8A6),
            title: s.teleprompter,
            desc: s.teleprompterDesc,
            onTap: () => _openTool(const TeleprompterScreen()),
          ),
          _row(
            context: context,
            icon: Icons.record_voice_over_outlined,
            iconColor: const Color(0xFFA855F7),
            title: s.voiceover,
            desc: s.voiceoverDesc,
            onTap: () => _openTool(const VoiceoverScreen()),
          ),
        ],
      ),
    );
  }
}
