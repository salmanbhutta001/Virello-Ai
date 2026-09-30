import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/virello_ui.dart';
import '../../data/discovery_models.dart';
import '../../services/api_client.dart';
import '../../main.dart';

/// Board screen 06 — "What are you interested in?": chip multi-select,
/// pink Continue. Loads real topics from the backend when available;
/// falls back to the board's static list. Saves via
/// PUT /api/v1/discovery/interests (local fallback on failure).
class InterestsScreen extends StatefulWidget {
  const InterestsScreen({super.key, required this.onDone});
  final VoidCallback onDone;

  @override
  State<InterestsScreen> createState() => _InterestsScreenState();
}

class _InterestsScreenState extends State<InterestsScreen> {
  AppStrings get s => AppStrings(appState.localeCode);

  /// Board fallback: (slug, English label, icon).
  static const _fallback = [
    ('health', 'Health', Icons.favorite_outline),
    ('food', 'Food & Recipes', Icons.restaurant_outlined),
    ('travel', 'Travel', Icons.flight_outlined),
    ('tech', 'Tech & Gadgets', Icons.memory_outlined),
    ('beauty', 'Beauty & Skincare', Icons.spa_outlined),
    ('education', 'Education', Icons.school_outlined),
    ('gaming', 'Gaming', Icons.sports_esports_outlined),
    ('sports', 'Sports', Icons.fitness_center_outlined),
  ];

  List<Topic> _topics = [];
  final Set<String> _selected = {};
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final topics = await apiClient.getTopics();
      if (!mounted) return;
      setState(() {
        _topics = topics.where((t) => t.slug.isNotEmpty).toList();
        _loading = false;
      });
      // Pre-select previously saved interests.
      try {
        final saved = await apiClient.getInterests();
        if (mounted) setState(() => _selected.addAll(saved));
      } catch (_) {}
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  IconData _iconFor(String slug) {
    for (final f in _fallback) {
      if (f.$1 == slug) return f.$3;
    }
    return Icons.tag_outlined;
  }

  String _labelFor(Topic t) {
    for (final f in _fallback) {
      if (f.$1 == t.slug) return f.$2;
    }
    return t.name(appState.localeCode);
  }

  Future<void> _continue() async {
    setState(() => _saving = true);
    try {
      await apiClient.setInterests(_selected);
    } catch (_) {
      // Offline: keep a local copy; the feed still works.
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList(
          'virello_interests_local',
          _selected.toList(),
        );
      } catch (_) {}
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('virello_board_onboarded', true);
    } catch (_) {}
    if (mounted) setState(() => _saving = false);
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final topics = _topics.isEmpty
        ? _fallback
              .map((f) => Topic(slug: f.$1, nameEn: f.$2, nameUr: f.$2))
              .toList()
        : _topics;
    return Scaffold(
      backgroundColor: VTheme.scaffold(context),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Text(
                s.boardInterestedIn,
                textAlign: TextAlign.center,
                style:  TextStyle(
                  color: VTheme.text(context),
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: VirelloColors.pink,
                        ),
                      )
                    : SingleChildScrollView(
                        child: Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: topics.map((t) {
                            final sel = _selected.contains(t.slug);
                            return VSelectChip(
                              label: _labelFor(t),
                              icon: _iconFor(t.slug),
                              selected: sel,
                              onTap: () => setState(() {
                                if (sel) {
                                  _selected.remove(t.slug);
                                } else {
                                  _selected.add(t.slug);
                                }
                              }),
                            );
                          }).toList(),
                        ),
                      ),
              ),
              const SizedBox(height: 12),
              VPinkButton(
                label: s.continueBtn,
                loading: _saving,
                onPressed: _selected.isEmpty ? null : _continue,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
