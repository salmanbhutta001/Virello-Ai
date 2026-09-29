import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../services/api_client.dart';
import '../../main.dart';

/// AI Academy (Phase 5): a library of bite-size lessons with real quizzes.
/// Everything — lessons, progress, quiz grading — comes from the backend;
/// nothing is faked client-side.
class AcademyScreen extends StatefulWidget {
  const AcademyScreen({super.key});
  @override
  State<AcademyScreen> createState() => _AcademyScreenState();
}

class _AcademyScreenState extends State<AcademyScreen> {
  // '' = All. Backend categories: content, growth, commerce, marketing.
  String _category = '';
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _lessons = [];
  // lesson_id -> {status, quiz_score, completed_at}.
  Map<String, Map<String, dynamic>> _progress = {};

  AppStrings get s => AppStrings(appState.localeCode);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final lessons = await apiClient.getAcademyLessons(
        category: _category.isEmpty ? null : _category,
        language: appState.localeCode,
      );
      Map<String, Map<String, dynamic>> progress = {};
      try {
        final p = await apiClient.getAcademyProgress();
        for (final e in (p['progress'] as List? ?? [])) {
          final m = Map<String, dynamic>.from(e as Map);
          progress['${m['lesson_id'] ?? ''}'] = m;
        }
      } catch (_) {
        // Progress is nice-to-have; lessons still render without it.
      }
      if (!mounted) return;
      setState(() {
        _lessons =
            lessons.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _progress = progress;
        _loading = false;
      });
    } on AuthException {
      if (!mounted) return;
      setState(() => _loading = false);
      handleAuthFailure(s.sessionExpired);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = s.askFailed;
      });
    }
  }

  String _categoryLabel(String c) {
    switch (c) {
      case 'content':
        return s.categoryContent;
      case 'growth':
        return s.categoryGrowth;
      case 'commerce':
        return s.categoryCommerce;
      case 'marketing':
        return s.categoryMarketing;
      default:
        return c;
    }
  }

  Color _levelColor(String level) {
    switch (level.toLowerCase()) {
      case 'beginner':
        return VirelloColors.success;
      case 'intermediate':
        return VirelloColors.amber;
      default:
        return VirelloColors.danger;
    }
  }

  String _levelLabel(String level) {
    switch (level.toLowerCase()) {
      case 'beginner':
        return s.levelBeginner;
      case 'intermediate':
        return s.levelIntermediate;
      case 'advanced':
        return s.levelAdvanced;
      default:
        return level;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(s.academy)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(s.academyTagline,
                      style: const TextStyle(
                          color: VirelloColors.muted, fontSize: 13)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ('', s.categoryAll),
                      ('content', s.categoryContent),
                      ('growth', s.categoryGrowth),
                      ('commerce', s.categoryCommerce),
                      ('marketing', s.categoryMarketing),
                    ]
                        .map((c) => ChoiceChip(
                              label: Text(c.$2),
                              selected: _category == c.$1,
                              onSelected: (_) {
                                setState(() => _category = c.$1);
                                _load();
                              },
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                  Text(s.lessonLibrary,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Column(
                        children: [
                          Text(_error!,
                              textAlign: TextAlign.center,
                              style:
                                  const TextStyle(color: VirelloColors.danger)),
                          const SizedBox(height: 12),
                          OutlinedButton(
                              onPressed: _load, child: Text(s.tryAgain)),
                        ],
                      ),
                    )
                  else if (_lessons.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 48),
                      child: Column(
                        children: [
                          const Icon(Icons.school_outlined,
                              size: 56, color: VirelloColors.muted),
                          const SizedBox(height: 12),
                          Text(s.noLessons,
                              style: const TextStyle(
                                  color: VirelloColors.muted, fontSize: 15)),
                        ],
                      ),
                    )
                  else
                    for (final l in _lessons) _lessonCard(l),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _lessonCard(Map<String, dynamic> l) {
    final id = '${l['id'] ?? ''}';
    final level = '${l['level'] ?? 'beginner'}';
    final prog = _progress[id];
    final completed = prog != null &&
        ('${prog['status'] ?? ''}'.toLowerCase() == 'completed');
    final started = prog != null && !completed;
    final quizScore = prog?['quiz_score'];
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => LessonDetailScreen(id: id)))
            .then((_) => _load()),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('${l['title'] ?? ''}',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                  if (completed)
                    const Icon(Icons.check_circle,
                        color: VirelloColors.success, size: 22),
                ],
              ),
              const SizedBox(height: 6),
              Text('${l['description'] ?? ''}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: VTheme.textSec(context),
                      fontSize: 13,
                      height: 1.4)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: VirelloColors.pink.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(_categoryLabel('${l['category'] ?? ''}'),
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: VirelloColors.pink)),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _levelColor(level).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(_levelLabel(level),
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _levelColor(level))),
                  ),
                  if (started)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: VTheme.chip(context),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(s.startLesson,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: VTheme.textSec(context))),
                    ),
                  if (quizScore != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: VTheme.chip(context),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.emoji_events_outlined,
                              size: 13, color: VirelloColors.amber),
                          const SizedBox(width: 4),
                          Text('${s.quizScore} $quizScore',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: VTheme.textSec(context))),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lesson detail: sections as heading+body cards, Start button, optional
