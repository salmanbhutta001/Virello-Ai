import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/virello_ui.dart';
import '../../services/api_client.dart';
import '../../main.dart';

/// Community Directory: curated public groups/communities by niche.
///
/// Read-only discovery — users find where their audience hangs out and
/// share manually. Virello never auto-posts to these communities.
class CommunitiesScreen extends StatefulWidget {
  final String? initialCategory;
  const CommunitiesScreen({super.key, this.initialCategory});

  @override
  State<CommunitiesScreen> createState() => _CommunitiesScreenState();
}

class _CommunitiesScreenState extends State<CommunitiesScreen> {
  AppStrings get s => AppStrings(appState.localeCode);

  List<dynamic> _categories = [];
  List<dynamic> _communities = [];
  String? _selectedCategory;
  bool _loading = true;
  String? _error;

  static const _categoryIcons = {
    'business': Icons.business_center_outlined,
    'fitness': Icons.fitness_center_outlined,
    'tech': Icons.computer_outlined,
    'food': Icons.restaurant_outlined,
    'fashion': Icons.checkroom_outlined,
    'travel': Icons.flight_outlined,
    'finance': Icons.account_balance_outlined,
    'education': Icons.school_outlined,
    'parenting': Icons.child_care_outlined,
    'home': Icons.home_outlined,
    'gaming': Icons.sports_esports_outlined,
    'art': Icons.palette_outlined,
  };

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final cats = await apiClient.getCommunityCategories();
      final comms = await apiClient.browseCommunities(category: _selectedCategory);
      if (!mounted) return;
      setState(() {
        _categories = cats;
        _communities = comms;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load communities';
      });
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String _formatMembers(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M members';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(0)}K members';
    return '$n members';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Community Directory')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!),
                      const SizedBox(height: 12),
                      FilledButton(
                          onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: CustomScrollView(
                    slivers: [
                      // Category chips
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height: 96,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            children: [
                              _categoryChip(null, 'All', Icons.apps_outlined),
                              for (final c in _categories)
                                _categoryChip(
                                  c['id'],
                                  c['name'] ?? '',
                                  _categoryIcons[c['id']] ??
                                      Icons.group_outlined,
                                  count: c['community_count'] ?? 0,
                                ),
                            ],
                          ),
                        ),
                      ),
                      // Communities list
                      if (_communities.isEmpty)
                        const SliverFillRemaining(
                          child: Center(
                            child: Text('No communities in this category yet.'),
                          ),
                        )
                      else
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (ctx, i) => _communityCard(_communities[i]),
                            childCount: _communities.length,
                          ),
                        ),
                      const SliverToBoxAdapter(
                          child: SizedBox(height: 24)),
                    ],
                  ),
                ),
    );
  }

  Widget _categoryChip(String? id, String name, IconData icon, {int count = 0}) {
    final selected = _selectedCategory == id;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20),
            const SizedBox(height: 4),
            Text(name, style: const TextStyle(fontSize: 11)),
            if (count > 0)
              Text('$count', style: const TextStyle(fontSize: 10)),
          ],
        ),
        selected: selected,
        onSelected: (_) {
          setState(() => _selectedCategory = id);
          _load();
        },
      ),
    );
  }

  Widget _communityCard(dynamic c) {
    final platform = (c['platform'] ?? '').toString();
    final platformIcon = platform == 'reddit'
        ? Icons.forum_outlined
        : platform == 'facebook'
            ? Icons.group_outlined
            : Icons.public_outlined;
    return VCard(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: () => _openUrl(c['url'] ?? ''),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: VirelloColors.chipBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(platformIcon,
                    color: VirelloColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c['name'] ?? '',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(
                      _formatMembers(c['member_count'] ?? 0),
                      style: const TextStyle(
                          fontSize: 12, color: VirelloColors.muted),
                    ),
                    if ((c['description'] ?? '').toString().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          c['description'],
                          style: const TextStyle(fontSize: 13),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
              const Icon(Icons.open_in_new_outlined, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
