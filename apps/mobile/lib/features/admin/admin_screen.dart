import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/strings.dart';
import '../../services/admin_api.dart';
import '../../services/api_client.dart';
import '../../main.dart';

/// Admin Dashboard — the core control room. Every section talks to the real
/// backend (/api/v1/admin/*, require_admin). Non-admins never see the entry
/// point (Profile shows it only when /me.is_admin is true).
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});
  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

mixin _AdminGuard<T extends StatefulWidget> on State<T> {
  AppStrings get s => AppStrings(appState.localeCode);
  AdminApi get admin => AdminApi(apiClient);

  Future<R?> guard<R>(Future<R> Function() call) async {
    try {
      return await call();
    } on AuthException {
      if (mounted) handleAuthFailure(s.sessionExpired);
    } on AdminForbiddenException {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(s.adminOnly)));
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(s.growFailed)));
      }
    }
    return null;
  }

  void toast(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  /// Runs a void admin action; returns true on success.
  Future<bool> act(Future<void> Function() call) async {
    final r = await guard(() => call().then((_) => true));
    return r == true;
  }
}

class _AdminScreenState extends State<AdminScreen> with _AdminGuard<AdminScreen> {
  int _i = 0;

  List<String> get _tabs => [
        s.adminOverview, s.adminAnalytics, s.adminUsers, s.campaigns,
        s.adminPayments, s.adminFraud, s.adminDiscovery, s.adminPlans,
        s.adminBroadcasts, s.adminAiUsage, s.adminSettings, s.adminAudit,
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(s.adminDashboard)),
      body: Column(children: [
        SizedBox(
          height: 48,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: _tabs.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) => ChoiceChip(
              label: Text(_tabs[i]),
              selected: _i == i,
              onSelected: (_) => setState(() => _i = i),
            ),
          ),
        ),
        Expanded(
          child: IndexedStack(index: _i, children: const [
            _OverviewSection(),
            _AnalyticsSection(),
            _UsersSection(),
            _CampaignsSection(),
            _PaymentsSection(),
            _FraudSection(),
            _DiscoverySection(),
            _PlansSection(),
            _BroadcastsSection(),
            _AiUsageSection(),
            _SettingsSection(),
            _AuditSection(),
          ]),
        ),
      ]),
    );
  }
}

// ---------------------------------------------------------------- overview
class _OverviewSection extends StatefulWidget {
  const _OverviewSection();
  @override
  State<_OverviewSection> createState() => _OverviewSectionState();
}

class _OverviewSectionState extends State<_OverviewSection>
    with _AdminGuard<_OverviewSection> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final o = await admin.overview();
    final a = await admin.analyticsSummary();
    return {'overview': o, 'analytics': a};
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (c, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        if (snap.hasError) return _errRetry();
        final o = snap.data!['overview'] as Map<String, dynamic>;
        final a = snap.data!['analytics'] as Map<String, dynamic>;
        final byStatus = Map<String, dynamic>.from(a['campaigns_by_status'] as Map? ?? {});
        final byGoal = Map<String, dynamic>.from(a['campaigns_by_goal'] as Map? ?? {});
        return RefreshIndicator(
          onRefresh: () async => setState(() => _future = _load()),
          child: ListView(padding: const EdgeInsets.all(16), children: [
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.6,
              children: [
                _stat(s.totalUsers, '${o['users'] ?? 0}', Icons.people_outline),
                _stat(s.totalCampaigns, '${o['campaigns'] ?? 0}', Icons.campaign_outlined),
                _stat(s.liveCampaigns, '${o['live_campaigns'] ?? 0}', Icons.bolt_outlined),
                _stat(s.revenueUsd, '\$${(o['revenue_usd'] as num? ?? 0).toStringAsFixed(2)}',
                    Icons.payments_outlined),
                _stat(s.openFlags, '${o['open_fraud_flags'] ?? 0}', Icons.flag_outlined),
              ],
            ),
            const SizedBox(height: 16),
            _breakdown(s.byStatus, byStatus),
            const SizedBox(height: 12),
            _breakdown(s.byGoal, byGoal),
          ]),
        );
      },
    );
  }

  Widget _stat(String label, String value, IconData icon) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 20, color: const Color(0xFFF95177)),
            const Spacer(),
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ]),
        ),
      );

  Widget _breakdown(String title, Map<String, dynamic> m) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (m.isEmpty)
              Text(s.noItems, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            for (final e in m.entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(children: [
                  Expanded(child: Text(e.key, style: const TextStyle(fontSize: 13))),
                  Text('${e.value}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                ]),
              ),
          ]),
        ),
      );

  Widget _errRetry() => Center(
        child: TextButton(
          onPressed: () => setState(() => _future = _load()),
          child: Text(s.growFailed),
        ),
      );
}

