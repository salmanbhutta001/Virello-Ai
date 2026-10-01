import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/virello_ui.dart';
import '../../main.dart';
import '../social/time_ago.dart';

/// Board 19 — Notifications.
///
/// "Notifications" header, filter pills (All / Unread), rows with a pink
/// icon circle, title, body and time-ago. Real data only:
/// GET /api/v1/users/notifications (admin broadcasts visible to this user).
/// "Unread" is session-local: items you haven't opened yet this session —
/// the backend has no read/unread state, so nothing is faked as server-side.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  int _filter = 0; // 0 = all, 1 = unread
  List<Map<String, dynamic>> _items = [];
  final Set<String> _read = {};
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
      final r = await apiClient.notifications();
      if (!mounted) return;
      setState(() {
        _items = (r['notifications'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _idOf(Map<String, dynamic> n) =>
      (n['id'] ?? '${n['title']}-${n['created_at']}').toString();

  List<Map<String, dynamic>> get _visible {
    if (_filter == 1) {
      return _items.where((n) => !_read.contains(_idOf(n))).toList();
    }
    return _items;
  }

  void _open(Map<String, dynamic> n) {
    final s = AppStrings(appState.localeCode);
    setState(() => _read.add(_idOf(n)));
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: VTheme.card(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('${n['title'] ?? ''}',
            style: const TextStyle(fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${n['body'] ?? ''}'),
            const SizedBox(height: 12),
            Text(
              boardTimeAgo(n['created_at']?.toString(), s) ?? '',
              style: const TextStyle(fontSize: 12, color: VirelloColors.muted),
            ),
            if (n['fallback_used'] == true) ...[
              const SizedBox(height: 8),
              Text('⚠ ${s.langFallbackNote}',
                  style: const TextStyle(
                      fontSize: 12, color: VirelloColors.amber)),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(s.cancelBtn),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings(appState.localeCode);
    final rows = _visible;
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(s.notifications,
            style: const TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: VPillTabs(
                tabs: [s.p11TabAll, s.p11FilterUnread],
                selected: _filter,
                onTap: (i) => setState(() => _filter = i),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: VirelloColors.pink))
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 72,
                                  height: 72,
                                  decoration: BoxDecoration(
                                    color: VirelloColors.pink
                                        .withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                      Icons
                                          .notifications_off_outlined,
                                      size: 32,
                                      color: VirelloColors.pink),
                                ),
                                const SizedBox(height: 16),
                                Text(s.growFailed,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: VTheme.text(context))),
                                const SizedBox(height: 16),
                                VPinkButton(
                                    label: s.retry,
                                    onPressed: () => _load()),
                              ],
                            ),
                          ),
                        )
                      : rows.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 88,
                                      height: 88,
                                      decoration: BoxDecoration(
                                        color: VirelloColors.pink
                                            .withValues(alpha: 0.12),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                          Icons.notifications_outlined,
                                          size: 40,
                                          color: VirelloColors.pink),
                                    ),
                                    const SizedBox(height: 20),
                                    Text(
                                      _filter == 1
                                          ? s.p11NoUnread
                                          : s.noNotifications,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w800,
                                          color: VTheme.text(context)),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      s.noNotificationsHint,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          height: 1.5,
                                          color: VirelloColors.muted),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _load,
                              child: ListView.separated(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 4, 16, 24),
                                itemCount: rows.length,
                                separatorBuilder: (_, __) =>  Divider(
                                    height: 1,
                                    color: VTheme.divider(context)),
                                itemBuilder: (_, i) {
                                  final n = rows[i];
                                  final unread = !_read.contains(_idOf(n));
                                  final ago = boardTimeAgo(
                                      n['created_at']?.toString(), s);
                                  return ListTile(
                                    contentPadding:
                                        const EdgeInsets.symmetric(vertical: 8),
                                    leading: Container(
                                      width: 46,
                                      height: 46,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          colors: [
                                            VirelloColors.pink,
                                            VirelloColors.pinkDeep
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                      ),
                                      child:  Icon(
                                          Icons.notifications_outlined,
                                          color: VTheme.onBrand(context),
                                          size: 22),
                                    ),
                                    title: Text(
                                      '${n['title'] ?? ''}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontWeight: unread
                                            ? FontWeight.w800
                                            : FontWeight.w600,
                                        fontSize: 15,
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 2),
                                        Text(
                                          '${n['body'] ?? ''}',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontSize: 13,
                                              color: VirelloColors.muted),
                                        ),
                                        if (ago != null) ...[
                                          const SizedBox(height: 4),
                                          Text(ago,
                                              style: const TextStyle(
                                                  fontSize: 11,
                                                  color: VirelloColors.muted)),
                                        ],
                                      ],
                                    ),
                                    trailing: unread
                                        ? Container(
                                            width: 10,
                                            height: 10,
                                            decoration: const BoxDecoration(
                                              color: VirelloColors.pink,
                                              shape: BoxShape.circle,
                                            ),
                                          )
                                        : null,
                                    onTap: () => _open(n),
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
}
