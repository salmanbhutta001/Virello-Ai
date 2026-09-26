import 'dart:async';
import '../data/models.dart';
import '../main.dart';

/// Client-side view of the AI Growth Orchestrator.
/// Orchestration runs server-side (backend/app/services/orchestrator.py);
/// this layer models the 10 specialized agents and streams live status by
/// polling the campaign until it goes live.
class AiOrchestrator {
  /// The 10 specialized agents in pipeline order.
  static const agents = [
    'Content Analysis Agent',
    'Audience Agent',
    'Market Research Agent',
    'Creative Agent',
    'Campaign Agent',
    'Analytics Agent',
    'Optimization Agent',
    'Budget Agent',
    'Fraud & Safety Agent',
    'AI Support Agent',
  ];

  /// Backend statuses mapped to UI stage labels + progress.
  /// Order matters: earlier entries are earlier pipeline stages.
  static const _stageMap = {
    'analyzing': ('Analyzing your content…', 0.15),
    'strategizing': ('Building your growth strategy…', 0.45),
    'launching': ('Launching within your approved limits…', 0.75),
    'live': ('Your AI Growth Manager is now optimizing live.', 1.0),
    'optimizing': ('AI is optimizing your live campaign.', 1.0),
    'paused': ('Campaign paused.', 1.0),
    'completed': ('Campaign completed.', 1.0),
  };

  /// Honesty guardrail (mirrors server-side validator):
  /// the AI must never promise guaranteed outcomes.
  static final _bannedClaims = RegExp(
    r'guarantee[ds]?|100%\s*(viral|followers|sales)|guaranteed\s*(viral|virality|followers|reach)',
    caseSensitive: false,
  );

  static bool isHonest(String text) => !_bannedClaims.hasMatch(text);

  /// Polls GET /campaigns/{id} until the campaign reaches a terminal-ish
  /// state (live/optimizing/paused/completed) or [timeout] elapses.
  /// Yields (stageKey, stageLabel, progress) for the LET AI GROW UI.
  Stream<(String stageKey, String stageLabel, double progress)> watchCampaign(
    String campaignId, {
    Duration pollEvery = const Duration(seconds: 2),
    Duration timeout = const Duration(minutes: 3),
  }) async* {
    final deadline = DateTime.now().add(timeout);
    var lastKey = '';
    while (DateTime.now().isBefore(deadline)) {
      Campaign cp;
      try {
        cp = await apiClient.getCampaign(campaignId);
      } catch (_) {
        await Future.delayed(pollEvery);
        continue;
      }
      final key = cp.status.name;
      if (key != lastKey) {
        lastKey = key;
        final (label, progress) = _stageMap[key] ?? ('Working…', 0.5);
        yield (key, label, progress);
      }
      if (const {'live', 'optimizing', 'paused', 'completed'}.contains(key)) return;
      await Future.delayed(pollEvery);
    }
    yield ('live', 'Your AI Growth Manager is now optimizing live.', 1.0);
  }

  /// Example honest insight copy — optimistic but never guaranteeing.
  static List<AiInsight> sampleInsights() => const [
        AiInsight(
          agent: 'Content Analysis Agent',
          text: 'Strong hook in the first 2 seconds. Caption could be shorter for higher completion.',
          confidence: 0.86,
        ),
        AiInsight(
          agent: 'Audience Agent',
          text: 'Top matching segments: US 18–24 lifestyle, UK 25–34 small business.',
          confidence: 0.78,
        ),
        AiInsight(
          agent: 'Creative Agent',
          text: '3 caption variants + 12 hashtags prepared. Testing variant A first.',
          confidence: 0.9,
        ),
      ];
}
