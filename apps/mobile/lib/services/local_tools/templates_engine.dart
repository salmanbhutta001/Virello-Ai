/// Local templates engine — pure Dart, no network.
///
/// Built-in proven content templates (POV, Before/After, Tutorial, Unboxing,
/// Quick Review). Each template declares named slots (hook, beats, CTA);
/// [TemplatesEngine.buildProject] fills them with the user's values and
/// produces a structured, JSON-serializable project plan: shot list with
/// timings + caption timing via [CaptionTools]. Phase B will render the
/// plan into a finished video (ffmpeg); Phase A shows the plan.
library;

import 'caption_tools.dart';

/// One fillable slot inside a template.
class TemplateSlot {
  final String id;
  final String label;
  final String hint;
  final int maxSeconds;

  const TemplateSlot({
    required this.id,
    required this.label,
    required this.hint,
    required this.maxSeconds,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'hint': hint,
        'maxSeconds': maxSeconds,
      };
}

/// A content template: ordered slots + a default call-to-action.
class ContentTemplate {
  final String id;
  final String name;
  final String category;
  final String description;
  final List<TemplateSlot> slots;
  final String defaultCta;

  const ContentTemplate({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.slots,
    required this.defaultCta,
  });

  /// Total planned runtime in seconds.
  int get totalSeconds => slots.fold(0, (a, s) => a + s.maxSeconds);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'description': description,
        'defaultCta': defaultCta,
        'slots': slots.map((s) => s.toJson()).toList(),
      };
}

/// One planned shot with absolute timing.
class PlannedShot {
  final int index;
  final String slotId;
  final String slotLabel;
  final String content;
  final double start;
  final double end;

  const PlannedShot({
    required this.index,
    required this.slotId,
    required this.slotLabel,
    required this.content,
    required this.start,
    required this.end,
  });

  Map<String, dynamic> toJson() => {
        'index': index,
        'slotId': slotId,
        'slotLabel': slotLabel,
        'content': content,
        'start': start,
        'end': end,
      };
}

/// A filled project plan, ready for Phase B rendering.
class TemplateProject {
  final String templateId;
  final String templateName;
  final Map<String, String> slotValues;
  final List<String> assetPaths;
  final List<PlannedShot> shots;
  final List<CaptionLine> captions;
  final String cta;

  const TemplateProject({
    required this.templateId,
    required this.templateName,
    required this.slotValues,
    required this.assetPaths,
    required this.shots,
    required this.captions,
    required this.cta,
  });

  Map<String, dynamic> toJson() => {
        'templateId': templateId,
        'templateName': templateName,
        'slotValues': slotValues,
        'assetPaths': assetPaths,
        'cta': cta,
        'shots': shots.map((s) => s.toJson()).toList(),
        'captions': captions.map((c) => c.toJson()).toList(),
      };

  /// Human-readable shot list with timings, e.g.:
  /// `Shot 1 [0s-3s] HOOK: <text>`
  String shotList() {
    final buf = StringBuffer();
    buf.writeln('Project: $templateName');
    buf.writeln('Runtime: ~${shots.isEmpty ? 0 : shots.last.end.round()}s');
    buf.writeln('Assets: ${assetPaths.length}');
    buf.writeln();
    for (final s in shots) {
      buf.writeln(
          'Shot ${s.index} [${s.start.round()}s-${s.end.round()}] ${s.slotLabel}: ${s.content}');
    }
    buf.writeln();
    buf.writeln('CTA: $cta');
    return buf.toString();
  }
}

class TemplatesEngine {
  TemplatesEngine._();

