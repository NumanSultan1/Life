# Life: security review

**Date:** 8 October 2026 · **Build tested:** 1.0.0 (versionCode 2001), Android release, on a Galaxy S23 Ultra (Android 16).

Life stores private data: journal, mood, health vitals, medical ID, medicines, spending and assistant memory. The review
looked at how that data is stored, what leaves the phone, what other apps can reach, and the release build.

## How it was tested

| Area | Method |
|---|---|
| Data at rest | Code review; tried to read the app's files over USB (`run-as`, `/data/data`) |
| Other apps / components | Manifest review; tried to start every internal activity, service and receiver from outside (`am start`, `am startservice`, `am broadcast`) |
| Logs | Read the app's logcat output while it ran |
| Network | Listed every URL in the code; checked HTTPS, consent and integrity checks |
| Secrets | Searched code and full git history for API keys, tokens and private keys |
| Dependencies | Checked all 122 hosted packages against the OSV vulnerability database |
| Backups | Backup file format, restore input handling, Android backup flags |
| Native channels | Reviewed every Dart↔Android method channel for unchecked input |

## Findings and fixes

| # | Finding | Risk | Status |
|---|---|---|---|
| 1 | **Android cloud backup was on** (`ALLOW_BACKUP`), so journal, health and medical data could be copied to the Google account backup, while the app says it stays on the phone. | High | **Fixed**: `allowBackup=false` and data-extraction rules exclude everything from cloud backup and device transfer. Verified on the phone (flag gone). |
| 2 | **Data stored unencrypted** on the phone (Hive files). Readable on a rooted phone or with forensic tools. | Medium | **Fixed**: all boxes are encrypted with AES-256; the key is kept in the Android Keystore (`flutter_secure_storage`, key never wiped on error). Existing data is converted once, with a safety copy until the encrypted copy is complete (tested, including a crash mid-conversion). Hive keys (record names such as `numan_…`) stay readable; values are encrypted. |
| 3 | **Backup files were plain JSON** with medical ID, journal and health data, and are often saved to Drive or chat apps. | Medium | **Fixed**: backups are password protected by default (AES-256-GCM, key from PBKDF2-HMAC-SHA256 with 120,000 rounds and a random salt). A wrong password or an edited file is rejected. Saving without a password needs an extra confirmation. |
| 4 | **No app lock.** Anyone holding the unlocked phone could read everything; profiles have no password. | Medium | **Fixed (opt-in)**: Profile › App lock uses fingerprint, face or the phone PIN, relocks after 30 s in the background, and while on hides Life in recent apps and blocks screenshots (`FLAG_SECURE`). |
| 5 | **Health values written to the system log** by the health plugin (e.g. "returning 1465 steps"). | Low | **Fixed**: release builds strip Android log calls (R8 rule) and silence Dart debug output. Verified: no health lines in logcat. |
| 6 | **Reminder notifications show medicine/task names on the lock screen.** | Low | **Fixed**: notifications are marked private, so the phone hides their text when locked if the user's lock-screen setting asks for it. |
| 7 | **Restore accepted any JSON shape.** A crafted file could put unexpected types into storage. | Low | **Fixed**: only plain JSON values are accepted, files over 50 MB are refused, and encrypted files are authenticated before use. |
| 8 | **Release signed with the shared Flutter debug key.** Anyone could sign an "update" that installs over Life. | Medium (if distributed) | **Not changed, needs your decision**: switching keys means uninstalling the current app (data loss without a backup). Before publishing, create a private upload key (see below). |
| 9 | **Profiles have no password** (log in by name). | Low | **Mitigated** by the App lock. Profiles are meant for one person's phone. |

## What was already good

- Release build is not debuggable: the app's private files can't be read over USB (`run-as` refused, `/data/data` denied).
- Only the launcher activity is exported. The block screen, app-limit service, boot and widget receivers refused outside launches (`SecurityException`). The permission-usage alias needs a system-only permission.
- All network traffic is HTTPS; cleartext is disabled. No secrets in the code or git history.
- The Pashto voice model download is checked against a fixed SHA-256 before use.
- Translation sends text only after the user agrees (to MyMemory, over HTTPS). Voice recordings never leave the phone.
- The watch-setup channel can only open a fixed list of health apps, so it can't be used to launch arbitrary apps.
- No known vulnerabilities in any of the 122 packages (OSV database, 8 Oct 2026).

## Before publishing on the Play Store

1. Create an upload key and keep it (and its password) safe. Losing it means you can't update the app:
   `keytool -genkey -v -keystore ~/life-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias life`
2. Add `android/key.properties` (already git-ignored) and point `signingConfigs.release` at it in
   `android/app/build.gradle.kts`.
3. Change `applicationId` from `com.example.vortextech_appdev_week4` to your own (e.g. `com.yourname.life`).
4. Build with obfuscation: `flutter build appbundle --obfuscate --split-debug-info=build/symbols`.
5. Re-run this review after major changes (especially new network calls or new exported components).
