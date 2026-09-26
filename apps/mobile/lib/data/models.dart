/// Core domain models shared across the app. Mirror backend schemas (backend/app/models/).
enum CampaignGoal { reach, engagement, profileVisits, websiteTraffic, leads, customers }

extension CampaignGoalX on CampaignGoal {
  String label(AppStringsRef s) => const {
        CampaignGoal.reach: 'Reach',
        CampaignGoal.engagement: 'Engagement',
        CampaignGoal.profileVisits: 'Profile Visits',
        CampaignGoal.websiteTraffic: 'Website Traffic',
        CampaignGoal.leads: 'Leads',
        CampaignGoal.customers: 'Customers',
      }[this]!;

  /// Wire value the backend expects (snake_case).
  String get apiValue => const {
        CampaignGoal.reach: 'reach',
        CampaignGoal.engagement: 'engagement',
        CampaignGoal.profileVisits: 'profile_visits',
        CampaignGoal.websiteTraffic: 'website_traffic',
        CampaignGoal.leads: 'leads',
        CampaignGoal.customers: 'customers',
      }[this]!;

  static CampaignGoal fromApi(String? v) => CampaignGoal.values.firstWhere(
        (g) => g.apiValue == v,
        orElse: () => CampaignGoal.reach,
      );
}

extension CampaignStatusX on CampaignStatus {
  static CampaignStatus fromApi(String? v) => CampaignStatus.values.firstWhere(
        (s) => s.name == v,
        orElse: () => CampaignStatus.analyzing,
      );
}

enum GrowthMode { organic, paid }

enum Market { worldwide, usa, uk, custom }

enum CampaignStatus { analyzing, strategizing, launching, live, optimizing, paused, completed }

/// Minimal string accessor to avoid importing Flutter in pure-Dart contexts.
class AppStringsRef {
  final String localeCode;
  const AppStringsRef(this.localeCode);
}

class GrowRequest {
  final String postUrl;
  final String platform; // auto-detected: tiktok | instagram | youtube | x | …
  final CampaignGoal goal;
  final Set<Market> markets;
  final GrowthMode mode;
  final double? budgetUsd; // paid mode only; hard cap enforced server-side
  final int? durationDays;

  const GrowRequest({
    required this.postUrl,
    required this.platform,
    required this.goal,
    required this.markets,
    required this.mode,
    this.budgetUsd,
    this.durationDays,
  });

  Map<String, dynamic> toJson() => {
        'post_url': postUrl,
        'platform': platform,
        'goal': goal.apiValue,
        'markets': markets.map((m) => m.name).toList(),
        'mode': mode.name,
        'budget_usd': budgetUsd,
        'duration_days': durationDays,
      };
}

class Campaign {
  final String id;
  final String title;
  final String postUrl;
  final String platform;
  final CampaignGoal goal;
  final GrowthMode mode;
  final List<String> markets;
  final CampaignStatus status;
  final double reach, engagementRate, clicks, conversions;
  final double spendUsd, budgetUsd;

  const Campaign({
    required this.id,
    required this.title,
    this.postUrl = '',
    this.platform = '',
    required this.goal,
    this.mode = GrowthMode.organic,
    this.markets = const [],
    required this.status,
    this.reach = 0,
    this.engagementRate = 0,
    this.clicks = 0,
    this.conversions = 0,
    this.spendUsd = 0,
    this.budgetUsd = 0,
  });

  /// Parses backend CampaignOut. Metrics default to 0 — the card hides them
  /// until the backend reports real numbers (never faked).
  factory Campaign.fromJson(Map<String, dynamic> j) => Campaign(
        id: '${j['id'] ?? ''}',
        title: '${j['title'] ?? ''}',
        postUrl: '${j['post_url'] ?? ''}',
        platform: '${j['platform'] ?? ''}',
        goal: CampaignGoalX.fromApi(j['goal'] as String?),
        mode: j['mode'] == 'paid' ? GrowthMode.paid : GrowthMode.organic,
        markets: (j['markets'] as String? ?? '').split(',').where((m) => m.isNotEmpty).toList(),
        status: CampaignStatusX.fromApi(j['status'] as String?),
        reach: (j['reach'] as num? ?? 0).toDouble(),
        engagementRate: (j['engagement_rate'] as num? ?? 0).toDouble(),
        clicks: (j['clicks'] as num? ?? 0).toDouble(),
        conversions: (j['conversions'] as num? ?? 0).toDouble(),
        spendUsd: (j['spend_usd'] as num? ?? 0).toDouble(),
        budgetUsd: (j['budget_usd'] as num? ?? 0).toDouble(),
      );

  bool get hasMetrics => reach > 0 || clicks > 0 || conversions > 0;
}

class AiInsight {
  final String agent; // e.g. 'Creative Agent'
  final String text;
  final double confidence; // 0..1 — never presented as a guarantee
  const AiInsight({required this.agent, required this.text, required this.confidence});
}
