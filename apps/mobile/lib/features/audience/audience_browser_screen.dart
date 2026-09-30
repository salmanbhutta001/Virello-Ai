import 'package:flutter/material.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../data/ads_models.dart';
import '../../services/api_client.dart';
import '../../main.dart';

/// Audience Intelligence: multi-source connector status, hierarchical
/// segment browser, and explainable fingerprint matching.
///
/// Honesty rules enforced in UI:
/// - Volumes shown ONLY when the source provided a real number; otherwise
///   "Volume unavailable".
/// - Scores are relevance fits — labeled "not a reach or virality guarantee".
/// - Unconfigured sources show "Not configured", never synthetic data.
class AudienceBrowserScreen extends StatefulWidget {
  /// Optional query (e.g. an upload caption) pre-filled into the
  /// fingerprint input.
  final String? initialQuery;
  const AudienceBrowserScreen({super.key, this.initialQuery});
  @override
  State<AudienceBrowserScreen> createState() => _AudienceBrowserScreenState();
}

class _AudienceBrowserScreenState extends State<AudienceBrowserScreen> {
  AppStrings get s => AppStrings(appState.localeCode);

  late Future<List<Map<String, dynamic>>> _sourcesFuture;
  late Future<List<AudienceSegment>> _segmentsFuture;
  final _fpCtrl = TextEditingController();

  bool _matching = false;
  String? _matchError;
  Map<String, dynamic>? _matchResult;

  @override
  void initState() {
    super.initState();
    // Optional pre-filled query from Upload Studio.
    if (widget.initialQuery != null && widget.initialQuery!.trim().isNotEmpty) {
      _fpCtrl.text = widget.initialQuery!.trim();
    }
    _sourcesFuture = apiClient.listAudienceSources();
    _segmentsFuture = apiClient.listAudienceSegments();
  }

  @override
  void dispose() {
    _fpCtrl.dispose();
    super.dispose();
  }

