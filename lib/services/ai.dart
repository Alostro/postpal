import 'dart:convert';

import 'package:http/http.dart' as http;

import 'store.dart';

/// Which AI service drafts captions. The user brings their own API key.
enum AiProvider {
  gemini('Google Gemini', 'gemini-2.5-flash', 'Has a free tier. Get a key at aistudio.google.com'),
  claude('Anthropic Claude', 'claude-haiku-5-5', 'Paid per use. Get a key at console.anthropic.com');

  const AiProvider(this.label, this.defaultModel, this.help);
  final String label;
  final String defaultModel;
  final String help;

  static AiProvider byName(String name) =>
      values.firstWhere((p) => p.name == name, orElse: () => gemini);
}

class AiException implements Exception {
  AiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class CaptionAi {
  CaptionAi._();
  static final CaptionAi instance = CaptionAi._();

  static const _system = '''
You help a young South African creator write Instagram captions.
Write like a real person texting friends, not like a brand or an AI.
Rules:
- Use only facts from the notes. Never invent prices, dishes, names or places.
- Short sentences. Natural, everyday English (light SA slang is fine if it fits).
- At most 2 emojis per caption. No hashtags. No quotation marks around the caption.
- Avoid AI-sounding words: "elevate", "delve", "vibrant", "culinary journey", "unforgettable", "embark", "nestled", "tantalizing", "testament".
- End with a simple question or call to action only when it feels natural.
Return exactly 3 different options separated by a line containing only ---
and nothing else (no numbering, no intro, no notes).''';

  String _prompt({
    required String notes,
    required String postType,
    required String tone,
    required String voiceSamples,
  }) {
    final b = StringBuffer()
      ..writeln('Post type: $postType')
      ..writeln('Tone: $tone')
      ..writeln()
      ..writeln('My notes:')
      ..writeln(notes.trim());
    if (voiceSamples.trim().isNotEmpty) {
      b
        ..writeln()
        ..writeln('Captions I wrote before. Match this voice, length and emoji habits:')
        ..writeln(voiceSamples.trim());
    }
    return b.toString();
  }

  /// Returns up to 3 caption drafts.
  Future<List<String>> draftCaptions({
    required String notes,
    required String postType,
    required String tone,
  }) async {
    final store = Store.instance;
    final key = store.aiKey.trim();
    if (key.isEmpty) {
      throw AiException('Add your API key first (tap the ⚙ on the AI card).');
    }
    final provider = AiProvider.byName(store.aiProvider);
    final model = store.aiModel.trim().isEmpty ? provider.defaultModel : store.aiModel.trim();
    final prompt = _prompt(
      notes: notes,
      postType: postType,
      tone: tone,
      voiceSamples: store.voiceSamples,
    );

    final text = switch (provider) {
      AiProvider.gemini => await _gemini(key, model, prompt),
      AiProvider.claude => await _claude(key, model, prompt),
    };

    final options = text
        .split(RegExp(r'^\s*---+\s*$', multiLine: true))
        .map((s) => s.trim().replaceAll(RegExp(r'^(Option\s*)?\d+[.):]\s*', caseSensitive: false), ''))
        .where((s) => s.isNotEmpty)
        .take(3)
        .toList();
    if (options.isEmpty) throw AiException('The AI sent back an empty answer. Try again.');
    return options;
  }

  Future<String> _gemini(String key, String model, String prompt) async {
    final res = await http
        .post(
          Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent'),
          headers: {'content-type': 'application/json', 'x-goog-api-key': key},
          body: jsonEncode({
            'systemInstruction': {
              'parts': [
                {'text': _system}
              ]
            },
            'contents': [
              {
                'role': 'user',
                'parts': [
                  {'text': prompt}
                ]
              }
            ],
            'generationConfig': {'temperature': 0.9, 'maxOutputTokens': 1024},
          }),
        )
        .timeout(const Duration(seconds: 45));
    final data = _decode(res);
    try {
      final parts = data['candidates'][0]['content']['parts'] as List;
      return parts.map((p) => p['text'] ?? '').join();
    } catch (_) {
      throw AiException('Gemini didn\'t return a caption. Try different notes.');
    }
  }

  Future<String> _claude(String key, String model, String prompt) async {
    final res = await http
        .post(
          Uri.parse('https://api.anthropic.com/v1/messages'),
          headers: {
            'content-type': 'application/json',
            'x-api-key': key,
            'anthropic-version': '2023-06-01',
          },
          body: jsonEncode({
            'model': model,
            'max_tokens': 1024,
            'system': _system,
            'messages': [
              {'role': 'user', 'content': prompt}
            ],
          }),
        )
        .timeout(const Duration(seconds: 45));
    final data = _decode(res);
    final content = data['content'];
    if (content is! List) throw AiException('Claude didn\'t return a caption.');
    return content.where((c) => c['type'] == 'text').map((c) => c['text']).join();
  }

  Map<String, dynamic> _decode(http.Response res) {
    Map<String, dynamic> data;
    try {
      data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw AiException('Unexpected reply from the AI service (${res.statusCode}).');
    }
    if (res.statusCode >= 400) {
      final err = data['error'];
      final msg = err is Map ? (err['message'] ?? '').toString() : '';
      throw AiException(switch (res.statusCode) {
        400 => 'The AI service rejected the request. $msg',
        401 || 403 => 'Your API key was not accepted. Check it in AI settings.',
        404 => 'Model not found. Check the model name in AI settings. $msg',
        429 => 'Too many requests or out of credit. Wait a minute and try again.',
        _ => 'AI service error ${res.statusCode}. $msg',
      });
    }
    return data;
  }
}
