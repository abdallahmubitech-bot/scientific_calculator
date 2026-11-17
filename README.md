# Scientific Calculator

A Calces-inspired scientific calculator built with Flutter.

## Features

- **Dual-line display** – editable, syntax-highlighted expression with a blinking cursor (tap to
  position it) and a live result preview. Tap the result or `S⇔D` to switch fraction / decimal.
- **Mode bar** – `SHIFT`, `HYP` and `DEG / RAD / GRAD`.
- **Scientific keypad** – trig, inverse and hyperbolic trig, `log`, `ln`, `logₐb`, `x²`, `x³`, `xʸ`,
  `x⁻¹`, `√`, `∛`, `ʸ√x`, `n!`, `nCr`, `nPr`, `π`, `e`, `mod`, `|x|`, `%`, parentheses, `Ans`, `×10ˣ`.
- **Memory** – `MC`, `MR`, `M+`, `M−`.
- **History** – persisted with `shared_preferences`; tap an expression to load it, tap a result to
  insert it, swipe to delete.
- **Engine** – implicit multiplication (`2π`, `3sin(30)`, `(2+3)(4+5)`), auto-closing parentheses,
  `Math Error` / `Syntax Error` instead of exceptions.
- Portrait (collapsible scientific grid) and landscape (side-by-side) layouts, haptic feedback.

## Getting started

This repository contains the Dart sources only. Generate the platform folders once, then run:

```sh
flutter create .   # adds android/, ios/, web/ … without touching lib/
flutter pub get
flutter test
flutter run
```

## Building the APK

Two ways, both starting from a machine with the Flutter SDK and an Android SDK installed.

**Locally**

```sh
flutter create --platforms=android .
flutter pub get
flutter build apk --release                 # → build/app/outputs/flutter-apk/app-release.apk
flutter build apk --release --split-per-abi  # → one smaller APK per ABI
```

**In CI (no local SDK needed)**

`.github/workflows/build-apk.yml` builds on every push, pull request and tag. Open the run's
*Artifacts* section and download `scientific-calculator-apk`, which holds:

- `app-release.apk` – universal, installs on any Android device
- `app-arm64-v8a-release.apk`, `app-armeabi-v7a-release.apk`, `app-x86_64-release.apk` – smaller,
  ABI-specific

Pushing a `v*` tag additionally attaches them to a GitHub release. The workflow generates the
Android host project itself, restores `pubspec.yaml` afterwards so the pinned dependencies survive,
and deletes the default counter widget test that `flutter create` drops into `test/`.

Release APKs are signed with the debug key, which is fine for sideloading but not for the Play
Store – add a `signingConfigs` block to `android/app/build.gradle` to ship for real.

## Structure

```
lib/
  main.dart
  theme/       app_colors.dart, app_theme.dart
  models/      calculation_history.dart
  services/    math_engine.dart          (pure Dart recursive-descent evaluator)
  providers/   calculator_controller.dart (ChangeNotifier + Provider)
  widgets/     calculator_display.dart, scientific_keypad.dart, calc_button.dart,
               history_bottom_sheet.dart
  screens/     calculator_screen.dart
test/          math_engine_test.dart, calculator_controller_test.dart
```
