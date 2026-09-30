import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../main.dart';
import '../../services/api_client.dart';
import 'time_ago.dart';

/// Board screen 15: Comments.
///
/// Real user-generated comments only, from GET /api/v1/social/comments.
/// Empty state when nobody commented yet — never fabricated. Users can
/// post and delete their own comments.
class CommentsScreen extends StatefulWidget {
  final String postUrl;
  final String postTitle;
  const CommentsScreen({
    super.key,
    required this.postUrl,
    required this.postTitle,
  });

  @override
  State<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen> {
  late Future<List<Map<String, dynamic>>> _future;
  final _ctrl = TextEditingController();
  bool _posting = false;

  AppStrings get s => AppStrings(appState.localeCode);

  @override
  void initState() {
    super.initState();
    _future = apiClient.getComments(widget.postUrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _future = apiClient.getComments(widget.postUrl));
    try {
      await _future;
    } catch (_) {}
  }

  Future<void> _post() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _posting) return;
    setState(() => _posting = true);
    try {
      await apiClient.postComment(widget.postUrl, text);
      _ctrl.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.boardCommentPosted)));
      await _refresh();
    } on AuthException {
      if (!mounted) return;
      handleAuthFailure(s.sessionExpired);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.analyzeFailed)));
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  Future<void> _delete(Map<String, dynamic> c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(s.boardComments),
        content: Text(s.boardDeleteCommentConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(d).pop(false),
            child: Text(s.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(d).pop(true),
            child: Text(
              s.boardDelete,
              style: const TextStyle(color: VirelloColors.danger),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await apiClient.deleteComment('${c['id']}');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.boardCommentDeleted)));
      await _refresh();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.analyzeFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(s.boardComments)),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _future,
                builder: (c, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    return _empty(Icons.wifi_off_outlined, s.analyzeFailed);
                  }
                  final list = snap.data ?? [];
                  if (list.isEmpty) {
                    return _empty(Icons.chat_bubble_outline, s.boardNoComments);
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (_, i) => _row(list[i]),
                  );
                },
              ),
            ),
          ),
          _composer(),
        ],
      ),
    );
  }

  /// Board 15 comment card: dark rounded card, avatar + name/time + text.
  Widget _row(Map<String, dynamic> c) {
    final author = '${c['author_name'] ?? '?'}';
    final initial = author.isNotEmpty ? author[0].toUpperCase() : '?';
    final ago = boardTimeAgo('${c['created_at'] ?? ''}', s);
    final mine = c['mine'] == true;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: VTheme.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: VTheme.divider(context)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: VirelloColors.brandGradient,
            ),
            child: Text(
              initial,
              style:  TextStyle(
                color: VTheme.onBrand(context),
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                        ),
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
                    if (mine)
                      IconButton(
                        icon:  Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: VTheme.textSec(context),
                        ),
                        tooltip: s.delete,
                        onPressed: () => _delete(c),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${c['text'] ?? ''}',
                  style: const TextStyle(fontSize: 14, height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _composer() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        decoration:  BoxDecoration(
          border: Border(top: BorderSide(color: VTheme.divider(context))),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _post(),
                decoration: InputDecoration(
                  hintText: s.boardWriteComment,
                  filled: true,
                  fillColor: VTheme.chip(context),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: VirelloColors.brandGradient,
              ),
              child: IconButton(
                icon: _posting
                    ?  SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: VTheme.onBrand(context),
                        ),
                      )
                    :  Icon(
                        Icons.send_rounded,
                        color: VTheme.text(context),
                        size: 20,
                      ),
                onPressed: _post,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _empty(IconData icon, String message) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.18),
        Icon(icon, size: 56, color: VTheme.textSec(context)),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: Text(
            message,
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
