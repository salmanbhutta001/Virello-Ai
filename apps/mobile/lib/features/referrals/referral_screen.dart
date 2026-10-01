import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/config.dart';
import '../../core/theme.dart';
import '../../core/virello_ui.dart';
import '../../main.dart';
import 'invite_card.dart';
import 'referral_strings.dart';

/// Refer & Earn — free organic growth strategy #5.
///
/// Shows the user's permanent referral link/code with a copy-to-clipboard
/// share button, plus honest stats (invites / joined / pending / credits
/// earned) from GET /api/v1/referrals/{mine,stats}.
///
/// NOTE: the HTTP calls live here (not in ApiClient) so this feature stays
/// fully self-contained; a coordinator can hoist them into
/// lib/services/api_client.dart later.
class ReferralScreen extends StatefulWidget {
  const ReferralScreen({super.key});

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralBundle {
  final Map<String, dynamic> mine;
  final Map<String, dynamic> stats;
  _ReferralBundle(this.mine, this.stats);
}

class _ReferralScreenState extends State<ReferralScreen> {
  late Future<_ReferralBundle> _future;
  final GlobalKey _cardKey = GlobalKey();
  bool _sharing = false;
  _ReferralBundle? _bundle;

  ReferralStrings get s => ReferralStrings(appState.localeCode);

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (authStore.accessToken != null && authStore.accessToken!.isNotEmpty)
          'Authorization': 'Bearer ${authStore.accessToken}',
      };

  Future<_ReferralBundle> _load() async {
    const base = AppConfig.baseUrl;
    final mineRes = await http.get(Uri.parse('$base/api/v1/referrals/mine'),
        headers: _headers);
    if (mineRes.statusCode != 200) {
      throw Exception('mine ${mineRes.statusCode}');
    }
    final statsRes = await http.get(Uri.parse('$base/api/v1/referrals/stats'),
        headers: _headers);
    if (statsRes.statusCode != 200) {
      throw Exception('stats ${statsRes.statusCode}');
    }
    return _ReferralBundle(
      jsonDecode(mineRes.body) as Map<String, dynamic>,
      jsonDecode(statsRes.body) as Map<String, dynamic>,
    );
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    try {
      await _future;
    } catch (_) {}
  }

  Future<void> _copyLink(String link) async {
    await Clipboard.setData(ClipboardData(text: link));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(s.copied)));
  }

  /// Renders the branded invite card offstage, captures it as PNG and opens
  /// the system share sheet with the image + persuasive text. A visual card
  /// with QR + code converts far better than a bare text link.
  Future<void> _shareInvite() async {
    final bundle = _bundle;
    if (bundle == null || _sharing) return;
    setState(() => _sharing = true);
    try {
      // Let the offstage card lay out one frame before capture.
      await Future.delayed(const Duration(milliseconds: 300));
      final boundary = _cardKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('card not ready');
      final image = await boundary.toImage(pixelRatio: 2.0);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) throw Exception('capture failed');
      final data = bytes.buffer.asUint8List();
      final dir = await getTemporaryDirectory();
      final file = await File(
              '${dir.path}/virello-invite-${DateTime.now().millisecondsSinceEpoch}.png')
          .writeAsBytes(data, flush: true);
      final code = '${bundle.mine['code'] ?? ''}';
      final link = '${bundle.mine['share_url'] ?? ''}';
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        text: s.shareText(code, link),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(s.shareFailed)));
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(s.title)),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<_ReferralBundle>(
          future: _future,
          builder: (c, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError || !snap.hasData) {
              return ListView(
                padding: const EdgeInsets.all(20),
                children: [Center(child: Text(s.loadFailed))],
              );
            }
            final bundle = snap.data!;
            _bundle = bundle;
            final code = '${bundle.mine['code'] ?? ''}';
            final link = '${bundle.mine['share_url'] ?? ''}';
            final stats = bundle.stats;
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(s.tagline,
                    style: TextStyle(fontSize: 14, color: VTheme.textSec(c))),
                const SizedBox(height: 16),
                VCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(s.yourLink,
                          style: TextStyle(
                              fontSize: 12, color: VTheme.textSec(c))),
                      const SizedBox(height: 8),
                      SelectableText(link,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text('${s.yourCode}: ',
                              style: TextStyle(
                                  fontSize: 12, color: VTheme.textSec(c))),
                          SelectableText(code,
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 2)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      VGradientButton(
                        label: s.copyLink,
                        onPressed: () => _copyLink(link),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _sharing ? null : _shareInvite,
                          icon: _sharing
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.ios_share, size: 18),
                          label: Text(_sharing ? s.generating : s.shareInvite),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: VirelloColors.pink,
                            foregroundColor: Colors.white,
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    VStatTile(
                        label: s.invites, value: '${stats['invites'] ?? 0}'),
                    const SizedBox(width: 10),
                    VStatTile(
                        label: s.credited,
                        value: '${stats['credited_invites'] ?? 0}'),
                    const SizedBox(width: 10),
                    VStatTile(
                        label: s.pending,
                        value: '${stats['pending_invites'] ?? 0}'),
                  ],
                ),
                const SizedBox(height: 10),
                VCard(
                  child: Row(
                    children: [
                      const Icon(Icons.stars,
                          color: VirelloColors.pink, size: 28),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${stats['credits_earned'] ?? 0}',
                              style: const TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.w800)),
                          Text(s.creditsEarned,
                              style: TextStyle(
                                  fontSize: 12, color: VTheme.textSec(c))),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                VSectionHeader(title: s.howItWorks),
                const SizedBox(height: 8),
                VCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _step(Icons.share, s.step1),
                      const SizedBox(height: 10),
                      _step(Icons.person_add_alt, s.step2),
                      const SizedBox(height: 10),
                      _step(Icons.card_giftcard, s.step3),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(s.honestNote,
                    style: TextStyle(fontSize: 12, color: VTheme.textSec(c))),
                // Offstage invite card — rendered for PNG capture only.
                Offstage(
                  child: RepaintBoundary(
                    key: _cardKey,
                    child: InviteCard(
                      code: code,
                      link: link,
                      headline: s.cardHeadline,
                      subline: s.cardSubline,
                      codeLabel: s.yourCode,
                      scanLabel: s.cardScan,
                      offerLabel: s.cardOffer,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _step(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 20, color: VirelloColors.pink),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
      ],
    );
  }
}
