/// Legal document viewer — displays User Agreement and Privacy Policy.
///
/// Loads the bundled HTML documents from assets/legal/ in a WebView
/// with proper styling. Fully functional, no "coming soon".
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../main.dart';

/// Which legal document to show.
enum LegalDoc { userAgreement, privacyPolicy }

class LegalDocumentScreen extends StatefulWidget {
  final LegalDoc doc;

  const LegalDocumentScreen({super.key, required this.doc});

  @override
  State<LegalDocumentScreen> createState() => _LegalDocumentScreenState();
}

class _LegalDocumentScreenState extends State<LegalDocumentScreen> {
  late final WebViewController _controller;
  bool _loading = true;
  String? _error;

  String get _assetPath => widget.doc == LegalDoc.userAgreement
      ? 'assets/legal/user_agreement.html'
      : 'assets/legal/privacy_policy.html';

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.disabled)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (error) {
            if (mounted) {
              setState(() {
                _loading = false;
                _error = error.description;
              });
            }
          },
        ),
      );
    _loadDocument();
  }

  Future<void> _loadDocument() async {
    try {
      final html = await rootBundle.loadString(_assetPath);
      // Inject theme-aware tweaks: dark mode support via CSS.
      final isDark =
          WidgetsBinding.instance.platformDispatcher.platformBrightness ==
              Brightness.dark;
      final themedHtml = html.replaceFirst(
        '</head>',
        '''<style>
          ${isDark ? '''
          body { background: #1a1a2e !important; color: #e0e0e0 !important; }
          h1, h2 { color: #f0a0b0 !important; }
          .box { background: #252540 !important; border-color: #3a3a5e !important; }
          .meta, footer { color: #999 !important; }
          a { color: #f07090 !important; }
          ''' : ''}
        </style>
        </head>''',
      );
      await _controller.loadHtmlString(themedHtml);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings(appState.localeCode);
    final title = widget.doc == LegalDoc.userAgreement
        ? s.userAgreement
        : s.privacyPolicy;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: VTheme.scaffold(context),
      ),
      body: Stack(
        children: [
          if (_error == null)
            WebViewWidget(controller: _controller)
          else
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: VirelloColors.muted,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      s.documentLoadError,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: VTheme.textSec(context)),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _loading = true;
                          _error = null;
                        });
                        _loadDocument();
                      },
                      child: Text(s.retry),
                    ),
                  ],
                ),
              ),
            ),
          if (_loading)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
