import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../../core/config.dart';
import '../../core/theme.dart';
import '../../core/virello_ui.dart';
import '../../main.dart';
import 'seeding_strings.dart';

/// Smart Community Seeding — free organic growth strategy #3.
///
/// The user pastes post content, picks topics, and gets matched public
/// communities (Reddit-style subreddits / Facebook groups from a curated
/// static list — nothing scraped) with a value-first, rules-aware draft for
/// each. The user posts MANUALLY: Approve / Mark-as-posted only track status
/// (suggested → approved → posted). Virello never auto-posts, never bots.
class SeedingScreen extends StatefulWidget {
  const SeedingScreen({super.key});

  @override
  State<SeedingScreen> createState() => _SeedingScreenState();
}

class _SeedingScreenState extends State<SeedingScreen> {
  SeedingStrings get s => SeedingStrings(appState.localeCode);

  final _contentCtrl = TextEditingController();
  final Set<String> _topics = {};

  bool _suggesting = false;
  String? _error;
  String? _info;
  List<Map<String, dynamic>> _suggestions = [];
  List<Map<String, dynamic>> _myPlans = [];
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  @override
  void dispose() {
    _contentCtrl.dispose();
    super.dispose();
  }

  Map<String, String> get _headers {
    final token = authStore.accessToken;
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Future<void> _suggest() async {
    final content = _contentCtrl.text.trim();
    if (content.isEmpty) {
      setState(() => _error = s.needContent);
      return;
    }
    setState(() {
      _suggesting = true;
      _error = null;
      _info = null;
    });
    try {
      final res = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/v1/seeding/suggest'),
        headers: _headers,
        body: jsonEncode({'content': content, 'topics': _topics.toList()}),
      );
      if (res.statusCode != 200) throw Exception(res.body);
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      setState(() {
        _suggestions =
            (body['plans'] as List).cast<Map<String, dynamic>>();
        _info = body['message'] as String?;
      });
      await _loadPlans(silent: true);
    } catch (_) {
      setState(() => _error = s.errorGeneric);
    } finally {
      setState(() => _suggesting = false);
    }
  }

  Future<void> _loadPlans({bool silent = false}) async {
    try {
      final res = await http.get(
        Uri.parse('${AppConfig.baseUrl}/api/v1/seeding/plans'),
        headers: _headers,
      );
      if (res.statusCode != 200) throw Exception(res.body);
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      setState(() {
        _myPlans = (body['plans'] as List).cast<Map<String, dynamic>>();
      });
    } catch (_) {
      if (!silent) setState(() => _error = s.errorGeneric);
    }
  }

  Future<void> _setStatus(Map<String, dynamic> plan, String status) async {
    final id = plan['id'] as String;
    setState(() => _busy.add(id));
    try {
      final res = await http.patch(
        Uri.parse('${AppConfig.baseUrl}/api/v1/seeding/plans/$id'),
        headers: _headers,
        body: jsonEncode({'status': status}),
      );
      if (res.statusCode != 200) throw Exception(res.body);
      await _loadPlans(silent: true);
      setState(() {
        // Keep the suggestion cards in sync with the new status.
        for (final p in _suggestions) {
          if (p['id'] == id) p['status'] = status;
        }
      });
    } catch (_) {
      setState(() => _error = s.errorGeneric);
    } finally {
      setState(() => _busy.remove(id));
    }
  }

