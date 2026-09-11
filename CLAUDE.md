# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

MATRIX Mobile is the Flutter client for **SiLAKES MATRIX** (Manajemen Absensi Terintegrasi dan Remunerasi Insentif eXpert), an HR attendance app for Labkesda Sumenep. It talks to a separate Laravel API backend (not in this repo). Core features: face-recognition attendance (Google ML Kit + liveness/blink detection + TTS voice guidance), GPS/geofenced check-in/out, schedule management, leave requests, and performance/points tracking.

The Laravel backend for this app lives in `D:\Project_Web\SiLAKES\api-administrasi-labkesda` (a separate working directory) — check there when a task requires understanding or changing API behavior this app depends on.

## Commands

```bash
flutter pub get                                              # install dependencies
flutter pub run build_runner build --delete-conflicting-outputs  # regenerate *.g.dart (json_serializable, hive, riverpod_generator)
flutter analyze                                               # static analysis (flutter_lints)
flutter test                                                  # run tests (test/widget_test.dart)
flutter test test/widget_test.dart                            # run a single test file
flutter run                                                    # run on connected device/emulator
flutter clean && flutter pub get && flutter build apk --release --split-per-abi   # release APK
flutter build appbundle --release                              # release AAB (Play Store)
```

There's also `verify_no_service_bugs.ps1` (PowerShell) — a project-specific lint script that greps for two recurring bug classes: importing `security/data/security_service` (wrong/stale path) instead of the real one at `lib/core/services/security_service.dart`, and instantiating `SecurityService()` directly instead of via `securityServiceProvider`. Run it after touching security/PIN code.

## Architecture

Feature-first structure under `lib/`:

```
lib/
├── core/                  # cross-cutting: api client, constants, theme, shared utils/widgets
│   ├── api/               # DioClient (singleton HTTP wrapper), SecureStorageService
│   ├── constants/         # app_constants.dart — ALL API endpoints, storage keys, Hive box names, config
│   ├── services/          # SecurityService (PIN/biometric) exposed via securityServiceProvider
│   └── theme/, utils/, widgets/, providers/
├── features/<feature>/
│   ├── data/
│   │   ├── models/        # JSON models (some hand-written, some json_serializable/hive with .g.dart)
│   │   └── repositories/  # wrap DioClient calls, exposed as Riverpod providers
│   └── presentation/
│       ├── pages/         # screens
│       ├── providers/     # Riverpod providers/notifiers (FutureProvider, StateNotifier, etc.)
│       └── widgets/       # feature-local widgets
└── main.dart               # entrypoint: inits Dio, locale, ProviderScope, boots SplashPage
```

Features: `activation`, `attendance` (includes schedule + performance tabs), `auth`, `dashboard`, `leave`, `profile`, `schedule`, `security`, `splash`. Shared cross-feature widgets go in `lib/shared/widgets/`.

Key architectural points:

- **State management**: Riverpod (`flutter_riverpod`). Repositories and services are exposed as `Provider`/`FutureProvider` (e.g. `securityServiceProvider`, `attendanceRepositoryProvider`) — never instantiate a repository/service class directly in a widget; get it via `ref.watch`/`ref.read`.
- **Networking**: all HTTP goes through the `DioClient` singleton (`lib/core/api/dio_client.dart`), which attaches the bearer token from `SecureStorageService`, auto-refreshes on 401, and logs via `pretty_dio_logger`. Every endpoint path is centralized in `lib/core/constants/app_constants.dart` — add new endpoints there rather than inlining URL strings.
- **Navigation**: plain `Navigator.push`/`MaterialPageRoute`, no router package — despite what the README's tech-stack list says, `go_router` is not actually a dependency.
- **Local storage**: `flutter_secure_storage` for tokens/PIN, `hive`/`hive_flutter` for structured caches (box names in `app_constants.dart`), `shared_preferences` for simple flags.
- **Attendance modes**: two independent axes drive attendance behavior — attendance mode (`Fixed`: strict check-in/out windows with late penalties and a locked state outside the window, vs `Flexi`: free check-in time with a flat point value) and location mode (`Location-Based`: GPS geofence validation, vs `WFA`/Work From Anywhere: no location validation). Check `attendance_config_model.dart` / `attendance_provider.dart` when touching check-in/out logic.
- **Face attendance flow**: camera → ML Kit face detection → blink-based liveness check → TTS voice prompts (Indonesian) at each stage → auto photo capture → GPS validation → submit. See `lib/features/attendance/TTS_FEATURE.md` for the exact prompt script and trigger points if modifying `face_attendance_page.dart`.
- **Stray files**: some directories contain `*.dart.backup` / `*.dart.old` files left from prior refactors (e.g. `attendance_tab.dart.backup`, `security_service.dart.old`) — these are not part of the build; don't edit them, and treat the extensionless-matching file as the live one.

## Locale & i18n

UI strings and TTS prompts are in Indonesian (`id_ID` locale, initialized in `main.dart` via `initializeDateFormatting`). Match existing Indonesian copy style when adding user-facing text.
