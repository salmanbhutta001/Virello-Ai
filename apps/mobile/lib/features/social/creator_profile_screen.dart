import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/virello_ui.dart';
import '../../main.dart';
import '../../services/api_client.dart';
import 'time_ago.dart';

/// Board screen 17: Creator Profile.
///
/// Honest by design: the backend only stores a handle (+ optional display
/// name) per follow, so this screen shows exactly that — avatar initial,
/// name/handle, when the follow started, and a real Follow/Unfollow
/// button. Follower counts, post counts and bios are NOT invented.
class CreatorProfileScreen extends StatefulWidget {
  final Map<String, dynamic> follow;
  const CreatorProfileScreen({super.key, required this.follow});

  @override
  State<CreatorProfileScreen> createState() => _CreatorProfileScreenState();
}

class _CreatorProfileScreenState extends State<CreatorProfileScreen> {
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

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final ago = boardTimeAgo('${widget.follow['followed_at'] ?? ''}', s);
    return Scaffold(
      appBar: AppBar(title: Text('@$handle')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          VBoardCard(
            child: Column(
              children: [
                Container(
                  width: 88,
                  height: 88,
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
                      fontSize: 34,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '@$handle',
                  style: const TextStyle(
                    fontSize: 14,
                    color: VirelloColors.boardTextSec,
                  ),
                ),
                if (ago != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${s.boardFollowedSince} $ago',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: VirelloColors.boardTextSec,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: _busy ? null : _toggle,
                    style: FilledButton.styleFrom(
                      backgroundColor: _following
                          ? VirelloColors.boardField
                          : VirelloColors.pink,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
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
                        : Text(
                            _following ? s.boardFollowingBtn : s.boardFollow,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
