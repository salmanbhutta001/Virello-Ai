import 'package:flutter/material.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/virello_ui.dart';
import '../../main.dart';
import 'result_screen.dart';

/// Step 2 of the journey: paste a link → deep analysis → Result screen.
/// Can be pre-filled from a discovery feed item (carries its campaignId so
/// Save also records a genuine backend interaction).
class AnalyzeScreen extends StatefulWidget {
  final String initialUrl;
  final String? campaignId;
  final String? variantId;
  const AnalyzeScreen(
      {super.key, this.initialUrl = '', this.campaignId, this.variantId});

  @override
  State<AnalyzeScreen> createState() => _AnalyzeScreenState();
}

class _AnalyzeScreenState extends State<AnalyzeScreen> {
  late final TextEditingController _ctrl;
  String _platform = 'auto';
  bool _working = false;

  AppStrings get s => AppStrings(appState.localeCode);

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialUrl);
    _detectPlatform(widget.initialUrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _detectPlatform(String url) {
    final u = url.toLowerCase();
    setState(() {
      if (u.contains('tiktok')) {
        _platform = 'tiktok';
      } else if (u.contains('instagram')) {
        _platform = 'instagram';
      } else if (u.contains('youtube') || u.contains('youtu.be')) {
        _platform = 'youtube';
      } else if (u.contains('x.com') || u.contains('twitter')) {
        _platform = 'x';
      } else if (u.contains('facebook') || u.contains('fb.watch')) {
        _platform = 'facebook';
      } else if (u.contains('snapchat')) {
        _platform = 'snapchat';
      } else if (u.contains('pinterest') || u.contains('pin.it')) {
        _platform = 'pinterest';
      } else if (u.contains('linkedin')) {
        _platform = 'linkedin';
      } else if (u.contains('reddit')) {
        _platform = 'reddit';
      } else if (u.contains('threads')) {
        _platform = 'threads';
      } else {
        _platform = 'auto';
      }
    });
  }

  bool get _valid {
    final v = _ctrl.text.trim().toLowerCase();
    return v.startsWith('http://') || v.startsWith('https://');
  }

  Future<void> _analyze() async {
    if (!_valid) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.invalidUrl)));
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _working = true);
    try {
      final result = await apiClient.analyzePost(_ctrl.text.trim(),
          campaignId: widget.campaignId);
      if (!mounted) return;
      setState(() => _working = false);
      await Navigator.of(context).push(
        MaterialPageRoute(
            builder: (_) =>
                ResultScreen(result: result, variantId: widget.variantId)),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _working = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.analyzeFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(s.aiAnalyzePostTitle)),
      body: _working ? _buildWorking() : _buildForm(),
    );
  }

  Widget _buildForm() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(s.pasteYourPost,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text(s.discoverTagline,
            style: const TextStyle(color: VirelloColors.muted, fontSize: 13)),
        const SizedBox(height: 20),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: VirelloColors.divider),
            boxShadow: VirelloColors.cardShadow,
          ),
          child: TextField(
            controller: _ctrl,
            keyboardType: TextInputType.url,
            onChanged: _detectPlatform,
            decoration: InputDecoration(
              hintText: s.pasteHint,
              hintStyle:
                  const TextStyle(color: VirelloColors.muted, fontSize: 14),
              prefixIcon:
                  const Icon(Icons.link, color: VirelloColors.violet, size: 22),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: _platformChip(),
        ),
        const SizedBox(height: 28),
        VGradientButton(
          label: s.analyze,
          icon: Icons.analytics_outlined,
          onPressed: _working ? null : _analyze,
        ),
        const SizedBox(height: 12),
        Text(s.estimatedNote,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: VirelloColors.muted)),
      ],
    );
  }

  Widget _platformChip() {
    final detected = _platform != 'auto';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: detected
            ? VirelloColors.violet.withValues(alpha: 0.1)
            : VirelloColors.chipBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(detected ? Icons.check_circle : Icons.link,
            size: 16,
            color: detected ? VirelloColors.violet : VirelloColors.muted),
        const SizedBox(width: 6),
        Text(_platform,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color:
                    detected ? VirelloColors.violet : VirelloColors.mutedDark)),
      ]),
    );
  }

  Widget _buildWorking() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: VCard(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(
              width: 64,
              height: 64,
              child: CircularProgressIndicator(
                  strokeWidth: 6, color: VirelloColors.violet),
            ),
            const SizedBox(height: 24),
            Text(s.analyzing,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(s.analyzingSub,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(color: VirelloColors.muted, fontSize: 13)),
          ]),
        ),
      ),
    );
  }
}
