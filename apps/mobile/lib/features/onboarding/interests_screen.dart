import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/virello_ui.dart';
import '../../data/discovery_models.dart';
import '../../services/api_client.dart';
import '../../main.dart';

/// Board screen 06 — "What are you interested in?": premium 2-column card
/// grid multi-select with pink gradient selected state, fixed bottom
/// Continue. Loads real topics from the backend when available; falls back
/// to the board's static list. Saves via
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

  /// Icons for backend topic slugs beyond the board fallback, so any topic
  /// count renders a proper card instead of a generic tag icon.
  static const _iconBySlug = <String, IconData>{
    'technology': Icons.devices_other_outlined,
    'business': Icons.business_center_outlined,
    'fashion': Icons.checkroom_outlined,
    'food_recipes': Icons.restaurant_outlined,
    'fitness': Icons.fitness_center_outlined,
    'music': Icons.music_note_outlined,
    'comedy': Icons.emoji_emotions_outlined,
    'beauty_skincare': Icons.spa_outlined,
    'finance': Icons.account_balance_outlined,
    'photography': Icons.camera_alt_outlined,
    'art_design': Icons.brush_outlined,
    'motivation': Icons.local_fire_department_outlined,
    'parenting': Icons.family_restroom_outlined,
    'real_estate': Icons.home_work_outlined,
    'automobiles': Icons.directions_car_outlined,
    'pets': Icons.pets_outlined,
    'news': Icons.newspaper_outlined,
    'tech_gadgets': Icons.devices_other_outlined,
    'health': Icons.favorite_outline,
    'education': Icons.school_outlined,
    'sports': Icons.emoji_events_outlined,
    'gaming': Icons.sports_esports_outlined,
  };

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
    return _iconBySlug[slug] ?? Icons.tag_outlined;
  }

  String _labelFor(Topic t) {
    for (final f in _fallback) {
      if (f.$1 == t.slug) return f.$2;
    }
    return t.name(appState.localeCode);
  }

  void _toggle(String slug) {
    setState(() {
      if (_selected.contains(slug)) {
        _selected.remove(slug);
      } else {
        _selected.add(slug);
      }
    });
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  Text(
                    s.boardInterestedIn,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: VTheme.text(context),
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    s.interestsSelected(_selected.length),
                    style: TextStyle(
                      color: VTheme.textSec(context),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: VirelloColors.pink,
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 2.1,
                      ),
                      itemCount: topics.length,
                      itemBuilder: (context, i) {
                        final t = topics[i];
                        final sel = _selected.contains(t.slug);
                        return _InterestCard(
                          label: _labelFor(t),
                          icon: _iconFor(t.slug),
                          selected: sel,
                          onTap: () => _toggle(t.slug),
                        );
                      },
                    ),
            ),
            // Fixed bottom CTA bar: the grid scrolls above it and can never
            // slide underneath the Continue button.
            Container(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
              decoration: BoxDecoration(
                color: VTheme.scaffold(context),
                border: Border(
                  top: BorderSide(
                    color: VTheme.divider(context),
                    width: 1,
                  ),
                ),
              ),
              child: VPinkButton(
                label: s.continueBtn,
                loading: _saving,
                onPressed: _selected.isEmpty ? null : _continue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact interest card: tinted icon tile + label on a hairline-bordered
/// card; selected state gets a solid pink fill with white icon/text and a
/// white checkmark badge (Hafiz 2026-10-03: selected text must stay visible).
class _InterestCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _InterestCard({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: selected ? VirelloColors.pink : VTheme.card(context),
            border: selected
                ? null
                : Border.all(color: VTheme.divider(context), width: 1.2),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: VirelloColors.pink.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: selected
                          ? Colors.white.withValues(alpha: 0.22)
                          : VTheme.chip(context),
                    ),
                    child: Icon(
                      icon,
                      size: 20,
                      color: selected
                          ? Colors.white
                          : VTheme.textSec(context),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color:
                            selected ? Colors.white : VTheme.text(context),
                      ),
                    ),
                  ),
                ],
              ),
              if (selected)
                PositionedDirectional(
                  top: -14,
                  end: -6,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      size: 13,
                      color: VirelloColors.pink,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
