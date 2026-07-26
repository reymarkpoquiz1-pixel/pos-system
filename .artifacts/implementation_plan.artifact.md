# Implementation Plan - Fix Android Build (NDK/CMake Conflict)

This plan addresses the build failure where CMake cannot find or verify the C compiler in NDK version 28. We will revert to a more stable NDK version and clean the build artifacts.

## User Review Required

> [!WARNING]
> This fix changes the Android Native Development Kit (NDK) version used by the project. NDK 28 is experimental/very new and is currently failing on your machine's CMake configuration.

## Proposed Changes

### Android Configuration

#### [MODIFY] [app/build.gradle.kts](file:///C:/pos-all-in-one/frontend/android/app/build.gradle.kts)
- Change `ndkVersion` from `"28.2.13676358"` to a stable version like `"26.1.10909125"`.
- Lower `compileSdk` and `targetSdk` to `34` (Android 14) to ensure maximum compatibility with existing Flutter plugins, as `36` is still in preview/alpha.

### Build Cleanup
I will execute commands to remove the corrupted CMake cache.

## Verification Plan

### Manual Verification
1. Run `flutter clean` in the terminal.
2. Attempt to run the app on an Android device or emulator.
3. If NDK 26 is missing, Android Studio will automatically prompt to download it, or I can provide the command to install it via `sdkmanager`.
