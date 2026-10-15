import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A post you plan to publish on Instagram.
class PlannedPost {
  PlannedPost({
    required this.id,
    required this.title,
    required this.caption,
    required this.when,
    this.type = 'Reel',
    this.posted = false,
  });

  final int id;
  String title;
  String caption;
  DateTime when;
  String type; // Reel, Photo, Carousel, Story
  bool posted;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'caption': caption,
        'when': when.toIso8601String(),
        'type': type,
        'posted': posted,
      };

  factory PlannedPost.fromJson(Map<String, dynamic> j) => PlannedPost(
        id: j['id'] as int,
        title: j['title'] as String? ?? '',
        caption: j['caption'] as String? ?? '',
        when: DateTime.tryParse(j['when'] as String? ?? '') ?? DateTime.now(),
        type: j['type'] as String? ?? 'Reel',
        posted: j['posted'] as bool? ?? false,
      );
}

/// Reminder preferences. Weekdays use DateTime's 1 = Monday ... 7 = Sunday.
class ReminderSettings {
  bool weeklyOn = false;
  int weeklyDay = DateTime.sunday;
  int weeklyHour = 18;
  int weeklyMinute = 0;

  bool outingOn = false;
  int outingDay = DateTime.friday;
  int outingHour = 17;
  int outingMinute = 0;

  bool postAlertsOn = true;

  Map<String, dynamic> toJson() => {
        'weeklyOn': weeklyOn,
        'weeklyDay': weeklyDay,
        'weeklyHour': weeklyHour,
        'weeklyMinute': weeklyMinute,
        'outingOn': outingOn,
        'outingDay': outingDay,
        'outingHour': outingHour,
        'outingMinute': outingMinute,
        'postAlertsOn': postAlertsOn,
      };

  static ReminderSettings fromJson(Map<String, dynamic> j) => ReminderSettings()
    ..weeklyOn = j['weeklyOn'] as bool? ?? false
    ..weeklyDay = j['weeklyDay'] as int? ?? DateTime.sunday
    ..weeklyHour = j['weeklyHour'] as int? ?? 18
    ..weeklyMinute = j['weeklyMinute'] as int? ?? 0
    ..outingOn = j['outingOn'] as bool? ?? false
    ..outingDay = j['outingDay'] as int? ?? DateTime.friday
    ..outingHour = j['outingHour'] as int? ?? 17
    ..outingMinute = j['outingMinute'] as int? ?? 0
    ..postAlertsOn = j['postAlertsOn'] as bool? ?? true;
}

/// Simple app-wide state saved on the phone.
class Store extends ChangeNotifier {
  Store._();
  static final Store instance = Store._();

  late SharedPreferences _prefs;

  List<PlannedPost> posts = [];
  ReminderSettings reminders = ReminderSettings();
  Map<String, bool> shotChecks = {};
  String myLook = 'Natural';
  double myLookStrength = 0.7;
  int _nextId = 1;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    try {
      final raw = _prefs.getString('posts');
      if (raw != null) {
        posts = (jsonDecode(raw) as List)
            .map((e) => PlannedPost.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
      final rem = _prefs.getString('reminders');
      if (rem != null) {
        reminders = ReminderSettings.fromJson(
            Map<String, dynamic>.from(jsonDecode(rem) as Map));
      }
      final checks = _prefs.getString('shotChecks');
      if (checks != null) {
        shotChecks = Map<String, bool>.from(jsonDecode(checks) as Map);
      }
    } catch (_) {
      // Corrupt data shouldn't stop the app from opening.
    }
    myLook = _prefs.getString('myLook') ?? 'Natural';
    myLookStrength = _prefs.getDouble('myLookStrength') ?? 0.7;
    _nextId = _prefs.getInt('nextId') ?? 1;
  }

  int newId() {
    final id = _nextId++;
    _prefs.setInt('nextId', _nextId);
    return id;
  }

  List<PlannedPost> get sortedPosts =>
      [...posts]..sort((a, b) => a.when.compareTo(b.when));

  Future<void> upsertPost(PlannedPost post) async {
    final i = posts.indexWhere((p) => p.id == post.id);
    if (i >= 0) {
      posts[i] = post;
    } else {
      posts.add(post);
    }
    await _savePosts();
  }

  Future<void> deletePost(int id) async {
    posts.removeWhere((p) => p.id == id);
    await _savePosts();
  }

  Future<void> _savePosts() async {
    await _prefs.setString(
        'posts', jsonEncode(posts.map((p) => p.toJson()).toList()));
    notifyListeners();
  }

  Future<void> saveReminders() async {
    await _prefs.setString('reminders', jsonEncode(reminders.toJson()));
    notifyListeners();
  }

  Future<void> setShotCheck(String key, bool value) async {
    shotChecks[key] = value;
    await _prefs.setString('shotChecks', jsonEncode(shotChecks));
    notifyListeners();
  }

  Future<void> resetShotList(String listName) async {
    shotChecks.removeWhere((k, _) => k.startsWith('$listName::'));
    await _prefs.setString('shotChecks', jsonEncode(shotChecks));
    notifyListeners();
  }

  Future<void> saveMyLook(String preset, double strength) async {
    myLook = preset;
    myLookStrength = strength;
    await _prefs.setString('myLook', preset);
    await _prefs.setDouble('myLookStrength', strength);
    notifyListeners();
  }
}
