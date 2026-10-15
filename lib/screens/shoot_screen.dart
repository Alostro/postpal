import 'package:flutter/material.dart';

import '../services/store.dart';

class ShotList {
  const ShotList(this.name, this.icon, this.shots);
  final String name;
  final IconData icon;
  final List<(String, String)> shots; // (shot, tip)
}

const shotLists = <ShotList>[
  ShotList('Restaurant outing', Icons.restaurant, [
    ('Walking in / the sign', 'Hook: start outside so people know where you are.'),
    ('Slow pan of the vibe', 'Lights, décor, the view. 3–4 seconds, move slowly.'),
    ('Menu or prices', 'People love knowing what it costs.'),
    ('Food arriving', 'Film from above, then a side angle with steam or sauce.'),
    ('First bite / reaction', 'A real reaction beats a perfect one.'),
    ('Drinks or dessert', 'A second food moment keeps viewers watching.'),
    ('Your verdict to camera', '"Worth it?" + a rating out of 10. Great ending.'),
  ]),
  ShotList('Celebration / event', Icons.celebration, [
    ('Getting ready', 'Outfit, mirror, details. Quick cuts work well.'),
    ('Arriving', 'Wide shot of the venue or crowd.'),
    ('The big moment', 'Walking the stage, cutting the cake, the toast.'),
    ('People you love', 'Hugs, laughs, candid moments.'),
    ('A selfie video message', 'What this moment means to you, in 1–2 lines.'),
    ('The ending', 'Leaving, sunset, or a final group shot.'),
  ]),
  ShotList('Day in my life', Icons.wb_sunny_outlined, [
    ('Morning start', 'Alarm, coffee, window light.'),
    ('Getting to work or class', 'Commute, walking shot, laptop opening.'),
    ('What you\'re working on', 'Screen, notes, the process.'),
    ('Lunch', 'What you ate and where.'),
    ('One fun or real moment', 'Something unplanned makes it human.'),
    ('Evening wind-down', 'End with how you felt about the day.'),
  ]),
];

class ShootScreen extends StatelessWidget {
  const ShootScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = Store.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Shot lists', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 4),
          const Text(
              'Tick shots off while you\'re out. Later, these clips drop straight into your CapCut template.'),
          const SizedBox(height: 12),
          const _TipsCard(),
          const SizedBox(height: 12),
          for (final list in shotLists) _ShotListCard(list: list, store: store),
        ],
      ),
    );
  }
}

class _TipsCard extends StatelessWidget {
  const _TipsCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: DefaultTextStyle.merge(
          style: TextStyle(color: scheme.onSecondaryContainer),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Filming tips', style: TextStyle(fontWeight: FontWeight.w600)),
              SizedBox(height: 6),
              Text('• Film vertical (9:16) and hold each shot 3–5 seconds.'),
              Text('• Wipe your lens first. It makes a huge difference.'),
              Text('• Face the light: sit near windows or warm lamps.'),
              Text('• Move slowly, and grab more clips than you need.'),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShotListCard extends StatelessWidget {
  const _ShotListCard({required this.list, required this.store});
  final ShotList list;
  final Store store;

  @override
  Widget build(BuildContext context) {
    final keys = [for (final s in list.shots) '${list.name}::${s.$1}'];
    final done = keys.where((k) => store.shotChecks[k] ?? false).length;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: Icon(list.icon),
        title: Text(list.name),
        subtitle: Text('$done of ${list.shots.length} shots'),
        children: [
          for (var i = 0; i < list.shots.length; i++)
            CheckboxListTile(
              value: store.shotChecks[keys[i]] ?? false,
              onChanged: (v) => store.setShotCheck(keys[i], v ?? false),
              title: Text(list.shots[i].$1),
              subtitle: Text(list.shots[i].$2),
              controlAffinity: ListTileControlAffinity.leading,
            ),
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 8, bottom: 8),
              child: TextButton.icon(
                onPressed: () => store.resetShotList(list.name),
                icon: const Icon(Icons.restart_alt),
                label: const Text('Reset for next outing'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
