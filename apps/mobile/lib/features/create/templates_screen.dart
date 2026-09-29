import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/virello_ui.dart';
import '../../main.dart';
import 'content_editor_screen.dart';

/// Board screen 29: "Templates".
///
/// Board layout: header "Templates", tabs All / Trending (pink active
/// pill), grid of template cards.
///
/// HONEST: the backend has no template catalog endpoint, so the grid shows
/// an honest empty state — never fake templates. Tapping a template would
/// open the Content Editor; with no real templates there is nothing to tap.
class TemplatesScreen extends StatefulWidget {
  const TemplatesScreen({super.key});

  @override
  State<TemplatesScreen> createState() => _TemplatesScreenState();
}

class _TemplatesScreenState extends State<TemplatesScreen> {
  int _tab = 0;

  AppStrings get s => AppStrings(appState.localeCode);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(s.boardTemplates)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: VPillTabs(
              tabs: [s.boardTabAll, s.boardTabTrending],
              selected: _tab,
              onTap: (i) => setState(() => _tab = i),
            ),
          ),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.dashboard_customize_outlined,
                      size: 56,
                      color: VTheme.textSec(context).withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      s.boardNoTemplates,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: VTheme.textSec(context),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Honest fallback: open the editor directly.
                    SizedBox(
                      height: 48,
                      child: FilledButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ContentEditorScreen(),
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: VirelloColors.pink,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(s.boardEditContent),
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
