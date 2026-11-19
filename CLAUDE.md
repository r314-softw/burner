# CLAUDE.md

Context for AI assistants working on **Burner**.

## What it is

Burner is an AirDrop-style tool for Ubuntu, web and Android. A user drags files
(or pastes text) into the window, burner uploads them and returns a short code
(`ABC-234`), a link and a QR code. Another device signed in to burner enters
the code and downloads the contents. Drops expire (10 min to 7 days) and can be
"burn after first open".

## Hard constraints

- **No server/backend.** No Cloud Functions, no custom API. Clients talk to
  Firebase directly; all authorisation is in `firestore.rules` and
  `storage.rules`. Don't propose a backend to solve a problem; find a
  rules-based or client-side approach (or a Firebase/GCS-native feature like
  TTL policies and bucket lifecycle rules).
- **Only authenticated users** (Firebase Auth, email + password) can read or
  write anything in Firestore or Storage. The one exception: opening a
  **public link** drop (long secret token, burns once), which the rules allow
  without auth.
- **Platforms:** Linux (Ubuntu) desktop, web, Android. The UI must be
  responsive across all three. iOS/macOS/Windows folders exist from
  `flutter create` but are not targets.

## Architecture

Flutter app, no FlutterFire. FlutterFire has no Linux support, so every
Firebase call goes through small pure-Dart REST clients built on
`package:http`. One code path for all platforms.

```
lib/
  main.dart                    wires services, reads ?code= from the web URL
  app.dart                     MaterialApp, auth gate, SetupRequiredApp
  config/firebase_config.dart  values from --dart-define-from-file
  models/drop.dart             Drop, DropFile, UsageStats (+ Firestore mapping)
  services/
    auth_service.dart          Identity Toolkit REST: sign in/up, reset,
                               token refresh; session in shared_preferences
    firestore_client.dart      Firestore v1 REST: get/commit/delete/runQuery,
                               FirestoreCodec for typed Value JSON
    storage_client.dart        Storage v0 REST: streamed upload, download, delete
    drop_service.dart          domain logic + DropLimits (shared with the rules)
    file_saver*.dart           conditional import: io (Downloads dir / Android
                               save dialog) vs web (blob download)
    firebase_exception.dart    REST error parsing + user-facing messages
  ui/
    services_scope.dart        InheritedWidget giving pages the services
    theme.dart                 theme, Breakpoints, ContentWidth, showMessage
    home_screen.dart           NavigationRail (>=840px) / NavigationBar
    send_page.dart             DropTarget (desktop_drop) + file_picker + text
    receive_page.dart          code entry, text/file display, downloads
    history_page.dart          the user's drops + usage counters
    widgets/share_card.dart    code, copy buttons, QR
```

State management is plain `ChangeNotifier` / `setState`; no provider/bloc.
Keep it that way unless the app clearly outgrows it.

## Data model

- `drops/{id}`: `ownerUid`, `text`, `files[] {name,size,contentType,path}`,
  `createdAt` (server time), `expiresAt`, `burnAfterRead`, `public`, `burned`,
  `downloads`, plus `burnedAt` (server time) once burned. For private drops
  the id is the 6-char code from `ABCDEFGHJKLMNPQRSTUVWXYZ23456789`. For public
  drops it's a 24-char `[A-Za-z0-9]` token, `burnAfterRead` is always true,
  and `public` is true. Older docs may lack `public`; read it as false.
- `users/{uid}`: usage counters `dropsCreated`, `bytesUploaded`,
  `dropsReceived`, `bytesDownloaded`, `lastActiveAt`. Written with Firestore
  `increment` transforms in the same commit as the drop.
- Storage: `drops/{ownerUid}/{folder}/{index}_{safeName}`. `folder` is a
  20-char random id for private drops, or the drop's token for public drops.
  The public Storage rule uses it to `firestore.get` the drop.

Flow: upload files → one Firestore `commit` creates the drop
(`currentDocument.exists=false`) and bumps usage. On a code collision the
commit fails (ALREADY_EXISTS or PERMISSION_DENIED) and `create` retries with a
new code. If the commit fails, uploaded files are deleted.

Receiving: `find` (GET) → `markReceived` (download +1, set `burned` and
`burnedAt` when burn-after-read) → per-file download.

Public links (`?p=<token>`): `main.dart` reads the token and `BurnerApp`
shows `PublicReceiveScreen` instead of the auth gate. It uses
`FirestoreClient.anonymous` / `StorageClient.anonymous` (no token, `?key=`).
The steps are `findPublic` → the user taps Open → `openPublic` (burn) →
`downloadPublic`. Files stay readable for `DropService.publicDownloadWindow`
(15 min, mirrored in `storage.rules`) after `burnedAt`. Pasting a public link
into the in-app Receive page pushes the same screen.

Cleanup without a backend: on app start, `DropService.cleanup()` deletes the
current user's expired/burned drops and their files. The backstop for users
who never return is a Firestore TTL policy on `drops.expiresAt` and a bucket
lifecycle rule (`storage-lifecycle.json`); see README.

