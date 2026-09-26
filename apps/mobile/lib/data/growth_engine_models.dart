/// AI Growth Engine domain models. Mirror backend/app/models/growth_engine.py
/// and app/routers/growth_engine.py responses.
class GrowthLoop {
  final String id;
  final String campaignId;
  final String status; // running | paused | awaiting_approval | completed | stopped
  final int round;
  final String? placementStatus;
  const GrowthLoop({
    required this.id,
    required this.campaignId,
    required this.status,
    required this.round,
    this.placementStatus,
  });

  factory GrowthLoop.fromJson(Map<String, dynamic> j) => GrowthLoop(
        id: j['id'] as String? ?? '',
        campaignId: j['campaign_id'] as String? ?? '',
        status: j['status'] as String? ?? 'unknown',
        round: (j['round'] as num? ?? 0).toInt(),
        placementStatus: j['placement_status'] as String?,
      );

  bool get isRunning => status == 'running';
  bool get isPaused => status == 'paused';
  bool get isAwaitingApproval => status == 'awaiting_approval';
}

class GrowthSegment {
  final String id;
  final String name;
  final List<String> topics;
  final double weight;
  final String status;
  const GrowthSegment({
    required this.id,
    required this.name,
    required this.topics,
    required this.weight,
    required this.status,
  });

  factory GrowthSegment.fromJson(Map<String, dynamic> j) => GrowthSegment(
        id: j['id'] as String? ?? '',
        name: j['name'] as String? ?? '',
        topics: (j['topics'] as List? ?? []).map((e) => '$e').toList(),
        weight: (j['weight'] as num? ?? 1).toDouble(),
        status: j['status'] as String? ?? 'active',
      );
}

class GrowthVariant {
  final String id;
  final String label;
  final String kind;
  final Map<String, dynamic> content;
  final String rationale;
  final double weight;
  final bool isOriginal;
  final String status;
  const GrowthVariant({
    required this.id,
    required this.label,
    required this.kind,
    required this.content,
    required this.rationale,
    required this.weight,
    required this.isOriginal,
    required this.status,
  });

  factory GrowthVariant.fromJson(Map<String, dynamic> j) => GrowthVariant(
        id: j['id'] as String? ?? '',
        label: j['label'] as String? ?? '',
        kind: j['kind'] as String? ?? '',
        content: Map<String, dynamic>.from(j['content'] as Map? ?? {}),
        rationale: j['rationale'] as String? ?? '',
        weight: (j['weight'] as num? ?? 0).toDouble(),
        isOriginal: j['is_original'] as bool? ?? false,
        status: j['status'] as String? ?? 'active',
      );

  String get caption => content['caption'] as String? ?? '';
  List<String> get hashtags =>
      (content['hashtags'] as List? ?? []).map((e) => '$e').toList();
}

class GrowthObservation {
  final String? segmentId;
  final String? variantId;
  final int views;
  final int saves;
  final int visits;
  final int dismissals;
  final String attribution;
  const GrowthObservation({
    this.segmentId,
    this.variantId,
    required this.views,
    required this.saves,
    required this.visits,
    required this.dismissals,
    required this.attribution,
  });

  factory GrowthObservation.fromJson(Map<String, dynamic> j) => GrowthObservation(
        segmentId: j['segment_id'] as String?,
        variantId: j['variant_id'] as String?,
        views: (j['views'] as num? ?? 0).toInt(),
        saves: (j['saves'] as num? ?? 0).toInt(),
        visits: (j['visits'] as num? ?? 0).toInt(),
        dismissals: (j['dismissals'] as num? ?? 0).toInt(),
        attribution: j['attribution'] as String? ?? '',
      );
}

class GrowthLearning {
  final int round;
  final String action;
  final Map<String, dynamic> details;
  final String? createdAt;
  const GrowthLearning({
    required this.round,
    required this.action,
    required this.details,
    this.createdAt,
  });

  factory GrowthLearning.fromJson(Map<String, dynamic> j) => GrowthLearning(
        round: (j['round'] as num? ?? 0).toInt(),
        action: j['action'] as String? ?? '',
        details: Map<String, dynamic>.from(j['details'] as Map? ?? {}),
        createdAt: j['created_at'] as String?,
      );

  List<String> get reasons =>
      (details['reasons'] as List? ?? []).map((e) => '$e').toList();
}

class GrowthDecision {
  final int round;
  final String agent;
  final String action;
  final Map<String, dynamic> details;
  final String? createdAt;
  const GrowthDecision({
    required this.round,
    required this.agent,
    required this.action,
    required this.details,
    this.createdAt,
  });

  factory GrowthDecision.fromJson(Map<String, dynamic> j) => GrowthDecision(
        round: (j['round'] as num? ?? 0).toInt(),
        agent: j['agent'] as String? ?? '',
        action: j['action'] as String? ?? '',
        details: Map<String, dynamic>.from(j['details'] as Map? ?? {}),
        createdAt: j['created_at'] as String?,
      );

  List<String> get reasons =>
      (details['reasons'] as List? ?? []).map((e) => '$e').toList();
}

class GrowthLoopDetail {
  final GrowthLoop loop;
  final List<GrowthSegment> segments;
  final List<GrowthVariant> variants;
  final List<GrowthObservation> observations;
  final List<GrowthLearning> learnings;
  const GrowthLoopDetail({
    required this.loop,
    required this.segments,
    required this.variants,
    required this.learnings,
    required this.observations,
  });

  factory GrowthLoopDetail.fromJson(Map<String, dynamic> j) => GrowthLoopDetail(
        loop: GrowthLoop.fromJson(
            Map<String, dynamic>.from(j['loop'] as Map? ?? {})),
        segments: (j['segments'] as List? ?? [])
            .map((e) => GrowthSegment.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        variants: (j['variants'] as List? ?? [])
            .map((e) => GrowthVariant.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        observations: (j['observations'] as List? ?? [])
            .map((e) => GrowthObservation.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        learnings: (j['learnings'] as List? ?? [])
            .map((e) => GrowthLearning.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );

  GrowthObservation totalsForVariant(String variantId) {
    var t = const GrowthObservation(
        views: 0, saves: 0, visits: 0, dismissals: 0, attribution: 'direct');
    for (final o in observations) {
      if (o.variantId == variantId) {
        t = GrowthObservation(
          variantId: variantId,
          views: t.views + o.views,
          saves: t.saves + o.saves,
          visits: t.visits + o.visits,
          dismissals: t.dismissals + o.dismissals,
          attribution: o.attribution,
        );
      }
    }
    return t;
  }
}