// ---------------------------------------------------------------- analytics
/// Admin-only user-visit analytics: Daily / Weekly / Monthly reports of
/// active users, new signups and visits, powered by the user_activity table.
/// User emails need no separate report — they are saved on users.email at
/// signup (email OTP or Google/Apple OAuth) and listed in the Users tab.
class _AnalyticsSection extends StatefulWidget {
  const _AnalyticsSection();
  @override
  State<_AnalyticsSection> createState() => _AnalyticsSectionState();
}

class _AnalyticsSectionState extends State<_AnalyticsSection>
    with _AdminGuard<_AnalyticsSection> {
  String _range = 'daily';
  int _selected = -1;
  int _revSelected = -1;
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() {
    final f = guard(() => admin.analytics(range: _range));
    return f.then((v) => v ?? {'series': []});
  }

  void _setRange(String r) => setState(() {
        _range = r;
        _selected = -1;
        _revSelected = -1;
        _future = _load();
      });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (c, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final j = snap.data!;
        final series = (j['series'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        final signupsTotal =
            series.fold<int>(0, (a, e) => a + ((e['signups'] as int?) ?? 0));
        final visitsTotal =
            series.fold<int>(0, (a, e) => a + ((e['visits'] as int?) ?? 0));
        return RefreshIndicator(
          onRefresh: () async => setState(() => _future = _load()),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(value: 'daily', label: Text(s.rangeDaily)),
                  ButtonSegment(value: 'weekly', label: Text(s.rangeWeekly)),
                  ButtonSegment(value: 'monthly', label: Text(s.rangeMonthly)),
                ],
                selected: {_range},
                onSelectionChanged: (v) => _setRange(v.first),
              ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.15,
                children: [
                  _stat(s.statDau, '${j['dau'] ?? 0}'),
                  _stat(s.statWau, '${j['wau'] ?? 0}'),
                  _stat(s.statMau, '${j['mau'] ?? 0}'),
                  _stat(s.statSignups, '$signupsTotal'),
                  _stat(s.statVisits, '$visitsTotal'),
                  _stat(s.statTotalUsers, '${j['total_users'] ?? 0}'),
                ],
              ),
              const SizedBox(height: 16),
              _chart(series),
              if (_selected >= 0 && _selected < series.length) ...[
                const SizedBox(height: 8),
                _bucketDetail(series[_selected]),
              ],
              // Sales (paid services). Hidden when the backend is older
              // than the sales block.
              if (j['sales'] is Map) ...[
                const SizedBox(height: 20),
                _salesSection(Map<String, dynamic>.from(j['sales'] as Map)),
              ],
            ],
          ),
        );
      },
    );
  }

  String _money(dynamic v) {
    final n = (v as num?)?.toDouble() ?? 0.0;
    return '\$${n.toStringAsFixed(2)}';
  }

  /// Sales section: revenue cards, per-bucket revenue chart, by-kind rows.
  Widget _salesSection(Map<String, dynamic> sales) {
    final series = ((sales['revenue_series'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final byKind = (sales['by_kind'] as Map?) ?? {};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(s.salesTitle,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.15,
          children: [
            _stat(s.salesTotalRevenue, _money(sales['total_revenue'])),
            _stat(s.salesOrders, '${sales['orders_count'] ?? 0}'),
            _stat(s.salesNetRevenue, _money(sales['net_revenue'])),
          ],
        ),
        const SizedBox(height: 12),
        _revenueChart(series),
        if (_revSelected >= 0 && _revSelected < series.length) ...[
          const SizedBox(height: 8),
          _revBucketDetail(series[_revSelected]),
        ],
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                _kindRow(s.salesSubscriptions,
                    _money(byKind['subscription']), const Color(0xFFF95177)),
                _kindRow(s.salesCredits, _money(byKind['credits']),
                    const Color(0xFF22B8CF)),
                _kindRow(s.salesRefunds, _money(byKind['refund']),
                    Colors.orange),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _kindRow(String label, String value, Color dot) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
                width: 10,
                height: 10,
                decoration:
                    BoxDecoration(color: dot, shape: BoxShape.circle)),
            const SizedBox(width: 10),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            const Spacer(),
            Text(value,
                style:
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          ],
        ),
      );

  /// Tappable revenue bar chart, same pattern as the activity chart.
  Widget _revenueChart(List<Map<String, dynamic>> series) {
    if (series.isEmpty) return Center(child: Text(s.noItems));
    final maxV = series
        .map((e) => ((e['revenue'] as num?) ?? 0).toDouble())
        .fold<double>(1.0, (a, b) => a > b ? a : b);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.salesTotalRevenue,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            SizedBox(
              height: 160,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < series.length; i++)
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _revSelected = i),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: AnimatedContainer(
                                  duration:
                                      const Duration(milliseconds: 250),
                                  width: double.infinity,
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 2),
                                  height: 130 *
                                      ((((series[i]['revenue'] as num?) ?? 0)
                                              .toDouble()) /
                                          maxV),
                                  decoration: BoxDecoration(
                                    color: _revSelected == i
                                        ? const Color(0xFF16A34A)
                                        : const Color(0xFF16A34A)
                                            .withValues(alpha: 0.45),
                                    borderRadius:
                                        const BorderRadius.vertical(
                                            top: Radius.circular(4)),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text('${series[i]['label'] ?? ''}',
                                style: const TextStyle(fontSize: 8),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _revBucketDetail(Map<String, dynamic> b) => Card(
        color: const Color(0xFFF0FDF4),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _detailNum('${b['label']}', ''),
              _detailNum(_money(b['revenue']), s.salesTotalRevenue),
            ],
          ),
        ),
      );

  Widget _stat(String label, String value) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(value,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(label,
                    style:
                        const TextStyle(fontSize: 11, color: Colors.grey)),
              ]),
        ),
      );

  /// Vertical bar chart of active users per bucket. Tapping a bar shows that
  /// bucket's signups + visits below.
  Widget _chart(List<Map<String, dynamic>> series) {
    if (series.isEmpty) return Center(child: Text(s.noItems));
    final maxV = series
        .map((e) => (e['active'] as int?) ?? 0)
        .fold<int>(1, (a, b) => a > b ? a : b);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.adminAnalytics,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            SizedBox(
              height: 160,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < series.length; i++)
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selected = i),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: AnimatedContainer(
                                  duration:
                                      const Duration(milliseconds: 250),
                                  width: double.infinity,
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 2),
                                  height: 130 *
                                      (((series[i]['active'] as int?) ??
                                              0) /
                                          maxV),
                                  decoration: BoxDecoration(
                                    color: _selected == i
                                        ? const Color(0xFFF95177)
                                        : const Color(0xFFF95177)
                                            .withValues(alpha: 0.45),
                                    borderRadius:
                                        const BorderRadius.vertical(
                                            top: Radius.circular(4)),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text('${series[i]['label'] ?? ''}',
                                style: const TextStyle(fontSize: 8),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bucketDetail(Map<String, dynamic> b) => Card(
        color: const Color(0xFFF7F4FF),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _detailNum('${b['label']}', ''),
              _detailNum('${b['active'] ?? 0}', s.statDau),
              _detailNum('${b['signups'] ?? 0}', s.statSignups),
              _detailNum('${b['visits'] ?? 0}', s.statVisits),
            ],
          ),
        ),
      );

  Widget _detailNum(String value, String label) => Column(children: [
        Text(value,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w800)),
        if (label.isNotEmpty)
          Text(label,
              style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ]);
}

