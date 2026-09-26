/// Phase 1 ad platform models. Mirror backend/app/models/ads.py
/// and app/routers/audience.py + app/routers/ads.py responses.
class AudienceSegment {
  final String id;
  final String name;
  final String description;
  final Map<String, dynamic> rule;
  final List<String> signalsUsed;
  final int sizeEstimate;
  final List<String> languages;
  final List<String> topics;
  final bool isActive;
  final String explanation;
  final String disclaimer;
  // Multi-source intelligence graph fields.
  final String path;
  final String geography;
  final List<Map<String, dynamic>> sourceBreakdown;
  final double confidence;

  const AudienceSegment({
    required this.id,
    required this.name,
    required this.description,
    required this.rule,
    required this.signalsUsed,
    required this.sizeEstimate,
    required this.languages,
    required this.topics,
    required this.isActive,
    required this.explanation,
    required this.disclaimer,
    this.path = '',
    this.geography = '',
    this.sourceBreakdown = const [],
    this.confidence = 0.5,
  });

  factory AudienceSegment.fromJson(Map<String, dynamic> j) => AudienceSegment(
        id: j['id'] as String? ?? '',
        name: j['name'] as String? ?? '',
        description: j['description'] as String? ?? '',
        rule: Map<String, dynamic>.from(j['rule'] as Map? ?? const {}),
        signalsUsed:
            ((j['signals_used'] as List?) ?? []).map((e) => '$e').toList(),
        sizeEstimate: (j['size_estimate'] as num? ?? 0).toInt(),
        languages: ((j['languages'] as List?) ?? []).map((e) => '$e').toList(),
        topics: ((j['topics'] as List?) ?? []).map((e) => '$e').toList(),
        isActive: j['is_active'] as bool? ?? true,
        explanation: j['explanation'] as String? ?? '',
        disclaimer: j['disclaimer'] as String? ?? '',
        path: j['path'] as String? ?? '',
        geography: j['geography'] as String? ?? '',
        sourceBreakdown: ((j['source_breakdown'] as List?) ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList(),
        confidence: (j['confidence'] as num? ?? 0.5).toDouble(),
      );
}

class MatchContribution {
  final String factor;
  final double weight;
  final double score;
  final double contribution;
  final String reason;

  const MatchContribution({
    required this.factor,
    required this.weight,
    required this.score,
    required this.contribution,
    required this.reason,
  });

  factory MatchContribution.fromJson(Map<String, dynamic> j) =>
      MatchContribution(
        factor: j['factor'] as String? ?? '',
        weight: (j['weight'] as num? ?? 0).toDouble(),
        score: (j['score'] as num? ?? 0).toDouble(),
        contribution: (j['contribution'] as num? ?? 0).toDouble(),
        reason: j['reason'] as String? ?? '',
      );
}

class SegmentMatch {
  final String segmentId;
  final String name;
  final double score;
  final List<MatchContribution> contributions;
  final List<String> reasons;
  final List<String> signalsUsed;

  const SegmentMatch({
    required this.segmentId,
    required this.name,
    required this.score,
    required this.contributions,
    required this.reasons,
    required this.signalsUsed,
  });

  factory SegmentMatch.fromJson(Map<String, dynamic> j) => SegmentMatch(
        segmentId: j['segment_id'] as String? ?? '',
        name: j['name'] as String? ?? '',
        score: (j['score'] as num? ?? 0).toDouble(),
        contributions: ((j['contributions'] as List?) ?? [])
            .map((e) => MatchContribution.fromJson(
                Map<String, dynamic>.from(e as Map)))
            .toList(),
        reasons: ((j['reasons'] as List?) ?? []).map((e) => '$e').toList(),
        signalsUsed:
            ((j['signals_used'] as List?) ?? []).map((e) => '$e').toList(),
      );
}

class CampaignProposal {
  final String objective;
  final List<String> topics;
  final List<String> languages;
  final List<String> segmentIds;
  final double recommendedBudgetUsd;
  final int durationDays;
  final String rationale;
  final bool heuristic;

