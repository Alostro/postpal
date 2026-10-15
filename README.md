# PostPal

Your Instagram helper: plan posts, follow shot lists, give every photo the same natural look, write captions in your own words, and get reminded at the right time.

## What's inside

| Tab | What it does |
|---|---|
| **Plan** | Plan Reels, photos, carousels and stories with a date, time and caption. Tracks your weekly goal (4 posts) and reminds you when it's time to post. Tap a post to copy its caption. |
| **Shoot** | Shot lists for restaurant outings, celebrations and day-in-my-life videos. Tick clips off while you film. |
| **Edit** | Pick up to 20 photos, choose a subtle look (Natural, Warm, Food pop, Clean, Film, Moody), set the strength and apply it to all of them at once. Saves to a "PostPal" album and can share straight to Instagram. Hold a photo to compare with the original. |
| **Write** | Fill-in-the-blank caption templates (restaurant review, "worth it?", graduation, day in my life, weekend recap) plus hashtag sets. Copy it or add it straight to your plan. |
| **Remind** | Weekly content-session reminder, a weekend filming nudge, and time-to-post alerts. All run on the phone, even with the app closed. |

Videos: PostPal plans and reminds; the actual Reel editing happens in CapCut using one template you reuse (steps are in the Edit tab).

## Get the APK (no setup on your PC)

1. Create a new repository on GitHub (e.g. `postpal`).
2. Upload everything in this folder, including the hidden `.github` folder. Easiest: on the repo page, choose **Add file → Upload files**, then drag the folder contents in. Or with git:
   ```bash
   git init && git add . && git commit -m "PostPal"
   git branch -M main
   git remote add origin https://github.com/<you>/postpal.git
   git push -u origin main
   ```
3. Open the **Actions** tab. The **Build APK** run starts automatically (about 5–8 minutes).
4. When it's green, open the run and download **PostPal-apk** under *Artifacts*. Unzip it to get `app-release.apk`.
5. Send it to your phone, open it, and allow "Install unknown apps" when Android asks.

## Build on your own PC instead

Needs Flutter (3.32 or newer) and Android Studio's SDK.

```bash
flutter create --platforms=android --org com.dintle --project-name postpal .
dart tool/setup_android.dart
flutter pub get
flutter build apk --release
```

The APK lands in `build/app/outputs/flutter-apk/app-release.apk`. To try it on a plugged-in phone: `flutter run`.

## Notes

- The release APK is signed with a debug key: perfect for your own phone, not for the Play Store.
- On first use, allow notifications (for reminders) and photo access (for saving edits).
- Everything is stored on your phone; there are no accounts and no servers.
