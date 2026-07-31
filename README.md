# Vortex Tech — App Dev Week 4

A cross-platform mobile/desktop/web application built with **Flutter**, developed as part of the Vortex Tech App Development course (Week 4 assignment).

> ✏️ **Replace this line** with a 2–3 sentence description of what the app actually does — e.g. "This app lets users track X, manage Y, and view Z in real time."

---

## Table of Contents

- [About the Project](#about-the-project)
- [Tech Stack](#tech-stack)
- [Project Structure](#project-structure)
- [Prerequisites](#prerequisites)
- [Getting Started](#getting-started)
- [Running the App](#running-the-app)
- [Building for Release](#building-for-release)
- [Running Tests](#running-tests)
- [Code Style & Linting](#code-style--linting)
- [Supported Platforms](#supported-platforms)
- [Contributing](#contributing)
- [Troubleshooting](#troubleshooting)
- [License](#license)
- [ScreenShots]
  

---

## About the Project

This repository contains a Flutter application generated with `flutter create` and extended for a Week 4 App Development assignment/task.

> ✏️ **Add here:**
> - What problem the app solves / what it demonstrates
> - Key screens or features (e.g. login, list view, detail view, API integration, state management)
> - Any specific concepts from the course this week's task is meant to practice (widgets, state management, navigation, API calls, etc.)

---

## Tech Stack

| Layer | Technology |
|---|---|
| Framework | [Flutter](https://flutter.dev/) |
| Language | [Dart](https://dart.dev/) |
| Platforms | Android, iOS, Web, Windows, macOS, Linux |
| Linting | `flutter_lints` (via `analysis_options.yaml`) |
| Dependency Management | `pubspec.yaml` / `pubspec.lock` |

> ✏️ If you added packages like `provider`, `bloc`, `http`, `firebase_core`, etc., list them here with a one-line reason for each (e.g. `http` — for calling the REST API).

---

## Project Structure

```
vortex-tech-appdev-week4/
├── android/          # Android platform-specific project files
├── ios/              # iOS platform-specific project files
├── linux/            # Linux desktop platform files
├── macos/            # macOS desktop platform files
├── windows/          # Windows desktop platform files
├── web/              # Web platform files (index.html, manifest, icons)
├── lib/              # Main Dart source code (app logic, UI, models)
│   └── main.dart      # App entry point
├── test/             # Unit and widget tests
├── analysis_options.yaml  # Dart/Flutter linting rules
├── pubspec.yaml       # Project metadata and dependencies
├── pubspec.lock        # Locked dependency versions
├── .metadata           # Flutter tooling metadata (auto-generated, don't edit manually)
└── README.md           # Project documentation (this file)
```

> ✏️ If `lib/` is organized into subfolders (e.g. `lib/screens`, `lib/widgets`, `lib/models`, `lib/services`), expand this tree to reflect that — it makes the codebase much easier to navigate for reviewers/graders.

---

## Prerequisites

Before running this project, make sure you have the following installed:

- **Flutter SDK** — [Install guide](https://docs.flutter.dev/get-started/install)
- **Dart SDK** — bundled with Flutter
- **A code editor** — [VS Code](https://code.visualstudio.com/) (with the Flutter/Dart extensions) or [Android Studio](https://developer.android.com/studio)
- **Platform-specific tooling** (only needed for the platform you're targeting):
  - Android: Android Studio + Android SDK + an emulator or physical device
  - iOS/macOS: Xcode (macOS only)
  - Web: Google Chrome
  - Windows/Linux: respective desktop build toolchains (see [Flutter desktop setup](https://docs.flutter.dev/platform-integration/desktop))

Verify your environment is correctly set up:

```bash
flutter doctor
```

Resolve any issues it reports before continuing.

---

## Getting Started

1. **Clone the repository**

   ```bash
   git clone https://github.com/NumanSultan1/vortex-tech-appdev-week4.git
   cd vortex-tech-appdev-week4
   ```

2. **Install dependencies**

   ```bash
   flutter pub get
   ```

3. **Check available devices**

   ```bash
   flutter devices
   ```

---

## Running the App

Run on a connected device, emulator, or simulator:

```bash
flutter run
```

Run on a specific platform:

```bash
flutter run -d chrome     # Web
flutter run -d windows    # Windows desktop
flutter run -d macos      # macOS desktop
flutter run -d linux      # Linux desktop
flutter run -d <device-id> # Specific Android/iOS device (find with `flutter devices`)
```

---

## Building for Release

```bash
flutter build apk           # Android APK
flutter build appbundle     # Android App Bundle (for Play Store)
flutter build ios           # iOS (requires macOS + Xcode)
flutter build web           # Web build (output in build/web)
flutter build windows       # Windows executable
flutter build macos         # macOS app
flutter build linux         # Linux executable
```

Build output is placed in the `build/` directory (git-ignored by default).

---

## Running Tests

```bash
flutter test
```

This runs all unit and widget tests located in the `test/` directory.

> ✏️ If you've written specific test files, list the key ones here (e.g. `test/widget_test.dart — verifies the home screen renders correctly`).

---

## Code Style & Linting

This project uses the recommended Flutter lint rules defined in `analysis_options.yaml` (based on [`flutter_lints`](https://pub.dev/packages/flutter_lints)).

Run the analyzer before committing:

```bash
flutter analyze
```

Format code automatically:

```bash
dart format .
```

---

## Supported Platforms

| Platform | Status |
|---|---|
| Android | ✅ |
| iOS | ✅ |
| Web | ✅ |
| Windows | ✅ |
| macOS | ✅ |
| Linux | ✅ |

---

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature-name`
3. Commit your changes: `git commit -m "Add: your change description"`
4. Push to the branch: `git push origin feature/your-feature-name`
5. Open a Pull Request

---

## Troubleshooting

- **`flutter: command not found`** — Make sure the Flutter SDK's `bin` folder is added to your system `PATH`.
- **Build fails after pulling changes** — Try:
  ```bash
  flutter clean
  flutter pub get
  flutter run
  ```
- **iOS build fails** — Run `cd ios && pod install && cd ..` to make sure CocoaPods dependencies are up to date.
- **`flutter doctor` shows issues** — Resolve each flagged item; most run/build errors trace back to an unresolved `flutter doctor` warning.

---

## License

> ✏️ Add your license here (e.g. MIT, or "This project is for educational purposes as part of the App Development course").

##ScreenShots
<img width="1088" height="645" alt="image" src="https://github.com/user-attachments/assets/efaa04be-264c-4dd6-9e14-873646e2ae12" />
<img width="1088" height="645" alt="image" src="https://github.com/user-attachments/assets/f51c2717-f940-432e-b41e-149cb48273cd" />
<img width="1088" height="645" alt="image" src="https://github.com/user-attachments/assets/98246b85-783c-4cc1-b13c-610261b7510c" />
<img width="1088" height="645" alt="image" src="https://github.com/user-attachments/assets/61ee597c-dd51-4b83-87dc-17c9d318dd8a" />
<img width="616" height="686" alt="image" src="https://github.com/user-attachments/assets/b7a4eed3-a9d6-45e3-baa5-f01b87c7d36b" />
<img width="616" height="686" alt="image" src="https://github.com/user-attachments/assets/1c2cdf0a-1fb1-4650-bbbe-d3fb832c43c7" />
<img width="616" height="686" alt="image" src="https://github.com/user-attachments/assets/5799360b-5b6a-4fe2-b354-0e93e0fb50b3" />
<img width="616" height="686" alt="image" src="https://github.com/user-attachments/assets/fe5f4384-9db5-448f-a178-535a3289ecfc" />
<img width="616" height="686" alt="image" src="https://github.com/user-attachments/assets/c618505b-48ee-436a-bd70-e894afa5c4d9" />
<img width="616" height="686" alt="image" src="https://github.com/user-attachments/assets/00ee468b-06bd-4312-947c-60f98a18f919" />








---

## Author

**Numan Sultan** — [GitHub](https://github.com/NumanSultan1)
