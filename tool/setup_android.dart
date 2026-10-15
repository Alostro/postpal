// Configures the generated Android project for PostPal.
// Run once after `flutter create --platforms=android .`:
//   dart tool/setup_android.dart
// Safe to run more than once.
import 'dart:io';

void main() {
  _patchManifest();
  _patchGradle();
  stdout.writeln('Android project configured for PostPal.');
}

void _patchManifest() {
  final file = File('android/app/src/main/AndroidManifest.xml');
  if (!file.existsSync()) {
    stderr.writeln('Missing ${file.path}. Run: flutter create --platforms=android .');
    exit(1);
  }
  var xml = file.readAsStringSync();

  xml = xml.replaceFirst(RegExp(r'android:label="[^"]*"'), 'android:label="PostPal"');

  const permissions = <String>[
    'android.permission.INTERNET" />',
    'android.permission.POST_NOTIFICATIONS" />',
    'android.permission.RECEIVE_BOOT_COMPLETED" />',
    'android.permission.VIBRATE" />',
    'android.permission.WAKE_LOCK" />',
    'android.permission.USE_FULL_SCREEN_INTENT" />',
    // Lets reminders ring at the exact minute, like an alarm clock.
    'android.permission.USE_EXACT_ALARM" />',
    'android.permission.SCHEDULE_EXACT_ALARM" android:maxSdkVersion="32" />',
    'android.permission.WRITE_EXTERNAL_STORAGE" android:maxSdkVersion="29" />',
  ];
  for (final perm in permissions) {
    final name = perm.substring(0, perm.indexOf('"'));
    if (!xml.contains('"$name"')) {
      xml = xml.replaceFirst(
          '<application', '<uses-permission android:name="$perm\n    <application');
    }
  }

  // Alarm reminders can light up the screen and show over the lock screen.
  if (!xml.contains('android:showWhenLocked')) {
    xml = xml.replaceFirst('<activity',
        '<activity\n            android:showWhenLocked="true"\n            android:turnScreenOn="true"');
  }

  const receivers = '''
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
                <action android:name="android.intent.action.QUICKBOOT_POWERON" />
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
            </intent-filter>
        </receiver>
''';
  if (!xml.contains('ScheduledNotificationReceiver')) {
    xml = xml.replaceFirst('</application>', '$receivers    </application>');
  }

  // Lets the gallery save work on Android 9 and older.
  if (!xml.contains('requestLegacyExternalStorage')) {
    xml = xml.replaceFirst('<application', '<application\n        android:requestLegacyExternalStorage="true"');
  }

  file.writeAsStringSync(xml);
}

void _patchGradle() {
  final kts = File('android/app/build.gradle.kts');
  final groovy = File('android/app/build.gradle');
  final isKts = kts.existsSync();
  final file = isKts ? kts : groovy;
  if (!file.existsSync()) {
    stderr.writeln('Could not find android/app/build.gradle(.kts)');
    exit(1);
  }
  var gradle = file.readAsStringSync();
  if (gradle.contains('desugar_jdk_libs')) return;

  // Required by flutter_local_notifications.
  final enable = isKts
      ? 'isCoreLibraryDesugaringEnabled = true'
      : 'coreLibraryDesugaringEnabled true';
  if (gradle.contains('compileOptions {')) {
    gradle = gradle.replaceFirst('compileOptions {', 'compileOptions {\n        $enable');
  } else {
    gradle = gradle.replaceFirst(
        'android {', 'android {\n    compileOptions {\n        $enable\n    }');
  }

  final dep = isKts
      ? 'coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")'
      : "coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'";
  gradle = '$gradle\ndependencies {\n    $dep\n}\n';

  file.writeAsStringSync(gradle);
}
