import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/virello_ui.dart';
import '../../main.dart';
import '../../services/ai_text_service.dart';
import '../../services/local_tools/caption_tools.dart';
import '../../services/local_tools/templates_engine.dart';
import 'template_render_screen.dart';

/// Board screen 29: "Templates" — fully functional.
///
/// Ships a REAL built-in catalog of 12 proven content templates (hooks,
/// reels formats, product videos, storytelling structures). All / Trending
/// tabs filter for real. Tapping a template shows its full structure +
/// example, with Copy and AI-customize actions.
///
/// AI intelligence: "AI Match" — describe your content idea and the AI
/// recommends the best templates for it with reasons.
class TemplatesScreen extends StatefulWidget {
  const TemplatesScreen({super.key});

  @override
  State<TemplatesScreen> createState() => _TemplatesScreenState();
}

class _Template {
  final String id;
  final String name;
  final String category;
  final String description;
  final String structure;
  final String example;
  final bool trending;
  final IconData icon;
  const _Template({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.structure,
    required this.example,
    required this.trending,
    required this.icon,
  });
}

const _catalog = [
  _Template(
    id: 'hook-story-offer',
    name: 'Hook · Story · Offer',
    category: 'Reels',
    description: 'The classic high-converting short video formula.',
    structure:
        '0-3s HOOK: bold claim or question\n3-20s STORY: quick personal story proving it\n20-30s OFFER: what to do next + CTA',
    example: '"I grew 10k followers with zero ads — here\'s the exact 3-step system. Comment GROW and I\'ll send it."',
    trending: true,
    icon: Icons.bolt_outlined,
  ),
  _Template(
    id: 'before-after',
    name: 'Before / After',
    category: 'Reels',
    description: 'Transformation content that stops the scroll.',
    structure:
        '0-2s BEFORE: show the painful starting point\n2-8s PROCESS: fast montage of the change\n8-15s AFTER: reveal + reaction\nCaption: how long it took + CTA',
    example: 'Messy kitchen → 60-second speed clean → sparkling reveal. "Save this for your next reset day!"',
    trending: true,
    icon: Icons.compare_arrows_outlined,
  ),
  _Template(
    id: 'three-sec-hook',
    name: '3-Second Hook Loop',
    category: 'Hooks',
    description: 'End where you began so viewers rewatch.',
    structure:
        'Line 1: the payoff, stated first\nMiddle: the 3 steps that got you there\nLast line: repeats line 1 (seamless loop)',
    example: '"This towel dries dishes in one wipe. Here\'s why: 1) twisted fibers 2) ... — this towel dries dishes in one wipe."',
    trending: true,
    icon: Icons.loop_outlined,
  ),
  _Template(
    id: 'pas',
    name: 'Problem · Agitate · Solve',
    category: 'Sales',
    description: 'Copywriting classic for product videos.',
    structure:
        'PROBLEM: name the pain in their words\nAGITATE: make it sting (what it costs them)\nSOLVE: your product as the relief + proof',
    example: '"Tired of streaky glasses? Every dinner party, same embarrassment. This microfiber set ends it — 2,000+ five-star reviews."',
    trending: false,
    icon: Icons.psychology_outlined,
  ),
  _Template(
    id: 'unboxing',
    name: 'Unboxing / First Look',
    category: 'Product',
    description: 'First-impression energy that builds trust.',
    structure:
        '0-5s: the box + one-line promise\n5-25s: unbox piece by piece, honest reactions\n25-35s: first test + verdict',
    example: '"This gadget claims to chop onions with zero tears — let\'s see. [unboxes] Okay, first impression: solid build…"',
    trending: true,
    icon: Icons.inventory_2_outlined,
  ),
  _Template(
    id: 'tutorial',
    name: '60-Second Tutorial',
    category: 'Educational',
    description: 'Teach one thing, fast and clearly.',
    structure:
        '0-3s: what they\'ll learn + why it matters\n3-45s: 3 steps, show don\'t tell\n45-60s: common mistake to avoid + follow CTA',
    example: '"Perfect omelet in 60 seconds. Step 1: low heat, always. Step 2… The mistake everyone makes? High heat."',
    trending: false,
    icon: Icons.school_outlined,
  ),
  _Template(
    id: 'bts',
    name: 'Behind the Scenes',
    category: 'Story',
    description: 'Humanize your brand with real moments.',
    structure:
        'Setup: what we\'re working on today\nMessy middle: the real, unpolished process\nPayoff: the result + one honest lesson',
    example: '"Packing 200 orders today — here\'s what actually goes wrong. [chaos] …and that\'s why we triple-check labels now."',
    trending: false,
    icon: Icons.movie_filter_outlined,
  ),
  _Template(
    id: 'testimonial',
    name: 'Customer Story',
    category: 'Sales',
    description: 'Let proof do the selling.',
    structure:
        'Who they were before (relatable)\nThe doubt they had\nThe result + their own words\nYour CTA',
    example: '"Sara thought serums were a scam. 3 weeks later her dark spots faded — here\'s her unfiltered routine."',
    trending: false,
    icon: Icons.verified_outlined,
  ),
  _Template(
    id: 'myth-fact',
    name: 'Myth vs Fact',
    category: 'Educational',
    description: 'Bust a belief in 30 seconds.',
    structure:
        'MYTH: state the common belief boldly\nFACT: the truth with one proof point\nTAKEAWAY: what to do instead',
    example: '"MYTH: you need expensive tools to grow. FACT: my best video was shot on a 3-year-old phone. Here\'s the real lever…"',
    trending: false,
    icon: Icons.fact_check_outlined,
  ),
  _Template(
    id: 'day-in-life',
    name: 'Day in My Life',
    category: 'Story',
    description: 'Vlog-style authenticity that builds fans.',
    structure:
        'Morning hook: today\'s mission in one line\n3-4 timestamped moments (keep each under 8s)\nEvening reflection: one honest takeaway',
    example: '"Running a small business solo — today: 40 orders, one disaster, and a surprise. 7am: warehouse…"',
    trending: true,
    icon: Icons.wb_sunny_outlined,
  ),
  _Template(
    id: 'product-demo',
    name: '30-Second Product Demo',
    category: 'Product',
    description: 'Show, don\'t tell — pure demonstration.',
    structure:
        '0-5s: the claim, on camera\n5-25s: live demo, no cuts if possible\n25-30s: price + where to get it',
    example: '"They say it holds 50kg. [hangs weight] No edits, no tricks — link in bio, 20% off this week."',
    trending: false,
    icon: Icons.play_circle_outline,
  ),
  _Template(
    id: 'faq-rapid',
    name: 'FAQ Rapid Fire',
    category: 'Educational',
    description: 'Answer 5 questions in 45 seconds.',
    structure:
        'Hook: "You asked, I answer — fast."\n5 questions, one-line answers, jump cuts\nEnd: "Drop your question for part 2."',
    example: '"Is it worth it? Yes. How long does it last? 2 years. … Comment your question for part 2!"',
    trending: false,
    icon: Icons.question_answer_outlined,
  ),
];

