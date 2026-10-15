import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../services/looks.dart';
import '../services/store.dart';

class EditScreen extends StatefulWidget {
  const EditScreen({super.key});

  @override
  State<EditScreen> createState() => _EditScreenState();
}

class _EditScreenState extends State<EditScreen> {
  final _picker = ImagePicker();
  List<XFile> _photos = [];
  List<String> _edited = [];
  late Look _look;
  late double _strength;
  bool _busy = false;
  int _done = 0;
  bool _showOriginal = false;

  @override
  void initState() {
    super.initState();
    _look = lookByName(Store.instance.myLook);
    _strength = Store.instance.myLookStrength;
  }

  Future<void> _pick() async {
    final picked = await _picker.pickMultiImage(limit: 20);
    if (picked.isEmpty) return;
    setState(() {
      _photos = picked;
      _edited = [];
    });
  }

  Future<void> _applyAll() async {
    if (_photos.isEmpty) return;
    setState(() {
      _busy = true;
      _done = 0;
    });
    final messenger = ScaffoldMessenger.of(context);
    final dir = await getTemporaryDirectory();
    final matrix = _look.matrix(_strength);
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final out = <String>[];
    var saved = 0;
    try {
      for (var i = 0; i < _photos.length; i++) {
        final path = await compute(processPhoto, <String, Object>{
          'in': _photos[i].path,
          'out': '${dir.path}/postpal_${stamp}_$i.jpg',
          'matrix': matrix,
        });
        out.add(path);
        try {
          await Gal.putImage(path, album: 'PostPal');
          saved++;
        } catch (_) {
          // Saving can fail if gallery access is denied; sharing still works.
        }
        if (mounted) setState(() => _done = i + 1);
      }
      await Store.instance.saveMyLook(_look.name, _strength);
      messenger.showSnackBar(SnackBar(
        content: Text(saved == out.length
            ? 'Saved ${out.length} photo(s) to your PostPal album'
            : 'Edited ${out.length} photo(s). Allow gallery access to save them.'),
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Something went wrong: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _edited = out;
        });
      }
    }
  }

  Future<void> _share() async {
    if (_edited.isEmpty) return;
    await SharePlus.instance.share(ShareParams(
      files: [for (final p in _edited) XFile(p)],
    ));
  }

  @override
  Widget build(BuildContext context) {
    final matrix = _look.matrix(_strength);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Your look', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 4),
        const Text(
            'Pick one subtle look and use it on every post. A consistent, natural edit makes your feed look like you, not a filter.'),
        const SizedBox(height: 12),
        if (_photos.isEmpty)
          _PickCard(onPick: _pick)
        else ...[
          GestureDetector(
            onLongPressStart: (_) => setState(() => _showOriginal = true),
            onLongPressEnd: (_) => setState(() => _showOriginal = false),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 4 / 5,
                child: PageView.builder(
                  itemCount: _photos.length,
                  itemBuilder: (_, i) {
                    final image = Image.file(File(_photos[i].path), fit: BoxFit.cover);
                    return _showOriginal
                        ? image
                        : ColorFiltered(
                            colorFilter: ColorFilter.matrix(matrix), child: image);
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${_photos.length} photo(s) · swipe to check each · hold to see the original',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 16),
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: looks.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) => ChoiceChip(
              label: Text(looks[i].name),
              selected: looks[i].name == _look.name,
              onSelected: (_) => setState(() => _look = looks[i]),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(_look.description),
        Row(
          children: [
            const Text('Strength'),
            Expanded(
              child: Slider(
                value: _strength,
                onChanged: (v) => setState(() => _strength = v),
              ),
            ),
            Text('${(_strength * 100).round()}%'),
          ],
        ),
        const SizedBox(height: 8),
        if (_photos.isNotEmpty) ...[
          FilledButton.icon(
            onPressed: _busy ? null : _applyAll,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.auto_fix_high),
            label: Text(_busy
                ? 'Editing $_done of ${_photos.length}…'
                : 'Apply to all ${_photos.length} & save'),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _pick,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Pick again'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _edited.isEmpty || _busy ? null : _share,
                  icon: const Icon(Icons.ios_share),
                  label: const Text('Share'),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 20),
        const _VideoCard(),
      ],
    );
  }
}

class _PickCard extends StatelessWidget {
  const _PickCard({required this.onPick});
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onPick,
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 40, horizontal: 16),
          child: Column(
            children: [
              Icon(Icons.add_photo_alternate_outlined, size: 48),
              SizedBox(height: 8),
              Text('Choose photos', style: TextStyle(fontWeight: FontWeight.w600)),
              SizedBox(height: 4),
              Text('Pick up to 20 and edit them all in one go.',
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

class _VideoCard extends StatelessWidget {
  const _VideoCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.movie_edit),
              const SizedBox(width: 8),
              Text('Reels in 5 minutes',
                  style: Theme.of(context).textTheme.titleMedium),
            ]),
            const SizedBox(height: 8),
            const Text('1. In CapCut, edit one Reel you love: cuts, text style, music.'),
            const Text('2. Save it as your template (or duplicate the project).'),
            const Text('3. Each week, swap in clips from your shot list.'),
            const Text('4. Skip AI beauty filters and heavy effects. Real looks better.'),
            const Text('5. Plan it in the Plan tab so PostPal reminds you to post.'),
          ],
        ),
      ),
    );
  }
}
