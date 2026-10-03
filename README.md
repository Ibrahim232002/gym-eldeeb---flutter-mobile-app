# Gym ElDeeb — Flutter Mobile App

Arabic-first gym management application built with Flutter, Riverpod, GoRouter, and Supabase.

## Requirements
- Flutter SDK compatible with the constraints in `pubspec.yaml`
- Dart SDK compatible with the constraints in `pubspec.yaml`

## Run locally

```bash
flutter pub get
flutter run
```

## Validate

```bash
flutter analyze
flutter test
```

## Backend configuration

The app uses the Supabase project URL and publishable client key configured in `lib/core/constants/supabase_constants.dart`. Only a publishable/anon key belongs in a client application. Never place a Supabase service-role key or other privileged secret in Flutter source or a distributed app.

The application also relies on the configured Supabase database schema and the `join-gym` Edge Function.


## Android release signing

Release builds never fall back to the Android debug key. Before producing a distributable APK/AAB:

1. Create a private upload/release keystore and keep it outside Git.
2. Copy `android/key.properties.example` to `android/key.properties`.
3. Fill in the keystore path, alias, and passwords.
4. Keep `android/key.properties` and all `.jks` files out of source control.

Without `android/key.properties`, a release build is intentionally left unsigned instead of using the debug key.

## Security / RLS audit

See `docs/RLS_AUDIT.sql` for the repeatable database checks. RLS must be verified with separate authenticated accounts from different gyms; running queries in the SQL editor alone is not a substitute for client-session testing.
