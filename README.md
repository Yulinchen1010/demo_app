# demo_app

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Working with GitHub

If you want to collaborate through GitHub, the typical workflow looks like this:

1. **Clone or sync the repository**
   ```bash
   git clone git@github.com:YourOrg/demo_app.git
   cd demo_app
   git pull # keep the local clone up to date
   ```
2. **Create a feature branch for your work**
   ```bash
   git checkout -b feature/your-task
   ```
3. **Make changes locally** using your preferred editor (for example VS Code),
   run tests, and verify the app.
4. **Stage and commit the changes** with a descriptive message:
   ```bash
   git status
   git add path/to/changed/files
   git commit -m "Describe what you changed"
   ```
5. **Push the branch to GitHub** and open a Pull Request (PR):
   ```bash
   git push -u origin feature/your-task
   ```
6. **Create the PR on GitHub**, request a review from your teammate, address
   feedback, and merge once checks pass.

Repeat the cycle for each bug fix or new feature so the `main` branch stays
stable and reviewable.

## ESP32 Sensor Integration

The Flutter app is designed to read the packets emitted by the provided
ESP32 firmware. To verify the end-to-end flow:

1. **Flash the firmware** shown above to your ESP32 and keep `SIM_MODE` at `0`
   for real sensor data (or switch to `1` for synthetic signals).
2. **Pair the device** with your Android phone/tablet. It advertises the name
   `ESP32_EMG_IMU` over classic Bluetooth (SPP).
3. **Grant Bluetooth permissions** when Android prompts you. On Android 12+
   the app requests `BLUETOOTH_SCAN` and `BLUETOOTH_CONNECT`; older versions
   fall back to the legacy Bluetooth/location permissions.
4. **Launch the app** and open the “即時” tab. After a successful connection
   the UI will display the latest EMG RMS value and plot the rolling chart.
5. Each packet follows the format
   `timestamp_ms,emg_rms,emg_%` followed by the averaged IMU axes for six
   sensors. The app consumes the timestamp/RMS/% fields, retains the newest
   500 samples, and uploads them to the cloud API.

If the connection drops, the screen will show an error message with a button to
retry. Ensure the ESP32 stays powered and within Bluetooth range during tests.

## Troubleshooting

### "Gradle build failed to produce an .apk file"

Flutter expects debug builds to land in `build/app/outputs/flutter-apk/`. When
the Android tooling cannot create that artifact, the CLI prints the above
message. Common fixes include:

- Install Android SDK 34 (the project now targets/compiles against API 34) via
  Android Studio's SDK Manager, then accept the licenses:
  ```bash
  flutter doctor --android-licenses
  ```
- Clean any stale artifacts before rebuilding:
  ```bash
  flutter clean
  flutter pub get
  flutter run
  ```
- If you still hit the error, look under `build/app/outputs/` for Gradle logs.
  Often a missing SDK component or incompatible AGP/Kotlin version is the root
  cause—updating to the versions noted in `android/settings.gradle.kts` and
  `android/app/build.gradle.kts` should resolve it.
