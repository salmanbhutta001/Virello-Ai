import 'package:flutter/material.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/virello_ui.dart';
import '../../data/ads_models.dart';
import '../../services/api_client.dart';
import '../../main.dart';
import 'campaign_builder_screen.dart';

/// Ad Campaigns: Free Services and Paid Services as clearly separate
/// modules — Hafiz's concept. Free cards show "Worldwide · Limited ·
/// No budget" + the Free Grow AI agent + live impression progress toward
/// the free limit. Paid cards show the package, price/duration, geography,
/// and the Paid Boost AI agent.
class AdCampaignsScreen extends StatefulWidget {
  const AdCampaignsScreen({super.key});
  @override
  State<AdCampaignsScreen> createState() => _AdCampaignsScreenState();
}

class _AdCampaignsScreenState extends State<AdCampaignsScreen> {
  late Future<_Lists> _future;

  AppStrings get s => AppStrings(appState.localeCode);

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_Lists> _load() async {
    try {
      final free = await apiClient.listAdCampaigns(plan: 'free');
      final paid = await apiClient.listAdCampaigns(plan: 'paid');
      return _Lists(free: free, paid: paid);
    } on AuthException {
      if (mounted) handleAuthFailure(s.sessionExpired);
      return const _Lists(free: [], paid: []);
    }
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(s.campaigns),
        actions: [
          IconButton(
            tooltip: s.adBuilder,
            icon: const Icon(Icons.addchart_outlined),
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(
                    builder: (_) => const CampaignBuilderScreen()))
                .then((_) => _refresh()),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<_Lists>(
          future: _future,
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(
                  child: CircularProgressIndicator(
                      color: VirelloColors.violet));
            }
            final lists = snap.data!;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _sectionHeader(
                    Icons.public_outlined, s.freeServices, Colors.teal,
                    lists.free.length),
                const SizedBox(height: 8),
                if (lists.free.isEmpty)
                  _emptyNote()
                else
                  ...lists.free.map((c) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _freeCard(c))),
                const SizedBox(height: 16),
                _sectionHeader(Icons.rocket_launch_outlined, s.paidServices,
                    VirelloColors.violet, lists.paid.length),
                const SizedBox(height: 8),
                if (lists.paid.isEmpty)
                  _emptyNote()
                else
                  ...lists.paid.map((c) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _paidCard(c))),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _sectionHeader(
      IconData icon, String title, Color color, int count) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color, size: 20),
      ),
      const SizedBox(width: 10),
      Expanded(
          child: Text(title,
              style:
                  const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
            color: VirelloColors.chipBg,
            borderRadius: BorderRadius.circular(20)),
        child: Text('$count',
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: VirelloColors.muted)),
      ),
    ]);
  }

  Widget _emptyNote() => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text('—',
            style:
                TextStyle(fontSize: 13, color: VirelloColors.muted)),
      );

  Widget _baseCard(AdCampaign c,
      {required Color accent,
      required String planLabel,
      required String agentLabel,
      required List<Widget> meta}) {
    return VCard(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context)
            .push(MaterialPageRoute(
                builder: (_) => CampaignBuilderScreen(campaignId: c.id)))
            .then((_) => _refresh()),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(
                  c.contentRef.isNotEmpty ? c.contentRef : c.objective,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 8),
            _chip(planLabel, accent),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            const Icon(Icons.smart_toy_outlined,
                size: 14, color: VirelloColors.muted),
            const SizedBox(width: 4),
            Expanded(
                child: Text(agentLabel,
                    style: const TextStyle(
                        fontSize: 11.5, color: VirelloColors.muted))),
            _statusChip(c.status),
          ]),
          ...meta,
        ]),
      ),
    );
  }

  Widget _chip(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20)),
        child: Text(label,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      );

  Widget _statusChip(String status) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: VirelloColors.chipBg,
            borderRadius: BorderRadius.circular(20)),
        child: Text(status,
            style: const TextStyle(fontSize: 10.5, color: VirelloColors.muted)),
      );

  /// Free card: "Worldwide · Limited · No budget" + Free Grow AI agent +
  /// live impression progress toward the 1,000-impression cap.
  Widget _freeCard(AdCampaign c) {
    return _baseCard(c,
        accent: Colors.teal,
        planLabel: s.freeGrow,
        agentLabel: s.managedByFreeAi,
        meta: [
          const SizedBox(height: 6),
          const Text('Worldwide · Limited · No budget',
              style: TextStyle(fontSize: 12, color: VirelloColors.muted)),
          const SizedBox(height: 8),
          FutureBuilder<AdDashboard>(
            future: apiClient.getAdDashboard(c.id),
            builder: (context, snap) {
              if (!snap.hasData) return const SizedBox.shrink();
              final imp = snap.data!
                  .metric('impressions')
                  .value
                  .toInt();
              const cap = 1000;
              final pct = (imp / cap).clamp(0.0, 1.0);
              return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 6,
                        backgroundColor: VirelloColors.chipBg,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            Colors.teal),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('$imp / $cap genuine impressions',
                        style: const TextStyle(
                            fontSize: 11, color: VirelloColors.muted)),
                  ]);
            },
          ),
        ]);
  }

  /// Paid card: package name + price/duration, geography, Paid Boost AI.
  Widget _paidCard(AdCampaign c) {
    final geo = c.geoMode == 'worldwide'
        ? 'Worldwide'
        : c.geoCountries.isNotEmpty
            ? c.geoCountries.take(3).join(', ') +
                (c.geoCountries.length > 3
                    ? ' +${c.geoCountries.length - 3}'
                    : '')
            : c.geoMode;
    return _baseCard(c,
        accent: VirelloColors.violet,
        planLabel: s.paidBoost,
        agentLabel: s.managedByPaidAi,
        meta: [
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: [
            if ((c.packageId ?? '').isNotEmpty)
              _chip(c.packageId!, VirelloColors.violetDeep),
            _chip('\$${c.budget.toStringAsFixed(0)}', VirelloColors.violet),
            _chip(s.packageDays(c.durationDays), VirelloColors.muted),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            const Icon(Icons.public_outlined,
                size: 14, color: VirelloColors.muted),
            const SizedBox(width: 4),
            Expanded(
                child: Text(geo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11.5, color: VirelloColors.muted))),
          ]),
        ]);
  }
}

class _Lists {
  final List<AdCampaign> free;
  final List<AdCampaign> paid;
  const _Lists({required this.free, required this.paid});
}
