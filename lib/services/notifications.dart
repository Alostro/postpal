import 'dart:typed_data';

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

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  /// Rings like an alarm clock: alarm volume (works on silent), keeps
  /// ringing until you tap or swipe it, and lights up the screen.
  static final NotificationDetails _alarm = NotificationDetails(
    android: AndroidNotificationDetails(
      'postpal_alarm',
      'Alarm reminders',
      channelDescription: 'Loud reminders that ring until you respond',
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.alarm,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      sound: const UriAndroidNotificationSound('content://settings/system/alarm_alert'),
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 800, 400, 800, 400, 800]),
      fullScreenIntent: true,
      visibility: NotificationVisibility.public,
      // FLAG_INSISTENT: repeat the sound until the notification is handled.
      additionalFlags: Int32List.fromList(<int>[4]),
    ),
  );

  /// A normal, single notification sound.
  static const NotificationDetails _gentle = NotificationDetails(
    android: AndroidNotificationDetails(
      'postpal_reminders',
      'Reminders',
      channelDescription: 'Filming, editing and posting reminders',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  NotificationDetails get _details =>
      Store.instance.alarmSound ? _alarm : _gentle;

  Future<void> init() async {
    tzdata.initializeTimeZones();
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(settings);
  }

  /// Asks for notification permission and, where Android needs it,
  /// permission to ring at an exact time.
  Future<bool> requestPermission() async {
    final android = _android;
    if (android == null) return true;
    final allowed = await android.requestNotificationsPermission() ?? true;
    try {
      if (await android.canScheduleExactNotifications() == false) {
        await android.requestExactAlarmsPermission();
      }
    } catch (_) {}
    return allowed;
  }

  /// Exact alarm-clock timing when allowed, otherwise Android's best effort.
  Future<AndroidScheduleMode> _mode() async {
    try {
      if (await _android?.canScheduleExactNotifications() ?? false) {
        return AndroidScheduleMode.alarmClock;
      }
    } catch (_) {}
    return AndroidScheduleMode.inexactAllowWhileIdle;
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
      androidScheduleMode: await _mode(),
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
      androidScheduleMode: await _mode(),
    );
  }

  /// Re-schedules everything, e.g. after switching between alarm and gentle sound.
  Future<void> rescheduleAll() async {
    final store = Store.instance;
    await applyReminderSettings(store.reminders);
    for (final p in store.posts) {
      await schedulePost(p, enabled: store.reminders.postAlertsOn);
    }
  }

  Future<void> cancelPost(int id) => _plugin.cancel(postId(id));

  Future<void> showTest() => _plugin.show(
        99,
        'PostPal reminders are on ✅',
        Store.instance.alarmSound
            ? 'This is your alarm. Tap or swipe it to stop the ringing.'
            : 'This is what your reminders will look like.',
        _details,
      );
}
