import 'package:flutter/material.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../services/api_client.dart';
import '../../main.dart';
import 'billing_screen.dart';

/// Live Chat Support — fast, live-feeling support chat backed by Virello's
/// self-contained support brain (POST /api/v1/support/chat).
/// No AI branding anywhere (silent-intelligence rule).
class SupportChatScreen extends StatefulWidget {
  const SupportChatScreen({super.key});
  @override
  State<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _ChatMsg {
  final bool fromUser;
  final String text;
  final DateTime time;
  final List<Map<String, dynamic>> actions;
  _ChatMsg(this.fromUser, this.text,
      {DateTime? time, List<Map<String, dynamic>>? actions})
      : time = time ?? DateTime.now(),
        actions = actions ?? const [];
}

class _SupportChatScreenState extends State<SupportChatScreen> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _messages = <_ChatMsg>[];
  List<String> _suggestions = [];
  bool _sending = false;

  AppStrings get s => AppStrings(appState.localeCode);

  @override
  void initState() {
    super.initState();
    _messages.add(_ChatMsg(false, s.supportWelcome));
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  String _stamp(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _send(String text) async {
    final q = text.trim();
    if (q.isEmpty || _sending) return;
    setState(() {
      _messages.add(_ChatMsg(true, q));
      _suggestions = [];
      _sending = true;
    });
    _inputCtrl.clear();
    _scrollToEnd();
    try {
      final history = _messages
          .take(6)
          .map((m) => {
                'role': m.fromUser ? 'user' : 'assistant',
                'text': m.text,
              })
          .toList();
      final res =
          await apiClient.supportChat(q, appState.localeCode, history);
      if (!mounted) return;
      final answer = '${res['answer'] ?? ''}';
      final sugg =
          (res['suggestions'] as List? ?? []).map((e) => '$e').toList();
      final acts = (res['actions'] as List? ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      setState(() {
        _messages.add(_ChatMsg(false,
            answer.isEmpty ? s.growFailed : answer, actions: acts));
        _suggestions = sugg;
        _sending = false;
      });
    } on AuthException {
      if (!mounted) return;
      setState(() => _sending = false);
      handleAuthFailure(s.sessionExpired);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _messages.add(_ChatMsg(false, s.growFailed));
        _sending = false;
      });
    }
    _scrollToEnd();
  }

  void _onActionTap(Map<String, dynamic> action) {
    final label = '${action['label'] ?? ''}';
    final tab = action['tab'];
    final route = '${action['route'] ?? ''}';
    if (tab is int) {
      requestedTab.value = tab;
      Navigator.of(context).pop();
    } else if (route.contains('billing') || route.contains('plan')) {
      Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const BillingScreen()));
    } else if (label.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(label),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(s.liveChatSupport),
            const SizedBox(width: 8),
            Container(
              width: 9,
              height: 9,
              decoration: const BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(s.onlineNow,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: VirelloColors.muted)),
          ],
        ),
      ),
      body: Column(
        children: [
          // Subtle caption — no automated/AI banner (silent-intelligence).
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 2),
            child: Text(s.supportCaption,
                style: const TextStyle(
                    fontSize: 11, color: VirelloColors.muted)),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              itemCount: _messages.length + (_sending ? 1 : 0),
              itemBuilder: (_, i) {
                if (i == _messages.length) {
                  return const Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 10),
                      child: _TypingDots(),
                    ),
                  );
                }
                return _bubble(_messages[i]);
              },
            ),
          ),
          if (_suggestions.isNotEmpty && !_sending)
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _suggestions.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => ActionChip(
                  label: Text(_suggestions[i],
                      style: const TextStyle(fontSize: 12)),
                  onPressed: () => _send(_suggestions[i]),
                ),
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
                        hintText: s.askQuestionHint,
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

  Widget _bubble(_ChatMsg m) {
    final align = m.fromUser ? Alignment.centerRight : Alignment.centerLeft;
    final bg = m.fromUser ? VirelloColors.pink : VTheme.chip(context);
    final fg = m.fromUser ? Colors.white : VTheme.text(context);
    return Align(
      alignment: align,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        child: Column(
          crossAxisAlignment: m.fromUser
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(m.text,
                  style:
                      TextStyle(fontSize: 14, height: 1.45, color: fg)),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 3, left: 4, right: 4),
              child: Text(_stamp(m.time),
                  style: const TextStyle(
                      fontSize: 10, color: VirelloColors.muted)),
            ),
            if (m.actions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: m.actions
                      .map((a) => ActionChip(
                            avatar: const Icon(Icons.open_in_new, size: 14),
                            label: Text('${a['label'] ?? ''}',
                                style: const TextStyle(fontSize: 12)),
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
}

/// Animated 3-dot typing indicator — the "live" feel.
class _TypingDots extends StatefulWidget {
  const _TypingDots();
  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: VTheme.chip(context),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          return AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) {
              final t = (_ctrl.value + i / 3) % 1.0;
              final opacity = 0.25 + 0.75 * (1 - (t - 0.5).abs() * 2).clamp(0.0, 1.0);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2.5),
                child: Opacity(
                  opacity: opacity,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: VTheme.text(context),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}