  void _copyDraft(String draft) {
    Clipboard.setData(ClipboardData(text: draft));
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(s.copied)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(s.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(s.subtitle,
              style: TextStyle(
                  fontSize: 13, color: Theme.of(context).hintColor)),
          const SizedBox(height: 12),
          VCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(s.contentLabel,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                TextField(
                  controller: _contentCtrl,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: s.contentHint,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Text(s.topicsLabel,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final slug in seedingTopicSlugs)
                      FilterChip(
                        label: Text(s.topicName(slug)),
                        selected: _topics.contains(slug),
                        onSelected: (sel) => setState(() {
                          if (sel) {
                            _topics.add(slug);
                          } else {
                            _topics.remove(slug);
                          }
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                VGradientButton(
                  label: _suggesting ? s.suggesting : s.suggestBtn,
                  icon: Icons.groups_outlined,
                  onPressed: _suggesting ? null : _suggest,
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                style: const TextStyle(color: Colors.red, fontSize: 13)),
          ],
          if (_info != null) ...[
            const SizedBox(height: 12),
            Text(_info!, style: const TextStyle(fontSize: 13)),
          ],
          if (_suggestions.isNotEmpty) ...[
            const SizedBox(height: 16),
            for (final plan in _suggestions) _planCard(plan, inMyPlans: false),
          ],
          const SizedBox(height: 20),
          VSectionHeader(
              title: s.myPlans, actionLabel: s.refresh, onAction: _loadPlans),
          const SizedBox(height: 8),
          if (_myPlans.isEmpty)
            Text(s.noPlans,
                style: TextStyle(
                    fontSize: 13, color: Theme.of(context).hintColor))
          else
            for (final plan in _myPlans) _planCard(plan, inMyPlans: true),
          const SizedBox(height: 12),
          Text('ℹ️ ${s.manualNote}',
              style:
                  TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
        ],
      ),
    );
  }

  Widget _statusChip(String status) {
    final Color color;
    final String label;
    switch (status) {
      case 'approved':
        color = Colors.blue;
        label = s.approved;
      case 'posted':
        color = Colors.green;
        label = s.posted;
      default:
        color = Colors.amber.shade800;
        label = s.suggested;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700, color: color)),
    );
  }

  Widget _planCard(Map<String, dynamic> plan, {required bool inMyPlans}) {
    final id = plan['id'] as String;
    final status = (plan['status'] as String?) ?? 'suggested';
    final busy = _busy.contains(id);
    final isAi = (plan['draft_source'] as String?) == 'ai';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: VCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(plan['community_name'] as String? ?? '',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800)),
                ),
                _statusChip(status),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.public,
                    size: 14, color: Theme.of(context).hintColor),
                const SizedBox(width: 4),
                Text(
                    '${plan['platform'] as String? ?? ''} • ${plan['member_hint'] as String? ?? ''}',
                    style: TextStyle(
                        fontSize: 12, color: Theme.of(context).hintColor)),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: Colors.amber.withValues(alpha: 0.35)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.rule_outlined,
                      size: 16, color: Colors.amber),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${s.rulesNote}: ${plan['rules_note'] as String? ?? '—'}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: VirelloColors.violet.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: VirelloColors.violet.withValues(alpha: 0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(isAi ? Icons.auto_awesome : Icons.description_outlined,
                          size: 14, color: VirelloColors.violet),
                      const SizedBox(width: 6),
                      Text(isAi ? s.aiDraft : s.heuristicDraft,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: VirelloColors.violet)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(plan['draft'] as String? ?? '',
                      style: const TextStyle(fontSize: 13, height: 1.45)),
                  const SizedBox(height: 4),
                  Text(s.draftNote,
                      style: TextStyle(
                          fontSize: 11, color: Theme.of(context).hintColor)),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () => _copyDraft(plan['draft'] as String? ?? ''),
                  icon: const Icon(Icons.copy, size: 16),
                  label: Text(s.copy),
                ),
                const SizedBox(width: 8),
                if (status == 'suggested')
                  Expanded(
                    child: ElevatedButton(
                      onPressed:
                          busy ? null : () => _setStatus(plan, 'approved'),
                      child: Text(s.approve),
                    ),
                  ),
                if (status == 'approved')
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: busy ? null : () => _setStatus(plan, 'posted'),
                      icon: const Icon(Icons.check_circle_outline, size: 16),
                      label: Text(s.markPosted),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
