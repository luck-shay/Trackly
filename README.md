# Trackly

Trackly is a Flutter habit-tracking app with Google sign-in, Firebase-backed persistence, shared habits, groups, streak tracking, and social activity views.

## Stack

- Flutter
- Provider for state management
- Firebase Authentication
- Cloud Firestore

## Core Features

- Personal habits with daily completion tracking
- Quantified habits with units and max daily targets
- Shared tasks with friends
- Group-based routines with invites and leaderboards
- Activity history calendar
- Basic social graph with friend requests and profiles

## Development

1. Install Flutter and platform toolchains.
2. Run `flutter pub get`.
3. Ensure Firebase config files are present for the target platform.
4. Set AI env vars when needed:
	- `export GEMINI_API_KEY=your_key`
	- `export GEMINI_MODEL=gemini-1.5-flash`
5. Run `flutter run`.

## Quality Checks

- `flutter analyze`
- `flutter test`
- `bash tool/quality_gate.sh`

## Release Notes

- Android release signing still needs to be configured in [android/app/build.gradle.kts](android/app/build.gradle.kts).
- Firebase security rules should be reviewed before shipping to production.
