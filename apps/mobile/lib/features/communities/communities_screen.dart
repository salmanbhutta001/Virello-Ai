import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../../core/config.dart';
import '../../core/strings.dart';
import '../../main.dart';

/// Community Directory — curated public communities where the user's
/// audience hangs out. Read-only discovery; users share manually.
/// Virello never auto-posts to these communities.
///
/// Self-contained: uses http directly, no api_client changes needed.
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
    'technology': Icons.computer,
    'business': Icons.business_center,
    'fitness': Icons.fitness_center,
    'fashion': Icons.checkroom,
    'food': Icons.restaurant,
    'travel': Icons.flight,
    'education': Icons.school,
    'entertainment': Icons.movie,
    'health': Icons.health_and_safety,
    'sports': Icons.sports_soccer,
    'art': Icons.palette,
    'home': Icons.home,
  };

  IconData _iconFor(String category) {
    final c = category.toLowerCase();
    for (final entry in _categoryIcons.entries) {
      if (c.contains(entry.key)) return entry.value;
    }
    return Icons.groups;
  }

  Map<String, String> get _headers {
    final token = authStore.accessToken;
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

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
      final base = AppConfig.baseUrl;
      final catRes = await http.get(
        Uri.parse('$base/api/v1/communities/categories'),
        headers: _headers,
      );
      final qs = _selectedCategory != null
          ? '?category=${Uri.encodeComponent(_selectedCategory!)}&limit=50'
          : '?limit=50';
      final comRes = await http.get(
        Uri.parse('$base/api/v1/communities$qs'),
        headers: _headers,
      );
      if (!mounted) return;
      if (catRes.statusCode == 200 && comRes.statusCode == 200) {
        setState(() {
          _categories = jsonDecode(catRes.body) as List;
          _communities = jsonDecode(comRes.body) as List;
          _loading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to load (${comRes.statusCode})';
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Community Directory'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: Colors.grey),
                      const SizedBox(height: 12),
                      Text(_error!,
                          style: const TextStyle(color: Colors.grey)),
                      const SizedBox(height: 12),
                      ElevatedButton(
                          onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                )
              : Column(
                  children: [
                    _buildCategoryChips(),
                    Expanded(child: _buildList()),
                  ],
                ),
    );
  }

  Widget _buildCategoryChips() {
    if (_categories.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          _chip(null, 'All', Icons.apps),
          for (final c in _categories)
            _chip(
              c['slug'] as String?,
              c['name'] as String? ?? '',
              _iconFor(c['slug'] as String? ?? ''),
            ),
        ],
      ),
    );
  }

  Widget _chip(String? slug, String label, IconData icon) {
    final selected = _selectedCategory == slug;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16),
            const SizedBox(width: 6),
            Text(label),
          ],
        ),
        selected: selected,
        onSelected: (_) {
          setState(() => _selectedCategory = slug);
          _load();
        },
      ),
    );
  }

  Widget _buildList() {
    if (_communities.isEmpty) {
      return const Center(
        child: Text('No communities found',
            style: TextStyle(color: Colors.grey)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _communities.length,
      itemBuilder: (context, i) {
        final c = _communities[i] as Map<String, dynamic>;
        return _communityCard(c);
      },
    );
  }

  Widget _communityCard(Map<String, dynamic> c) {
    final name = c['name'] as String? ?? 'Unknown';
    final platform = c['platform'] as String? ?? '';
    final description = c['description'] as String? ?? '';
    final url = c['url'] as String? ?? '';
    final memberCount = c['member_count'];
    final category = c['category'] as String? ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: url.isNotEmpty ? () => _openUrl(url) : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor:
                        Theme.of(context).colorScheme.primaryContainer,
                    child: Icon(_iconFor(category),
                        color: Theme.of(context).colorScheme.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        Text(platform.toUpperCase(),
                            style: TextStyle(
                                color: Colors.grey[600], fontSize: 12)),
                      ],
                    ),
                  ),
                  if (memberCount != null)
                    Text(
                      _formatCount(memberCount),
                      style: TextStyle(
                          color: Colors.grey[600], fontSize: 12),
                    ),
                ],
              ),
              if (description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(description,
                    style: TextStyle(color: Colors.grey[700], fontSize: 14)),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton.icon(
                    onPressed:
                        url.isNotEmpty ? () => _openUrl(url) : null,
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: const Text('Open'),
                  ),
                  const Spacer(),
                  Text(
                    'Share manually',
                    style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                        fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatCount(dynamic count) {
    if (count is! num) return '';
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M members';
    }
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K members';
    }
    return '$count members';
  }
}
