import 'package:flutter/material.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../main.dart';

/// Analytics: honest performance dashboards. Actuals only — never promises.
/// Aggregates come from GET /analytics/overview (backend computes these);
/// the daily breakdown comes from the per-campaign timeseries endpoint.
/// When there is no data yet, an honest empty state is shown — never a
/// fabricated curve.
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});
  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsBundle {
  final Map<String, dynamic> overview;
  final Map<String, dynamic>? timeseries;
  _AnalyticsBundle(this.overview, this.timeseries);
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  late Future<_AnalyticsBundle> _future;

  AppStrings get s => AppStrings(appState.localeCode);

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_AnalyticsBundle> _load() async {
    final overview = await apiClient.analyticsOverview();
    String? campaignId;
    try {
      final campaigns = await apiClient.listCampaigns();
      if (campaigns.isNotEmpty) campaignId = campaigns.first.id;
    } catch (_) {
      // Timeseries is a bonus; aggregates still render without it.
    }
    Map<String, dynamic>? ts;
    if (campaignId != null) {
      try {
        ts = await apiClient.campaignTimeseries(campaignId);
      } catch (_) {}
    }
    return _AnalyticsBundle(overview, ts);
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    try {
      await _future;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(s.analytics)),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<_AnalyticsBundle>(
          future: _future,
          builder: (c, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError || !snap.hasData) {
              return _errorState();
            }
            final d = snap.data!.overview;
            final reach = (d['reach'] as num? ?? 0).toDouble();
            final eng = (d['engagement_rate'] as num? ?? 0).toDouble();
            final clicks = (d['clicks'] as num? ?? 0).toDouble();
            final conv = (d['conversions'] as num? ?? 0).toDouble();

            // Honest empty state: real numbers only, zeros when no data.
            if (reach <= 0 && clicks <= 0 && conv <= 0) {
              return _emptyState();
            }

            final points = _points(snap.data!.timeseries);
            return ListView(padding: const EdgeInsets.all(16), children: [
              _statRow(reach, eng, clicks, conv),
              const SizedBox(height: 12),
              if (points.isNotEmpty)
                _chartCard(context, s.dailyReachTitle, points)
              else
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(s.dailyBreakdownNote,
                        style: const TextStyle(
                            fontSize: 13,
                            color: VirelloColors.muted,
                            height: 1.5)),
                  ),
                ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.trustTitle,
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Text(s.noGuarantees,
                            style: const TextStyle(
                                fontSize: 13,
                                color: Colors.grey,
                                height: 1.5)),
                      ]),
                ),
              ),
            ]);
          },
        ),
      ),
    );
  }

  /// Real per-day points from the timeseries payload, or empty.
  List<_Point> _points(Map<String, dynamic>? ts) {
    if (ts == null) return const [];
    final raw = ts['points'] as List? ?? const [];
    final pts = <_Point>[];
    for (final e in raw) {
      final m = e as Map? ?? const {};
      final v = (m['value'] as num? ?? 0).toDouble();
      pts.add(_Point('${m['date'] ?? ''}', v));
    }
    return pts.where((p) => p.value > 0).toList();
  }

  Widget _emptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.18),
        const Icon(Icons.bar_chart_outlined,
            size: 64, color: VirelloColors.muted),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: Text(s.noAnalyticsYet,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 14, color: VirelloColors.muted, height: 1.5)),
        ),
      ],
    );
  }

  Widget _errorState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.18),
        const Icon(Icons.wifi_off_outlined,
            size: 56, color: VirelloColors.muted),
        const SizedBox(height: 16),
        Center(
          child: SizedBox(
            width: 200,
            child: ElevatedButton(
              onPressed: _refresh,
              child: Text(s.continueBtn),
            ),
          ),
        ),
      ],
    );
  }

  Widget _statRow(double reach, double eng, double clicks, double conv) {
    return Row(children: [
      Expanded(child: _stat('Reach', _fmt(reach))),
      const SizedBox(width: 8),
      Expanded(child: _stat('Eng.', '${eng.toStringAsFixed(1)}%')),
      const SizedBox(width: 8),
      Expanded(child: _stat('Clicks', _fmt(clicks))),
      const SizedBox(width: 8),
      Expanded(child: _stat('Conv.', _fmt(conv))),
    ]);
  }

  Widget _stat(String label, String value) => Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(children: [
            Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ]),
        ),
      );

  String _fmt(double n) => n >= 1000
      ? '${(n / 1000).toStringAsFixed(1)}K'
      : n.toStringAsFixed(0);

  /// Real per-day bars, normalized to the day's max value.
  Widget _chartCard(
      BuildContext context, String title, List<_Point> points) {
    final max = points.fold<double>(
        0, (a, p) => p.value > a ? p.value : a);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: points
                  .map((p) => Expanded(
                        child: Container(
                          margin:
                              const EdgeInsets.symmetric(horizontal: 3),
                          height: max > 0
                              ? (110 * p.value / max).clamp(4.0, 110.0)
                              : 4.0,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                                colors: [
                                  Color(0xFFF95177),
                                  Color(0xFF22D3EE)
                                ],
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 8),
          // Day labels (MM-DD tail) under the real bars.
          Row(
            children: points
                .map((p) => Expanded(
                      child: Text(
                        p.date.length >= 5
                            ? p.date.substring(p.date.length - 5)
                            : p.date,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 9, color: Colors.grey),
                        overflow: TextOverflow.clip,
                      ),
                    ))
                .toList(),
          ),
        ]),
      ),
    );
  }
}

class _Point {
  final String date;
  final double value;
  const _Point(this.date, this.value);
}
