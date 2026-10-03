import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/virello_ui.dart';
import '../../main.dart';
import '../../services/rewards_api.dart';

/// Full leaderboard: Week / Month / All time (rolling) switcher, top-20
/// rows. Data from GET /api/v1/rewards/leaderboard?period=... — the list is
/// shown as returned; an empty server list renders an empty state, never
/// placeholders.
class LeaderboardScreen extends StatefulWidget {
  /// Which tab to open on: 'week' | 'month' | 'rolling'.
  final String initialPeriod;
  const LeaderboardScreen({super.key, this.initialPeriod = 'week'});
  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  RewardsApi get _api => RewardsApi(apiClient);

  String _period = 'week';
  Future<Map<String, dynamic>>? _future;

  AppStrings get s => AppStrings(appState.localeCode);

  @override
  void initState() {
    super.initState();
    _period = widget.initialPeriod;
    _load();
  }

  void _load() {
    setState(() {
      _future = _api.leaderboard(_period).catchError((_) =>
          <String, dynamic>{'leaderboard': <dynamic>[]});
    });
  }

  String _periodLabel(String p) => p == 'week'
      ? s.weeklyRace
      : p == 'month'
          ? s.monthlyRace
          : s.leaderboard;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(s.leaderboard)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'week', label: Text(s.weeklyRace)),
                ButtonSegment(value: 'month', label: Text(s.monthlyRace)),
                ButtonSegment(
                  value: 'rolling',
                  label: Text(s.leaderboard),
                ),
              ],
              selected: {_period},
              onSelectionChanged: (sel) {
                _period = sel.first;
                _load();
              },
            ),
          ),
          Expanded(
            child: FutureBuilder<Map<String, dynamic>>(
              future: _future,
              builder: (c, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }
                final d = snap.data ?? {};
                final rows = (d['leaderboard'] as List? ?? [])
                    .map((e) => Map<String, dynamic>.from(e as Map))
                    .toList();
                final p = d['period'] as Map<String, dynamic>?;
                final label = '${p?['label'] ?? _periodLabel(_period)}';
                if (rows.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.emoji_events_outlined,
                            size: 48,
                            color: VirelloColors.muted,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            s.noRacersYet,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: VirelloColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: rows.take(20).length + 1,
                  itemBuilder: (ctx, i) {
                    if (i == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          label,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: VirelloColors.muted,
                          ),
                        ),
                      );
                    }
                    final row = rows[i - 1];
                    final rank = i;
                    return VCard(
                      padding: EdgeInsets.zero,
                      child: ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor: rank == 1
                              ? const Color(0xFFFFD54F)
                              : rank == 2
                                  ? const Color(0xFFB0BEC5)
                                  : rank == 3
                                      ? const Color(0xFFD7A971)
                                      : VTheme.chip(context),
                          child: Text(
                            '$rank',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: rank <= 3
                                  ? Colors.black87
                                  : null,
                            ),
                          ),
                        ),
                        title: Text(
                          '${row['username'] ?? '—'}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        trailing: Text(
                          '${row['points'] ?? 0}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: VirelloColors.pink,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
