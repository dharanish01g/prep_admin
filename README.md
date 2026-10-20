# PrepWisely Team

Simple reminders for small teams of 4–5 people. Remind a colleague what needs
doing and by when, and see when it's done. Not another Asana or Trello.

Free for everyone. Website: https://dharanish01g.github.io/prepwisely-team/

## Download

Android only for now: get the APK from the
[latest release](https://github.com/dharanish01g/prep_admin/releases/latest).

We don't have Play Store or Apple developer accounts yet. If you can publish
the app under your account, please get in touch on
[WhatsApp](https://wa.me/917401777918).

## Build

A Flutter app (`lib/`) with a Supabase backend. The database schema and access
rules are in `supabase/migrations/`.

```sh
flutter pub get
flutter run
flutter test                           # widget tests, on mock data
flutter test test_live/remote_test.dart  # maintainers: end-to-end against the live project
```

Release APKs are built split per ABI and obfuscated:

```sh
flutter build apk --release --split-per-abi --obfuscate --split-debug-info=build/symbols
```

Signing needs `android/key.properties` and its keystore, which are not in the
repo.

## License

GPL-3.0 (see [LICENSE](LICENSE)), with an additional permission for app store
distribution (see [APP_STORE_EXCEPTION](APP_STORE_EXCEPTION)).
