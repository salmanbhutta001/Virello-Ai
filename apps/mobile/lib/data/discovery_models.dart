/// Discovery + analysis domain models. Mirror backend schemas
/// (backend/app/models/growth.py, app/services/analysis/service.py).
class Topic {
  final String slug;
  final String nameEn;
  final String nameUr;
  const Topic({required this.slug, required this.nameEn, required this.nameUr});

  String name(String locale) => locale == 'ur' && nameUr.isNotEmpty ? nameUr : nameEn;

  factory Topic.fromJson(Map<String, dynamic> j) => Topic(
        slug: j['slug'] as String? ?? '',
        nameEn: j['name_en'] as String? ?? '',
        nameUr: j['name_ur'] as String? ?? '',
      );
}

class DiscoveryItem {
  final String campaignId;
  final String title;
  final String platform;
  final String goal;
  final String postUrl;
  final String thumbnailUrl;
  final double matchScore;
  final List<String> matchReasons;
  /// AI Growth Engine presentation (null when no loop is distributing this item).
  final GrowthVariantView? growthVariant;
  final double growthBoost;
  /// Original content language metadata (multilingual layer).
  final String contentLanguage;
  final List<String> contentLanguages;
  final bool languageUncertain;
  /// Backend-derived post type: 'link' for generic web URLs, otherwise the
  /// social platform name ('youtube', 'tiktok', ...). The feed uses this to
  /// render link-type posts as native LinkCards.
  final String postType;
  const DiscoveryItem({
    required this.campaignId,
    required this.title,
    required this.platform,
    required this.goal,
    required this.postUrl,
    required this.thumbnailUrl,
    required this.matchScore,
    required this.matchReasons,
    this.growthVariant,
    this.growthBoost = 1.0,
    this.contentLanguage = '',
    this.contentLanguages = const [],
    this.languageUncertain = false,
    this.postType = '',
  });

  factory DiscoveryItem.fromJson(Map<String, dynamic> j) {
    final gv = j['growth_variant'] as Map<String, dynamic>?;
    final g = j['growth'] as Map<String, dynamic>?;
    return DiscoveryItem(
      campaignId: j['campaign_id'] as String? ?? '',
      title: j['title'] as String? ?? '',
      platform: j['platform'] as String? ?? '',
      goal: j['goal'] as String? ?? '',
      postUrl: j['post_url'] as String? ?? '',
      thumbnailUrl: j['thumbnail_url'] as String? ?? '',
      matchScore: (j['match_score'] as num? ?? 0).toDouble(),
      matchReasons: (j['match_reasons'] as List? ?? []).map((e) => '$e').toList(),
      growthVariant: gv == null ? null : GrowthVariantView.fromJson(gv),
      growthBoost: (g?['boost'] as num? ?? 1.0).toDouble(),
      contentLanguage: j['content_language'] as String? ?? '',
      contentLanguages:
          ((j['content_languages'] as List?) ?? []).map((e) => '$e').toList(),
      languageUncertain: j['language_uncertain'] == true,
      postType: j['post_type'] as String? ?? '',
    );
  }
}

/// A content variant the AI Growth Engine rotated into the feed for this item.
/// The client echoes `variantId` when recording interactions so the engine can
/// measure which variant genuinely performs better.
class GrowthVariantView {
  final String variantId;
  final String label;
  final String title;
  final String caption;
  final List<String> hashtags;
  final bool isOriginal;
  const GrowthVariantView({
    required this.variantId,
    required this.label,
    required this.title,
    required this.caption,
    required this.hashtags,
    required this.isOriginal,
  });

  factory GrowthVariantView.fromJson(Map<String, dynamic> j) => GrowthVariantView(
        variantId: j['variant_id'] as String? ?? '',
        label: j['label'] as String? ?? '',
        title: j['title'] as String? ?? '',
        caption: j['caption'] as String? ?? '',
        hashtags: (j['hashtags'] as List? ?? []).map((e) => '$e').toList(),
        isOriginal: j['is_original'] as bool? ?? true,
      );
}

/// Result of POST /analysis/analyze. `campaignId` is set by the app when the
/// analysis was launched from a discovery feed item (enables Save → backend).
class PostAnalysisResult {
  final String url;
  final String platform;
  final String fetchLevel;
  final String title;
  final String author;
  final String description;
  final String thumbnailUrl;
  final String mediaType;
  final String language;
  final List<String> hashtags;
  final int score;
  final Map<String, int> components;
  final String disclaimer;
  final String? campaignId;

  const PostAnalysisResult({
    required this.url,
    required this.platform,
    required this.fetchLevel,
    required this.title,
    required this.author,
    required this.description,
    required this.thumbnailUrl,
    required this.mediaType,
    required this.language,
    required this.hashtags,
    required this.score,
    required this.components,
    required this.disclaimer,
    this.campaignId,
  });

  factory PostAnalysisResult.fromJson(Map<String, dynamic> j, {String? campaignId}) {
    final s = j['score'] as Map<String, dynamic>? ?? {};
    final comps = <String, int>{};
    (s['components'] as Map? ?? {}).forEach((k, v) => comps['$k'] = (v as num? ?? 0).toInt());
    return PostAnalysisResult(
      url: j['url'] as String? ?? '',
      platform: j['platform'] as String? ?? 'unknown',
      fetchLevel: j['fetch_level'] as String? ?? 'minimal',
      title: j['title'] as String? ?? '',
      author: j['author'] as String? ?? '',
      description: j['description'] as String? ?? '',
      thumbnailUrl: j['thumbnail_url'] as String? ?? '',
      mediaType: j['media_type'] as String? ?? 'unknown',
      language: j['language'] as String? ?? 'unknown',
      hashtags: (j['hashtags'] as List? ?? []).map((e) => '$e').toList(),
      score: (s['score'] as num? ?? 0).toInt(),
      components: comps,
      disclaimer: s['disclaimer'] as String? ?? '',
      campaignId: campaignId ?? j['campaign_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'url': url, 'platform': platform, 'fetch_level': fetchLevel,
        'title': title, 'author': author, 'description': description,
        'thumbnail_url': thumbnailUrl, 'media_type': mediaType,
        'language': language, 'hashtags': hashtags,
        'score': {'score': score, 'components': components, 'disclaimer': disclaimer},
        'campaign_id': campaignId,
      };

  PostAnalysisResult withCampaign(String id) => PostAnalysisResult(
        url: url, platform: platform, fetchLevel: fetchLevel, title: title,
        author: author, description: description, thumbnailUrl: thumbnailUrl,
        mediaType: mediaType, language: language, hashtags: hashtags,
        score: score, components: components, disclaimer: disclaimer,
        campaignId: id,
      );
}
