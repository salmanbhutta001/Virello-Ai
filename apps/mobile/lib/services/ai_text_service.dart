import 'dart:convert';

import 'package:http/http.dart' as http;

/// Central AI text generation service for Virello Create Hub.
///
/// Uses the Pollinations OpenAI-compatible endpoint
/// (https://text.pollinations.ai/openai) which is free, keyless, and
/// reliable. The legacy GET endpoint (text.pollinations.ai/{prompt})
/// is deprecated and budget-exhausted — do NOT use it.
///
/// All 10 text-generation call sites route through here so the provider
/// can be swapped in one place.
class AiTextService {
  AiTextService._();
  static final AiTextService instance = AiTextService._();

  static const _endpoint = 'https://text.pollinations.ai/openai';
  static const _model = 'openai'; // maps to gpt-oss-20b, free tier

  /// Generate text from a prompt. [system] sets the assistant's role.
  /// Returns the generated text, or null on failure.
  /// Retries once on failure for reliability.
  Future<String?> generate({
    required String prompt,
    String? system,
    int maxTokens = 1500,
    double temperature = 0.85,
    Duration timeout = const Duration(seconds: 120),
  }) async {
    // First attempt.
    var result = await _attempt(
      prompt: prompt,
      system: system,
      maxTokens: maxTokens,
      temperature: temperature,
      timeout: timeout,
    );
    // One retry on failure (transient network/model hiccups).
    result ??= await _attempt(
      prompt: prompt,
      system: system,
      maxTokens: maxTokens,
      temperature: temperature,
      timeout: timeout,
    );
    return result;
  }

  Future<String?> _attempt({
    required String prompt,
    String? system,
    required int maxTokens,
    required double temperature,
    required Duration timeout,
  }) async {
    final messages = <Map<String, String>>[];
    if (system != null && system.isNotEmpty) {
      messages.add({'role': 'system', 'content': system});
    }
    messages.add({'role': 'user', 'content': prompt});

    try {
      final res = await http
          .post(
            Uri.parse(_endpoint),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'model': _model,
              'messages': messages,
              'max_tokens': maxTokens,
              'temperature': temperature,
              'private': true,
            }),
          )
          .timeout(timeout);

      if (res.statusCode != 200) return null;

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final choices = data['choices'] as List?;
      if (choices == null || choices.isEmpty) return null;
      final message = (choices[0] as Map)['message'] as Map?;
      final content = message?['content']?.toString().trim();
      if (content == null || content.isEmpty) return null;
      return content;
    } catch (_) {
      return null;
    }
  }
}
