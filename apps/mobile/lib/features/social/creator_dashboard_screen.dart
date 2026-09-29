import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/virello_ui.dart';
import '../../main.dart';
import '../../services/api_client.dart';

/// Board screen 18: Creator Dashboard.
///
/// Real numbers only, from GET /api/v1/analytics/overview (genuine
/// ad_impressions on the user's own campaigns). Zeros when there is no
/// data — demo numbers are never served.
class CreatorDashboardScreen extends StatefulWidget {
  const CreatorDashboardScreen({super.key});
  @override
  State<CreatorDashboardScreen> createState() => _CreatorDashboardScreenState();
}

class _CreatorDashboardScreenState extends State<CreatorDashboardScreen> {
  late Future<Map<String, dynamic>> _future;

  AppStrings get s => AppStrings(appState.localeCode);

  @override
  void initState() {
    super.initState();
    _future = apiClient.analyticsOverview();
  }

  Future<void> _refresh() async {
    setState(() => _future = apiClient.analyticsOverview());
    try {
      await _future;
    } catch (_) {}
  }

  String _fmt(num v) {
    if (v >= 1000000) {
      final x = v / 1000000;
      return '${x.toStringAsFixed(x >= 10 ? 1 : 2)}M';
    }
    if (v >= 1000) {
      final x = v / 1000;
      return '${x.toStringAsFixed(x >= 10 ? 1 : 2)}K';
    }
    return v.toStringAsFixed(v is int || v == v.roundToDouble() ? 0 : 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(s.boardCreatorDashboard)),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (c, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return _error();
            }
            final d = snap.data ?? {};
            final reach = (d['reach'] as num? ?? 0);
            final rate = (d['engagement_rate'] as num? ?? 0);
            final clicks = (d['clicks'] as num? ?? 0);
            final conv = (d['conversions'] as num? ?? 0);
            final empty = reach == 0 && clicks == 0 && conv == 0;
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _statCard(
                        label: s.boardTotalReach,
                        value: _fmt(reach),
                        icon: Icons.visibility_outlined,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _statCard(
                        label: s.boardEngagementRate,
                        value:
                            '${rate.toStringAsFixed(rate == rate.roundToDouble() ? 0 : 1)}%',
                        icon: Icons.favorite_outline,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _statCard(
                        label: s.boardClicks,
                        value: _fmt(clicks),
                        icon: Icons.mouse_outlined,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _statCard(
                        label: s.boardConversions,
                        value: _fmt(conv),
                        icon: Icons.shopping_cart_outlined,
                      ),
                    ),
                  ],
                ),
                if (empty) ...[
                  const SizedBox(height: 24),
                  Icon(
                    Icons.bar_chart_outlined,
                    size: 56,
                    color: VirelloColors.boardTextSec,
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      s.boardNoStatsYet,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: VirelloColors.boardTextSec,
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _statCard({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return VBoardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: VirelloColors.pink.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: VirelloColors.pink, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              color: VirelloColors.boardTextSec,
            ),
          ),
        ],
      ),
    );
  }

  Widget _error() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
        const Icon(
          Icons.wifi_off_outlined,
          size: 56,
          color: VirelloColors.boardTextSec,
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: Text(
            s.analyzeFailed,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: VirelloColors.boardTextSec,
            ),
          ),
        ),
      ],
    );
  }
}