## Keep these in sync

Limits are duplicated by necessity (rules can't import Dart):

| Limit | Dart (`DropLimits`) | Rules |
| --- | --- | --- |
| 100 MB per file | `maxFileBytes` | `storage.rules` |
| 20 files per drop | `maxFiles` | `firestore.rules` |
| 100 000 text chars | `maxTextChars` | `firestore.rules` |
| 7-day max expiry | `maxTtl` | `firestore.rules` (+5 min skew) |
| Code alphabet/length | `DropCodes` | `firestore.rules` regex |
| Drop document fields | `Drop.toCreateMap` | `dropFields()` |
| Public token length | `DropCodes.publicTokenLength` | both rules files |
| Public download window | `DropService.publicDownloadWindow` | `storage.rules` |
| Usage fields | `UsageStats` / `DropService` | `counters()` |

If you change the drop document shape, update `firestore.rules` too or
creates will be denied.

## Feature flags

`lib/config/features.dart` holds build-time flags read with
`bool.fromEnvironment`. They're set in `config/firebase.env.json`.

- `BURNER_SIGNUP_ENABLED` (default `false`): shows "Create an account".
  The sign-up code is kept; it's hidden until the owner enables it.

## Changelog

Add every user-visible change to `CHANGELOG.md` under `[Unreleased]`
(Keep a Changelog format). On release, move it under a new version heading
and bump `version:` in `pubspec.yaml`.

## TODO

Planned work lives in `TODO.md`. When an item ships, remove it there and add
it to `CHANGELOG.md`.

## Commands

```bash
flutter pub get
flutter analyze
flutter test
flutter run -d linux   --dart-define-from-file=config/firebase.env.json
flutter run -d chrome  --dart-define-from-file=config/firebase.env.json
flutter run -d <android-device> --dart-define-from-file=config/firebase.env.json
flutter build web --dart-define-from-file=config/firebase.env.json && firebase deploy --only hosting
firebase deploy --only firestore:rules,storage
```

`config/firebase.env.json` is gitignored; `config/firebase.env.example.json`
is the template. Without it the app shows `SetupRequiredApp`.

## Branding

- The app name shown to users is **Burner** (capital B). The package, binary
  and folder names stay `burner`.
- The icon is the Material `local_fire_department` glyph with an ember
  gradient on `#201A17`. `tool/generate_icons.py` renders every platform's
  icons and splash images from it. Re-run the script rather than editing PNGs.
- Splash: Android uses `drawable*/launch_background.xml` (API ≤30) and
  `values*-v31/styles.xml` (API 31+). Web uses the `#splash` div in
  `web/index.html`, removed on `flutter-first-frame`. All platforms then show
  `SplashScreen` while the session restores. On Linux that's the only splash;
  the GTK window appears on the first frame with the brand background.
- Brand colours are duplicated in `BurnerTheme`, `generate_icons.py`,
  `android/.../values/colors.xml`, `web/index.html` and
  `linux/runner/my_application.cc`. Change them together.
- Linux window icon: `linux/icons/burner.png` is installed to `data/` by
  CMake and loaded in `my_application.cc`. GNOME/Wayland takes the dock icon
  from the desktop entry that `linux/install-desktop-entry.sh` writes.

## Conventions and gotchas

- Share links point to `/s` (`firebase.json` rewrites it to
  `web/share.html`). That page only carries the link-preview meta tags ("Someone
  sent you a burner") and forwards to `./` with the same query. Preview bots
  don't run JS, and Hosting can't vary `index.html` by query string, so the
  separate path is the backend-free way to get a custom preview. Don't add a
  `/s/` rewrite: `./` would loop.

- Deploy storage rules interactively. `storage.rules` uses `firestore.get`,
  which needs `roles/firebaserules.firestoreServiceAgent` on the Storage
  service agent. The CLI only offers the grant in an interactive run and only
  when the rules file changed. Without it, public downloads return 403.

- Firebase REST auth headers: Firestore uses `Authorization: Bearer <idToken>`,
  Storage uses `Authorization: Firebase <idToken>`.
- Firestore REST integers are strings (`integerValue: "42"`); use
  `FirestoreCodec`, don't hand-build Value JSON.
- A GET on a missing or hidden drop returns 403 (rules can't evaluate
  `resource.data` on a null doc), so `find` treats PERMISSION_DENIED as "not
  found".
- `DropTarget` must be disabled when its page is hidden (`SendPage.dropEnabled`)
  or it keeps catching drops.
- On web, upload progress jumps to 100% before the network send finishes
  (BrowserClient buffers the body). Downloads on web need bucket CORS
  (`storage-cors.json`).
- `file_picker` on Linux needs `zenity` (or `kdialog`) installed.
- Tests use `MockClient` from `package:http/testing.dart`; services take an
  optional `http.Client` for that reason. Rules are not covered by tests yet
  (needs the Firebase emulator + Java).
- Commit messages and code comments in English. Run `flutter analyze` and
  `flutter test` before committing.
