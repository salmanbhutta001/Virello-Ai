import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/virello_ui.dart';
import '../../main.dart';
import 'collab_api.dart';
import 'collab_strings.dart';

/// Creator Collab Match — free organic growth strategy #4.
///
/// Three tabs: Find Creators (topic filter + ranked matches + request),
/// My Requests (outbox, mark shared), Inbox (creator view: accept/decline).
/// Audience sizes are always shown with the "self-declared" label.
class CollabScreen extends StatefulWidget {
  const CollabScreen({super.key});

  @override
  State<CollabScreen> createState() => _CollabScreenState();
}

class _CollabScreenState extends State<CollabScreen> {
  int _tab = 0;
  CollabStrings get s => CollabStrings(appState.localeCode);

  // --- find tab state
  List<Map<String, String>> _topics = [];
  final Set<String> _picked = {};
  List<Map<String, dynamic>> _matches = [];
  bool _matching = false;
  String? _matchNote;

  // --- profile state
  Map<String, dynamic>? _profile;
  bool _profileLoading = true;

  // --- requests state
  List<Map<String, dynamic>> _mine = [];
  List<Map<String, dynamic>> _inbox = [];
  bool _reqLoading = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadTopics();
  }

  Future<void> _loadProfile() async {
    try {
      final j = await CollabApi.getMyProfile();
      if (!mounted) return;
      setState(() {
        _profile = (j['profile'] as Map?)?.cast<String, dynamic>();
        _profileLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _profileLoading = false);
    }
  }

  Future<void> _loadTopics() async {
    try {
      final j = await CollabApi.topics();
      final list = (j['topics'] as List?) ?? const [];
      if (!mounted) return;
      setState(() {
        _topics = [
          for (final t in list)
            {
              'slug': (t['slug'] ?? '').toString(),
              'name': (t['name_en'] ?? t['slug'] ?? '').toString(),
            }
        ];
      });
    } catch (_) {}
  }

  Future<void> _findMatches() async {
    if (_picked.isEmpty) return;
    setState(() {
      _matching = true;
      _matchNote = null;
    });
    try {
      final j = await CollabApi.match({'topics': _picked.toList()});
      if (!mounted) return;
      setState(() {
        _matches = [
          for (final m in (j['matches'] as List? ?? const []))
            (m as Map).cast<String, dynamic>()
        ];
        _matching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _matching = false;
        _matchNote = e.toString();
      });
    }
  }

  Future<void> _loadRequests() async {
    setState(() => _reqLoading = true);
    try {
      final results = await Future.wait([CollabApi.outbox(), CollabApi.inbox()]);
      if (!mounted) return;
      setState(() {
        _mine = [
          for (final m in (results[0]['requests'] as List? ?? const []))
            (m as Map).cast<String, dynamic>()
        ];
        _inbox = [
          for (final m in (results[1]['requests'] as List? ?? const []))
            (m as Map).cast<String, dynamic>()
        ];
        _reqLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _reqLoading = false);
    }
  }

  void _onTab(int i) {
    setState(() => _tab = i);
    if (i > 0) _loadRequests();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(s.title,
            style: const TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(s.subtitle,
                  style: const TextStyle(
                      color: VirelloColors.muted, fontSize: 13)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: VPillTabs(
                tabs: [s.tabFind, s.tabMine, s.tabInbox],
                selected: _tab,
                onTap: _onTab,
              ),
            ),
            Expanded(
              child: _tab == 0
                  ? _buildFind()
                  : _tab == 1
                      ? _buildRequests(mine: true)
                      : _buildRequests(mine: false),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------ find tab

  Widget _buildFind() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      children: [
        _buildCreatorCard(),
        const SizedBox(height: 16),
        VSectionHeader(title: s.pickTopics),
        const SizedBox(height: 10),
        if (_topics.isEmpty)
          Text(s.loading,
              style: const TextStyle(color: VirelloColors.muted))
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in _topics)
                ChoiceChip(
                  label: Text(t['name'] ?? ''),
                  selected: _picked.contains(t['slug']),
                  onSelected: (sel) {
                    final slug = t['slug'] ?? '';
                    setState(() {
                      if (sel) {
                        _picked.add(slug);
                      } else {
                        _picked.remove(slug);
                      }
                    });
                  },
                  selectedColor: VirelloColors.violet,
                  labelStyle: TextStyle(
                    color: _picked.contains(t['slug'])
                        ? Colors.white
                        : VirelloColors.mutedDark,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                  backgroundColor: VirelloColors.chipBg,
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18)),
                ),
            ],
          ),
        const SizedBox(height: 16),
        VGradientButton(
          label: s.findMatches,
          onPressed: _picked.isEmpty || _matching ? null : _findMatches,
          icon: Icons.search,
        ),
        if (_matchNote != null) ...[
          const SizedBox(height: 8),
          Text(_matchNote!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
        ],
        if (_matching) ...[
          const SizedBox(height: 24),
          const Center(child: CircularProgressIndicator()),
        ],
        if (!_matching && _matches.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('${s.topicFit}: ${s.topicFitNote}',
              style: const TextStyle(
                  color: VirelloColors.muted, fontSize: 12)),
          const SizedBox(height: 10),
          for (final m in _matches) _buildMatchCard(m),
        ],
        if (!_matching && _matches.isEmpty && _matchNote == null) ...[
          const SizedBox(height: 16),
          Text(s.noMatches,
              style: const TextStyle(color: VirelloColors.muted, fontSize: 13)),
        ],
      ],
    );
  }

  Widget _buildCreatorCard() {
    if (_profileLoading) {
      return const VCard(child: VShimmerBox(height: 72));
    }
    final p = _profile;
    final optedIn = p != null && (p['is_opted_in'] == true);
    return VCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.handshake_outlined,
                  color: VirelloColors.violet, size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  optedIn
                      ? '${s.myCreatorProfile}: ${p['display_name'] ?? ''}'
                      : s.becomeCreator,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(s.becomeCreatorDesc,
              style:
                  const TextStyle(color: VirelloColors.muted, fontSize: 12)),
          const SizedBox(height: 10),
          VGradientButton(
            label: optedIn ? s.myCreatorProfile : s.becomeCreator,
            onPressed: () => _openProfileSheet(p),
            height: 46,
          ),
        ],
      ),
    );
  }

  Widget _buildMatchCard(Map<String, dynamic> m) {
    final fit = ((m['topic_fit'] as num?) ?? 0).toDouble();
    final audience = m['audience_size'];
    final matched = (m['matched_topics'] as List?)?.cast<String>() ?? [];
    final platforms = (m['platforms'] as List?)?.cast<String>() ?? [];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: VCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text((m['display_name'] ?? '').toString(),
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 16)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: VirelloColors.violet.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    '${s.topicFit}: ${(fit * 100).round()}%',
                    style: const TextStyle(
                        color: VirelloColors.violet,
                        fontWeight: FontWeight.w800,
                        fontSize: 12),
                  ),
                ),
              ],
            ),
            if ((m['bio'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text((m['bio'] ?? '').toString(),
                  style: const TextStyle(
                      color: VirelloColors.muted, fontSize: 13)),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.people_outline,
                    size: 16, color: VirelloColors.muted),
                const SizedBox(width: 4),
                Text(
                  audience == null
                      ? '—'
                      : '$audience (${s.selfDeclared})',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
                if (platforms.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(platforms.join(' · '),
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: VirelloColors.muted, fontSize: 12)),
                  ),
                ],
              ],
            ),
            if (matched.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('${s.matchedOn}: ${matched.join(', ')}',
                  style: const TextStyle(
                      color: VirelloColors.muted, fontSize: 12)),
            ],
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _openRequestSheet(m),
                icon: const Icon(Icons.send_outlined, size: 16),
                label: Text(s.sendRequest),
                style: OutlinedButton.styleFrom(
                  foregroundColor: VirelloColors.violet,
                  side: const BorderSide(color: VirelloColors.violet),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------- requests tabs

  Widget _buildRequests({required bool mine}) {
    final list = mine ? _mine : _inbox;
    if (_reqLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(mine ? s.noRequests : s.noInbox,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(color: VirelloColors.muted, fontSize: 14)),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      itemCount: list.length,
      itemBuilder: (ctx, i) =>
          _buildRequestCard(list[i], mine: mine),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> r, {required bool mine}) {
    final status = (r['status'] ?? 'pending').toString();
    final name = mine
        ? (r['creator_name'] ?? '').toString()
        : (r['owner_name'] ?? '').toString();
    final canDecide = !mine && status == 'pending';
    final canShare = mine && status == 'accepted';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: VCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 15)),
                ),
                _statusChip(status),
              ],
            ),
            const SizedBox(height: 4),
            Text((r['post_url'] ?? '').toString(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: VirelloColors.violet, fontSize: 12)),
            if ((r['message'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text((r['message'] ?? '').toString(),
                  style: const TextStyle(
                      color: VirelloColors.mutedDark, fontSize: 13)),
            ],
            if (canDecide) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: VGradientButton(
                      label: s.accept,
                      onPressed: () => _decide(
                          (r['request_id'] ?? '').toString(), 'accept'),
                      height: 44,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _decide(
                          (r['request_id'] ?? '').toString(), 'decline'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side:
                            const BorderSide(color: Colors.redAccent),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        minimumSize: const Size(0, 44),
                      ),
                      child: Text(s.decline),
                    ),
                  ),
                ],
              ),
            ],
            if (canShare) ...[
              const SizedBox(height: 6),
              Text(s.markSharedHint,
                  style: const TextStyle(
                      color: VirelloColors.muted, fontSize: 12)),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _decide(
                      (r['request_id'] ?? '').toString(), 'mark_shared'),
                  icon: const Icon(Icons.check_circle_outline, size: 16),
                  label: Text(s.markShared),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: VirelloColors.violet,
                    side: const BorderSide(color: VirelloColors.violet),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String status) {
    final Color color;
    switch (status) {
      case 'accepted':
        color = Colors.green;
        break;
      case 'declined':
        color = Colors.redAccent;
        break;
      case 'shared':
        color = VirelloColors.violet;
        break;
      default:
        color = Colors.orange;
    }
    final label = switch (status) {
      'accepted' => s.statusAccepted(status),
      'declined' => s.statusDeclined(status),
      'shared' => s.statusShared(status),
      _ => s.statusPending(status),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontWeight: FontWeight.w800, fontSize: 12)),
    );
  }

  Future<void> _decide(String id, String action) async {
    try {
      await CollabApi.decide(id, action);
      _snack(action == 'mark_shared'
          ? s.sharedDone
          : action == 'accept'
              ? s.statusAccepted('accepted')
              : s.statusDeclined('declined'));
      await _loadRequests();
    } catch (e) {
      _snack('${s.errorGeneric}: $e');
    }
  }

  // ------------------------------------------------------------ sheets

  Future<void> _openRequestSheet(Map<String, dynamic> m) async {
    final urlCtrl = TextEditingController();
    final msgCtrl = TextEditingController();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('${s.sendRequest} — ${m['display_name']}',
                style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 14),
            TextField(
              controller: urlCtrl,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: s.yourPostLink,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: msgCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: s.messageOptional,
                hintText: s.messageHint,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 16),
            VGradientButton(
              label: s.sendRequest,
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
          ],
        ),
      ),
    );
    if (ok != true || urlCtrl.text.trim().isEmpty) return;
    try {
      await CollabApi.sendRequest({
        'creator_id': m['creator_id'],
        'post_url': urlCtrl.text.trim(),
        'message': msgCtrl.text.trim(),
      });
      _snack(s.requestSent);
      _onTab(1);
    } catch (e) {
      _snack('${s.errorGeneric}: $e');
    }
  }

  Future<void> _openProfileSheet(Map<String, dynamic>? p) async {
    final nameCtrl =
        TextEditingController(text: (p?['display_name'] ?? '').toString());
    final topicsCtrl = TextEditingController(
        text: ((p?['topics'] as List?) ?? const []).join(', '));
    final bioCtrl = TextEditingController(text: (p?['bio'] ?? '').toString());
    final audCtrl = TextEditingController(
        text: p?['audience_size']?.toString() ?? '');
    final Set<String> plats =
        ((p?['platforms'] as List?) ?? const []).map((e) => e.toString()).toSet();
    bool optedIn = (p?['is_opted_in'] ?? true) == true;
    const allPlatforms = ['instagram', 'tiktok', 'youtube', 'x', 'facebook'];

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(s.becomeCreator,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 14),
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: s.displayName,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: topicsCtrl,
                  decoration: InputDecoration(
                    labelText: s.topicsHint,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 12),
                Text(s.platforms,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final pl in allPlatforms)
                      FilterChip(
                        label: Text(pl),
                        selected: plats.contains(pl),
                        onSelected: (sel) => setSheet(() {
                          if (sel) {
                            plats.add(pl);
                          } else {
                            plats.remove(pl);
                          }
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: audCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: s.audienceSize,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: bioCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: s.bio,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(s.optIn,
                      style: const TextStyle(fontSize: 14)),
                  value: optedIn,
                  activeThumbColor: VirelloColors.violet,
                  onChanged: (v) => setSheet(() => optedIn = v),
                ),
                const SizedBox(height: 8),
                VGradientButton(
                  label: s.saveProfile,
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty) {
                      Navigator.of(ctx).pop(false);
                      return;
                    }
                    try {
                      final navigator = Navigator.of(ctx);
                      final j = await CollabApi.saveProfile({
                        'display_name': nameCtrl.text.trim(),
                        'topics': topicsCtrl.text
                            .split(',')
                            .map((e) => e.trim())
                            .where((e) => e.isNotEmpty)
                            .toList(),
                        'platforms': plats.toList(),
                        'audience_size':
                            int.tryParse(audCtrl.text.trim()),
                        'bio': bioCtrl.text.trim(),
                        'is_opted_in': optedIn,
                      });
                      if (!mounted) return;
                      setState(() {
                        _profile = (j['profile'] as Map)
                            .cast<String, dynamic>();
                      });
                      navigator.pop(true);
                    } catch (e) {
                      _snack('${s.errorGeneric}: $e');
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (saved == true) _snack(s.profileSaved);
  }
}
