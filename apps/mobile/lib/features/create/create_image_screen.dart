import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/virello_ui.dart';
import '../../main.dart';

/// Board screen 22: "Create Image".
///
/// Board layout: prompt hint at top, style tabs (Realistic / Cartoon / 3D
/// with pink active pill), preview area, pink circular generate button.
///
/// HONEST: no production image provider is configured, so Generate shows an
/// honest "coming soon" state. Never fakes a generated image.
class CreateImageScreen extends StatefulWidget {
  const CreateImageScreen({super.key});

  @override
  State<CreateImageScreen> createState() => _CreateImageScreenState();
}

class _CreateImageScreenState extends State<CreateImageScreen> {
  final _promptCtrl = TextEditingController();
  int _style = 0; // 0 realistic, 1 cartoon, 2 3d
  bool _tried = false;

  AppStrings get s => AppStrings(appState.localeCode);

  @override
  void dispose() {
    _promptCtrl.dispose();
    super.dispose();
  }

  void _generate() {
    if (_promptCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.boardEnterTextFirst)),
      );
      return;
    }
    setState(() => _tried = true);
  }

  @override
  Widget build(BuildContext context) {
    final styles = [s.boardStyleRealistic, s.boardStyleCartoon, s.boardStyle3d];
    return Scaffold(
      appBar: AppBar(title: Text(s.boardCreateImage)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // Prompt hint (board shows suggestion text at top).
          Text(
            s.boardImagePromptHint,
            style: TextStyle(
              fontSize: 13,
              fontStyle: FontStyle.italic,
              color: VTheme.textSec(context),
            ),
          ),
          const SizedBox(height: 12),
          // Prompt field.
          VBoardCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              controller: _promptCtrl,
              maxLines: 3,
              minLines: 2,
              style: TextStyle(color: VTheme.text(context)),
              decoration: InputDecoration(
                hintText: s.boardImagePromptHint,
                hintStyle: TextStyle(color: VTheme.textSec(context)),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Style tabs (board: Realistic pink pill / Cartoon / 3D).
          VPillTabs(
            tabs: styles,
            selected: _style,
            onTap: (i) => setState(() => _style = i),
          ),
          const SizedBox(height: 16),
          // Preview area.
          AspectRatio(
            aspectRatio: 1,
            child: Container(
              decoration: BoxDecoration(
                color: VTheme.chip(context),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: VirelloColors.boardBorder),
              ),
              child: _tried
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.image_outlined,
                            size: 56,
                            color: VirelloColors.pink,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            s.boardImageComingSoon,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13.5,
                              height: 1.6,
                              color: VTheme.textSec(context),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: VirelloColors.boardBg,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _promptCtrl.text.trim(),
                              style: TextStyle(
                                fontSize: 13,
                                color: VTheme.text(context),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Center(
                      child: Icon(
                        Icons.image_outlined,
                        size: 64,
                        color: VTheme.textSec(context).withValues(alpha: 0.5),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 24),
          // Pink circular generate button (board style).
          Center(
            child: VPinkCircleButton(onPressed: _generate),
          ),
        ],
      ),
    );
  }
}