  const CampaignProposal({
    required this.objective,
    required this.topics,
    required this.languages,
    required this.segmentIds,
    required this.recommendedBudgetUsd,
    required this.durationDays,
    required this.rationale,
    required this.heuristic,
  });

  factory CampaignProposal.fromJson(Map<String, dynamic> j) => CampaignProposal(
        objective: j['objective'] as String? ?? 'views',
        topics: ((j['topics'] as List?) ?? []).map((e) => '$e').toList(),
        languages: ((j['languages'] as List?) ?? []).map((e) => '$e').toList(),
        segmentIds:
            ((j['segment_ids'] as List?) ?? []).map((e) => '$e').toList(),
        recommendedBudgetUsd:
            (j['recommended_budget_usd'] as num? ?? 0).toDouble(),
        durationDays: (j['duration_days'] as num? ?? 7).toInt(),
        rationale: j['rationale'] as String? ?? '',
        heuristic: j['heuristic'] as bool? ?? false,
      );
}

class ReachEstimate {
  final int low;
  final int high;
  final String disclaimer;

  const ReachEstimate({
    required this.low,
    required this.high,
    required this.disclaimer,
  });

  factory ReachEstimate.fromJson(Map<String, dynamic> j) => ReachEstimate(
        low: (j['estimated_reach_low'] as num? ?? 0).toInt(),
        high: (j['estimated_reach_high'] as num? ?? 0).toInt(),
        disclaimer: j['disclaimer'] as String? ?? '',
      );
}

class AdCampaign {
  final String id;
  final String objective;
  final String contentRef;
  final Map<String, dynamic> contentSignals;
  final List<String> topics;
  final List<String> languages;
  final List<String> segmentIds;
  final double budget;
  final int durationDays;
  final String status; // draft|pending_approval|approved|rejected|active|paused|completed
  final ReachEstimate? estimate;
  final String aiProvider;
  final bool dev;
  final String? createdAt;
  final String languageTargetingMode; // single|multiple|all_relevant
  final List<String> targetLanguages;
  final List<Map<String, dynamic>> suggestedLanguages;
  final String geoMode; // ai_recommended|worldwide|custom
  final List<String> geoCountries; // effective ISO codes (worldwide -> [])
  final Map<String, dynamic> suggestedGeography; // {countries, reasons}
  final String plan; // free|paid — Free Grow (worldwide, $0) vs Paid Boost
  final String? packageId; // paid package id (starter|growth|pro|scale), null for free
  final String growthAgent; // free_growth_agent | paid_growth_agent

  const AdCampaign({
    required this.id,
    required this.objective,
    required this.contentRef,
    required this.contentSignals,
    required this.topics,
    required this.languages,
    required this.segmentIds,
    required this.budget,
    required this.durationDays,
    required this.status,
    this.estimate,
    required this.aiProvider,
    required this.dev,
    this.createdAt,
    this.languageTargetingMode = 'single',
    this.targetLanguages = const [],
    this.suggestedLanguages = const [],
    this.geoMode = 'ai_recommended',
    this.geoCountries = const [],
    this.suggestedGeography = const {},
    this.plan = 'paid',
    this.packageId,
    this.growthAgent = 'paid_growth_agent',
  });

