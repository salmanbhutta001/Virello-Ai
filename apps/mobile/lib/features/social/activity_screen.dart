import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../main.dart';
import '../../services/api_client.dart';
import 'creator_profile_screen.dart';
import 'time_ago.dart';

/// Board screen 16: Activity — pixel-faithful.
///
/// Header "Activity", 4 tabs (All / Likes / Comments / Follows, pink
/// pill active), flat rows: avatar + text + time, dividers between rows.
/// All real: likes from GET /api/v1/discovery/interactions/mine,
/// comments from /social/comments/mine, follows from /social/following.
class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});
  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityItem {
  final String kind; // 'like' | 'comment' | 'follow'
  final DateTime? at;
  final Map<String, dynamic> data;
  _ActivityItem(this.kind, this.at, this.data);
}

class _ActivityScreenState extends State<ActivityScreen> {
  int _tab = 0;
  late Future<List<_ActivityItem>> _future;

  AppStrings get s => AppStrings(appState.localeCode);

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  DateTime? _parse(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    try {
      return DateTime.parse(iso).toLocal();
    } catch (_) {
      return null;
    }
  }

  Future<List<_ActivityItem>> _load() async {
    final items = <_ActivityItem>[];
    try {
      final likes = await apiClient.myInteractions(kind: 'like');
      for (final l in likes) {
        items.add(
          _ActivityItem('like', _parse('${l['created_at'] ?? ''}'), l),
        );
      }
    } catch (_) {}
    try {
      final comments = await apiClient.myComments();
      for (final c in comments) {
        items.add(
          _ActivityItem('comment', _parse('${c['created_at'] ?? ''}'), c),
        );
      }
    } catch (_) {}
    try {
      final follows = await apiClient.getFollowing();
      for (final f in follows) {
        items.add(
          _ActivityItem('follow', _parse('${f['followed_at'] ?? ''}'), f),
        );
      }
    } catch (_) {}
    items.sort((a, b) {
      final x = a.at, y = b.at;
      if (x == null && y == null) return 0;
      if (x == null) return 1;
      if (y == null) return -1;
      return y.compareTo(x);
    });
    return items;
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    try {
      await _future;
    } catch (_) {}
  }

  List<_ActivityItem> _filtered(List<_ActivityItem> all) {
    switch (_tab) {
      case 1:
        return all.where((e) => e.kind == 'like').toList();
      case 2:
        return all.where((e) => e.kind == 'comment').toList();
      case 3:
        return all.where((e) => e.kind == 'follow').toList();
      default:
        return all;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(),
            _tabs(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: FutureBuilder<List<_ActivityItem>>(
                  future: _future,
                  builder: (c, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final items = _filtered(snap.data ?? []);
                    if (items.isEmpty) {
                      return _empty();
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: items.length,
                      separatorBuilder: (_, __) =>  Divider(
                        color: VTheme.divider(context),
                        height: 1,
                      ),
                      itemBuilder: (_, i) => _row(items[i]),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Board header: "Activity" title, left-aligned.
  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.of(context).pop(),
          ),
          Text(
            s.boardActivity,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  /// Board tabs: All / Likes / Comments / Follows — pink pill active.
  Widget _tabs() {
    final labels = [
      s.boardAll,
      s.boardLikes,
      s.boardComments,
      s.boardFollows,
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < labels.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              _tabPill(labels[i], i),
            ],
          ],
        ),
      ),
    );
  }

  Widget _tabPill(String label, int index) {
    final active = _tab == index;
    return GestureDetector(
      onTap: () => setState(() => _tab = index),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? VirelloColors.pink : VTheme.chip(context),
          borderRadius: BorderRadius.circular(19),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: active ? Colors.white : VTheme.textSec(context),
          ),
        ),
      ),
    );
  }

  /// Board activity row: flat, avatar + text + time.
  Widget _row(_ActivityItem e) {
    final isLike = e.kind == 'like';
    final isComment = e.kind == 'comment';
    final title = isLike
        ? '${e.data['campaign_title'] ?? ''}'
        : isComment
            ? '${e.data['author_name'] ?? ''}'
            : '${e.data['creator_name'] ?? e.data['creator_handle'] ?? ''}';
    final subtitle = isLike
        ? s.boardLikedPost
        : isComment
            ? '${s.boardCommentedOn}: "${_short('${e.data['text'] ?? ''}')}"'
            : '${s.boardStartedFollowing} @${e.data['creator_handle'] ?? ''}';
    final initial = title.isNotEmpty ? title[0].toUpperCase() : '?';
    final ago = e.at == null
        ? null
        : boardTimeAgo(e.at!.toUtc().toIso8601String(), s);
    final icon = isLike
        ? Icons.favorite_rounded
        : isComment
            ? Icons.chat_bubble_outline_rounded
            : null;
    return InkWell(
      onTap: e.kind == 'follow'
          ? () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => CreatorProfileScreen(follow: e.data),
              ),
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: icon != null
                    ? VirelloColors.pink.withValues(alpha: 0.14)
                    : null,
                gradient: icon != null ? null : VirelloColors.brandGradient,
              ),
              child: icon != null
                  ? Icon(icon, color: VirelloColors.pink, size: 20)
                  : Text(
                      initial,
                      style:  TextStyle(
                        color: VTheme.onBrand(context),
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style:  TextStyle(
                      fontSize: 12.5,
                      color: VTheme.textSec(context),
                    ),
                  ),
                ],
              ),
            ),
            if (ago != null)
              Text(
                ago,
                style:  TextStyle(
                  fontSize: 11.5,
                  color: VTheme.textSec(context),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _short(String text) {
    const max = 60;
    return text.length <= max ? text : '${text.substring(0, max)}…';
  }

  Widget _empty() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.16),
         Icon(
          Icons.notifications_outlined,
          size: 56,
          color: VTheme.textSec(context),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: Text(
            s.boardNoActivity,
            textAlign: TextAlign.center,
            style:  TextStyle(
              fontSize: 14,
              color: VTheme.textSec(context),
            ),
          ),
        ),
      ],
    );
  }
}
