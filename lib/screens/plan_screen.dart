import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/notifications.dart';
import '../services/store.dart';

const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];
const postTypes = ['Reel', 'Photo', 'Carousel', 'Story'];

String two(int n) => n.toString().padLeft(2, '0');
String formatWhen(DateTime d) =>
    '${_days[d.weekday - 1]} ${d.day} ${_months[d.month - 1]} · ${two(d.hour)}:${two(d.minute)}';

IconData typeIcon(String type) => switch (type) {
      'Reel' => Icons.movie_outlined,
      'Carousel' => Icons.view_carousel_outlined,
      'Story' => Icons.amp_stories_outlined,
      _ => Icons.photo_outlined,
    };

class PlanScreen extends StatelessWidget {
  const PlanScreen({super.key, required this.onWriteCaption});

  final VoidCallback onWriteCaption;

  @override
  Widget build(BuildContext context) {
    final store = Store.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final now = DateTime.now();
        final weekStart = DateTime(now.year, now.month, now.day - (now.weekday - 1));
        final weekEnd = weekStart.add(const Duration(days: 7));
        final thisWeek = store.posts
            .where((p) => !p.when.isBefore(weekStart) && p.when.isBefore(weekEnd))
            .toList();
        final postedCount = thisWeek.where((p) => p.posted).length;

        final upcoming = store.sortedPosts.where((p) => !p.posted).toList();
        final done = store.sortedPosts.where((p) => p.posted).toList().reversed.toList();

        return Scaffold(
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => showPostEditor(context),
            icon: const Icon(Icons.add),
            label: const Text('Plan a post'),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              Text('Your plan', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 12),
              _WeekCard(planned: thisWeek.length, posted: postedCount),
              const SizedBox(height: 20),
              if (upcoming.isEmpty)
                _EmptyPlan(onWriteCaption: onWriteCaption)
              else ...[
                Text('Coming up', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                for (final p in upcoming) _PostTile(post: p),
              ],
              if (done.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text('Posted', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                for (final p in done.take(10)) _PostTile(post: p),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _WeekCard extends StatelessWidget {
  const _WeekCard({required this.planned, required this.posted});
  final int planned;
  final int posted;

  @override
  Widget build(BuildContext context) {
    const goal = 4;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This week',
                style: TextStyle(color: scheme.onPrimaryContainer, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('$posted posted · $planned planned · goal $goal',
                style: TextStyle(color: scheme.onPrimaryContainer)),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: (posted / goal).clamp(0, 1).toDouble(),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              posted >= goal
                  ? 'Goal hit. Consistency is what grows accounts 🔥'
                  : 'Posting 3–4 times a week beats daily bursts.',
              style: TextStyle(color: scheme.onPrimaryContainer, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyPlan extends StatelessWidget {
  const _EmptyPlan({required this.onWriteCaption});
  final VoidCallback onWriteCaption;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(Icons.event_available_outlined, size: 40),
            const SizedBox(height: 8),
            const Text('Nothing planned yet',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            const Text(
              'Plan your posts for the week and PostPal will remind you when it\'s time.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onWriteCaption,
              icon: const Icon(Icons.edit_note),
              label: const Text('Start with a caption'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PostTile extends StatelessWidget {
  const _PostTile({required this.post});
  final PlannedPost post;

  @override
  Widget build(BuildContext context) {
    final overdue = !post.posted && post.when.isBefore(DateTime.now());
    return Card(
      child: ListTile(
        leading: Icon(typeIcon(post.type)),
        title: Text(post.title.isEmpty ? post.type : post.title,
            style: TextStyle(
                decoration: post.posted ? TextDecoration.lineThrough : null)),
        subtitle: Text(
          '${post.type} · ${formatWhen(post.when)}${overdue ? ' · due' : ''}',
          style: overdue
              ? TextStyle(color: Theme.of(context).colorScheme.error)
              : null,
        ),
        trailing: Checkbox(
          value: post.posted,
          onChanged: (v) async {
            post.posted = v ?? false;
            await Store.instance.upsertPost(post);
            await Notifications.instance.schedulePost(post,
                enabled: Store.instance.reminders.postAlertsOn);
          },
        ),
        onTap: () => _showActions(context, post),
      ),
    );
  }

  void _showActions(BuildContext context, PlannedPost post) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(post.title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              if (post.caption.isNotEmpty)
                Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SingleChildScrollView(child: Text(post.caption)),
                ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: post.caption.isEmpty
                    ? null
                    : () {
                        Clipboard.setData(ClipboardData(text: post.caption));
                        Navigator.pop(sheet);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text('Caption copied. Paste it in Instagram.')));
                      },
                icon: const Icon(Icons.copy),
                label: const Text('Copy caption'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(sheet);
                  showPostEditor(context, existing: post);
                },
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit'),
              ),
              TextButton.icon(
                onPressed: () async {
                  Navigator.pop(sheet);
                  await Notifications.instance.cancelPost(post.id);
                  await Store.instance.deletePost(post.id);
                },
                icon: const Icon(Icons.delete_outline),
                label: const Text('Delete'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens the add/edit form. [caption] pre-fills a new post's caption.
Future<bool> showPostEditor(BuildContext context,
    {PlannedPost? existing, String? caption, String? title}) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _PostEditor(existing: existing, caption: caption, title: title),
  );
  return saved ?? false;
}

class _PostEditor extends StatefulWidget {
  const _PostEditor({this.existing, this.caption, this.title});
  final PlannedPost? existing;
  final String? caption;
  final String? title;

  @override
  State<_PostEditor> createState() => _PostEditorState();
}

class _PostEditorState extends State<_PostEditor> {
  late final TextEditingController _title;
  late final TextEditingController _caption;
  late String _type;
  late DateTime _when;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? widget.title ?? '');
    _caption = TextEditingController(text: e?.caption ?? widget.caption ?? '');
    _type = e?.type ?? 'Reel';
    final now = DateTime.now();
    // Default: tomorrow at 18:30, a good evening slot.
    _when = e?.when ?? DateTime(now.year, now.month, now.day + 1, 18, 30);
  }

  @override
  void dispose() {
    _title.dispose();
    _caption.dispose();
    super.dispose();
  }

  Future<void> _pickWhen() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _when,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_when),
    );
    if (time == null || !mounted) return;
    setState(() => _when =
        DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  Future<void> _save() async {
    final store = Store.instance;
    final post = widget.existing ??
        PlannedPost(id: store.newId(), title: '', caption: '', when: _when);
    post
      ..title = _title.text.trim().isEmpty ? _type : _title.text.trim()
      ..caption = _caption.text
      ..type = _type
      ..when = _when;
    await store.upsertPost(post);
    if (store.reminders.postAlertsOn) {
      await Notifications.instance.requestPermission();
    }
    await Notifications.instance
        .schedulePost(post, enabled: store.reminders.postAlertsOn);
    if (mounted) Navigator.pop(context, true);
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
            Text(widget.existing == null ? 'Plan a post' : 'Edit post',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: 'What is it?',
                hintText: 'e.g. Ribs spot review',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: [
                for (final t in postTypes)
                  ButtonSegment(value: t, label: Text(t)),
              ],
              selected: {_type},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule),
              title: Text(formatWhen(_when)),
              subtitle: const Text('You\'ll get a reminder at this time'),
              trailing: const Icon(Icons.edit_calendar_outlined),
              onTap: _pickWhen,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _caption,
              minLines: 3,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: 'Caption',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _save, child: const Text('Save')),
          ],
        ),
      ),
    );
  }
}
