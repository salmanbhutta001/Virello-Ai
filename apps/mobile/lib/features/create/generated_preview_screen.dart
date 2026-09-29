import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../main.dart';

/// Board screen 28: "Generated Preview".
///
/// Board layout: header "Preview". Shows generated/transformed content when
/// available; otherwise an honest empty state. Never invents a preview.
class GeneratedPreviewScreen extends StatelessWidget {
  final String? title;
  final String? body;
  const GeneratedPreviewScreen({super.key, this.title, this.body});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings(appState.localeCode);
    final hasContent = (body ?? '').trim().isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: Text(s.boardPreview)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: Container(
              decoration: BoxDecoration(
                color: VTheme.chip(context),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: VirelloColors.boardBorder),
              ),
              child: hasContent
                  ? Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if ((title ?? '').isNotEmpty)
                            Text(
                              title!,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: VTheme.text(context),
                              ),
                            ),
                          if ((title ?? '').isNotEmpty)
                            const SizedBox(height: 10),
                          Expanded(
                            child: SingleChildScrollView(
                              child: Text(
                                body!,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  height: 1.7,
                                  color: VTheme.text(context),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.preview_outlined,
                            size: 56,
                            color:
                                VTheme.textSec(context).withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            s.boardNoRecommendations,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: VTheme.textSec(context),
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
