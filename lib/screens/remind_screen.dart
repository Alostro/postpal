import 'package:flutter/material.dart';

import '../services/notifications.dart';
import '../services/store.dart';
import 'plan_screen.dart' show two;

const _dayNames = [
  'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
];

class RemindScreen extends StatefulWidget {
  const RemindScreen({super.key});

  @override
  State<RemindScreen> createState() => _RemindScreenState();
}

class _RemindScreenState extends State<RemindScreen> {
  final store = Store.instance;
  ReminderSettings get r => store.reminders;

  Future<void> _apply() async {
    if (r.weeklyOn || r.outingOn || r.postAlertsOn) {
      final allowed = await Notifications.instance.requestPermission();
      if (!allowed && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Notifications are blocked. Turn them on for PostPal in your phone settings.'),
        ));
      }
    }
    await store.saveReminders();
    await Notifications.instance.applyReminderSettings(r);
    for (final p in store.posts) {
      await Notifications.instance.schedulePost(p, enabled: r.postAlertsOn);
    }
    if (mounted) setState(() {});
  }

  Future<void> _pickDayTime({
    required int day,
    required int hour,
    required int minute,
    required void Function(int day, int hour, int minute) onPicked,
  }) async {
    final pickedDay = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Which day?'),
        children: [
          for (var i = 0; i < 7; i++)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, i + 1),
              child: Text(_dayNames[i],
                  style: TextStyle(
                      fontWeight: i + 1 == day ? FontWeight.bold : FontWeight.normal)),
            ),
        ],
      ),
    );
    if (pickedDay == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: hour, minute: minute),
    );
    if (time == null) return;
    onPicked(pickedDay, time.hour, time.minute);
    await _apply();
  }

  String _label(int day, int h, int m) => '${_dayNames[day - 1]}s at ${two(h)}:${two(m)}';

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Reminders', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 4),
        const Text('PostPal nudges you at the right moments, so growing your account runs on routine instead of willpower.'),
        const SizedBox(height: 16),
        _ReminderCard(
          icon: Icons.auto_fix_high,
          title: 'Weekly content session',
          body: 'Edit the week\'s clips with your look, write captions, plan posts. About an hour.',
          on: r.weeklyOn,
          when: _label(r.weeklyDay, r.weeklyHour, r.weeklyMinute),
          onToggle: (v) {
            r.weeklyOn = v;
            _apply();
          },
          onChangeTime: () => _pickDayTime(
            day: r.weeklyDay,
            hour: r.weeklyHour,
            minute: r.weeklyMinute,
            onPicked: (d, h, m) => r
              ..weeklyDay = d
              ..weeklyHour = h
              ..weeklyMinute = m,
          ),
        ),
        _ReminderCard(
          icon: Icons.videocam,
          title: 'Weekend filming nudge',
          body: 'A reminder before you go out to film your shot list.',
          on: r.outingOn,
          when: _label(r.outingDay, r.outingHour, r.outingMinute),
          onToggle: (v) {
            r.outingOn = v;
            _apply();
          },
          onChangeTime: () => _pickDayTime(
            day: r.outingDay,
            hour: r.outingHour,
            minute: r.outingMinute,
            onPicked: (d, h, m) => r
              ..outingDay = d
              ..outingHour = h
              ..outingMinute = m,
          ),
        ),
        Card(
          child: SwitchListTile(
            secondary: const Icon(Icons.send),
            title: const Text('Time-to-post alerts'),
            subtitle: const Text('A reminder at the time you planned each post.'),
            value: r.postAlertsOn,
            onChanged: (v) {
              r.postAlertsOn = v;
              _apply();
            },
          ),
        ),
        Card(
          child: SwitchListTile(
            secondary: const Icon(Icons.alarm),
            title: const Text('Ring like an alarm'),
            subtitle: Text(store.alarmSound
                ? 'Loud alarm sound that keeps ringing until you tap or swipe it. Works on silent.'
                : 'Off: reminders use your normal notification sound once.'),
            value: store.alarmSound,
            onChanged: (v) async {
              await store.setAlarmSound(v);
              await _apply(); // re-schedules everything with the new sound
            },
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () async {
            await Notifications.instance.requestPermission();
            await Notifications.instance.showTest();
          },
          icon: const Icon(Icons.notifications_active_outlined),
          label: const Text('Send a test notification'),
        ),
        const SizedBox(height: 16),
        Text(
          'Tip: the best time to post is usually when your followers are free, often 12:00–13:00 or 18:00–21:00. Check Instagram Insights after a few weeks and adjust.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _ReminderCard extends StatelessWidget {
  const _ReminderCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.on,
    required this.when,
    required this.onToggle,
    required this.onChangeTime,
  });

  final IconData icon;
  final String title;
  final String body;
  final bool on;
  final String when;
  final ValueChanged<bool> onToggle;
  final VoidCallback onChangeTime;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          SwitchListTile(
            secondary: Icon(icon),
            title: Text(title),
            subtitle: Text(body),
            value: on,
            onChanged: onToggle,
          ),
          ListTile(
            enabled: on,
            leading: const SizedBox(width: 24),
            title: Text(when),
            trailing: const Icon(Icons.edit_calendar_outlined),
            onTap: on ? onChangeTime : null,
          ),
        ],
      ),
    );
  }
}
