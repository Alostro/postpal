import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'plan_screen.dart';

/// Fill-in-the-blank caption templates. {field} becomes a text box.
class CaptionTemplate {
  const CaptionTemplate(this.name, this.icon, this.body, this.tags);
  final String name;
  final IconData icon;
  final String body;
  final String tags; // which hashtag set fits best
}

const templates = <CaptionTemplate>[
  CaptionTemplate('Restaurant review', Icons.restaurant, '''📍 {place}, {area}
🍽️ I ordered: {what you ordered}
💸 About R{price} for {how many people}
⭐ Verdict: {rating}/10, {one honest line}

Would you go? Tag who you'd bring 👇''', 'Food'),
  CaptionTemplate('Worth it?', Icons.thumbs_up_down, '''Is {place} worth the hype? 👀

Honestly… {your answer}.
Best thing: {best thing}
Skip: {what to skip}

Save this for your next date night 📌''', 'Food'),
  CaptionTemplate('Graduation', Icons.school, '''{years} years, {a struggle you got through}, and a lot of {coffee/late nights/prayer} later… I'm officially a {qualification} graduate 🎓

To first-year me: {advice to yourself}

Thank you {who you want to thank} ❤️''', 'Grad'),
  CaptionTemplate('Day in my life', Icons.wb_sunny_outlined, '''A day in my life as a {what you do} 🌤️

{highlight of the day}
Lesson of the day: {lesson}

What does your {weekday} look like?''', 'Lifestyle'),
  CaptionTemplate('Weekend recap', Icons.weekend_outlined, '''Weekend in {number} moments ✨

Favourite part: {favourite part}
Would redo: {what you'd do again}

Swipe to the end for {a teaser} ➡️''', 'Lifestyle'),
];

const hashtagSets = <String, String>{
  'Food': '#foodie #foodiesofinstagram #restaurantreview #foodreview #mzansifoodie #saeats #datenight',
  'Grad': '#graduation #graduate #classof2026 #proudmoment #itgraduate #gradszn',
  'Lifestyle': '#dayinmylife #lifestyle #weekendvibes #mzansi #southafrica #youngandgrowing',
};

class WriteScreen extends StatefulWidget {
  const WriteScreen({super.key, required this.onAddedToPlan});
  final VoidCallback onAddedToPlan;

  @override
  State<WriteScreen> createState() => _WriteScreenState();
}

class _WriteScreenState extends State<WriteScreen> {
  static final _field = RegExp(r'\{([^}]+)\}');

  CaptionTemplate _template = templates.first;
  final Map<String, TextEditingController> _controllers = {};
  final Set<String> _tagSets = {'Food'};
  final _extraTags = TextEditingController();

  @override
  void initState() {
    super.initState();
    _useTemplate(templates.first);
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _extraTags.dispose();
    super.dispose();
  }

  List<String> get _fields {
    final seen = <String>{};
    return [
      for (final m in _field.allMatches(_template.body))
        if (seen.add(m.group(1)!)) m.group(1)!
    ];
  }

  void _useTemplate(CaptionTemplate t) {
    _template = t;
    _tagSets
      ..clear()
      ..add(t.tags);
    for (final f in _fields) {
      _controllers.putIfAbsent(f, () => TextEditingController());
    }
  }

  void _setTemplate(CaptionTemplate t) => setState(() => _useTemplate(t));

  String get _caption {
    final body = _template.body.replaceAllMapped(_field, (m) {
      final v = _controllers[m.group(1)!]?.text.trim() ?? '';
      return v.isEmpty ? '…' : v;
    });
    final tags = [
      for (final s in hashtagSets.keys)
        if (_tagSets.contains(s)) hashtagSets[s]!,
      if (_extraTags.text.trim().isNotEmpty) _extraTags.text.trim(),
    ].join(' ');
    return tags.isEmpty ? body : '$body\n\n.\n.\n$tags';
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Captions', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 4),
        const Text('Fill in the blanks in your own words. No robot captions.'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in templates)
              ChoiceChip(
                avatar: Icon(t.icon, size: 18),
                label: Text(t.name),
                selected: t == _template,
                onSelected: (_) => _setTemplate(t),
              ),
          ],
        ),
        const SizedBox(height: 16),
        for (final f in _fields)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: TextField(
              controller: _controllers[f],
              onChanged: (_) => setState(() {}),
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: f[0].toUpperCase() + f.substring(1),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
        const SizedBox(height: 6),
        Text('Hashtags', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: [
            for (final s in hashtagSets.keys)
              FilterChip(
                label: Text(s),
                selected: _tagSets.contains(s),
                onSelected: (on) => setState(
                    () => on ? _tagSets.add(s) : _tagSets.remove(s)),
              ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _extraTags,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'Your own tags (add your city and the place)',
            hintText: '#yourcity #placename',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 16),
        Text('Preview', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: SelectableText(_caption),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _caption));
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Caption copied')));
                },
                icon: const Icon(Icons.copy),
                label: const Text('Copy'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                onPressed: () async {
                  final place = _controllers['place']?.text.trim() ?? '';
                  final saved = await showPostEditor(
                    context,
                    caption: _caption,
                    title: place.isEmpty ? _template.name : place,
                  );
                  if (saved) widget.onAddedToPlan();
                },
                icon: const Icon(Icons.event),
                label: const Text('Add to plan'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