// ---------------------------------------------------------------- users
class _UsersSection extends StatefulWidget {
  const _UsersSection();
  @override
  State<_UsersSection> createState() => _UsersSectionState();
}

class _UsersSectionState extends State<_UsersSection>
    with _AdminGuard<_UsersSection> {
  final _q = TextEditingController();
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = admin.users();
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  void _search() => setState(() => _future = admin.users(q: _q.text.trim()));

  /// "Last active: 2026-09-26 14:20" or "Last active: Never".
  String _lastActive(String? iso) {
    if (iso == null || iso.isEmpty) return '${s.lastActive}: ${s.neverActive}';
    final t = DateTime.tryParse(iso)?.toLocal();
    if (t == null) return '${s.lastActive}: ${s.neverActive}';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${s.lastActive}: ${t.year}-${two(t.month)}-${two(t.day)} '
        '${two(t.hour)}:${two(t.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: TextField(
          controller: _q,
          decoration: InputDecoration(
            hintText: s.searchUsers,
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
          ),
          onSubmitted: (_) => _search(),
        ),
      ),
      Expanded(
        child: FutureBuilder<List<dynamic>>(
          future: _future,
          builder: (c, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final items = snap.data!;
            if (items.isEmpty) return Center(child: Text(s.noItems));
            return RefreshIndicator(
              onRefresh: () async => _search(),
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final u = items[i] as Map<String, dynamic>;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                          child: Text('${u['email'] ?? '?'}'.isNotEmpty
                              ? '${u['email']}'[0].toUpperCase()
                              : '?')),
                      title: Text('${u['email'] ?? ''}',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: Text(
                          '${u['plan'] ?? ''} · ${u['credits'] ?? 0} credits'
                          '${u['is_admin'] == true ? ' · ADMIN' : ''}'
                          '${u['suspended'] == true ? ' · SUSPENDED' : ''}'
                          '\n${_lastActive(u['last_active'] as String?)}',
                          style: const TextStyle(fontSize: 12)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _detail(u),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    ]);
  }

  void _detail(Map<String, dynamic> u) {
    final id = '${u['id']}';
    final suspended = u['suspended'] == true;
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('${u['email']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 4),
            Text('ID: $id', style: const TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: () async {
                Navigator.pop(context);
                final ok = await act(() => suspended
                    ? admin.unsuspendUser(id)
                    : admin.suspendUser(id));
                if (ok) { toast(suspended ? s.unsuspend : s.suspend); _search(); }
              },
              child: Text(suspended ? s.unsuspend : s.suspend),
            ),
            const SizedBox(height: 8),
            if (u['is_admin'] != true)
              FilledButton.tonal(
                onPressed: () async {
                  Navigator.pop(context);
                  final ok = await act(() => admin.makeAdmin(id));
                  if (ok) { toast(s.done); _search(); }
                },
                child: Text(s.makeAdmin),
              ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () { Navigator.pop(context); _creditDialog(id); },
              child: Text(s.adjustCredits),
            ),
          ]),
        ),
      ),
    );
  }

  void _creditDialog(String userId) {
    final deltaCtrl = TextEditingController();
    final reasonCtrl = TextEditingController(text: 'admin_adjustment');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(s.adjustCredits),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: deltaCtrl, keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: s.creditsDelta)),
          TextField(controller: reasonCtrl, decoration: InputDecoration(labelText: s.reason)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(s.cancel)),
          FilledButton(
            onPressed: () async {
              final delta = int.tryParse(deltaCtrl.text.trim());
              if (delta == null) return;
              Navigator.pop(context);
              final ok = await guard(
                  () => admin.adjustCredits(userId, delta, reasonCtrl.text.trim()));
              if (ok != null) { toast('${s.done}: ${ok['balance']}'); _search(); }
            },
            child: Text(s.saveChanges),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- campaigns (admin)
class _CampaignsSection extends StatefulWidget {
  const _CampaignsSection();
  @override
  State<_CampaignsSection> createState() => _CampaignsSectionState();
}

class _CampaignsSectionState extends State<_CampaignsSection>
    with _AdminGuard<_CampaignsSection> {
  String _status = '';
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = admin.campaigns();
  }

  void _load() => setState(() => _future = admin.campaigns(status: _status));

  @override
  Widget build(BuildContext context) {
    const statuses = ['', 'live', 'optimizing', 'paused', 'analyzing', 'completed'];
    return Column(children: [
      SizedBox(
        height: 44,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          itemCount: statuses.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) => ChoiceChip(
            label: Text(statuses[i].isEmpty ? 'all' : statuses[i]),
            selected: _status == statuses[i],
            onSelected: (_) { _status = statuses[i]; _load(); },
          ),
        ),
      ),
      Expanded(
        child: FutureBuilder<List<dynamic>>(
          future: _future,
          builder: (c, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final items = snap.data!;
            if (items.isEmpty) return Center(child: Text(s.noItems));
            return RefreshIndicator(
              onRefresh: () async => _load(),
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final cp = items[i] as Map<String, dynamic>;
                  final live = cp['status'] == 'live' || cp['status'] == 'optimizing';
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text('${cp['title'] ?? ''}',
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: Text(
                          '${cp['goal'] ?? ''} · ${cp['mode'] ?? ''} · \$${cp['budget_usd'] ?? 0} · ${cp['status'] ?? ''}',
                          style: const TextStyle(fontSize: 12)),
                      trailing: live
                          ? TextButton(
                              onPressed: () async {
                                final ok = await act(
                                    () => admin.pauseCampaign('${cp['id']}'));
                                if (ok) { toast(s.done); _load(); }
                              },
                              child: Text(s.pause))
                          : null,
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    ]);
  }
}

// ---------------------------------------------------------------- payments (admin)
class _PaymentsSection extends StatefulWidget {
  const _PaymentsSection();
  @override
  State<_PaymentsSection> createState() => _PaymentsSectionState();
}

class _PaymentsSectionState extends State<_PaymentsSection>
    with _AdminGuard<_PaymentsSection> {
  String _status = '';
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = admin.transactions();
  }

  void _load() => setState(() => _future = admin.transactions(status: _status));

  @override
  Widget build(BuildContext context) {
    const statuses = ['', 'pending', 'completed', 'failed', 'refunded'];
    return Column(children: [
      SizedBox(
        height: 44,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          itemCount: statuses.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) => ChoiceChip(
            label: Text(statuses[i].isEmpty ? 'all' : statuses[i]),
            selected: _status == statuses[i],
            onSelected: (_) { _status = statuses[i]; _load(); },
          ),
        ),
      ),
      Expanded(
        child: FutureBuilder<List<dynamic>>(
          future: _future,
          builder: (c, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final items = snap.data!;
            if (items.isEmpty) return Center(child: Text(s.noItems));
            return RefreshIndicator(
              onRefresh: () async => _load(),
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final t = items[i] as Map<String, dynamic>;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const Icon(Icons.receipt_outlined),
                      title: Text(
                          '${t['provider'] ?? ''} · ${t['kind'] ?? ''} — ${t['amount'] ?? 0} ${t['currency'] ?? ''}',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: Text('${t['status'] ?? ''} · ${t['provider_ref'] ?? ''}\n${t['created_at'] ?? ''}',
                          style: const TextStyle(fontSize: 11)),
                      isThreeLine: true,
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    ]);
  }
}

// ---------------------------------------------------------------- fraud
class _FraudSection extends StatefulWidget {
  const _FraudSection();
  @override
  State<_FraudSection> createState() => _FraudSectionState();
}

class _FraudSectionState extends State<_FraudSection>
    with _AdminGuard<_FraudSection> {
  bool _openOnly = true;
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = admin.fraudFlags(openOnly: _openOnly);
  }

  void _load() => setState(() => _future = admin.fraudFlags(openOnly: _openOnly));

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Row(children: [
          Text(s.openFlags, style: const TextStyle(fontSize: 13)),
          const Spacer(),
          Switch(value: _openOnly, onChanged: (v) { _openOnly = v; _load(); }),
        ]),
      ),
      Expanded(
        child: FutureBuilder<List<dynamic>>(
          future: _future,
          builder: (c, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final items = snap.data!;
            if (items.isEmpty) return Center(child: Text(s.noItems));
            return RefreshIndicator(
              onRefresh: () async => _load(),
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final f = items[i] as Map<String, dynamic>;
                  final resolved = f['resolved'] == true;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Icon(Icons.flag_outlined,
                          color: resolved ? Colors.grey : Colors.red),
                      title: Text('${f['reason'] ?? ''}',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: Text('${f['campaign_id'] ?? ''}\n${f['created_at'] ?? ''}',
                          style: const TextStyle(fontSize: 11)),
                      isThreeLine: true,
                      trailing: resolved
                          ? null
                          : TextButton(
                              onPressed: () async {
                                final ok = await act(
                                    () => admin.resolveFlag('${f['id']}'));
                                if (ok) { toast(s.done); _load(); }
                              },
                              child: Text(s.resolve)),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    ]);
  }
}

// ---------------------------------------------------------------- discovery queue
class _DiscoverySection extends StatefulWidget {
  const _DiscoverySection();
  @override
  State<_DiscoverySection> createState() => _DiscoverySectionState();
}

class _DiscoverySectionState extends State<_DiscoverySection>
    with _AdminGuard<_DiscoverySection> {
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = admin.discoveryQueue();
  }

  void _load() => setState(() => _future = admin.discoveryQueue());

  Future<void> _review(String placementId, bool approve) async {
    final noteCtrl = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(approve ? s.approve : s.reject),
        content: TextField(controller: noteCtrl,
            decoration: InputDecoration(labelText: s.noteOptional)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(s.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(context, noteCtrl.text.trim()),
              child: Text(approve ? s.approve : s.reject)),
        ],
      ),
    );
    if (note == null) return;
    final ok = await act(() => approve
        ? admin.approvePlacement(placementId, note)
        : admin.rejectPlacement(placementId, note));
    if (ok) { toast(s.done); _load(); }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _future,
      builder: (c, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final items = snap.data!;
        if (items.isEmpty) return Center(child: Text(s.noItems));
        return RefreshIndicator(
          onRefresh: () async => _load(),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (_, i) {
              final p = items[i] as Map<String, dynamic>;
              final topics = (p['topics'] as List? ?? []).join(', ');
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${p['title'] ?? ''}',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text('${p['platform'] ?? ''} · $topics',
                        style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(
                        child: OutlinedButton(
                            onPressed: () => _review('${p['placement_id']}', false),
                            child: Text(s.reject)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                            onPressed: () => _review('${p['placement_id']}', true),
                            child: Text(s.approve)),
                      ),
                    ]),
                  ]),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------- plans
class _PlansSection extends StatefulWidget {
  const _PlansSection();
  @override
  State<_PlansSection> createState() => _PlansSectionState();
}

class _PlansSectionState extends State<_PlansSection>
    with _AdminGuard<_PlansSection> {
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = admin.plans();
  }

  void _load() => setState(() => _future = admin.plans());

  void _edit(Map<String, dynamic> p) {
    final name = TextEditingController(text: '${p['name'] ?? ''}');
    final price = TextEditingController(text: '${p['price_usd'] ?? 0}');
    final credits = TextEditingController(text: '${p['ai_credits_monthly'] ?? 0}');
    final limit = TextEditingController(text: '${p['campaigns_limit'] ?? 0}');
    final sort = TextEditingController(text: '${p['sort'] ?? 0}');
    var active = p['active'] != false;
    showDialog(
      context: context,
      builder: (dctx) => StatefulBuilder(
        builder: (_, setD) => AlertDialog(
          title: Text(s.editPlan),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: name, decoration: InputDecoration(labelText: s.planName)),
              TextField(controller: price, keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: s.priceUsd)),
              TextField(controller: credits, keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: s.creditsMonthly)),
              TextField(controller: limit, keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: s.campaignsLimit)),
              TextField(controller: sort, keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: s.sortOrder)),
              SwitchListTile(title: Text(s.planActive), value: active,
                  onChanged: (v) => setD(() => active = v)),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dctx), child: Text(s.cancel)),
            FilledButton(
              onPressed: () async {
                Navigator.pop(dctx);
                final ok = await act(() => admin.upsertPlan('${p['slug']}', {
                      'name': name.text.trim(),
                      'price_usd': double.tryParse(price.text.trim()) ?? 0,
                      'ai_credits_monthly': int.tryParse(credits.text.trim()) ?? 0,
                      'campaigns_limit': int.tryParse(limit.text.trim()) ?? 0,
                      'active': active,
                      'sort': int.tryParse(sort.text.trim()) ?? 0,
                    }));
                if (ok) { toast(s.done); _load(); }
              },
              child: Text(s.saveChanges),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _future,
      builder: (c, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final items = snap.data!;
        if (items.isEmpty) return Center(child: Text(s.noItems));
        return RefreshIndicator(
          onRefresh: () async => _load(),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (_, i) {
              final p = items[i] as Map<String, dynamic>;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text('${p['name'] ?? p['slug']}',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(
                      '\$${p['price_usd'] ?? 0} · ${p['ai_credits_monthly'] ?? 0} credits/mo · ${p['campaigns_limit'] ?? 0} campaigns'
                      '${p['active'] == true ? '' : ' · INACTIVE'}',
                      style: const TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: () => _edit(p),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------- broadcasts
class _BroadcastsSection extends StatefulWidget {
  const _BroadcastsSection();
  @override
  State<_BroadcastsSection> createState() => _BroadcastsSectionState();
}

class _BroadcastsSectionState extends State<_BroadcastsSection>
    with _AdminGuard<_BroadcastsSection> {
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = admin.broadcasts();
  }

  void _load() => setState(() => _future = admin.broadcasts());

  void _compose() {
    final title = TextEditingController();
    final body = TextEditingController();
    var audience = 'all';
    final Map<String, Map<String, String>> translations = {};
    showDialog(
      context: context,
      builder: (dctx) => StatefulBuilder(
        builder: (_, setD) => AlertDialog(
          title: Text(s.composeBroadcast),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: title, decoration: InputDecoration(labelText: s.broadcastTitle)),
              TextField(controller: body, maxLines: 4,
                  decoration: InputDecoration(labelText: s.broadcastBody)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: audience,
                decoration: InputDecoration(labelText: s.audience),
                items: [
                  DropdownMenuItem(value: 'all', child: Text(s.audienceAll)),
                  DropdownMenuItem(value: 'free', child: Text(s.audienceFree)),
                  DropdownMenuItem(value: 'paid', child: Text(s.audiencePaid)),
                ],
                onChanged: (v) => setD(() => audience = v ?? 'all'),
              ),
              const SizedBox(height: 8),
              _TranslationsEditor(
                  translations: translations, setD: setD, s: s),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dctx), child: Text(s.cancel)),
            FilledButton(
              onPressed: () async {
                if (title.text.trim().isEmpty || body.text.trim().isEmpty) return;
                Navigator.pop(dctx);
                final ok = await act(() => admin.broadcast(
                    title.text.trim(), body.text.trim(), audience,
                    translations: translations));
                if (ok) { toast(s.done); _load(); }
              },
              child: Text(s.sendBroadcast),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _compose,
            icon: const Icon(Icons.campaign_outlined),
            label: Text(s.composeBroadcast),
          ),
        ),
      ),
      Expanded(
        child: FutureBuilder<List<dynamic>>(
          future: _future,
          builder: (c, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final items = snap.data!;
            if (items.isEmpty) return Center(child: Text(s.noItems));
            return RefreshIndicator(
              onRefresh: () async => _load(),
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final b = items[i] as Map<String, dynamic>;
                  final tr = (b['translations'] as Map?) ?? {};
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const Icon(Icons.notifications_outlined),
                      title: Text('${b['title'] ?? ''}',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: Text(
                          '${b['audience'] ?? ''} · ${b['created_at'] ?? ''}'
                          '${tr.isNotEmpty ? '\n🌐 ${tr.keys.join(', ')}' : ''}',
                          style: const TextStyle(fontSize: 12)),
                      isThreeLine: tr.isNotEmpty,
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    ]);
  }
}

/// Per-language translations for a broadcast (admin-composed). Only real
/// translations are stored; languages without one fall back honestly.
class _TranslationsEditor extends StatefulWidget {
  final Map<String, Map<String, String>> translations;
  final void Function(void Function()) setD;
  final dynamic s;
  const _TranslationsEditor(
      {required this.translations, required this.setD, required this.s});

  @override
  State<_TranslationsEditor> createState() => _TranslationsEditorState();
}

class _TranslationsEditorState extends State<_TranslationsEditor> {
  List<Map<String, String>> _langs = [];
  String? _picked;
  final _t = TextEditingController();
  final _b = TextEditingController();

  @override
  void initState() {
    super.initState();
    apiClient.listLanguages().then((r) {
      if (!mounted) return;
      setState(() {
        _langs = (r['languages'] as List)
            .map((e) {
              final m = Map<String, dynamic>.from(e as Map<String, dynamic>);
              return {
                'code': '${m['code']}',
                'label': '${m['name_en']} · ${m['name_native'] ?? ''}'
              };
            })
            .toList();
      });
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _t.dispose();
    _b.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Divider(),
      const Text('🌐 Translations (optional)',
          style: TextStyle(fontWeight: FontWeight.w600)),
      ...widget.translations.entries.map((e) => ListTile(
            dense: true,
            title: Text(e.key),
            subtitle: Text(e.value['title'] ?? '',
                maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              onPressed: () =>
                  widget.setD(() => widget.translations.remove(e.key)),
            ),
          )),
      if (_langs.isNotEmpty)
        DropdownButtonFormField<String>(
          initialValue: _picked,
          decoration: const InputDecoration(labelText: 'Language'),
          items: _langs
              .where((l) => !widget.translations.containsKey(l['code']))
              .map((l) => DropdownMenuItem(
                  value: l['code'], child: Text(l['label'] ?? '')))
              .toList(),
          onChanged: (v) => setState(() => _picked = v),
        ),
      if (_picked != null) ...[
        TextField(
            controller: _t,
            decoration: const InputDecoration(labelText: 'Translated title')),
        TextField(
            controller: _b,
            maxLines: 3,
            decoration:
                const InputDecoration(labelText: 'Translated message')),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {
              if (_t.text.trim().isEmpty || _b.text.trim().isEmpty) return;
              widget.setD(() {
                widget.translations[_picked!] = {
                  'title': _t.text.trim(),
                  'body': _b.text.trim()
                };
                _picked = null;
                _t.clear();
                _b.clear();
              });
            },
            child: const Text('Add translation'),
          ),
        ),
      ],
    ]);
  }
}

// ---------------------------------------------------------------- AI usage
class _AiUsageSection extends StatefulWidget {
  const _AiUsageSection();
  @override
  State<_AiUsageSection> createState() => _AiUsageSectionState();
}

class _AiUsageSectionState extends State<_AiUsageSection>
    with _AdminGuard<_AiUsageSection> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = admin.aiUsage();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (c, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final d = snap.data!;
        final byAgent = Map<String, dynamic>.from(d['by_agent'] as Map? ?? {});
        return RefreshIndicator(
          onRefresh: () async => setState(() => _future = admin.aiUsage()),
          child: ListView(padding: const EdgeInsets.all(16), children: [
            Row(children: [
              Expanded(child: _mini('Runs', '${d['total_runs'] ?? 0}')),
              const SizedBox(width: 8),
              Expanded(child: _mini('Input tokens', '${d['total_input_tokens'] ?? 0}')),
              const SizedBox(width: 8),
              Expanded(child: _mini('Output tokens', '${d['total_output_tokens'] ?? 0}')),
            ]),
            const SizedBox(height: 12),
            if (byAgent.isEmpty) Center(child: Text(s.noItems)),
            for (final e in byAgent.entries)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(e.key,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text(
                      '${(e.value as Map)['runs'] ?? 0} runs · '
                      'in ${(e.value as Map)['input_tokens'] ?? 0} / '
                      'out ${(e.value as Map)['output_tokens'] ?? 0} tokens',
                      style: const TextStyle(fontSize: 12)),
                ),
              ),
          ]),
        );
      },
    );
  }

  Widget _mini(String label, String value) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ]),
        ),
      );
}

