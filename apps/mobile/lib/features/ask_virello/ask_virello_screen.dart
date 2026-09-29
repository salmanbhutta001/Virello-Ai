import 'package:flutter/material.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/virello_ui.dart';
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
  final List<Map<String, dynamic>> products;
  _AskMsg({
    required this.fromUser,
    required this.text,
    this.intent,
    this.dev = false,
    this.comingSoon = false,
    this.actions = const [],
    this.products = const [],
  });
}

class _AskVirelloScreenState extends State<AskVirelloScreen> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _messages = <_AskMsg>[];
  String? _conversationId;
  bool _sending = false;
  bool _loadingHistory = false;
  int _tab = 0; // 0 = Chat, 1 = History (board pill tabs)
  List<dynamic> _historyItems = [];

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
      final products = (res['products'] as List? ?? [])
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
          products: products,
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

  Future<void> _loadHistory() async {
    setState(() => _loadingHistory = true);
    try {
      final list = await apiClient.getAiConversations();
      if (!mounted) return;
      setState(() {
        _historyItems = list;
        _loadingHistory = false;
      });
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
        _tab = 0; // back to the Chat tab
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
        leading: const BackButton(),
        title: Text(s.p10GrowthAI,
            style: const TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            tooltip: s.newChat,
            icon: const Icon(Icons.add_comment_outlined),
            onPressed: _newChat,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: VPillTabs(
                tabs: [s.p10Chat, s.p10History],
                selected: _tab,
                onTap: (i) {
                  setState(() => _tab = i);
                  if (i == 1) _loadHistory();
                },
              ),
            ),
          ),
          Expanded(
            child: _tab == 0 ? _chatBody() : _historyBody(),
          ),
          if (_tab == 0) _inputRow(),
        ],
      ),
    );
  }

  Widget _chatBody() {
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      itemCount: _messages.length + (_sending ? 1 : 0),
      itemBuilder: (_, i) {
        if (i == _messages.length) return _typingBubble();
        return _bubble(_messages[i]);
      },
    );
  }

  Widget _historyBody() {
    if (_loadingHistory) {
      return const Center(
          child: CircularProgressIndicator(color: VirelloColors.pink));
    }
    if (_historyItems.isEmpty) {
      return Center(
        child: Text(s.nothingHere,
            style: const TextStyle(color: VirelloColors.boardTextSec)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: _historyItems.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final it = Map<String, dynamic>.from(_historyItems[i] as Map);
        return VBoardCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          onTap: () => _openConversation('${it['id'] ?? ''}'),
          child: Row(
            children: [
              const Icon(Icons.chat_bubble_outline,
                  color: VirelloColors.pink, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${it['title'] ?? 'Chat'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, color: Colors.white)),
                    Text('${it['updated_at'] ?? ''}',
                        style: const TextStyle(
                            fontSize: 11, color: VirelloColors.boardTextSec)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right,
                  color: VirelloColors.boardTextSec),
            ],
          ),
        );
      },
    );
  }

  Widget _inputRow() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _inputCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: s.askVirelloHint,
                  hintStyle: const TextStyle(color: VirelloColors.boardTextSec),
                  filled: true,
                  fillColor: VirelloColors.boardField,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide:
                          const BorderSide(color: VirelloColors.boardBorder)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide:
                          const BorderSide(color: VirelloColors.boardBorder)),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: _send,
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              style: IconButton.styleFrom(backgroundColor: VirelloColors.pink),
              onPressed: _sending ? null : () => _send(_inputCtrl.text),
              icon: const Icon(Icons.send_outlined),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bubble(_AskMsg m) {
    final align = m.fromUser ? Alignment.centerRight : Alignment.centerLeft;
    final bg = m.fromUser ? VirelloColors.pink : VTheme.chip(context);
    final fg = m.fromUser ? Colors.white : VTheme.text(context);
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
                    color: VirelloColors.pink.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${s.intentEmoji(m.intent!)} ${s.intentLabel(m.intent!)}',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: VirelloColors.pink),
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
            if (m.products.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  children: m.products.map((p) => _productCard(p)).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Product card inside a chat bubble — rendered only when the AI
  /// response actually carries product data. Never synthesized.
  Widget _productCard(Map<String, dynamic> p) {
    final img = '${p['image_url'] ?? ''}';
    final price = '${p['price_display'] ?? ''}';
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: VirelloColors.boardField,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: VirelloColors.boardBorder),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: img.isNotEmpty
                ? Image.network(img,
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                        width: 52,
                        height: 52,
                        color: VirelloColors.boardSurface,
                        child: const Icon(Icons.shopping_bag_outlined,
                            color: VirelloColors.boardTextSec)))
                : Container(
                    width: 52,
                    height: 52,
                    color: VirelloColors.boardSurface,
                    child: const Icon(Icons.shopping_bag_outlined,
                        color: VirelloColors.boardTextSec)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${p['title'] ?? ''}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
                if (price.isNotEmpty && price != 'null')
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(price,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: VirelloColors.pink)),
                  ),
              ],
            ),
          ),
        ],
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
