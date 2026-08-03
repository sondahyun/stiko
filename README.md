# stiko

A cross-platform sticky-note style to-do app. Pin your tasks on top of your desktop, glance at them on your phone's lock screen, and keep everything in sync across all your devices.

> Status: early development. Built in the open, one feature at a time.

## Why stiko

Most to-do apps hide your tasks behind an icon you have to open first. stiko keeps them in front of you.

- Desktop (macOS, Windows): tasks float as always-on-top sticky notes.
- Mobile (Android, iOS): tasks live on your home screen and lock screen widgets.
- One account keeps every device in sync.

## Platforms

| Platform | Form factor | Signature feature |
|----------|-------------|-------------------|
| macOS    | Desktop app | Always-on-top sticky window |
| Windows  | Desktop app | Always-on-top sticky window |
| Android  | Mobile app  | Home and lock screen widget (Android 16+) |
| iOS      | Mobile app  | Lock screen widget (WidgetKit) |

## Tech stack

- Framework: Flutter (Dart)
- State management: Riverpod
- Local storage: Drift (SQLite), offline-first
- Routing: go_router
- Desktop windowing: window_manager
- Sync (planned): Firebase Authentication and Cloud Firestore
- Widgets (planned): home_widget with native SwiftUI (iOS) and Glance (Android)

## Getting started

You need the Flutter SDK (stable channel). Platform toolchains are only required for the platforms you actually build.

```bash
flutter pub get
flutter run
```

- macOS and iOS builds require Xcode and CocoaPods.
- Android builds require Android Studio and the Android SDK.

## Roadmap

- [x] Project scaffolding for the four platforms
- [ ] Local todo data model and storage
- [ ] Todo list UI (add, edit, complete, delete)
- [ ] Desktop always-on-top sticky window
- [ ] Account sync (Firebase)
- [ ] Mobile home and lock screen widgets
- [ ] Settings, theming, and polish

## License

Released under the MIT License. See [LICENSE](LICENSE).