class _TemplatesScreenState extends State<TemplatesScreen> {
  int _tab = 0;
  final _matchCtrl = TextEditingController();
  bool _matching = false;
  List<String> _matchedIds = [];
  String? _matchReason;
  bool _customizing = false;

  AppStrings get s => AppStrings(appState.localeCode);

  @override
  void dispose() {
    _matchCtrl.dispose();
    super.dispose();
  }

  List<_Template> get _visible {
    var list = _tab == 0
        ? _catalog.toList()
        : _catalog.where((t) => t.trending).toList();
    if (_matchedIds.isNotEmpty) {
      final matched = list.where((t) => _matchedIds.contains(t.id)).toList();
      final rest = list.where((t) => !_matchedIds.contains(t.id)).toList();
      return [...matched, ...rest];
    }
    return list;
  }

  /// AI Match: recommends the best templates for the user's idea.
  Future<void> _aiMatch() async {
    final idea = _matchCtrl.text.trim();
    if (idea.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.boardEnterTextFirst)),
      );
      return;
    }
    setState(() {
      _matching = true;
      _matchedIds = [];
      _matchReason = null;
    });
    try {
      final names = _catalog.map((t) => '${t.id}: ${t.name}').join('\n');
      final prompt =
          'A creator wants to make content about: $idea\n'
          'Available templates (id: name):\n$names\n'
          'Reply with ONLY the ids of the 3 best templates, comma-separated, then a new line, then one short sentence why (in English). '
          'Example:\nhook-story-offer, before-after, faq-rapid\nBecause short-form proof content converts best for product topics.';
      final body =
          await AiTextService.instance.generate(prompt: prompt);
      if (!mounted) return;
      if (body != null && body.trim().isNotEmpty) {
        final lines =
            body.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
        if (lines.isNotEmpty) {
          final ids = lines.first
              .split(',')
              .map((e) => e.trim().toLowerCase())
              .where((id) => _catalog.any((t) => t.id == id))
              .toList();
          setState(() {
            _matchedIds = ids;
            _matchReason = lines.length > 1 ? lines.sublist(1).join(' ') : null;
            _matching = false;
          });
          return;
        }
      }
      setState(() => _matching = false);
    } catch (_) {
      if (mounted) setState(() => _matching = false);
    }
  }

  /// Hafiz 2026-10-13: download any template text as a .txt file so
  /// users can save their work (share sheet -> Save to Files/Downloads).
  Future<void> _downloadTextFile(
      BuildContext ctx, String filename, String content) async {
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$filename');
      await file.writeAsString('$content\n\nvia Virello');
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/plain', name: filename)],
        text: 'via Virello',
      );
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text(s.boardImageDownload)),
        );
      }
    } catch (_) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text(s.boardImageSaveFailed)),
        );
      }
    }
  }

  void _openTemplate(_Template t) {
    // Local project plans (Phase A) exist for a subset of the catalog.
    final engineT = TemplatesEngine.byId(t.id);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scroll) => Container(
          decoration: BoxDecoration(
            color: VTheme.card(ctx),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: ListView(
            controller: scroll,
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
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: VirelloColors.pink.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(t.icon, color: VirelloColors.pink, size: 26),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.name,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: VTheme.text(ctx),
                          ),
                        ),
                        Text(
                          t.category,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: VTheme.textSec(ctx),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: s.boardImageDownload,
                    onPressed: () => _downloadTextFile(
                      ctx,
                      'virello_template_${t.id}.txt',
                      '${t.name}\n${t.category}\n\n${t.description}\n\n'
                      'STRUCTURE:\n${t.structure}\n\n'
                      'EXAMPLE:\n${t.example}',
                    ),
                    icon: const Icon(
                      Icons.download_outlined,
                      color: VirelloColors.pink,
                      size: 22,
                    ),
                  ),
                  if (t.trending)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: VirelloColors.pink.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        s.boardTabTrending,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: VirelloColors.pink,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                t.description,
                style: TextStyle(
                  fontSize: 13.5,
                  color: VTheme.textSec(ctx),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                s.boardTemplateStructure,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: VTheme.text(ctx),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: VTheme.chip(ctx),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: SelectableText(
                  t.structure,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.7,
                    color: VTheme.text(ctx),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                s.boardTemplateExample,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: VTheme.text(ctx),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: VirelloColors.pink.withValues(alpha: 0.3),
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  t.example,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontStyle: FontStyle.italic,
                    height: 1.6,
                    color: VTheme.text(ctx),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(
                            text: '${t.name}\n\n${t.structure}'));
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text(s.boardCopied)),
                        );
                      },
                      icon: const Icon(Icons.copy_outlined, size: 18),
                      label: Text(s.boardTemplateCopy),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _customizing
                          ? null
                          : () => _aiCustomize(ctx, t),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: VirelloColors.pink,
                        foregroundColor: Colors.white,
                      ),
                      icon: _customizing
                          ?  SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: VTheme.onBrand(context),
                              ),
                            )
                          : const Icon(Icons.auto_awesome_outlined,
                              size: 18),
                      label: Text(s.boardTemplateAiFill),
                    ),
                  ),
                ],
              ),
              // Phase B: render the filled template into a real video
              // on-device (ffmpeg slideshow → voice/music mix → captions).
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TemplateRenderScreen(
                          template: _toContentTemplate(t),
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.movie_creation_outlined, size: 18),
                  label: Text(s.renderVideo),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: VirelloColors.pink,
                    side: const BorderSide(color: VirelloColors.pink),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              // Local project plan (Phase A): shot list + caption timing,
              // built on-device from the user's slot values.
              if (engineT != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _openPlanBuilder(engineT);
                    },
                    icon: const Icon(Icons.list_alt_outlined, size: 18),
                    label: Text(s.buildPlan),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: VirelloColors.pink,
                      side: const BorderSide(color: VirelloColors.pink),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Maps a board [_Template] to a renderable [ContentTemplate].
  ///
  /// Prefers Phase A's curated slot definitions when they exist
  /// ([TemplatesEngine.byId]); otherwise builds a generic template from the
  /// board structure prose, deriving a slot (and rough duration) per line.
  ContentTemplate _toContentTemplate(_Template t) {
    final builtin = TemplatesEngine.byId(t.id);
    if (builtin != null) return builtin;
    final slots = <TemplateSlot>[];
    final lines = t.structure
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      var secs = 8;
      var label = line;
      final m = RegExp(r'^(\d+)\s*-\s*(\d+)s\s*:?\s*(.*)$').firstMatch(line);
      if (m != null) {
        final a = int.parse(m.group(1)!);
        final b = int.parse(m.group(2)!);
        secs = (b - a).clamp(2, 60);
        label = m.group(3)!.trim();
      } else {
        final ci = line.indexOf(':');
        if (ci > 0 && ci < 30) label = line.substring(0, ci).trim();
      }
      if (label.length > 40) label = '${label.substring(0, 37)}…';
      slots.add(TemplateSlot(
        id: 'beat$i',
        label: label.isEmpty ? 'Beat ${i + 1}' : label,
        hint: line,
        maxSeconds: secs,
      ));
    }
    return ContentTemplate(
      id: t.id,
      name: t.name,
      category: t.category,
      description: t.description,
      slots: slots,
      defaultCta: 'Follow for more.',
    );
  }

  /// Local template project builder: fills each slot, then produces a
  /// structured plan (shot list + caption timing) via [TemplatesEngine].
  void _openPlanBuilder(ContentTemplate template) {
    final ctrls = <String, TextEditingController>{
      for (final sl in template.slots) sl.id: TextEditingController(),
    };
    final ctaCtrl = TextEditingController(text: template.defaultCta);
    TemplateProject? project;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scroll) => StatefulBuilder(
          builder: (ctx2, setB) => Container(
            decoration: BoxDecoration(
              color: VTheme.card(ctx2),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: project == null
                ? _planForm(ctx2, scroll, template, ctrls, ctaCtrl, setB,
                    (p) => setB(() => project = p))
                : _planResult(ctx2, scroll, project!, setB,
                    () => setB(() => project = null)),
          ),
        ),
      ),
    ).whenComplete(() {
      for (final c in ctrls.values) {
        c.dispose();
      }
      ctaCtrl.dispose();
    });
  }

  Widget _planForm(
    BuildContext ctx,
    ScrollController scroll,
    ContentTemplate template,
    Map<String, TextEditingController> ctrls,
    TextEditingController ctaCtrl,
    StateSetter setB,
    ValueChanged<TemplateProject> onBuilt,
  ) {
    return ListView(
      controller: scroll,
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
        Text(
          '${s.buildPlan}: ${template.name}',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: VTheme.text(ctx),
          ),
        ),
        Text(
          template.description,
          style: TextStyle(fontSize: 12.5, color: VTheme.textSec(ctx)),
        ),
        const SizedBox(height: 16),
        for (final sl in template.slots) ...[
          Text(
            '${sl.label} (~${sl.maxSeconds}s)',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: VTheme.textSec(ctx),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: VTheme.chip(ctx),
              borderRadius: BorderRadius.circular(14),
            ),
            child: TextField(
              controller: ctrls[sl.id],
              maxLines: 2,
              minLines: 1,
              style: TextStyle(color: VTheme.text(ctx), fontSize: 14),
              decoration: InputDecoration(
                hintText: sl.hint,
                hintStyle: TextStyle(color: VTheme.textSec(ctx)),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        Text(
          'CTA',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: VTheme.textSec(ctx),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: VTheme.chip(ctx),
            borderRadius: BorderRadius.circular(14),
          ),
          child: TextField(
            controller: ctaCtrl,
            style: TextStyle(color: VTheme.text(ctx), fontSize: 14),
            decoration: const InputDecoration(border: InputBorder.none),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            onPressed: () {
              final values = {
                for (final e in ctrls.entries) e.key: e.value.text,
              };
              onBuilt(TemplatesEngine.buildProject(
                template: template,
                slotValues: values,
                cta: ctaCtrl.text,
              ));
            },
            style: FilledButton.styleFrom(
              backgroundColor: VirelloColors.pink,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              s.buildPlan,
              style:  TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: VTheme.onBrand(context),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _planResult(
    BuildContext ctx,
    ScrollController scroll,
    TemplateProject project,
    StateSetter setB,
    VoidCallback onEdit,
  ) {
    final plan = project.shotList();
    return ListView(
      controller: scroll,
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
            Expanded(
              child: Text(
                s.projectPlan,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: VTheme.text(ctx),
                ),
              ),
            ),
            TextButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: Text(s.boardWriteScript),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          s.shotList,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: VTheme.textSec(ctx),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: VTheme.chip(ctx),
            borderRadius: BorderRadius.circular(14),
          ),
          child: SelectableText(
            plan,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.7,
              color: VTheme.text(ctx),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          s.captionTiming,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: VTheme.textSec(ctx),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: VTheme.chip(ctx),
            borderRadius: BorderRadius.circular(14),
          ),
          child: SelectableText(
            CaptionTools.toSrt(project.captions),
            style: TextStyle(
              fontSize: 12.5,
              height: 1.7,
              color: VTheme.text(ctx),
              fontFamily: 'monospace',
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: plan));
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text(s.boardCopied)),
                  );
                },
                icon: const Icon(Icons.copy_outlined, size: 18),
                label: Text(s.copyText),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _downloadTextFile(
                  ctx,
                  'virello_template_plan.txt',
                  'SHOT LIST\n\n$plan\n\nCAPTION TIMING (SRT)\n\n'
                  '${CaptionTools.toSrt(project.captions)}',
                ),
                icon: const Icon(Icons.download_outlined, size: 18),
                label: Text(s.boardImageDownload),
                style: OutlinedButton.styleFrom(
                  foregroundColor: VirelloColors.pink,
                  side: const BorderSide(color: VirelloColors.pink),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// AI intelligence: fills the template with the user's topic.
  Future<void> _aiCustomize(BuildContext sheetCtx, _Template t) async {
    final messenger = ScaffoldMessenger.of(context);
    final idea = _matchCtrl.text.trim();
    if (idea.isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text(s.boardTemplateNeedIdea)),
      );
      return;
    }
    setState(() => _customizing = true);
    try {
      final langNote = appState.localeCode == 'ur'
          ? 'Write in Roman Urdu.'
          : appState.localeCode == 'ar'
              ? 'Write in Arabic.'
              : 'Write in English.';
      final prompt =
          'Fill this video content template for the topic: $idea\n'
          'Template "${t.name}":\n${t.structure}\n'
          '$langNote Keep every line short and speakable. Output only the filled script, no explanations.';
      final body =
          await AiTextService.instance.generate(prompt: prompt);
      if (!mounted) return;
      setState(() => _customizing = false);
      if (body != null && body.trim().isNotEmpty) {
        Navigator.pop(sheetCtx);
        _showCustomized(t, body.trim());
      } else {
        messenger.showSnackBar(
          SnackBar(content: Text(s.askFailed)),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _customizing = false);
        messenger.showSnackBar(
          SnackBar(content: Text(s.askFailed)),
        );
      }
    }
  }

  void _showCustomized(_Template t, String script) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scroll) => Container(
          decoration: BoxDecoration(
            color: VTheme.card(ctx),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: ListView(
            controller: scroll,
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
                  Expanded(
                    child: Text(
                      '${t.name} · ${s.boardImageAiLabel}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: VTheme.text(ctx),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: script));
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text(s.boardCopied)),
                      );
                    },
                    icon: const Icon(Icons.copy_outlined,
                        color: VirelloColors.pink),
                  ),
                  IconButton(
                    tooltip: s.boardImageDownload,
                    onPressed: () => _downloadTextFile(
                      ctx,
                      'virello_template_${t.id}_custom.txt',
                      '${t.name} (AI customized)\n\n$script',
                    ),
                    icon: const Icon(Icons.download_outlined,
                        color: VirelloColors.pink),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SelectableText(
                script,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.7,
                  color: VTheme.text(ctx),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final templates = _visible;
    return Scaffold(
      appBar: AppBar(title: Text(s.boardTemplates)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: VPillTabs(
              tabs: [s.boardTabAll, s.boardTabTrending],
              selected: _tab,
              onTap: (i) => setState(() => _tab = i),
            ),
          ),
          // AI Match bar.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: VBoardCard(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.auto_awesome_outlined,
                    color: VirelloColors.pink,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _matchCtrl,
                      style:
                          TextStyle(color: VTheme.text(context)),
                      decoration: InputDecoration(
                        hintText: s.boardTemplateMatchHint,
                        hintStyle:
                            TextStyle(color: VTheme.textSec(context)),
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) => _aiMatch(),
                    ),
                  ),
                  const SizedBox(width: 4),
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: FilledButton(
                      onPressed: _matching ? null : _aiMatch,
                      style: FilledButton.styleFrom(
                        backgroundColor: VirelloColors.pink,
                        shape: const CircleBorder(),
                        padding: EdgeInsets.zero,
                      ),
                      child: _matching
                          ?  SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: VTheme.onBrand(context),
                              ),
                            )
                          : const Icon(Icons.search_rounded, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_matchReason != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                _matchReason!,
                style: TextStyle(
                  fontSize: 12.5,
                  fontStyle: FontStyle.italic,
                  color: VTheme.textSec(context),
                ),
              ),
            ),
          Expanded(
            child: templates.isEmpty
                ? Center(
                    child: Text(
                      s.boardNoTemplates,
                      style:
                          TextStyle(color: VTheme.textSec(context)),
                    ),
                  )
                : GridView.builder(
                    padding:
                        const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.92,
                    ),
                    itemCount: templates.length,
                    itemBuilder: (c, i) {
                      final t = templates[i];
                      final isMatch = _matchedIds.contains(t.id);
                      return GestureDetector(
                        onTap: () => _openTemplate(t),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: VTheme.card(context),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isMatch
                                  ? VirelloColors.pink
                                  : VTheme.divider(context),
                              width: isMatch ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: VirelloColors.pink
                                          .withValues(alpha: 0.14),
                                      borderRadius:
                                          BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      t.icon,
                                      color: VirelloColors.pink,
                                      size: 20,
                                    ),
                                  ),
                                  const Spacer(),
                                  if (isMatch)
                                    const Icon(
                                      Icons.auto_awesome,
                                      color: VirelloColors.pink,
                                      size: 18,
                                    )
                                  else if (t.trending)
                                    Container(
                                      padding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 7,
                                              vertical: 3),
                                      decoration: BoxDecoration(
                                        color: VirelloColors.pink
                                            .withValues(alpha: 0.12),
                                        borderRadius:
                                            BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        s.boardTabTrending,
                                        style: const TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w700,
                                          color: VirelloColors.pink,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                t.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  color: VTheme.text(context),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Expanded(
                                child: Text(
                                  t.description,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    height: 1.4,
                                    color:
                                        VTheme.textSec(context),
                                  ),
                                ),
                              ),
                              Text(
                                t.category,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: VTheme.textSec(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
