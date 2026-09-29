import 'package:flutter/material.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../services/api_client.dart';
import '../../main.dart';

/// AI Support: real chat with Virello's automated support assistant
/// (POST /ai/support). Honestly labeled as automated in the header.
class SupportChatScreen extends StatefulWidget {
  const SupportChatScreen({super.key});
  @override
  State<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _ChatMsg {
  final bool fromUser;
  final String text;
  _ChatMsg(this.fromUser, this.text);
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

  Future<void> _send(String text) async {
    final q = text.trim();
    if (q.isEmpty || _sending) return;
    setState(() {
      _messages.add(_ChatMsg(true, q));
      _sending = true;
    });
    _inputCtrl.clear();
    _scrollToEnd();
    try {
      final res = await apiClient.aiSupportChat(q, appState.localeCode);
      if (!mounted) return;
      final answer = '${res['answer'] ?? ''}';
      final sugg = (res['suggestions'] as List? ?? []).map((e) => '$e').toList();
      setState(() {
        _messages.add(_ChatMsg(
            false, answer.isEmpty ? s.growFailed : answer));
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
      appBar: AppBar(title: Text(s.aiSupport)),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: VirelloColors.pink.withValues(alpha: 0.08),
            child: Row(
              children: [
                const Icon(Icons.smart_toy_outlined,
                    size: 18, color: VirelloColors.pink),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(s.supportAutomatedNote,
                      style: const TextStyle(
                          fontSize: 12,
                          color: VirelloColors.muted,
                          height: 1.4)),
                ),
              ],
            ),
          ),
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
    final align =
        m.fromUser ? Alignment.centerRight : Alignment.centerLeft;
    final bg = m.fromUser
        ? VirelloColors.pink
        : VTheme.chip(context);
    final fg = m.fromUser ? Colors.white : VTheme.text(context);
    return Align(
      alignment: align,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(m.text,
            style: TextStyle(fontSize: 14, height: 1.45, color: fg)),
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