/// MCQ quiz graded server-side, Mark complete.
class LessonDetailScreen extends StatefulWidget {
  final String id;
  const LessonDetailScreen({super.key, required this.id});

  @override
  State<LessonDetailScreen> createState() => _LessonDetailScreenState();
}

class _LessonDetailScreenState extends State<LessonDetailScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _lesson = {};
  bool _starting = false;
  bool _started = false;
  bool _completing = false;
  bool _completed = false;
  // Quiz state.
  bool _quizMode = false;
  List<Map<String, dynamic>> _questions = [];
  List<int?> _picked = [];
  bool _submitting = false;
  Map<String, dynamic>? _quizResult;

  AppStrings get s => AppStrings(appState.localeCode);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _askCtrl.dispose();
    super.dispose();
  }

  /// AI intelligence: ask anything about this lesson. The AI answers
  /// using the lesson's own content as context (never invented beyond it).
  bool _askAiOpen = false;
  bool _asking = false;
  final _askCtrl = TextEditingController();
  final List<Map<String, String>> _qa = [];

  Future<void> _askAi() async {
    final q = _askCtrl.text.trim();
    if (q.isEmpty || _asking) return;
    setState(() {
      _asking = true;
      _qa.add({'q': q, 'a': ''});
      _askCtrl.clear();
    });
    try {
      final content = _lesson['content'] as Map?;
      final sections = (content?['sections'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      final contextText = sections
          .map((sec) => '${sec['heading']}\n${sec['body']}')
          .join('\n\n');
      final langNote = appState.localeCode == 'ur'
          ? 'Answer in Roman Urdu.'
          : appState.localeCode == 'ar'
              ? 'Answer in Arabic.'
              : 'Answer in English.';
      final prompt =
          'You are Virello AI, a friendly teacher. Answer the student\'s question using ONLY the lesson below. Keep it short (under 80 words). $langNote\n\n'
          'Lesson: ${_lesson['title']}\n$contextText\n\nQuestion: $q';
      final url =
          'https://text.pollinations.ai/${Uri.encodeComponent(prompt)}?model=openai&private=true';
      final res =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 20));
      if (!mounted) return;
      final answer = res.statusCode == 200 && res.body.trim().isNotEmpty
          ? res.body.trim()
          : s.askFailed;
      setState(() {
        _qa.last['a'] = answer;
        _asking = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _qa.last['a'] = s.askFailed;
        _asking = false;
      });
    }
  }

  Widget _askAiCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.auto_awesome_outlined,
                  color: VirelloColors.pink, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(s.academyAskAi,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w800)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: VirelloColors.pink.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  s.boardImageAiLabel,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: VirelloColors.pink,
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 4),
            Text(s.academyAskDesc,
                style: const TextStyle(
                    fontSize: 12.5, color: VirelloColors.muted)),
            if (_askAiOpen) ...[
              const SizedBox(height: 10),
              for (final pair in _qa) ...[
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: VirelloColors.pink.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(pair['q']!,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                ),
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: VTheme.chip(context),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: pair['a']!.isEmpty
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: VirelloColors.pink))
                      : Text(pair['a']!,
                          style: const TextStyle(fontSize: 13, height: 1.5)),
                ),
              ],
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _askCtrl,
                    style: TextStyle(color: VTheme.text(context)),
                    decoration: InputDecoration(
                      hintText: s.academyAskHint,
                      hintStyle:
                          TextStyle(color: VTheme.textSec(context)),
                      filled: true,
                      fillColor: VTheme.chip(context),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                    ),
                    onSubmitted: (_) => _askAi(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _asking ? null : _askAi,
                  icon: _asking
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send_outlined, size: 18),
                  style: IconButton.styleFrom(
                      backgroundColor: VirelloColors.pink),
                ),
              ]),
            ] else ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => setState(() => _askAiOpen = true),
                  icon: const Icon(Icons.chat_bubble_outline, size: 18),
                  label: Text(s.academyAskOpen),
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
    );
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final l = await apiClient.getAcademyLesson(widget.id);
      if (!mounted) return;
      final quiz = l['quiz'] as Map?;
      final questions = (quiz?['questions'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      setState(() {
        _lesson = l;
        _questions = questions;
        _picked = List<int?>.filled(questions.length, null);
        _loading = false;
      });
    } on AuthException {
      if (!mounted) return;
      setState(() => _loading = false);
      handleAuthFailure(s.sessionExpired);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = s.askFailed;
      });
    }
  }

  Future<void> _start() async {
    setState(() => _starting = true);
    try {
      await apiClient.startAcademyLesson(widget.id);
      if (mounted) setState(() => _started = true);
    } catch (_) {
      // Stay on screen; user can still read the lesson.
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _submitQuiz() async {
    if (_submitting || _picked.any((p) => p == null)) return;
    setState(() => _submitting = true);
    try {
      final res = await apiClient.submitAcademyQuiz(
          widget.id, _picked.map((p) => p!).toList());
      if (mounted) setState(() => _quizResult = res);
    } on AuthException {
      if (!mounted) return;
      handleAuthFailure(s.sessionExpired);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(s.askFailed)));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _complete() async {
    setState(() => _completing = true);
    try {
      await apiClient.completeAcademyLesson(widget.id);
      if (mounted) setState(() => _completed = true);
    } on AuthException {
      if (!mounted) return;
      handleAuthFailure(s.sessionExpired);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(s.askFailed)));
      }
    } finally {
      if (mounted) setState(() => _completing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${_lesson['title'] ?? s.academy}')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!,
                          style: const TextStyle(color: VirelloColors.danger)),
                      const SizedBox(height: 12),
                      OutlinedButton(onPressed: _load, child: Text(s.tryAgain)),
                    ],
                  ),
                )
              : _quizMode
                  ? _quizBody()
                  : _contentBody(),
    );
  }

  Widget _contentBody() {
    final content = _lesson['content'] as Map?;
    final sections = (content?['sections'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final hasQuiz = _questions.isNotEmpty;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('${_lesson['title'] ?? ''}',
              style:
                  const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text('${_lesson['description'] ?? ''}',
              style: TextStyle(
                  color: VTheme.textSec(context), fontSize: 14, height: 1.5)),
          const SizedBox(height: 16),
          for (final sec in sections)
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${sec['heading'] ?? ''}',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text('${sec['body'] ?? ''}',
                        style: const TextStyle(fontSize: 14, height: 1.6)),
                  ],
                ),
              ),
            ),
          _askAiCard(),
          const SizedBox(height: 12),
          const SizedBox(height: 8),
          if (!_started && !_completed)
            FilledButton.icon(
              onPressed: _starting ? null : _start,
              icon: const Icon(Icons.play_arrow_outlined, size: 18),
              label: Text(s.startLesson),
            ),
          if (hasQuiz && !_quizMode) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => setState(() {
                _quizMode = true;
                _quizResult = null;
                _picked = List<int?>.filled(_questions.length, null);
              }),
              icon: const Icon(Icons.quiz_outlined, size: 18),
              label: Text(s.takeQuiz),
            ),
          ],
          const SizedBox(height: 8),
          if (_completed)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: VirelloColors.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: VirelloColors.success),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(s.completed,
                          style: const TextStyle(fontWeight: FontWeight.w700))),
                ],
              ),
            )
          else
            OutlinedButton.icon(
              onPressed: _completing ? null : _complete,
              icon: const Icon(Icons.flag_outlined, size: 18),
              label: Text(s.markComplete),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _quizBody() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_quizResult != null) _resultCard(),
                for (var i = 0; i < _questions.length; i++) _questionCard(i),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _quizMode = false),
                    child: const Icon(Icons.arrow_back_outlined),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: (_submitting || _picked.any((p) => p == null))
                        ? null
                        : _submitQuiz,
                    child: _submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text(s.submitQuiz),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _questionCard(int i) {
    final q = _questions[i];
    final options = (q['options'] as List? ?? []).map((e) => '$e').toList();
    final result = _quizResult == null
        ? null
        : ((_quizResult!['results'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .firstWhere((r) => (r['question_index'] as int?) == i,
                orElse: () => <String, dynamic>{}));
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.questionOf(i + 1, _questions.length),
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: VirelloColors.pink)),
            const SizedBox(height: 6),
            Text('${q['q'] ?? ''}',
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            RadioGroup<int>(
              groupValue: _picked[i],
              onChanged: result != null
                  ? (_) {}
                  : (v) => setState(() => _picked[i] = v),
              child: Column(
                children: [
                  for (var oi = 0; oi < options.length; oi++)
                    _optionTile(i, oi, options[oi], result),
                ],
              ),
            ),
            if (result != null && '${result['explanation'] ?? ''}'.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: VTheme.chip(context),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('${result['explanation']}',
                      style: TextStyle(
                          fontSize: 12,
                          height: 1.5,
                          color: VTheme.textSec(context))),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _optionTile(
      int qi, int oi, String text, Map<String, dynamic>? result) {
    final graded = result != null;
    final correctOption = (result?['correct_option'] as int?) ?? -1;
    final isCorrect = graded && oi == correctOption;
    final isWrongPick = graded && !isCorrect && _picked[qi] == oi;
    final selected = !graded && _picked[qi] == oi;
    Color? bg;
    Color? border;
    if (isCorrect) {
      bg = VirelloColors.success.withValues(alpha: 0.12);
      border = VirelloColors.success;
    } else if (isWrongPick) {
      bg = VirelloColors.danger.withValues(alpha: 0.1);
      border = VirelloColors.danger;
    } else if (selected) {
      bg = VirelloColors.pink.withValues(alpha: 0.08);
      border = VirelloColors.pink;
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border ?? VTheme.divider(context), width: 1.2),
      ),
      child: Row(
        children: [
          Radio<int>(
            value: oi,
            activeColor: VirelloColors.pink,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsetsDirectional.only(end: 12),
              child: Text(text, style: const TextStyle(fontSize: 13.5)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultCard() {
    final score = _quizResult!['score'];
    final total = _quizResult!['total'];
    final passed = _quizResult!['passed'] == true;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: (passed ? VirelloColors.success : VirelloColors.amber)
            .withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: (passed ? VirelloColors.success : VirelloColors.amber)
                .withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(passed ? Icons.emoji_events : Icons.refresh_outlined,
              size: 36,
              color: passed ? VirelloColors.success : VirelloColors.amber),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${s.yourScore}: $score / $total',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(passed ? s.passedQuiz : s.keepTrying,
                    style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
