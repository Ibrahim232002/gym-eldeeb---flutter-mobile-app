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