  factory AdCampaign.fromJson(Map<String, dynamic> j) => AdCampaign(
        id: j['id'] as String? ?? '',
        objective: j['objective'] as String? ?? 'views',
        contentRef: j['content_ref'] as String? ?? '',
        contentSignals:
            Map<String, dynamic>.from(j['content_signals'] as Map? ?? const {}),
        topics: ((j['topics'] as List?) ?? []).map((e) => '$e').toList(),
        languages: ((j['languages'] as List?) ?? []).map((e) => '$e').toList(),
        segmentIds:
            ((j['segment_ids'] as List?) ?? []).map((e) => '$e').toList(),
        budget: (j['budget'] as num? ?? 0).toDouble(),
        durationDays: (j['duration_days'] as num? ?? 7).toInt(),
        status: j['status'] as String? ?? 'draft',
        estimate: j['estimate'] == null
            ? null
            : ReachEstimate.fromJson(
                Map<String, dynamic>.from(j['estimate'] as Map)),
        aiProvider: j['ai_provider'] as String? ?? '',
        dev: j['dev'] as bool? ?? true,
        createdAt: j['created_at'] as String?,
        languageTargetingMode:
            j['language_targeting_mode'] as String? ?? 'single',
        targetLanguages:
            ((j['target_languages'] as List?) ?? []).map((e) => '$e').toList(),
        suggestedLanguages: ((j['suggested_languages'] as List?) ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList(),
        geoMode: j['geo_mode'] as String? ?? 'ai_recommended',
        geoCountries:
            ((j['geo_countries'] as List?) ?? []).map((e) => '$e').toList(),
        suggestedGeography: Map<String, dynamic>.from(
            j['suggested_geography'] as Map? ?? const {}),
        plan: j['plan'] as String? ?? 'paid',
        packageId: j['package_id'] as String?,
        growthAgent: j['growth_agent'] as String? ?? 'paid_growth_agent',
      );

  bool get isFree => plan == 'free';
  bool get isPaid => plan != 'free';
  bool get isFreeGrowthAgent => growthAgent == 'free_growth_agent';
  bool get isDraft => status == 'draft';
  bool get isPendingApproval => status == 'pending_approval';
  bool get isApproved => status == 'approved';
  bool get isActive => status == 'active';
  bool get isPaused => status == 'paused';
  bool get isCompleted => status == 'completed';
}

/// Detail view payload: the campaign plus its current ranked matches.
class AdCampaignDetail {
  final AdCampaign campaign;
  final List<SegmentMatch> matches;

  const AdCampaignDetail({required this.campaign, required this.matches});

