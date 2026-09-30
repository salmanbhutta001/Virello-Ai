import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/virello_ui.dart';
import '../../main.dart';

/// Local teleprompter — auto-scrolling script reader for hands-free
/// recording. 100% on-device: no network, no account, no setup.
///
/// Two modes: edit (write/paste the script) and prompter (big readable
/// text auto-scrolling at an adjustable speed).
class TeleprompterScreen extends StatefulWidget {
  final String initialScript;
  const TeleprompterScreen({super.key, this.initialScript = ''});

  @override
  State<TeleprompterScreen> createState() => _TeleprompterScreenState();
}

class _TeleprompterScreenState extends State<TeleprompterScreen> {
  late final TextEditingController _ctrl;
  final ScrollController _scroll = ScrollController();
  Timer? _timer;
  bool _playing = false;
  bool _prompterMode = false;
  double _speed = 2.0; // 1..6

  AppStrings get s => AppStrings(appState.localeCode);

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialScript);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _start() {
    if (_ctrl.text.trim().isEmpty) return;
    setState(() {
      _prompterMode = true;
      _playing = true;
    });
    _timer?.cancel();
    // Scroll ~110px/sec at speed 1x, scaled by _speed.
    _timer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!_scroll.hasClients) return;
      final pos = _scroll.position;
      final next = _scroll.offset + _speed * 5.5;
      if (next >= pos.maxScrollExtent) {
        _scroll.jumpTo(pos.maxScrollExtent);
        _stop();
      } else {
        _scroll.jumpTo(next);
      }
    });
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    if (mounted) setState(() => _playing = false);
  }

  void _toggle() {
    if (_playing) {
      _stop();
    } else {
      _start();
    }
  }

  void _restart() {
    _stop();
    if (_scroll.hasClients) _scroll.jumpTo(0);
    _start();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(s.teleprompter),
        actions: [
          if (_prompterMode)
            IconButton(
              tooltip: s.boardImageRegenerate,
              icon: const Icon(Icons.restart_alt_outlined),
              onPressed: _restart,
            ),
        ],
      ),
      body: _prompterMode ? _buildPrompter() : _buildEditor(),
      bottomNavigationBar: _prompterMode ? _buildControls() : _buildStartBar(),
    );
  }

  Widget _buildEditor() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        VBoardCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: TextField(
            controller: _ctrl,
            maxLines: 12,
            minLines: 8,
            style: TextStyle(
              color: VTheme.text(context),
              fontSize: 15,
              height: 1.7,
            ),
            decoration: InputDecoration(
              hintText: s.scriptHint,
              hintStyle: TextStyle(color: VTheme.textSec(context)),
              border: InputBorder.none,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          s.teleprompterSpeed,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: VTheme.textSec(context),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: Slider(
                value: _speed,
                min: 1,
                max: 6,
                divisions: 10,
                label: '${_speed.toStringAsFixed(1)}x',
                onChanged: (v) => setState(() => _speed = v),
              ),
            ),
            Text(
              '${_speed.toStringAsFixed(1)}x',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: VTheme.text(context),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPrompter() {
    return Container(
      color: Colors.black,
      child: SingleChildScrollView(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(24, 120, 24, 120),
        child: Text(
          _ctrl.text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 30,
            height: 1.9,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildControls() {
    return SafeArea(
      child: Container(
        color: Colors.black,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  _stop();
                  setState(() => _prompterMode = false);
                },
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: Text(s.boardWriteScript),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white24),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: _toggle,
                icon: Icon(
                  _playing ? Icons.pause : Icons.play_arrow,
                  size: 20,
                ),
                label: Text(_playing ? s.pause : s.play),
                style: FilledButton.styleFrom(
                  backgroundColor: VirelloColors.pink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStartBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton.icon(
            onPressed: _ctrl.text.trim().isEmpty ? null : _start,
            icon: const Icon(Icons.play_arrow, size: 20),
            label: Text(
              s.play,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: VirelloColors.pink,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