  Future<void> _runMatch() async {
    final text = _fpCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _matching = true;
      _matchError = null;
      _matchResult = null;
    });
    try {
      final res = await apiClient.matchAudience(text: text);
      setState(() => _matchResult = res);
    } on AuthException {
      setState(() => _matchError = s.sessionExpired);
    } catch (_) {
      setState(() => _matchError = s.growFailed);
    } finally {
      setState(() => _matching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(s.audienceIntel),
          bottom: TabBar(tabs: [
            Tab(text: s.aiSources, icon: const Icon(Icons.hub_outlined)),
            Tab(
                text: s.aiSegments,
                icon: const Icon(Icons.account_tree_outlined)),
            Tab(text: s.aiFingerprint, icon: const Icon(Icons.fingerprint)),
          ]),
        ),
        body: TabBarView(children: [
          _sourcesTab(),
          _segmentsTab(),
          _fingerprintTab(),
        ]),
      ),
    );
  }

  // ------------------------------------------------------------- sources tab
  Widget _sourcesTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _sourcesFuture,
      builder: (c, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text(s.growFailed));
        }
        final sources = snap.data ?? [];
        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.verified_user_outlined),
                title: Text(s.aiNoFakeData),
                dense: true,
              ),
            ),
            for (final src in sources) _sourceCard(src),
          ],
        );
      },
    );
  }

  Widget _sourceCard(Map<String, dynamic> src) {
    final status = '${src['status'] ?? ''}';
    final chipColor = status == 'ready'
        ? VirelloColors.success
        : status == 'not_configured'
            ? VTheme.textSec(context)
            : VirelloColors.amber;
    final chipLabel = status == 'ready'
        ? s.aiSourceStatusReady
        : status == 'not_configured'
            ? s.aiSourceStatusNotConfigured
            : s.aiSourceStatusDegraded;
    final conf = (src['confidence_score'] as num? ?? 0).toDouble();
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.source_outlined),
        title: Text('${src['source_name'] ?? ''}'),
        subtitle: Wrap(
          spacing: 6,
          children: [
            Chip(
              label: Text(chipLabel,
                  style:  TextStyle(fontSize: 11, color: VTheme.text(context))),
              backgroundColor: chipColor,
              visualDensity: VisualDensity.compact,
            ),
            Chip(
              label: Text(
                  '${src['cost_tier'] ?? ''} · ${src['freshness'] ?? ''}',
                  style: const TextStyle(fontSize: 11)),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _metaRow('Access', '${src['access_method'] ?? ''}'),
                _metaRow('Rate limit', '${src['rate_limit'] ?? ''}'),
                _metaRow('Coverage', '${src['geographic_coverage'] ?? ''}'),
                _metaRow('Permitted use', '${src['permitted_use'] ?? ''}'),
                const SizedBox(height: 6),
                Row(children: [
                  Text('${s.aiConfidence}: ',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: conf.clamp(0.0, 1.0),
                      minHeight: 8,
                      backgroundColor: VTheme.chip(context),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('${(conf * 100).round()}%'),
                ]),
                const SizedBox(height: 4),
                Text('${src['confidence_rationale'] ?? ''}',
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 4),
                Text('${src['tos_notes'] ?? ''}',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(fontStyle: FontStyle.italic)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metaRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: RichText(
          text: TextSpan(
            style: Theme.of(context).textTheme.bodySmall,
            children: [
              TextSpan(
                  text: '$label: ',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              TextSpan(text: value),
            ],
          ),
        ),
      );

  // ------------------------------------------------------------ segments tab
  Widget _segmentsTab() {
    return FutureBuilder<List<AudienceSegment>>(
      future: _segmentsFuture,
      builder: (c, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text(s.growFailed));
        }
        final segs = snap.data ?? [];
        if (segs.isEmpty) return Center(child: Text(s.noCampaigns));
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: segs.length,
          itemBuilder: (c, i) => _segmentCard(segs[i]),
        );
      },
    );
  }

  Widget _segmentCard(AudienceSegment seg) {
    final path = seg.path.isNotEmpty ? seg.path : seg.name;
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.group_outlined),
        title:
            Text(seg.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(path,
            style: Theme.of(context).textTheme.bodySmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis),
        trailing: Text('${(seg.confidence * 100).round()}%',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (seg.geography.isNotEmpty)
                  _metaRow('Geography', seg.geography),
                if (seg.languages.isNotEmpty)
                  _metaRow('Languages', seg.languages.join(', ')),
                if (seg.topics.isNotEmpty)
                  _metaRow('Topics', seg.topics.join(', ')),
                const SizedBox(height: 6),
                Text(s.aiSourceBreakdown,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                for (final b in seg.sourceBreakdown)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(children: [
                      Expanded(
                          child: Text('${b['source'] ?? ''}',
                              style: Theme.of(context).textTheme.bodySmall)),
                      SizedBox(
                        width: 120,
                        child: LinearProgressIndicator(
                          value: ((b['contribution'] as num?) ?? 0)
                              .toDouble()
                              .clamp(0.0, 1.0),
                          minHeight: 8,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                          '${((((b['contribution'] as num?) ?? 0).toDouble()) * 100).round()}%'),
                    ]),
                  ),
                const SizedBox(height: 6),
                Text(seg.explanation,
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 4),
                Text(seg.disclaimer,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(fontStyle: FontStyle.italic)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------- fingerprint tab
  Widget _fingerprintTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(s.aiAnalyzePost, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        TextField(
          controller: _fpCtrl,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: s.aiPastePostHint,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _matching ? null : _runMatch,
          icon: _matching
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.fingerprint),
          label: Text(s.analyze),
        ),
        if (_matchError != null) ...[
          const SizedBox(height: 8),
          Text(_matchError!,
              style: const TextStyle(color: VirelloColors.danger)),
        ],
        if (_matchResult != null) ...[
          const SizedBox(height: 16),
          _fingerprintSummary(),
          const SizedBox(height: 12),
          _matchesList(),
          const SizedBox(height: 8),
          Text(s.aiRelevanceFitNote,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(fontStyle: FontStyle.italic)),
        ],
      ],
    );
  }

  Widget _fingerprintSummary() {
    final fp =
        Map<String, dynamic>.from((_matchResult!['fingerprint'] as Map?) ?? {});
    final topics = ((fp['topics'] as List?) ?? []).join(', ');
    final keywords = ((fp['keywords'] as List?) ?? []).take(8).join(', ');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.aiFingerprint,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            _metaRow('Topics', topics.isEmpty ? '—' : topics),
            _metaRow('Keywords', keywords.isEmpty ? '—' : keywords),
            _metaRow('Language', '${fp['language'] ?? ''}'),
            _metaRow('Category', '${fp['category'] ?? ''}'),
          ],
        ),
      ),
    );
  }

  Widget _matchesList() {
    final matches = (((_matchResult!['matches'] as List?) ?? [])
        .cast<Map<String, dynamic>>());
    if (matches.isEmpty) return Text(s.aiNoMatch);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final m in matches) _matchCard(m),
      ],
    );
  }

  Widget _matchCard(Map<String, dynamic> m) {
    final score = (m['score'] as num? ?? 0).toDouble();
    final contribs =
        (((m['contributions'] as List?) ?? []).cast<Map<String, dynamic>>());
    return Card(
      child: ExpansionTile(
        leading: CircleAvatar(
          child: Text('${(score * 100).round()}',
              style: const TextStyle(fontSize: 12)),
        ),
        title: Text('${m['name'] ?? ''}',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${s.aiFitScore}: ${(score * 100).round()}%',
            style: Theme.of(context).textTheme.bodySmall),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.aiWhyThis,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                for (final c in contribs) _contributionBar(c),
                const SizedBox(height: 6),
                for (final r in ((m['reasons'] as List?) ?? []))
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• '),
                        Expanded(
                            child: Text('$r',
                                style: Theme.of(context).textTheme.bodySmall)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _contributionBar(Map<String, dynamic> c) {
    final factor = '${c['factor'] ?? ''}';
    final score = (c['score'] as num? ?? 0).toDouble().clamp(0.0, 1.0);
    final weight = (c['weight'] as num? ?? 0).toDouble();
    final contrib = (c['contribution'] as num? ?? 0).toDouble();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child:
                    Text(factor, style: Theme.of(context).textTheme.bodySmall),
              ),
              Text('w ${(weight * 100).round()}% · +${(contrib * 100).round()}',
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 2),
          LinearProgressIndicator(
            value: score,
            minHeight: 8,
            backgroundColor: VTheme.chip(context),
          ),
          Text('${c['reason'] ?? ''}',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: VTheme.textSec(context))),
        ],
      ),
    );
  }
}
