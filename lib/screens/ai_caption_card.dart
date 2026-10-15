import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/ai.dart';
import '../services/store.dart';
import 'plan_screen.dart';

/// "Draft with AI": turns quick notes into 3 caption options in your voice.
class AiCaptionCard extends StatefulWidget {
  const AiCaptionCard({super.key, required this.onAddedToPlan});
  final VoidCallback onAddedToPlan;

  @override
  State<AiCaptionCard> createState() => _AiCaptionCardState();
}

class _AiCaptionCardState extends State<AiCaptionCard> {
  static const _types = ['Reel', 'Photo', 'Carousel'];
  static const _tones = ['Chill', 'Funny', 'Short & sweet', 'Excited'];

  final _notes = TextEditingController();
  String _type = 'Reel';
  String _tone = 'Chill';
  bool _loading = false;
  String? _error;
  List<String> _options = [];

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _draft() async {
    if (_notes.text.trim().length < 5) {
      setState(() => _error = 'Write a few words about the post first.');
      return;
    }
    if (Store.instance.aiKey.isEmpty) {
      await showAiSettings(context);
      if (!mounted || Store.instance.aiKey.isEmpty) return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final options = await CaptionAi.instance.draftCaptions(
        notes: _notes.text,
        postType: _type,
        tone: _tone,
      );
      if (mounted) setState(() => _options = options);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e is AiException
            ? e.message
            : 'Couldn\'t reach the AI. Check your internet and try again.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, color: scheme.onTertiaryContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Draft with AI',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: scheme.onTertiaryContainer)),
                ),
                IconButton(
                  tooltip: 'AI settings',
                  icon: const Icon(Icons.settings_outlined),
                  color: scheme.onTertiaryContainer,
                  onPressed: () async {
                    await showAiSettings(context);
                    if (mounted) setState(() {});
                  },
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Type quick notes: where, what you had, price, how it felt. You\'ll get 3 drafts to tweak.',
                    style: TextStyle(color: scheme.onTertiaryContainer),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _notes,
                    minLines: 2,
                    maxLines: 5,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText:
                          'e.g. lunch at the new Thai place with my sister, green curry was fire, R180 each, chill vibe, would go back',
                      hintMaxLines: 3,
                      filled: true,
                      fillColor: scheme.surface,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final t in _types)
                        ChoiceChip(
                          label: Text(t),
                          selected: _type == t,
                          onSelected: (_) => setState(() => _type = t),
                        ),
                      const SizedBox(width: 6),
                      for (final t in _tones)
                        ChoiceChip(
                          label: Text(t),
                          selected: _tone == t,
                          onSelected: (_) => setState(() => _tone = t),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _loading ? null : _draft,
                    icon: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.auto_awesome),
                    label: Text(_loading
                        ? 'Writing…'
                        : _options.isEmpty
                            ? 'Draft 3 captions'
                            : 'Try again'),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(_error!, style: TextStyle(color: scheme.error)),
                  ],
                  if (_options.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text('Edit them so they sound 100% like you before posting.',
                        style: TextStyle(
                            color: scheme.onTertiaryContainer, fontSize: 13)),
                    const SizedBox(height: 6),
                    for (final o in _options) _OptionTile(
                      text: o,
                      onAddToPlan: () async {
                        final saved = await showPostEditor(context, caption: o);
                        if (saved) widget.onAddedToPlan();
                      },
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({required this.text, required this.onAddToPlan});
  final String text;
  final VoidCallback onAddToPlan;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 4, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SelectableText(text),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: text));
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Caption copied')));
                  },
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Copy'),
                ),
                TextButton.icon(
                  onPressed: onAddToPlan,
                  icon: const Icon(Icons.event, size: 18),
                  label: const Text('Add to plan'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Settings for the AI writer: service, API key, model and voice samples.
Future<void> showAiSettings(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _AiSettingsSheet(),
  );
}

class _AiSettingsSheet extends StatefulWidget {
  const _AiSettingsSheet();

  @override
  State<_AiSettingsSheet> createState() => _AiSettingsSheetState();
}

class _AiSettingsSheetState extends State<_AiSettingsSheet> {
  final store = Store.instance;
  late AiProvider _provider = AiProvider.byName(store.aiProvider);
  late final _key = TextEditingController(text: store.aiKey);
  late final _model = TextEditingController(text: store.aiModel);
  late final _voice = TextEditingController(text: store.voiceSamples);
  bool _showKey = false;

  @override
  void dispose() {
    _key.dispose();
    _model.dispose();
    _voice.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await store.saveAiSettings(
      provider: _provider.name,
      key: _key.text,
      model: _model.text,
      voice: _voice.text,
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 0, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('AI settings', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            SegmentedButton<AiProvider>(
              segments: [
                for (final p in AiProvider.values)
                  ButtonSegment(value: p, label: Text(p.label)),
              ],
              selected: {_provider},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() {
                _provider = s.first;
                _model.clear();
              }),
            ),
            const SizedBox(height: 6),
            Text(_provider.help, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            TextField(
              controller: _key,
              obscureText: !_showKey,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: 'API key',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_showKey ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _showKey = !_showKey),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _model,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: 'Model (optional)',
                hintText: _provider.defaultModel,
                helperText: 'Leave empty to use ${_provider.defaultModel}',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _voice,
              minLines: 3,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: 'Your voice (recommended)',
                hintText: 'Paste 2–3 captions you wrote yourself so drafts sound like you',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your key stays on this phone and is only sent to the AI service you picked.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _save, child: const Text('Save')),
          ],
        ),
      ),
    );
  }
}
