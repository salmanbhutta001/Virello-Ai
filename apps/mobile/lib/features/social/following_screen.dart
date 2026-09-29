import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../main.dart';
import '../../services/api_client.dart';
import 'creator_profile_screen.dart';
import 'time_ago.dart';

/// Board screen 13: Following — pixel-faithful.
///
/// Header: back arrow + "Following" + pink person-add action.
/// Tabs: Creators (pink pill) / Topics (dark pill), full-width.
/// Creator rows: flat with dividers (no cards), avatar, name, handle,
/// pink "Following" pill button. Real data only.
class FollowingScreen extends StatefulWidget {
  const FollowingScreen({super.key});
  @override
  State<FollowingScreen> createState() => _FollowingScreenState();
}

class _FollowingScreenState extends State<FollowingScreen> {
  int _tab = 0;
  late Future<List<Map<String, dynamic>>> _creatorsFuture;
  Future<List<String>>? _topicsFuture;
  final Set<String> _busy = {};

  AppStrings get s => AppStrings(appState.localeCode);

  @override
  void initState() {
    super.initState();
    _creatorsFuture = apiClient.getFollowing();
  }

  Future<List<String>> _loadTopics() async {
    try {
      final topics = await apiClient.getInterests();
      return topics.toList()..sort();
    } catch (_) {
      return [];
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _creatorsFuture = apiClient.getFollowing();
      if (_tab == 1) _topicsFuture = _loadTopics();
    });
    try {
      await _creatorsFuture;
    } catch (_) {}
  }

  Future<void> _unfollow(String handle) async {
    if (_busy.contains(handle)) return;
    setState(() => _busy.add(handle));
    try {
      await apiClient.unfollowCreator(handle);
      if (!mounted) return;
      setState(() => _creatorsFuture = apiClient.getFollowing());
    } on AuthException {
      if (!mounted) return;
      handleAuthFailure(s.sessionExpired);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.analyzeFailed)));
    } finally {
      if (mounted) setState(() => _busy.remove(handle));
    }
  }

  Future<void> _removeTopic(String topic, List<String> current) async {
    try {
      final updated = current.where((t) => t != topic).toSet();
      final saved = await apiClient.setInterests(updated);
      if (!mounted) return;
      final list = saved.toList()..sort();
      setState(() => _topicsFuture = Future.value(list));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.analyzeFailed)));
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
                child: _tab == 0 ? _creatorsTab() : _topicsTab(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Board header: back arrow + "Following" + pink person-add action.
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
            s.boardFollowing,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.person_add_alt_rounded,
                color: VirelloColors.pink),
            tooltip: s.followCreatorTitle,
            onPressed: _showFollowSheet,
          ),
        ],
      ),
    );
  }

  /// Board tabs: two equal pills, pink filled when active.
  Widget _tabs() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          Expanded(child: _tabPill(s.boardCreators, 0)),
          const SizedBox(width: 10),
          Expanded(child: _tabPill(s.boardTopics, 1)),
        ],
      ),
    );
  }

  Widget _tabPill(String label, int index) {
    final active = _tab == index;
    return GestureDetector(
      onTap: () => setState(() {
        _tab = index;
        if (index == 1 && _topicsFuture == null) {
          _topicsFuture = _loadTopics();
        }
      }),
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? VirelloColors.pink : VirelloColors.boardField,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: active ? Colors.white : VirelloColors.boardTextSec,
          ),
        ),
      ),
    );
  }

  Widget _creatorsTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _creatorsFuture,
      builder: (c, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return _empty(Icons.wifi_off_outlined, s.analyzeFailed);
        }
        final list = snap.data ?? [];
        if (list.isEmpty) {
          return _empty(Icons.people_outline, s.boardNoFollowing);
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: list.length,
          separatorBuilder: (_, __) => const Divider(
            color: VirelloColors.boardBorder,
            height: 1,
          ),
          itemBuilder: (_, i) => _creatorRow(list[i]),
        );
      },
    );
  }

  /// Board creator row: flat, avatar + name/handle + pink Following pill.
  Widget _creatorRow(Map<String, dynamic> f) {
    final handle = '${f['creator_handle'] ?? ''}';
    final rawName = '${f['creator_name'] ?? ''}';
    final name = rawName.isNotEmpty ? rawName : handle;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final busy = _busy.contains(handle);
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => CreatorProfileScreen(follow: f)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: VirelloColors.brandGradient,
              ),
              child: Text(
                initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 19,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '@$handle',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: VirelloColors.boardTextSec,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 34,
              child: FilledButton(
                onPressed: busy ? null : () => _unfollow(handle),
                style: FilledButton.styleFrom(
                  backgroundColor: VirelloColors.pink,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(17),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(s.boardFollowingBtn),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topicsTab() {
    final fut = _topicsFuture ??= _loadTopics();
    return FutureBuilder<List<String>>(
      future: fut,
      builder: (c, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final topics = snap.data ?? [];
        if (topics.isEmpty) {
          return _empty(Icons.interests_outlined, s.boardNoTopics);
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: topics.length,
          separatorBuilder: (_, __) => const Divider(
            color: VirelloColors.boardBorder,
            height: 1,
          ),
          itemBuilder: (_, i) => _topicRow(topics[i], topics),
        );
      },
    );
  }

  Widget _topicRow(String topic, List<String> all) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: VirelloColors.pink.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.tag_rounded,
              color: VirelloColors.pink,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              topic,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
          TextButton(
            onPressed: () => _removeTopic(topic, all),
            child: Text(
              s.boardUnfollow,
              style: const TextStyle(color: VirelloColors.danger),
            ),
          ),
        ],
      ),
    );
  }

  /// Follow-a-creator sheet (same as before — real API).
  void _showFollowSheet() {
    final handleCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    var saving = false;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: VirelloColors.boardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              24 + MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.followCreatorTitle,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: handleCtrl,
                  decoration: InputDecoration(
                    labelText: s.creatorHandleLabel,
                    prefixText: '@',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: s.creatorNameLabel,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    onPressed: saving
                        ? null
                        : () async {
                            final handle = handleCtrl.text
                                .trim()
                                .replaceFirst(RegExp(r'^@'), '');
                            if (handle.isEmpty) return;
                            final messenger = ScaffoldMessenger.of(context);
                            final sheetNav = Navigator.of(sheetCtx);
                            setSheet(() => saving = true);
                            try {
                              await apiClient.followCreator(
                                handle,
                                nameCtrl.text.trim(),
                              );
                              if (!mounted) return;
                              sheetNav.pop();
                              setState(() => _creatorsFuture =
                                  apiClient.getFollowing());
                            } on AuthException {
                              if (!mounted) return;
                              sheetNav.pop();
                              handleAuthFailure(s.sessionExpired);
                            } catch (_) {
                              if (!mounted) return;
                              setSheet(() => saving = false);
                              messenger.showSnackBar(
                                SnackBar(content: Text(s.growFailed)),
                              );
                            }
                          },
                    style: FilledButton.styleFrom(
                      backgroundColor: VirelloColors.pink,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(s.followBtn),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).whenComplete(() {
      handleCtrl.dispose();
      nameCtrl.dispose();
    });
  }

  Widget _empty(IconData icon, String message) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.16),
        Icon(icon, size: 56, color: VirelloColors.boardTextSec),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: Text(
            message,
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
