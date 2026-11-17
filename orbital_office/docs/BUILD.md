# Build & Deployment

## Prerequisites

- Flutter **stable** (≥ 3.24, Dart ≥ 3.5) — `flutter doctor` must be clean
- Android: Android Studio + SDK, JDK 17
- iOS (macOS only): Xcode + CocoaPods, Apple Developer account for signing
- Optional: Supabase CLI for backend deployment

## 1. Generate platform folders (first time only)

The repository ships the complete Dart source, tests, Supabase backend and
docs. Generate the native Android/iOS shells once — Flutter will not
overwrite `lib/`, `pubspec.yaml` or `test/`:

```bash
cd orbital_office
flutter create --platforms=android,ios --org com.orbitalstudio3 .
flutter pub get
```

## 2. Validate

```bash
flutter analyze
flutter test                 # unit + widget tests
flutter test test/integration/app_flow_test.dart
```

## 3. Configure the backend (optional)

The app runs fully offline with zero configuration (demo workspace).
For real accounts and sync:

```bash
supabase link --project-ref YOUR_REF
supabase db push
supabase functions deploy ai_assistant
supabase secrets set AI_PROVIDER_API_KEY=YOUR_KEY AI_PROVIDER_MODEL=YOUR_MODEL
```

Then pass **only the public anon key** to the app via `--dart-define`
(see `.env.example`). Never put the service-role key in the app.

## 4. Run

```bash
# Demo/offline
flutter run

# With Supabase
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLIC_ANON_KEY
```

## 5. Android APK (sideload/testing)

```bash
flutter build apk --release \
  --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
# Output: build/app/outputs/flutter-apk/app-release.apk
```

Per-ABI APKs (smaller): `flutter build apk --split-per-abi`

## 6. Android App Bundle (Play Store)

1. Create an upload keystore and `android/key.properties` (never commit it):

   ```properties
   storePassword=...
   keyPassword=...
   keyAlias=upload
   storeFile=/path/to/upload-keystore.jks
   ```

2. Build:

   ```bash
   flutter build appbundle --release \
     --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
   # Output: build/app/outputs/bundle/release/app-release.aab
   ```

3. Upload the `.aab` in Play Console. Set version in `pubspec.yaml`
   (`version: 1.0.0+1` → bump both parts for each release).

## 7. iOS

On macOS:

```bash
flutter build ipa --release \
  --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
# Output: build/ios/ipa/*.ipa  (upload via Xcode Organizer / Transporter)
```

Before the first build: open `ios/Runner.xcworkspace`, set your Team and
bundle identifier (`com.orbitalstudio3.orbitalOffice`), and confirm the
deployment target. No iOS build was produced from the development
environment used to author this source (no macOS/Xcode) — treat the first
`flutter build ipa` as the iOS compatibility test and fix any plugin
issues it reports.

## 8. Environment summary

| Variable | Where | Purpose |
|---|---|---|
| `SUPABASE_URL` | `--dart-define` | Supabase project URL (public) |
| `SUPABASE_ANON_KEY` | `--dart-define` | Public anon key — safe in app, RLS protects data |
| `AI_PROVIDER_API_KEY` | Edge Function secret only | AI provider key — **never** in the app |
| `AI_PROVIDER_MODEL` | Edge Function secret only | Model name for the AI function |

## 9. Release checklist

- [ ] `flutter analyze` clean, `flutter test` green
- [ ] Demo mode walkthrough on a fresh install (no backend defines)
- [ ] Supabase RLS verified with two different test accounts
- [ ] Invoice PDF checked on a physical printer (A4)
- [ ] Low-stock + overdue flows exercised
- [ ] Keystore backed up securely; `key.properties` not in git
- [ ] Version bumped in `pubspec.yaml`