  static const List<ContentTemplate> builtIn = [
    ContentTemplate(
      id: 'pov',
      name: 'POV',
      category: 'Reels',
      description: 'Put the viewer inside the moment. Fast, relatable, shareable.',
      defaultCta: 'Follow for more POVs like this.',
      slots: [
        TemplateSlot(
            id: 'hook', label: 'Hook (POV line)', hint: 'POV: …', maxSeconds: 3),
        TemplateSlot(
            id: 'scene',
            label: 'Scene',
            hint: 'What happens on camera',
            maxSeconds: 12),
        TemplateSlot(
            id: 'punchline',
            label: 'Punchline',
            hint: 'The twist or payoff',
            maxSeconds: 5),
      ],
    ),
    ContentTemplate(
      id: 'before-after',
      name: 'Before / After',
      category: 'Reels',
      description: 'Show the transformation. The contrast does the selling.',
      defaultCta: 'Comment RESULT and I will share how.',
      slots: [
        TemplateSlot(
            id: 'before',
            label: 'Before',
            hint: 'The starting point',
            maxSeconds: 5),
        TemplateSlot(
            id: 'process',
            label: 'Process',
            hint: 'What you did (quick cuts)',
            maxSeconds: 12),
        TemplateSlot(
            id: 'after',
            label: 'After reveal',
            hint: 'The result, held 3 seconds',
            maxSeconds: 6),
      ],
    ),
    ContentTemplate(
      id: 'tutorial',
      name: 'Tutorial',
      category: 'Education',
      description: 'Teach one clear thing in under a minute.',
      defaultCta: 'Save this and follow for part 2.',
      slots: [
        TemplateSlot(
            id: 'promise',
            label: 'Promise',
            hint: 'What they will learn',
            maxSeconds: 4),
        TemplateSlot(
            id: 'step1', label: 'Step 1', hint: 'First step', maxSeconds: 12),
        TemplateSlot(
            id: 'step2', label: 'Step 2', hint: 'Second step', maxSeconds: 12),
        TemplateSlot(
            id: 'step3', label: 'Step 3', hint: 'Final step', maxSeconds: 12),
        TemplateSlot(
            id: 'recap',
            label: 'Recap',
            hint: 'One-line summary',
            maxSeconds: 5),
      ],
    ),
    ContentTemplate(
      id: 'unboxing',
      name: 'Unboxing',
      category: 'Product',
      description: 'First-impression product reveal with honest reactions.',
      defaultCta: 'Link in bio if you want one.',
      slots: [
        TemplateSlot(
            id: 'tease',
            label: 'Tease',
            hint: 'What is in the box?',
            maxSeconds: 4),
        TemplateSlot(
            id: 'reveal',
            label: 'Reveal',
            hint: 'Open it on camera',
            maxSeconds: 10),
        TemplateSlot(
            id: 'firstlook',
            label: 'First look',
            hint: 'Hold it up, show details',
            maxSeconds: 10),
        TemplateSlot(
            id: 'verdict',
            label: 'Verdict',
            hint: 'Honest first impression',
            maxSeconds: 6),
      ],
    ),
    ContentTemplate(
      id: 'quick-review',
      name: 'Quick Review',
      category: 'Product',
      description: 'A 30-second honest review: what is good, what is not.',
      defaultCta: 'Follow for honest reviews, no hype.',
      slots: [
        TemplateSlot(
            id: 'product',
            label: 'Product',
            hint: 'Name it in one line',
            maxSeconds: 4),
        TemplateSlot(
            id: 'pros',
            label: 'Pros',
            hint: '2 things you like',
            maxSeconds: 10),
        TemplateSlot(
            id: 'cons',
            label: 'Cons',
            hint: '1 honest drawback',
            maxSeconds: 8),
        TemplateSlot(
            id: 'rating',
            label: 'Rating',
            hint: 'Score out of 10 + who it is for',
            maxSeconds: 8),
      ],
    ),
  ];

  static ContentTemplate? byId(String id) {
    for (final t in builtIn) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// Builds a project plan from user-filled [slotValues] (keyed by slot id),
  /// optional local [assetPaths], and an optional CTA override.
  ///
  /// Empty slot values are kept as the slot hint so the plan never silently
  /// drops a beat — the user sees exactly what is missing.
  static TemplateProject buildProject({
    required ContentTemplate template,
    required Map<String, String> slotValues,
    List<String> assetPaths = const [],
    String? cta,
    double wordsPerSecond = 2.5,
  }) {
    final shots = <PlannedShot>[];
    double t = 0;
    var i = 1;
    final scriptBuf = StringBuffer();
    for (final slot in template.slots) {
      final raw = slotValues[slot.id]?.trim() ?? '';
      final content = raw.isEmpty ? '[${slot.hint}]' : raw;
      final end = t + slot.maxSeconds;
      shots.add(PlannedShot(
        index: i++,
        slotId: slot.id,
        slotLabel: slot.label,
        content: content,
        start: t,
        end: end,
      ));
      if (raw.isNotEmpty) scriptBuf.writeln(raw);
      t = end;
    }
    final captions = CaptionTools.timedCaptions(
      scriptBuf.toString(),
      wordsPerSecond: wordsPerSecond,
    );
    return TemplateProject(
      templateId: template.id,
      templateName: template.name,
      slotValues: Map.unmodifiable(slotValues),
      assetPaths: List.unmodifiable(assetPaths),
      shots: shots,
      captions: captions,
      cta: (cta == null || cta.trim().isEmpty) ? template.defaultCta : cta.trim(),
    );
  }
}