  factory AdCampaignDetail.fromJson(Map<String, dynamic> j) => AdCampaignDetail(
        campaign: AdCampaign.fromJson(
            Map<String, dynamic>.from(j['campaign'] as Map)),
        matches: ((j['matches'] as List?) ?? [])
            .map((e) => SegmentMatch.fromJson(
                Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

/// Result of the builder POST: campaign + analysis + matches + proposal.
class AdBuildResult {  final AdCampaign campaign;
  final Map<String, dynamic> signals;
  final List<SegmentMatch> matches;
  final CampaignProposal proposal;
  final ReachEstimate estimate;
  final bool usedAi;

  const AdBuildResult({
    required this.campaign,
    required this.signals,
    required this.matches,
    required this.proposal,
    required this.estimate,
    required this.usedAi,
  });

  factory AdBuildResult.fromJson(Map<String, dynamic> j) => AdBuildResult(
        campaign: AdCampaign.fromJson(
            Map<String, dynamic>.from(j['campaign'] as Map)),
        signals: Map<String, dynamic>.from(
            (j['analysis'] as Map?)?['signals'] as Map? ?? const {}),
        matches: ((j['matches'] as List?) ?? [])
            .map((e) => SegmentMatch.fromJson(
                Map<String, dynamic>.from(e as Map)))
            .toList(),
        proposal: CampaignProposal.fromJson(
            Map<String, dynamic>.from(j['proposal'] as Map)),
        estimate: ReachEstimate.fromJson(
            Map<String, dynamic>.from(j['estimate'] as Map)),
        usedAi: j['used_ai'] as bool? ?? false,
      );
}

/// Phase 2: Sponsored Discovery / Ad Network models.
/// Mirror backend/app/models/ad_delivery.py + app/services/ad_distribution.py.

/// One place where a campaign's sponsored unit can be served.
class AdPlacement {
  final String id;
  final String campaignId;
  final String placementType; // sponsored_discovery | recommended_posts | native_promo | feed
  final String status; // active | paused
  final double weight;

  const AdPlacement({
    required this.id,
    required this.campaignId,
    required this.placementType,
    required this.status,
    required this.weight,
  });

  factory AdPlacement.fromJson(Map<String, dynamic> j) => AdPlacement(
        id: j['id'] as String? ?? '',
        campaignId: j['campaign_id'] as String? ?? '',
        placementType: j['placement_type'] as String? ?? 'sponsored_discovery',
        status: j['status'] as String? ?? 'active',
        weight: (j['weight'] as num? ?? 1.0).toDouble(),
      );
}

/// A sponsored unit served for the viewer. ALWAYS labeled:
/// [isSponsored] is true by contract and [label] is the visible
/// "Sponsored" badge text in the viewer's language.
class SponsoredAdUnit {
  final String campaignId;
  final String placementId;
  final String placementType;
  final String segmentId;
  final String segmentName;
  final double matchScore;
  final List<String> matchReasons;
  final String objective;
  final String contentRef;
  final List<String> topics;
  final bool isSponsored;
  final String label;
  // Phase 3: the rotated creative variant — report variantId back on events
  // so per-variant performance is measured from genuine renders.
  final String? variantId;
  final String? variantLabel;

  const SponsoredAdUnit({
    required this.campaignId,
    required this.placementId,
    required this.placementType,
    required this.segmentId,
    required this.segmentName,
    required this.matchScore,
    required this.matchReasons,
    required this.objective,
    required this.contentRef,
    required this.topics,
    required this.isSponsored,
    required this.label,
    this.variantId,
    this.variantLabel,
  });

  factory SponsoredAdUnit.fromJson(Map<String, dynamic> j) => SponsoredAdUnit(
        campaignId: j['campaign_id'] as String? ?? '',
        placementId: j['placement_id'] as String? ?? '',
        placementType: j['placement_type'] as String? ?? 'sponsored_discovery',
        segmentId: j['segment_id'] as String? ?? '',
        segmentName: j['segment_name'] as String? ?? '',
        matchScore: (j['match_score'] as num? ?? 0).toDouble(),
        matchReasons:
            ((j['match_reasons'] as List?) ?? []).map((e) => '$e').toList(),
        objective: j['objective'] as String? ?? 'views',
        contentRef: j['content_ref'] as String? ?? '',
        topics: ((j['topics'] as List?) ?? []).map((e) => '$e').toList(),
        // Transparency is non-negotiable: the backend always sends true.
        isSponsored: j['is_sponsored'] as bool? ?? true,
        label: j['label'] as String? ?? 'Sponsored',
        variantId: (j['variant'] as Map?)?['variant_id'] as String?,
        variantLabel: (j['variant'] as Map?)?['label'] as String?,
      );
}

/// Delivery overview for a campaign: genuine measured events, spend derived
/// from priced events, pacing status, per-placement breakdown.
class AdDeliveryStats {
  final String campaignId;
  final String status;
  final String objective;
  final int impressions;
  final Map<String, int> events;
  final int pricedEvents;
  final double spentUsd;
  final double budgetUsd;
  final double remainingUsd;
  final double dailyCapUsd;
  final double spentTodayUsd;
  final String pacingDate;
  final bool onPace;
  final List<AdPlacementStats> placements;
  final int freqCap;
  final String disclaimer;

  const AdDeliveryStats({
    required this.campaignId,
    required this.status,
    required this.objective,
    required this.impressions,
    required this.events,
    required this.pricedEvents,
    required this.spentUsd,
    required this.budgetUsd,
    required this.remainingUsd,
    required this.dailyCapUsd,
    required this.spentTodayUsd,
    required this.pacingDate,
    required this.onPace,
    required this.placements,
    required this.freqCap,
    required this.disclaimer,
  });

  factory AdDeliveryStats.fromJson(Map<String, dynamic> j) {
    final pacing = Map<String, dynamic>.from(j['pacing'] as Map? ?? const {});
    final ev = Map<String, dynamic>.from(j['events'] as Map? ?? const {});
    return AdDeliveryStats(
      campaignId: j['campaign_id'] as String? ?? '',
      status: j['status'] as String? ?? '',
      objective: j['objective'] as String? ?? '',
      impressions: (j['impressions'] as num? ?? 0).toInt(),
      events: ev.map((k, v) => MapEntry(k.toString(), (v as num? ?? 0).toInt())),
      pricedEvents: (j['priced_events'] as num? ?? 0).toInt(),
      spentUsd: (j['spent_usd'] as num? ?? 0).toDouble(),
      budgetUsd: (j['budget_usd'] as num? ?? 0).toDouble(),
      remainingUsd: (j['remaining_usd'] as num? ?? 0).toDouble(),
      dailyCapUsd: (pacing['daily_cap_usd'] as num? ?? 0).toDouble(),
      spentTodayUsd: (pacing['spent_today_usd'] as num? ?? 0).toDouble(),
      pacingDate: pacing['date'] as String? ?? '',
      onPace: pacing['on_pace'] as bool? ?? false,
      placements: ((j['placements'] as List?) ?? [])
          .map((e) => AdPlacementStats.fromJson(
              Map<String, dynamic>.from(e as Map)))
          .toList(),
      freqCap: (j['freq_cap'] as num? ?? 3).toInt(),
      disclaimer: j['disclaimer'] as String? ?? '',
    );
  }

  double get spendPct =>
      budgetUsd <= 0 ? 0 : (spentUsd / budgetUsd).clamp(0.0, 1.0);
}

class AdPlacementStats {
  final String placementId;
  final String placementType;
  final String status;
  final int impressions;

  const AdPlacementStats({
    required this.placementId,
    required this.placementType,
    required this.status,
    required this.impressions,
  });

  factory AdPlacementStats.fromJson(Map<String, dynamic> j) =>
      AdPlacementStats(
        placementId: j['placement_id'] as String? ?? '',
        placementType: j['placement_type'] as String? ?? '',
        status: j['status'] as String? ?? '',
        impressions: (j['impressions'] as num? ?? 0).toInt(),
      );
}

/// Phase 3: AI Distribution & Optimization Agent models.
/// Mirror backend/app/models/ad_optimization.py +
/// app/services/ad_optimizer.py responses.

/// One optimizer pass over a campaign: what was measured, what changed.
class AdOptimizationRun {
  final String id;
  final String status; // completed | safety_paused | skipped | failed
  final String triggeredBy; // manual | scheduler
  final String? startedAt;
  final String? endedAt;
  final Map<String, dynamic> summary;

  const AdOptimizationRun({
    required this.id,
    required this.status,
    required this.triggeredBy,
    this.startedAt,
    this.endedAt,
    required this.summary,
  });

  factory AdOptimizationRun.fromJson(Map<String, dynamic> j) =>
      AdOptimizationRun(
        id: j['id'] as String? ?? '',
        status: j['status'] as String? ?? 'completed',
        triggeredBy: j['triggered_by'] as String? ?? 'manual',
        startedAt: j['started_at'] as String?,
        endedAt: j['ended_at'] as String?,
        summary:
            Map<String, dynamic>.from(j['summary'] as Map? ?? const {}),
      );

  bool get wasSafetyPaused => status == 'safety_paused';

  String summaryLine() {
    final s = summary;
    if (wasSafetyPaused) {
      final reasons = (s['fraud_reasons'] as List?) ?? const [];
      return reasons.isNotEmpty ? '${reasons.first}' : 'Safety pause';
    }
    final seg = s['segments_adjusted'];
    final plc = s['placements_compared'];
    final vars = s['variants_tested'];
    return 'Segments adjusted: ${seg ?? 0} · '
        'Placements compared: ${plc ?? 0} · '
        'Variants tested: ${vars ?? 0}';
  }
}

/// One audited optimizer decision: reasons + before/after metrics.
class AdOptimizerDecision {
  final String id;
  final String action;
  final Map<String, dynamic> details;
  final String? createdAt;

  const AdOptimizerDecision({
    required this.id,
    required this.action,
    required this.details,
    this.createdAt,
  });

  factory AdOptimizerDecision.fromJson(Map<String, dynamic> j) =>
      AdOptimizerDecision(
        id: j['id'] as String? ?? '',
        action: j['action'] as String? ?? '',
        details:
            Map<String, dynamic>.from(j['details'] as Map? ?? const {}),
        createdAt: j['created_at'] as String?,
      );

  List<String> get reasons =>
      ((details['reasons'] as List?) ?? []).map((e) => '$e').toList();

  Map<String, dynamic> get metrics =>
      Map<String, dynamic>.from(details['metrics'] as Map? ?? const {});
}

/// Per-segment performance: measured figures + plain-language verdict.
class AdSegmentPerformance {
  final String segmentId;
  final String segmentName;
  final double weight;
  final int impressions;
  final int views;
  final int engagements;
  final double engagementRate;
  final String plain;

  const AdSegmentPerformance({
    required this.segmentId,
    required this.segmentName,
    required this.weight,
    required this.impressions,
    required this.views,
    required this.engagements,
    required this.engagementRate,
    required this.plain,
  });

  factory AdSegmentPerformance.fromJson(Map<String, dynamic> j) =>
      AdSegmentPerformance(
        segmentId: j['segment_id'] as String? ?? '',
        segmentName: j['segment_name'] as String? ?? '',
        weight: (j['weight'] as num? ?? 1.0).toDouble(),
        impressions: (j['impressions'] as num? ?? 0).toInt(),
        views: (j['views'] as num? ?? 0).toInt(),
        engagements: (j['engagements'] as num? ?? 0).toInt(),
        engagementRate: (j['engagement_rate'] as num? ?? 0).toDouble(),
        plain: j['plain'] as String? ?? '',
      );
}

/// Per-variant performance in the rotation.
class AdVariantPerformance {
  final String variantId;
  final String label;
  final bool isOriginal;
  final String status;
  final double weight;
  final int impressions;
  final double engagementRate;
  final String plain;

  const AdVariantPerformance({
    required this.variantId,
    required this.label,
    required this.isOriginal,
    required this.status,
    required this.weight,
    required this.impressions,
    required this.engagementRate,
    required this.plain,
  });

  factory AdVariantPerformance.fromJson(Map<String, dynamic> j) =>
      AdVariantPerformance(
        variantId: j['variant_id'] as String? ?? '',
        label: j['label'] as String? ?? '',
        isOriginal: j['is_original'] as bool? ?? false,
        status: j['status'] as String? ?? 'active',
        weight: (j['weight'] as num? ?? 1.0).toDouble(),
        impressions: (j['impressions'] as num? ?? 0).toInt(),
        engagementRate: (j['engagement_rate'] as num? ?? 0).toDouble(),
        plain: j['plain'] as String? ?? '',
      );
}

/// Per-placement performance comparison.
class AdPlacementPerformance {
  final String placementId;
  final String placementType;
  final String status;
  final double weight;
  final int impressions;
  final double engagementRate;
  final String plain;

  const AdPlacementPerformance({
    required this.placementId,
    required this.placementType,
    required this.status,
    required this.weight,
    required this.impressions,
    required this.engagementRate,
    required this.plain,
  });

  factory AdPlacementPerformance.fromJson(Map<String, dynamic> j) =>
      AdPlacementPerformance(
        placementId: j['placement_id'] as String? ?? '',
        placementType: j['placement_type'] as String? ?? '',
        status: j['status'] as String? ?? 'active',
        weight: (j['weight'] as num? ?? 1.0).toDouble(),
        impressions: (j['impressions'] as num? ?? 0).toInt(),
        engagementRate: (j['engagement_rate'] as num? ?? 0).toDouble(),
        plain: j['plain'] as String? ?? '',
      );
}

/// Full explainable performance summary for a campaign.
class AdInsights {
  final String campaignId;
  final String status;
  final String objective;
  final Map<String, int> totals;
  final List<AdSegmentPerformance> segments;
  final List<AdVariantPerformance> variants;
  final List<AdPlacementPerformance> placements;
  final int minSampleGuard;
  final String note;
  final String disclaimer;

  const AdInsights({
    required this.campaignId,
    required this.status,
    required this.objective,
    required this.totals,
    required this.segments,
    required this.variants,
    required this.placements,
    required this.minSampleGuard,
    required this.note,
    required this.disclaimer,
  });

  factory AdInsights.fromJson(Map<String, dynamic> j) {
    final t = Map<String, dynamic>.from(j['totals'] as Map? ?? const {});
    return AdInsights(
      campaignId: j['campaign_id'] as String? ?? '',
      status: j['status'] as String? ?? '',
      objective: j['objective'] as String? ?? '',
      totals:
          t.map((k, v) => MapEntry(k.toString(), (v as num? ?? 0).toInt())),
      segments: ((j['segments'] as List?) ?? [])
          .map((e) => AdSegmentPerformance.fromJson(
              Map<String, dynamic>.from(e as Map)))
          .toList(),
      variants: ((j['variants'] as List?) ?? [])
          .map((e) => AdVariantPerformance.fromJson(
              Map<String, dynamic>.from(e as Map)))
          .toList(),
      placements: ((j['placements'] as List?) ?? [])
          .map((e) => AdPlacementPerformance.fromJson(
              Map<String, dynamic>.from(e as Map)))
          .toList(),
      minSampleGuard: (j['min_sample_guard'] as num? ?? 50).toInt(),
      note: j['note'] as String? ?? '',
      disclaimer: j['disclaimer'] as String? ?? '',
    );
  }
}

/// Run history + the optimizer's explainable audit trail.
class AdOptimizationHistory {
  final String campaignId;
  final List<AdOptimizationRun> runs;
  final List<AdOptimizerDecision> decisions;
  final String disclaimer;

  const AdOptimizationHistory({
    required this.campaignId,
    required this.runs,
    required this.decisions,
    required this.disclaimer,
  });

  factory AdOptimizationHistory.fromJson(Map<String, dynamic> j) =>
      AdOptimizationHistory(
        campaignId: j['campaign_id'] as String? ?? '',
        runs: ((j['runs'] as List?) ?? [])
            .map((e) => AdOptimizationRun.fromJson(
                Map<String, dynamic>.from(e as Map)))
            .toList(),
        decisions: ((j['decisions'] as List?) ?? [])
            .map((e) => AdOptimizerDecision.fromJson(
                Map<String, dynamic>.from(e as Map)))
            .toList(),
        disclaimer: j['disclaimer'] as String? ?? '',
      );
}

/// Phase 4: one dashboard figure, labeled measured vs estimate.
class AdMetric {
  final dynamic value; // num | null
  final String kind; // 'measured' | 'estimate'
  final String note;

  const AdMetric({required this.value, required this.kind, required this.note});

  factory AdMetric.fromJson(Map<String, dynamic> j) => AdMetric(
        value: j['value'],
        kind: j['kind'] as String? ?? 'measured',
        note: j['note'] as String? ?? '',
      );

  double? get asDouble => (value as num?)?.toDouble();
  int? get asInt => (value as num?)?.toInt();
  bool get isEstimate => kind == 'estimate';
}

/// Phase 4: attributed conversions + advertiser-reported revenue for one
/// segment or one creative variant (last-click attribution).
class AdAttributionSlice {
  final String id;
  final String name;
  final int conversions;
  final double revenueUsd;

  const AdAttributionSlice({
    required this.id,
    required this.name,
    required this.conversions,
    required this.revenueUsd,
  });

  factory AdAttributionSlice.segment(Map<String, dynamic> j) =>
      AdAttributionSlice(
        id: j['segment_id'] as String? ?? '',
        name: j['segment_name'] as String? ?? '',
        conversions: (j['conversions'] as num? ?? 0).toInt(),
        revenueUsd: (j['revenue_usd'] as num? ?? 0).toDouble(),
      );

  factory AdAttributionSlice.variant(Map<String, dynamic> j) =>
      AdAttributionSlice(
        id: j['variant_id'] as String? ?? '',
        name: j['variant_label'] as String? ?? '',
        conversions: (j['conversions'] as num? ?? 0).toInt(),
        revenueUsd: (j['revenue_usd'] as num? ?? 0).toDouble(),
      );
}

/// Phase 4: the ONE advertiser dashboard payload — spend, delivery,
/// engagement, clicks, leads, conversions, cost per result, and
/// attributable revenue. Every figure carries its measured-vs-estimate
/// label; revenue is advertiser-reported/measured, never verified sales.
class AdDashboard {
  final String campaignId;
  final String status;
  final String objective;
  final Map<String, AdMetric> metrics;
  final String attributionModel;
  final String attributionLabel;
  final List<AdAttributionSlice> bySegment;
  final List<AdAttributionSlice> byVariant;
  final String pricingDisclaimer;
  final String revenueDisclaimer;

  const AdDashboard({
    required this.campaignId,
    required this.status,
    required this.objective,
    required this.metrics,
    required this.attributionModel,
    required this.attributionLabel,
    required this.bySegment,
    required this.byVariant,
    required this.pricingDisclaimer,
    required this.revenueDisclaimer,
  });

  factory AdDashboard.fromJson(Map<String, dynamic> j) {
    final m = Map<String, dynamic>.from(j['metrics'] as Map? ?? const {});
    final d = Map<String, dynamic>.from(j['disclaimers'] as Map? ?? const {});
    return AdDashboard(
      campaignId: j['campaign_id'] as String? ?? '',
      status: j['status'] as String? ?? '',
      objective: j['objective'] as String? ?? '',
      metrics: m.map((k, v) => MapEntry(k.toString(),
          AdMetric.fromJson(Map<String, dynamic>.from(v as Map)))),
      attributionModel: j['attribution_model'] as String? ?? 'last_click',
      attributionLabel: j['attribution_label'] as String? ?? '',
      bySegment: ((j['by_segment'] as List?) ?? [])
          .map((e) => AdAttributionSlice.segment(
              Map<String, dynamic>.from(e as Map)))
          .toList(),
      byVariant: ((j['by_variant'] as List?) ?? [])
          .map((e) => AdAttributionSlice.variant(
              Map<String, dynamic>.from(e as Map)))
          .toList(),
      pricingDisclaimer: d['pricing'] as String? ?? '',
      revenueDisclaimer: d['revenue'] as String? ?? '',
    );
  }

  AdMetric metric(String key) =>
      metrics[key] ?? const AdMetric(value: 0, kind: 'measured', note: '');
}

/// A Paid Boost package: fixed price + fixed duration, no manual budgeting.
class AdPackage {
  final String id; // starter|growth|pro|scale
  final String name;
  final double priceUsd;
  final int durationDays;
  final bool popular;

  const AdPackage({
    required this.id,
    required this.name,
    required this.priceUsd,
    required this.durationDays,
    this.popular = false,
  });

  factory AdPackage.fromJson(Map<String, dynamic> j) => AdPackage(
        id: j['id'] as String? ?? '',
        name: j['name'] as String? ?? '',
        priceUsd: (j['price_usd'] as num? ?? 0).toDouble(),
        durationDays: (j['duration_days'] as num? ?? 7).toInt(),
        popular: j['popular'] as bool? ?? false,
      );
}

/// One of the two growth AI agents: Free Grow AI vs Paid Boost AI.
class GrowthAgent {
  final String id; // free_growth_agent | paid_growth_agent
  final String name;
  final String tagline;
  final String manages; // free|paid
  final List<String> capabilities;
  final List<String> limits;

  const GrowthAgent({
    required this.id,
    required this.name,
    required this.tagline,
    required this.manages,
    this.capabilities = const [],
    this.limits = const [],
  });

  factory GrowthAgent.fromJson(Map<String, dynamic> j) => GrowthAgent(
        id: j['id'] as String? ?? '',
        name: j['name'] as String? ?? '',
        tagline: j['tagline'] as String? ?? '',
        manages: j['manages'] as String? ?? '',
        capabilities:
            ((j['capabilities'] as List?) ?? []).map((e) => '$e').toList(),
        limits: ((j['limits'] as List?) ?? []).map((e) => '$e').toList(),
      );

  bool get isFree => manages == 'free';
}
