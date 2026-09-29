import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../main.dart';
import '../../services/api_client.dart';

/// Board screen 17: Creator Profile — pixel-faithful.
///
/// Header: back arrow + name + share/more actions. Big avatar, name,
/// @handle, full-width pink Follow button. Tabs: Posts / Reels / Shop
/// (pink underline on active) with a 3-column grid.
///
/// Honest by design: the backend only stores handle + optional display
/// name per follow. Follower counts, post counts and bios are NOT
/// invented. Posts/Reels/Shop grids show honest empty states because no
/// per-creator post catalog exists.
class CreatorProfileScreen extends StatefulWidget {
  final Map<String, dynamic> follow;
  const CreatorProfileScreen({super.key, required this.follow});

  @override
  State<CreatorProfileScreen> createState() => _CreatorProfileScreenState();
}

class _CreatorProfileScreenState extends State<CreatorProfileScreen> {
  int _tab = 0;
  bool _following = true;
  bool _busy = false;

  AppStrings get s => AppStrings(appState.localeCode);

  String get handle => '${widget.follow['creator_handle'] ?? ''}';
  String get name {
    final n = '${widget.follow['creator_name'] ?? ''}';
    return n.isNotEmpty ? n : handle;
  }

  Future<void> _toggle() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (_following) {
        await apiClient.unfollowCreator(handle);
      } else {
        await apiClient.followCreator(handle, widget.follow['creator_name']);
      }
      if (!mounted) return;
      setState(() => _following = !_following);
    } on AuthException {
      if (!mounted) return;
      handleAuthFailure(s.sessionExpired);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.analyzeFailed)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _share() {
    Clipboard.setData(ClipboardData(text: '@$handle'));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(s.boardLinkCopied)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  _profileCard(initial),
                  const SizedBox(height: 8),
                  _tabs(),
                  const SizedBox(height: 12),
                  _grid(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Board header: back arrow + name + share/more actions.
  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: _share,
          ),
          IconButton(
            icon: const Icon(Icons.more_vert_rounded),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  /// Board profile block: big avatar, name, handle, pink Follow button.
  Widget _profileCard(String initial) {
    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          width: 84,
          height: 84,
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
              fontSize: 32,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          name,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          '@$handle',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            color: VirelloColors.boardTextSec,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: FilledButton(
            onPressed: _busy ? null : _toggle,
            style: FilledButton.styleFrom(
              backgroundColor:
                  _following ? VirelloColors.boardField : VirelloColors.pink,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(_following ? s.boardFollowingBtn : s.boardFollow),
          ),
        ),
      ],
    );
  }

  /// Board tabs: Posts / Reels / Shop with pink underline indicator.
  Widget _tabs() {
    final labels = [s.boardPosts, s.boardReels, s.boardShop];
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++)
          Expanded(child: _tabItem(labels[i], i)),
      ],
    );
  }

  Widget _tabItem(String label, int index) {
    final active = _tab == index;
    return GestureDetector(
      onTap: () => setState(() => _tab = index),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active ? VirelloColors.pink : Colors.transparent,
              width: 2.5,
            ),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
            color: active ? Colors.white : VirelloColors.boardTextSec,
          ),
        ),
      ),
    );
  }

  /// Honest empty grid: no per-creator post catalog exists on the backend.
  Widget _grid() {
    return Column(
      children: [
        const SizedBox(height: 32),
        const Icon(
          Icons.grid_on_rounded,
          size: 48,
          color: VirelloColors.boardTextSec,
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            s.boardNoCreatorPosts,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13.5,
              color: VirelloColors.boardTextSec,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}
