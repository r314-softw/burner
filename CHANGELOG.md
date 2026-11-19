# Changelog

All notable changes to Burner are listed here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and versions follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Changed
- Share links now use `/s?code=…` and `/s?p=…`. In messengers they preview as
  "Someone sent you a burner" instead of the app's generic description. Older
  links without `/s` still work.

## [1.1.0] - 2026-11-19

### Added
- **Public links:** share a drop with someone who doesn't use Burner. The
  link opens in any browser without signing in, works once, and burns when the
  receiver taps **Open**. Files stay downloadable for 15 minutes after that.
  Public links use a 24-character secret token instead of the short code.
- "Public link" toggle on the Send page; public drops are labelled in My drops.
- `BURNER_SIGNUP_ENABLED` build flag for the sign-up screen.
- This changelog.

### Changed
- Sign-up is hidden by default. Accounts are created in the Firebase console
  for now. Set `BURNER_SIGNUP_ENABLED` to `true` to bring it back.
- Burning a drop now records `burnedAt` (server time).
- Firestore and Storage rules allow token-less reads and burns of public drops
  only.

## [1.0.0] - 2026-11-18

### Added
- Send files (drag and drop or file picker) and text between devices with a
  6-character code, a link and a QR code.
- Receive by code or link, with per-file and "download all" downloads.
- Expiry of 10 minutes, 1 hour, 24 hours or 7 days, and an optional "burn
  after first open".
- My drops: your drops, their status and open count, and usage totals.
- Email and password sign-in through Firebase Auth, with password reset.
- Firestore and Storage security rules, Firebase Hosting config, bucket
  lifecycle and CORS files.
- Responsive layout: navigation rail on wide windows, bottom bar on phones.
- Flame app icon and splash screens for Android, web and Linux, plus an Ubuntu
  desktop-entry installer.
- Pure-Dart Firebase REST clients, so one code path covers Linux, web and
  Android.

[Unreleased]: https://github.com/r314-softw/burner/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/r314-softw/burner/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/r314-softw/burner/releases/tag/v1.0.0
