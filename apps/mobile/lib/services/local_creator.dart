/// On-device fallback creator — the LAST resort in the generation chain:
///
///   1) real AI provider  ->  2) backend heuristic  ->  3) THIS
///
/// Pure Dart, zero network, so the user ALWAYS gets a created result even
/// with no connectivity at all. Calling screens must keep labeling this
/// output as a basic draft (never as AI output) — the existing `_isAi`
/// flags already do that.
class LocalCreator {
  static bool _isUr(String lang) => lang == 'ur';

  // ---------------------------------------------------------------- script

  /// Returns {'title': ..., 'body': ...} — a structured 60-second script.
  static Map<String, String> buildScript(
      String topic, String tone, String lang) {
    final t = topic.trim().isEmpty ? 'your topic' : topic.trim();
    if (_isUr(lang)) {
      return {
        'title': '$t — 60 second video script',
        'body': 'HOOK (0-5s): Suno! $t ke baare me ek baat jo aapko hairan kar degi.\n'
            'BEAT 1 (5-20s): Pehli baat — $t me sab se zaroori cheez ye hai ke aap shuruat chhoti rakhen lekin consistent rahen.\n'
            'BEAT 2 (20-40s): Doosri baat — ghaltiyon se ghabrana nahi, har ghalti ek naya sabak hai.\n'
            'BEAT 3 (40-55s): Teesri baat — jo log aaj kamyab hain, unhon ne bhi wahin se shuru kiya tha jahan aap hain.\n'
            'CTA (55-60s): Abhi follow karen aur comment me batayen — aap $t me sab se pehle kya try karenge?',
      };
    }
    return {
      'title': '$t — 60-second video script',
      'body': 'HOOK (0-5s): Stop scrolling — here is what nobody tells you about $t.\n'
          'BEAT 1 (5-20s): First, the truth: most people fail at $t because they overcomplicate the start. Keep it simple.\n'
          'BEAT 2 (20-40s): Second, consistency beats intensity. Ten focused minutes daily beats one big push a month.\n'
          'BEAT 3 (40-55s): Third, learn from people already doing it — copy the process, not just the result.\n'
          'CTA (55-60s): Follow for part 2, and comment: what is your biggest struggle with $t?',
    };
  }

  // ----------------------------------------------------------------- story

  /// Returns {'title': ..., 'body': ...}. lengthIdx: 0 short, 1 medium, 2 long.
  static Map<String, String> buildStory(
      String idea, int lengthIdx, String lang) {
    final t = idea.trim().isEmpty ? 'a new beginning' : idea.trim();
    final paras = <String>[];
    if (_isUr(lang)) {
      paras.add(
          'Ye kahani hai $t ki. Ek aam sa din tha, lekin kuch ghair-mamooli honay wala tha.');
      paras.add(
          'Har kahani me ek mor aata hai — yahan bhi aaya. Himmat ne haar ko peeche chhor diya, aur qadam aagay barh gaye.');
      if (lengthIdx >= 1) {
        paras.add(
            'Raste me mushkilat aayen, logon ne kaha ye mumkin nahi. Lekin dil me ek chingari thi jo bujhne ka naam nahi le rahi thi.');
        paras.add(
            'Waqt guzarta gaya, mehnat rang laane lagi. Chhoti jeetain bari umeedon me badal gayin.');
      }
      if (lengthIdx >= 2) {
        paras.add(
            'Phir ek din sab kuch badal gaya — woh lamha jiska intezar tha, aakhir aa hi gaya. Aankhon me aansu thay, lekin ye khushi ke thay.');
        paras.add(
            'Aaj jab peeche mur kar dekhtay hain, to har dard ek tohfa lagta hai. Kahani khatm nahi hui — ye to bas shuruat thi.');
      }
      return {
        'title': t,
        'body': paras.join('\n\n'),
      };
    }
    paras.add(
        'This is a story about $t. It began on an ordinary day — the kind you forget — until one small moment changed everything.');
    paras.add(
        'Every story has a turning point. Here, it came quietly: a choice between giving up and going on. Going on won.');
    if (lengthIdx >= 1) {
      paras.add(
          'The road was not easy. Doubts arrived dressed as advice, and setbacks arrived uninvited. But each one taught something the easy days never could.');
      paras.add(
          'Slowly, effort compounded. Small wins stacked into confidence, and confidence into momentum.');
    }
    if (lengthIdx >= 2) {
      paras.add(
          'Then came the day everything shifted — the moment all the quiet work had been building toward. It felt less like luck and more like arrival.');
      paras.add(
          'Looking back now, every scar reads like a signature. The story is not over; this was only the first chapter.');
    }
    return {
      'title': t,
      'body': paras.join('\n\n'),
    };
  }

  // --------------------------------------------------------------- captions

  /// Returns 5 x {'text': ..., 'hashtags': ...}.
  static List<Map<String, String>> buildCaptions(String topic, String lang) {
    final t = topic.trim().isEmpty ? 'today' : topic.trim();
    final tag = '#${t.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').take(20)}';
    final tags = '$tag #virello #contentcreator #growth #trending';
    if (_isUr(lang)) {
      return [
        {'text': '$t — aaj ka din isi naam! Kaun agree karta hai?', 'hashtags': tags},
        {'text': 'Chhota qadam, bara khwab. $t ka safar jari hai.', 'hashtags': tags},
        {'text': 'Ye wali feeling sirf $t walay samjhenge.', 'hashtags': tags},
        {'text': '$t: mehnat + sabr = kamyabi. Save kar lo!', 'hashtags': tags},
        {'text': 'Comment me batao — $t me aapki sab se bari jeet kya thi?', 'hashtags': tags},
      ];
    }
    return [
      {'text': 'POV: $t finally makes sense.', 'hashtags': tags},
      {'text': 'Small steps, big vision. The $t journey continues.', 'hashtags': tags},
      {'text': 'Only real ones understand this $t feeling.', 'hashtags': tags},
      {'text': '$t rule #1: consistency beats motivation. Save this.', 'hashtags': tags},
      {'text': 'What is your biggest win with $t so far? Tell me below.', 'hashtags': tags},
    ];
  }

  // -------------------------------------------------------------- conversion

  /// Converts raw text into the requested format. formatKey is one of
  /// video_script | carousel | thread | story_caption.
  static String buildConversion(String raw, String formatKey, String lang) {
    final t = raw.trim().isEmpty ? 'your idea' : raw.trim();
    final firstSentence = t.split(RegExp(r'[.!?\n]')).first.trim();
    switch (formatKey) {
      case 'carousel':
        return 'SLIDE 1 (cover): $firstSentence\n'
            'SLIDE 2: The problem — why this matters right now.\n'
            'SLIDE 3: The insight — the one thing most people miss.\n'
            'SLIDE 4: The proof — a quick example from real life.\n'
            'SLIDE 5 (CTA): Save this and follow for more.';
      case 'thread':
        return '1/ $firstSentence\n\n'
            '2/ Here is why it matters more than you think.\n\n'
            '3/ The mistake almost everyone makes (and how to avoid it).\n\n'
            '4/ The simple framework that actually works.\n\n'
            '5/ TL;DR: start small, stay consistent. Repost if this helped.';
      case 'story_caption':
        return '$firstSentence ✨\n\n'
            'Tap through — this one is worth your 10 seconds.\n'
            '#storytime';
      case 'video_script':
      default:
        final s = buildScript(t, 'Bold', lang);
        return '${s['title']}\n\n${s['body']}';
    }
  }
}

extension _Take on String {
  String take(int n) => length <= n ? this : substring(0, n);
}
