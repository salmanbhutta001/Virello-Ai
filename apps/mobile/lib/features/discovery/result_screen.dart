import 'package:flutter/material.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/virello_ui.dart';
import '../../data/discovery_models.dart';
import '../../main.dart';
import '../audience/audience_insights_screen.dart';
import '../grow/grow_flow.dart';

/// Step 3–4 of the journey: the analysis result + Save / Grow actions.
/// The score is always presented with its honesty disclaimer — an estimate,
/// never a prediction or guarantee.
class ResultScreen extends StatefulWidget {
  final PostAnalysisResult result;
  final String? variantId;
  const ResultScreen({super.key, required this.result, this.variantId});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  bool _saving = false;

  AppStrings get s => AppStrings(appState.localeCode);
  PostAnalysisResult get r => widget.result;

  Future<void> _save() async {
    if (_saving) return;
    if (savedStore.contains(r.url)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.alreadySaved)));
      return;
    }
    setState(() => _saving = true);
    try {
      // Genuine backend signal when this came from the discovery feed.
      if (r.campaignId != null && r.campaignId!.isNotEmpty) {
        await apiClient.recordInteraction(
            campaignId: r.campaignId!,
            kind: 'save',
            variantId: widget.variantId);
      }
      await savedStore.save(r);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.savedDone)));
    } catch (_) {
      // Local save still counts if the backend call failed.
      await savedStore.save(r);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.savedDone)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _grow() {
    pendingGrowUrl.value = r.url;
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const GrowFlow()));
  }

  void _next() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            AudienceInsightsScreen(postUrl: r.url, postTitle: r.title),
      ),
    );
  }

  String get _fetchLabel => switch (r.fetchLevel) {
        'oembed' => s.fetchLevelOembed,
        'opengraph' => s.fetchLevelOpengraph,
        _ => s.fetchLevelMinimal,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(s.contentScore)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _postCard(),
          const SizedBox(height: 20),
          VSectionHeader(title: s.contentScore),
          const SizedBox(height: 12),
          _scoreCard(),
          const SizedBox(height: 16),
          _componentsCard(),
          const SizedBox(height: 16),
          _disclaimerCard(),
          if (r.hashtags.isNotEmpty) ...[
            const SizedBox(height: 16),
            _hashtagChips(),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.bookmark_add_outlined),
            label: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(s.save,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 12),
          VGradientButton(
            label: s.nextAudienceInsights,
            icon: Icons.arrow_forward,
            onPressed: _next,
          ),
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed: _grow,
            icon: const Icon(Icons.rocket_launch_outlined,
                color: VirelloColors.violet),
            label: Text(s.growThisPost,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: VirelloColors.violet)),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  /// Post summary: thumbnail (play overlay for video) + meta chips + title.
  Widget _postCard() {
    return VCard(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (r.thumbnailUrl.isNotEmpty)
          Stack(alignment: Alignment.center, children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.network(r.thumbnailUrl,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink()),
            ),
            if (r.mediaType == 'video')
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.55),
                ),
                child:
                    const Icon(Icons.play_arrow, color: Colors.white, size: 30),
              ),
          ]),
        if (r.thumbnailUrl.isNotEmpty) const SizedBox(height: 12),
        Wrap(spacing: 6, runSpacing: 6, children: [
          _metaChip(r.platform.isEmpty ? 'link' : r.platform, tinted: true),
          if (r.author.isNotEmpty) _metaChip(r.author),
          if (r.language != 'unknown') _metaChip(r.language.toUpperCase()),
          _metaChip(r.mediaType),
        ]),
        const SizedBox(height: 10),
        Text(r.title.isEmpty ? s.noTitle : r.title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        if (r.description.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(r.description,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: VirelloColors.muted)),
        ],
      ]),
    );
  }

  Widget _metaChip(String label, {bool tinted = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: tinted
            ? VirelloColors.violet.withValues(alpha: 0.1)
            : VirelloColors.chipBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color:
                  tinted ? VirelloColors.violetDeep : VirelloColors.mutedDark)),
    );
  }

  Widget _scoreCard() {
    return VCard(
      child: Row(children: [
        VScoreRing(score: r.score.toDouble(), size: 110),
        const SizedBox(width: 18),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.contentScore,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: VirelloColors.muted)),
            const SizedBox(height: 6),
            Text(_fetchLabel,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: VirelloColors.mutedDark)),
          ]),
        ),
      ]),
    );
  }

  Widget _componentsCard() {
    const order = [
      'hook',
      'clarity',
      'hashtag_hygiene',
      'media',
      'cta',
      'language_fit'
    ];
    final comps = order.where((k) => r.components.containsKey(k)).toList();
    if (comps.isEmpty) return const SizedBox.shrink();
    return VCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (var i = 0; i < comps.length; i++) ...[
          Row(children: [
            Expanded(
                flex: 3,
                child: Text(s.componentLabel(comps[i]),
                    style: const TextStyle(fontSize: 13))),
            Expanded(
              flex: 5,
              child: LinearProgressIndicator(
                value: (r.components[comps[i]]! / 100).clamp(0.0, 1.0),
                minHeight: 8,
                borderRadius: BorderRadius.circular(8),
                color: VirelloColors.violet,
                backgroundColor: VirelloColors.chipBg,
              ),
            ),
            SizedBox(
                width: 40,
                child: Text('${r.components[comps[i]]}',
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700))),
          ]),
          if (i != comps.length - 1) const SizedBox(height: 12),
        ],
      ]),
    );
  }

  Widget _disclaimerCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: VirelloColors.violet.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.verified_outlined,
            color: VirelloColors.violet, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            r.disclaimer.isEmpty ? s.estimatedNote : r.disclaimer,
            style:
                const TextStyle(fontSize: 12, color: VirelloColors.mutedDark),
          ),
        ),
      ]),
    );
  }

  Widget _hashtagChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: r.hashtags
          .take(12)
          .map((h) => Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: VirelloColors.violet.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text('#$h',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: VirelloColors.violetDeep)),
              ))
          .toList(),
    );
  }
}
