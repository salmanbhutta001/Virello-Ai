import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/virello_ui.dart';
import '../../main.dart';
import '../collab/collab_api.dart';
import '../social/time_ago.dart';

/// Board 20 — Messages.
///
/// There is no chat/messaging backend, so each tab shows the closest REAL
/// data, styled as conversation rows (avatar, name, preview, time):
/// - Creators: incoming collab requests (GET /api/v1/collab/inbox).
/// - Customers: genuine product leads (GET /api/v1/commerce/my/leads).
/// - All: both merged, newest first.
/// No fake conversations, no fake names. Tapping a row opens the real
/// request/lead detail (bottom sheet with Accept/Decline for collab).
class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});
  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _ChatRow {
  final String kind; // 'collab' | 'lead'
  final String name;
  final String preview;
  final DateTime? time;
  final Map<String, dynamic> raw;
  _ChatRow({
    required this.kind,
    required this.name,
    required this.preview,
    required this.time,
    required this.raw,
  });
}

class _MessagesScreenState extends State<MessagesScreen> {
  int _tab = 0; // 0 all, 1 creators, 2 customers
  List<_ChatRow> _collab = [];
  List<_ChatRow> _leads = [];
  bool _loading = true;
  String? _error;
  bool _deciding = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  DateTime? _parseTime(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    try {
      return DateTime.parse(iso).toLocal();
    } catch (_) {
      return null;
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait<Map<String, dynamic>>([
        CollabApi.inbox().catchError((_) => <String, dynamic>{'requests': []}),
        apiClient.myLeads().catchError((_) => <String, dynamic>{'leads': []}),
      ]);
      final inbox = results[0];
      final leadsRes = results[1];
      final collab = <_ChatRow>[];
      for (final r in (inbox['requests'] as List? ?? [])) {
        final m = Map<String, dynamic>.from(r as Map);
        final name = (m['owner_name'] ?? '').toString();
        if (name.isEmpty) continue;
        collab.add(_ChatRow(
          kind: 'collab',
          name: name,
          preview: (m['message'] ?? '').toString().isEmpty
              ? (m['post_url'] ?? '').toString()
              : (m['message'] ?? '').toString(),
          time: _parseTime(m['created_at']?.toString()),
          raw: m,
        ));
      }
      final leads = <_ChatRow>[];
      for (final l in (leadsRes['leads'] as List? ?? [])) {
        final m = Map<String, dynamic>.from(l as Map);
        final title = (m['product_title'] ?? '').toString();
        if (title.isEmpty) continue;
        leads.add(_ChatRow(
          kind: 'lead',
          name: title,
          preview: '${m['source'] ?? 'shop'} · ${m['status'] ?? 'new'}',
          time: _parseTime(m['created_at']?.toString()),
          raw: m,
        ));
      }
      collab.sort((a, b) => _cmpTime(b.time, a.time));
      leads.sort((a, b) => _cmpTime(b.time, a.time));
      if (!mounted) return;
      setState(() {
        _collab = collab;
        _leads = leads;
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

  int _cmpTime(DateTime? a, DateTime? b) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    return a.compareTo(b);
  }

  List<_ChatRow> get _visible {
    if (_tab == 1) return _collab;
    if (_tab == 2) return _leads;
    final all = [..._collab, ..._leads];
    all.sort((a, b) => _cmpTime(b.time, a.time));
    return all;
  }

  String _emptyForTab(AppStrings s) {
    if (_tab == 1) return s.p11NoCreators;
    if (_tab == 2) return s.p11NoCustomers;
    return s.p11NoMessages;
  }

  Future<void> _decide(_ChatRow row, String action) async {
    final s = AppStrings(appState.localeCode);
    setState(() => _deciding = true);
    try {
      await CollabApi.decide(row.raw['request_id'].toString(), action);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.p11RequestUpdated)));
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _deciding = false);
    }
  }

  void _openRow(_ChatRow row) {
    if (row.kind == 'collab') {
      _openCollab(row);
    } else {
      _openLead(row);
    }
  }

  void _openCollab(_ChatRow row) {
    final s = AppStrings(appState.localeCode);
    final status = (row.raw['status'] ?? 'pending').toString();
    final pending = status == 'pending';
    showModalBottomSheet(
      context: context,
      backgroundColor: VTheme.card(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: VTheme.divider(context),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _Avatar(name: row.name),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(row.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 16)),
                        Text(s.p11CollabRequest,
                            style: const TextStyle(
                                fontSize: 12, color: VirelloColors.muted)),
                      ],
                    ),
                  ),
                  _StatusChip(status: status, s: s),
                ],
              ),
              const SizedBox(height: 16),
              Text(s.p11RequestFrom,
                  style: const TextStyle(
                      fontSize: 12, color: VirelloColors.muted)),
              const SizedBox(height: 4),
              if ((row.raw['message'] ?? '').toString().isNotEmpty)
                Text((row.raw['message'] ?? '').toString(),
                    style: const TextStyle(fontSize: 14)),
              if ((row.raw['post_url'] ?? '').toString().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(s.p11PostLink,
                    style: const TextStyle(
                        fontSize: 12, color: VirelloColors.muted)),
                Text((row.raw['post_url'] ?? '').toString(),
                    style: const TextStyle(
                        fontSize: 13, color: VirelloColors.pink)),
              ],
              const SizedBox(height: 8),
              Text(
                boardTimeAgo(row.raw['created_at']?.toString(), s) ?? '',
                style:
                    const TextStyle(fontSize: 12, color: VirelloColors.muted),
              ),
              if (pending) ...[
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed:
                            _deciding ? null : () => _decide(row, 'decline'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999)),
                          side: const BorderSide(
                              color: VirelloColors.danger, width: 1.2),
                        ),
                        child: Text(s.p11Decline,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: VirelloColors.danger)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: VPinkButton(
                        label: s.p11Accept,
                        onPressed:
                            _deciding ? null : () => _decide(row, 'accept'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _openLead(_ChatRow row) {
    final s = AppStrings(appState.localeCode);
    showModalBottomSheet(
      context: context,
      backgroundColor: VTheme.card(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: VTheme.divider(context),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _Avatar(name: row.name),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(row.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 16)),
                        Text(s.p11ProductLead,
                            style: const TextStyle(
                                fontSize: 12, color: VirelloColors.muted)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _infoRow(
                  s.p11LeadSource, (row.raw['source'] ?? 'shop').toString()),
              _infoRow(
                  s.p11LeadStatus, (row.raw['status'] ?? 'new').toString()),
              _infoRow(s.p11LeadProduct,
                  (row.raw['product_title'] ?? '').toString()),
              const SizedBox(height: 8),
              Text(
                boardTimeAgo(row.raw['created_at']?.toString(), s) ?? '',
                style:
                    const TextStyle(fontSize: 12, color: VirelloColors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            SizedBox(
              width: 90,
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 12, color: VirelloColors.muted)),
            ),
            Expanded(
              child: Text(value,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final s = AppStrings(appState.localeCode);
    final rows = _visible;
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(s.p11Messages,
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
                tabs: [s.p11TabAll, s.p11TabCreators, s.p11TabCustomers],
                selected: _tab,
                onTap: (i) => setState(() => _tab = i),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(s.p11RecentChats,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: VirelloColors.muted)),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(_error!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: VirelloColors.muted)),
                          ),
                        )
                      : rows.isEmpty
                          ? _EmptyState(
                              message: _emptyForTab(s), sub: s.p11NoMessagesSub)
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
                                  final r = rows[i];
                                  final ago = boardTimeAgo(
                                      r.raw['created_at']?.toString(), s);
                                  return ListTile(
                                    contentPadding:
                                        const EdgeInsets.symmetric(vertical: 6),
                                    leading: _Avatar(name: r.name),
                                    title: Text(r.name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15)),
                                    subtitle: Text(
                                      r.preview.isEmpty ? '—' : r.preview,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          color: VirelloColors.muted),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (ago != null)
                                          Text(ago,
                                              style: const TextStyle(
                                                  fontSize: 11,
                                                  color: VirelloColors.muted)),
                                        const SizedBox(width: 4),
                                        const Icon(Icons.chevron_right,
                                            size: 18,
                                            color: VirelloColors.muted),
                                      ],
                                    ),
                                    onTap: () => _openRow(r),
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

class _Avatar extends StatelessWidget {
  final String name;
  const _Avatar({required this.name});
  @override
  Widget build(BuildContext context) {
    final ch = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return Container(
      width: 46,
      height: 46,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [VirelloColors.pink, VirelloColors.pinkDeep],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Text(ch,
          style:  TextStyle(
              color: VTheme.onBrand(context), fontWeight: FontWeight.w800, fontSize: 18)),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  final AppStrings s;
  const _StatusChip({required this.status, required this.s});
  @override
  Widget build(BuildContext context) {
    final label = status == 'accepted'
        ? s.p11StatusAccepted
        : status == 'declined'
            ? s.p11StatusDeclined
            : s.p11StatusPending;
    final color = status == 'accepted'
        ? Colors.green
        : status == 'declined'
            ? VirelloColors.danger
            : VirelloColors.pink;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  final String sub;
  const _EmptyState({required this.message, required this.sub});
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 48),
        const Icon(Icons.chat_bubble_outline,
            size: 56, color: VirelloColors.muted),
        const SizedBox(height: 16),
        Text(message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(sub,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: VirelloColors.muted)),
      ],
    );
  }
}
