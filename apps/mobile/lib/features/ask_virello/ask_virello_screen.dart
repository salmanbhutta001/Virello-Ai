import 'package:flutter/material.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../services/api_client.dart';
import '../../main.dart';

/// Ask Virello: the unified AI agent chat (POST /api/v1/ai-core/ask).
/// One conversational entry point that routes to every Virello module.
/// Dev/heuristic output is always labeled; unbuilt modules answer honestly
/// with their target phase instead of faking functionality.
class AskVirelloScreen extends StatefulWidget {
  /// Optional text to send automatically when the screen opens
  /// (e.g. "Tell me about this product: <title>" from the Shop).
  final String? initialText;
  const AskVirelloScreen({super.key, this.initialText});
  @override
  State<AskVirelloScreen> createState() => _AskVirelloScreenState();
}

class _AskMsg {
  final bool fromUser;
  final String text;
  final String? intent;
  final bool dev;
  final bool comingSoon;
  final List<Map<String, dynamic>> actions;
  _AskMsg({
    required this.fromUser,
    required this.text,
    this.intent,
    this.dev = false,
    this.comingSoon = false,
    this.actions = const [],
  });
}

class _AskVirelloScreenState extends State<AskVirelloScreen> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _messages = <_AskMsg>[];
  String? _conversationId;
  bool _sending = false;
  bool _loadingHistory = false;

  AppStrings get s => AppStrings(appState.localeCode);

  @override
  void initState() {
    super.initState();
    _messages.add(_AskMsg(fromUser: false, text: s.askVirelloWelcome));
    // Auto-send a prefilled question (e.g. from the Shop's "Ask Virello
    // about this") after the first frame so context is available.
    final initial = widget.initialText;
    if (initial != null && initial.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _send(initial);
      });
    }
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _send(String text) async {
    final q = text.trim();
    if (q.isEmpty || _sending) return;
    setState(() {
      _messages.add(_AskMsg(fromUser: true, text: q));
      _sending = true;
    });
    _inputCtrl.clear();
    _scrollToEnd();
    try {
      final res = await apiClient.askVirello(
        q,
        conversationId: _conversationId,
        language: appState.localeCode,
      );
      if (!mounted) return;
      final reply = '${res['reply'] ?? ''}';
      final intent = res['intent'] as String?;
      final dev = res['dev'] == true;
      final comingSoon = res['module_status'] == 'coming_soon';
      final actions = (res['actions'] as List? ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      setState(() {
        _conversationId = res['conversation_id'] as String? ?? _conversationId;
        _messages.add(_AskMsg(
          fromUser: false,
          text: reply.isEmpty ? s.askFailed : reply,
          intent: intent,
          dev: dev,
          comingSoon: comingSoon,
          actions: actions,
        ));
        _sending = false;
      });
    } on AuthException {
      if (!mounted) return;
      setState(() => _sending = false);
      handleAuthFailure(s.sessionExpired);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _messages.add(_AskMsg(fromUser: false, text: s.askFailed));
        _sending = false;
      });
    }
    _scrollToEnd();
  }

  Future<void> _newChat() async {
    setState(() {
      _conversationId = null;
      _messages
        ..clear()
        ..add(_AskMsg(fromUser: false, text: s.askVirelloWelcome));
    });
  }

  Future<void> _showHistory() async {
    setState(() => _loadingHistory = true);
    try {
      final list = await apiClient.getAiConversations();
      if (!mounted) return;
      setState(() => _loadingHistory = false);
      final picked = await showModalBottomSheet<String>(
        context: context,
        builder: (_) => _HistorySheet(items: list),
      );
      if (picked != null && mounted) _openConversation(picked);
    } on AuthException {
      if (!mounted) return;
      setState(() => _loadingHistory = false);
      handleAuthFailure(s.sessionExpired);
    } catch (_) {
      if (mounted) setState(() => _loadingHistory = false);
    }
  }

  Future<void> _openConversation(String id) async {
    try {
      final convo = await apiClient.getAiConversation(id);
      if (!mounted) return;
      final msgs = (convo['messages'] as List? ?? [])
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
      setState(() {
        _conversationId = id;
        _messages
          ..clear()
          ..addAll(msgs.map((m) => _AskMsg(
                fromUser: m['role'] == 'user',
                text: '${m['content'] ?? ''}',
                intent: m['intent'] as String?,
              )));
        if (_messages.isEmpty) {
          _messages.add(_AskMsg(fromUser: false, text: s.askVirelloWelcome));
        }
      });
      _scrollToEnd();
    } catch (_) {
      // Keep the current chat on failure.
    }
  }

  void _onActionTap(Map<String, dynamic> action) {
    final label = '${action['label'] ?? ''}';
    final note = action['note'];
    final path = '${action['path'] ?? ''}';
    // Deep-link known destinations; otherwise surface the honest note.
    if (path.contains('campaigns') || path.contains('growth')) {
      requestedTab.value = 3; // Grow tab
      Navigator.of(context).pop();
    } else if (path.contains('discovery')) {
      requestedTab.value = 1; // Discover tab
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(note != null && '$note'.isNotEmpty ? '$note' : label),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: VirelloColors.brandGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child:
                  const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 8),
            Text(s.askVirello),
          ],
        ),
        actions: [
          if (_loadingHistory)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            IconButton(
              tooltip: s.newChat,
              icon: const Icon(Icons.history_outlined),
              onPressed: _showHistory,
            ),
          IconButton(
            tooltip: s.newChat,
            icon: const Icon(Icons.add_comment_outlined),
            onPressed: _newChat,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_sending ? 1 : 0),
              itemBuilder: (_, i) {
                if (i == _messages.length) return _typingBubble();
                return _bubble(_messages[i]);
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputCtrl,
                      decoration: InputDecoration(
                        hintText: s.askVirelloHint,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(22)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: _send,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : () => _send(_inputCtrl.text),
                    icon: const Icon(Icons.send_outlined),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bubble(_AskMsg m) {
    final align = m.fromUser ? Alignment.centerRight : Alignment.centerLeft;
    final bg = m.fromUser ? VirelloColors.violet : VirelloColors.chipBg;
    final fg = m.fromUser ? Colors.white : VirelloColors.ink;
    return Align(
      alignment: align,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color:
              m.comingSoon ? VirelloColors.amber.withValues(alpha: 0.15) : bg,
          borderRadius: BorderRadius.circular(18),
          border: m.comingSoon
              ? Border.all(color: VirelloColors.amber.withValues(alpha: 0.5))
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!m.fromUser && m.intent != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: VirelloColors.violet.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${s.intentEmoji(m.intent!)} ${s.intentLabel(m.intent!)}',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: VirelloColors.violet),
                  ),
                ),
              ),
            if (m.comingSoon)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.schedule_outlined,
                        size: 14, color: VirelloColors.muted),
                    const SizedBox(width: 4),
                    Text(s.comingSoonPhase,
                        style: const TextStyle(
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                            color: VirelloColors.muted)),
                  ],
                ),
              ),
            Text(m.text,
                style: TextStyle(fontSize: 14, height: 1.45, color: fg)),
            if (!m.fromUser && m.dev)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(s.devPreviewNote,
                    style: const TextStyle(
                        fontSize: 10,
                        fontStyle: FontStyle.italic,
                        color: VirelloColors.muted)),
              ),
            if (m.actions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: m.actions
                      .map((a) => ActionChip(
                            label: Text('${a['label'] ?? ''}',
                                style: const TextStyle(fontSize: 12)),
                            avatar: const Icon(Icons.bolt_outlined, size: 14),
                            onPressed: () => _onActionTap(a),
                          ))
                      .toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _typingBubble() => const Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
}

class _HistorySheet extends StatelessWidget {
  final List<dynamic> items;
  const _HistorySheet({required this.items});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: VirelloColors.divider,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 12),
          Flexible(
            child: items.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('—'),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final it = Map<String, dynamic>.from(items[i] as Map);
                      return ListTile(
                        leading: const Icon(Icons.chat_bubble_outline),
                        title: Text('${it['title'] ?? 'Chat'}',
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text('${it['updated_at'] ?? ''}',
                            style: const TextStyle(color: VirelloColors.muted)),
                        onTap: () =>
                            Navigator.of(context).pop('${it['id'] ?? ''}'),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
