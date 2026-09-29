import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/virello_ui.dart';
import '../../main.dart';
import '../../services/api_client.dart';
import 'comments_screen.dart';
import 'creator_profile_screen.dart';
import 'time_ago.dart';

/// Board screen 16: Activity.
///
/// Real activity only: the user's own comments (GET /api/v1/social/
/// comments/mine) and follows (GET /api/v1/social/following). There is
/// no Likes tab because no backend lists the user's likes — a tab with
/// an always-empty state would be dishonest UI, so it is omitted.
class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});
  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityItem {
  final String kind; // 'comment' | 'follow'
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
        return all.where((e) => e.kind == 'comment').toList();
      case 2:
        return all.where((e) => e.kind == 'follow').toList();
      default:
        return all;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(s.boardActivity)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: VPillTabs(
              tabs: [s.boardAll, s.boardComments, s.boardFollows],
              selected: _tab,
              onTap: (i) => setState(() => _tab = i),
            ),
          ),
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
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _row(items[i]),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(_ActivityItem e) {
    final isComment = e.kind == 'comment';
    final title = isComment
        ? '${e.data['author_name'] ?? ''}'
        : '${e.data['creator_name'] ?? e.data['creator_handle'] ?? ''}';
    final subtitle = isComment
        ? '${s.boardCommentedOn}: "${_short('${e.data['text'] ?? ''}')}"'
        : '${s.boardStartedFollowing} @${e.data['creator_handle'] ?? ''}';
    final initial = title.isNotEmpty ? title[0].toUpperCase() : '?';
    final ago = e.at == null
        ? null
        : boardTimeAgo(e.at!.toUtc().toIso8601String(), s);
    return VBoardCard(
      onTap: isComment
          ? null
          : () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => CreatorProfileScreen(follow: e.data),
              ),
            ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isComment
                  ? VirelloColors.pink.withValues(alpha: 0.14)
                  : null,
              gradient: isComment ? null : VirelloColors.brandGradient,
            ),
            child: isComment
                ? const Icon(
                    Icons.chat_bubble_outline,
                    color: VirelloColors.pink,
                    size: 20,
                  )
                : Text(
                    initial,
                    style: const TextStyle(
                      color: Colors.white,
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
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: VirelloColors.boardTextSec,
                  ),
                ),
                if (ago != null)
                  Text(
                    ago,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: VirelloColors.boardTextSec,
                    ),
                  ),
              ],
            ),
          ),
        ],
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
        const Icon(
          Icons.notifications_outlined,
          size: 56,
          color: VirelloColors.boardTextSec,
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: Text(
            s.boardNoActivity,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: VirelloColors.boardTextSec,
            ),
          ),
        ),
      ],
    );
  }
}