// ---------------------------------------------------------------- settings
class _SettingsSection extends StatefulWidget {
  const _SettingsSection();
  @override
  State<_SettingsSection> createState() => _SettingsSectionState();
}

class _SettingsSectionState extends State<_SettingsSection>
    with _AdminGuard<_SettingsSection> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = admin.settings();
  }

  void _load() => setState(() => _future = admin.settings());

  void _edit(String key, dynamic value) {
    final ctrl = TextEditingController(text: jsonEncode(value));
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('${s.editSetting}: $key'),
        content: TextField(controller: ctrl, maxLines: 6,
            decoration: InputDecoration(labelText: s.settingValueJson)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(s.cancel)),
          FilledButton(
            onPressed: () async {
              dynamic parsed;
              try {
                parsed = jsonDecode(ctrl.text);
              } catch (_) {
                toast(s.invalidJson);
                return;
              }
              Navigator.pop(context);
              final ok = await act(() => admin.putSetting(key, parsed));
              if (ok) { toast(s.done); _load(); }
            },
            child: Text(s.saveChanges),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (c, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final entries = snap.data!.entries.toList();
        if (entries.isEmpty) return Center(child: Text(s.noItems));
        return RefreshIndicator(
          onRefresh: () async => _load(),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: entries.length,
            itemBuilder: (_, i) {
              final e = entries[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(e.key,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text(jsonEncode(e.value),
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: () => _edit(e.key, e.value),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------- audit
class _AuditSection extends StatefulWidget {
  const _AuditSection();
  @override
  State<_AuditSection> createState() => _AuditSectionState();
}

class _AuditSectionState extends State<_AuditSection>
    with _AdminGuard<_AuditSection> {
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = admin.auditLogs();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _future,
      builder: (c, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final items = snap.data!;
        if (items.isEmpty) return Center(child: Text(s.noItems));
        return RefreshIndicator(
          onRefresh: () async => setState(() => _future = admin.auditLogs()),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (_, i) {
              final l = items[i] as Map<String, dynamic>;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.history_outlined),
                  title: Text('${l['action'] ?? ''}',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  subtitle: Text('${l['details'] ?? ''}\n${l['created_at'] ?? ''}',
                      style: const TextStyle(fontSize: 11)),
                  isThreeLine: true,
                ),
              );
            },
          ),
        );
      },
    );
  }
}
