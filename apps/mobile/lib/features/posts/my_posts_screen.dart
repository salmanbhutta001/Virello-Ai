import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/virello_ui.dart';
import '../../services/api_client.dart';
import '../../services/posts_api.dart';
import 'post_strings.dart';

/// "My Posts" — the user's own discovery-feed posts.
///
/// Each post card carries a small three-dots menu: Edit (topics) / Delete.
/// All authorization is enforced server-side; the API returns 404 for
/// anything the caller does not own.
class MyPostsScreen extends StatefulWidget {
  const MyPostsScreen({super.key});

  @override
  State<MyPostsScreen> createState() => _MyPostsScreenState();
}

class _MyPostsScreenState extends State<MyPostsScreen> {
  List<Map<String, dynamic>> _posts = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final posts = await userPostsApi.myPosts();
      if (!mounted) return;
      setState(() {
        _posts = posts;
        _loading = false;
      });
    } on AuthException {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'auth';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'load';
        });
      }
    }
  }

  void _showPostMenu(Map<String, dynamic> post) {
    final s = AppStrings(Localizations.localeOf(context).languageCode);
    final ps = MyPostStrings(Localizations.localeOf(context).languageCode);
    final id = '${post['placement_id'] ?? ''}';
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(ps.editPost),
              onTap: () {
                Navigator.pop(ctx);
                _showEditSheet(post);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: Text(ps.deletePost,
                  style: const TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDelete(id);
              },
            ),
            ListTile(
              leading: const Icon(Icons.close),
              title: Text(s.cancel),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditSheet(Map<String, dynamic> post) {
    final ps = MyPostStrings(Localizations.localeOf(context).languageCode);
    final s = AppStrings(Localizations.localeOf(context).languageCode);
    final id = '${post['placement_id'] ?? ''}';
    final ctrl = TextEditingController(
        text: ((post['topics'] as List?) ?? []).join(', '));
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(ps.editPost,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: ps.topicsHint,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                final topics = ctrl.text
                    .split(',')
                    .map((t) => t.trim())
                    .where((t) => t.isNotEmpty)
                    .toList();
                if (topics.isEmpty || topics.length > 5) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text(ps.topicsHint)));
                  return;
                }
                Navigator.pop(ctx);
                try {
                  final updated =
                      await userPostsApi.editPostTopics(id, topics);
                  if (!mounted) return;
                  setState(() {
                    final i = _posts.indexWhere(
                        (p) => '${p['placement_id']}' == id);
                    if (i >= 0) _posts[i] = updated;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(updated['resubmitted'] == true
                          ? ps.resubmittedNote
                          : ps.postUpdated)));
                } catch (_) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(ps.saveFailed)));
                }
              },
              child: Text(s.save),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(String placementId) {
    final ps = MyPostStrings(Localizations.localeOf(context).languageCode);
    final s = AppStrings(Localizations.localeOf(context).languageCode);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ps.deletePost),
        content: Text(ps.deletePostConfirm),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(s.cancel)),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await userPostsApi.deletePost(placementId);
                if (!mounted) return;
                setState(() => _posts.removeWhere(
                    (p) => '${p['placement_id']}' == placementId));
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(ps.postDeleted)));
              } catch (_) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(s.deleteFailed)));
              }
            },
            child: Text(s.delete, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final code = Localizations.localeOf(context).languageCode;
    final s = AppStrings(code);
    final ps = MyPostStrings(code);
    return Scaffold(
      appBar: AppBar(title: Text(ps.myPosts)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error == 'auth' ? s.sessionExpired : s.growFailed),
                      const SizedBox(height: 12),
                      ElevatedButton(
                          onPressed: _load, child: Text(s.tryAgain)),
                    ],
                  ),
                )
              : _posts.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(ps.noPosts,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.grey)),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: _posts.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 8),
                        itemBuilder: (ctx, i) {
                          final p = _posts[i];
                          final topics =
                              ((p['topics'] as List?) ?? []).join(' · ');
                          return VCard(
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              title: Text('${p['campaign_title'] ?? ''}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                              subtitle: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  if (topics.isNotEmpty)
                                    Text(topics,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey)),
                                  const SizedBox(height: 4),
                                  _StatusChip(
                                      status: '${p['status'] ?? ''}'),
                                ],
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.more_vert, size: 20),
                                tooltip: ps.editPost,
                                onPressed: () => _showPostMenu(p),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final live = status == 'live';
    final rejected = status == 'rejected';
    final color = live
        ? Colors.green
        : rejected
            ? Colors.red
            : Colors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(status,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}
