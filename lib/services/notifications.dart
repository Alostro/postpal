import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'store.dart';

/// Local reminders that fire on the phone, even when the app is closed.
class Notifications {
  Notifications._();
  static final Notifications instance = Notifications._();

  static const int weeklyId = 1;
  static const int outingId = 2;
  static int postId(int id) => 1000 + id;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const NotificationDetails _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'postpal_reminders',
      'Reminders',
      channelDescription: 'Filming, editing and posting reminders',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  Future<void> init() async {
    tzdata.initializeTimeZones();
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(settings);
  }

  Future<bool> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? true;
  }

  /// Next time it is [weekday] at [hour]:[minute] on the phone's clock.
  tz.TZDateTime _nextWeekly(int weekday, int hour, int minute) {
    final now = DateTime.now();
    var t = DateTime(now.year, now.month, now.day, hour, minute);
    var guard = 0;
    while ((t.weekday != weekday || !t.isAfter(now)) && guard < 8) {
      t = DateTime(t.year, t.month, t.day + 1, hour, minute);
      guard++;
    }
    return tz.TZDateTime.from(t, tz.UTC);
  }

  Future<void> _weekly(int id, String title, String body, int weekday,
      int hour, int minute) async {
    await _plugin.cancel(id);
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      _nextWeekly(weekday, hour, minute),
      _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  /// Re-applies the weekly reminders from the saved settings.
  Future<void> applyReminderSettings(ReminderSettings r) async {
    if (r.weeklyOn) {
      await _weekly(
        weeklyId,
        'Content session time 🎬',
        'Edit this week\'s clips with your look, then schedule your posts.',
        r.weeklyDay,
        r.weeklyHour,
        r.weeklyMinute,
      );
    } else {
      await _plugin.cancel(weeklyId);
    }

    if (r.outingOn) {
      await _weekly(
        outingId,
        'Going out this weekend? 📸',
        'Open your shot list and film 5 short clips while you\'re there.',
        r.outingDay,
        r.outingHour,
        r.outingMinute,
      );
    } else {
      await _plugin.cancel(outingId);
    }
  }

  /// Reminder at the planned time for a post.
  Future<void> schedulePost(PlannedPost post, {required bool enabled}) async {
    await _plugin.cancel(postId(post.id));
    if (!enabled || post.posted || !post.when.isAfter(DateTime.now())) return;
    await _plugin.zonedSchedule(
      postId(post.id),
      'Time to post: ${post.title}',
      'Your caption is ready in PostPal. Tap Copy, then share.',
      tz.TZDateTime.from(post.when, tz.UTC),
      _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<void> cancelPost(int id) => _plugin.cancel(postId(id));

  Future<void> showTest() => _plugin.show(
        99,
        'PostPal reminders are on ✅',
        'This is what your reminders will look like.',
        _details,
      );
}
