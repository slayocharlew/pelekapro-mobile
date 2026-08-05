# PelekaPro Mobile

PelekaPro Mobile is the Android driver application for PelekaPro, a delivery-management and live-tracking platform for businesses that manage their own drivers. It is maintained separately from the Laravel backend and initially targets Android only.

## Architecture

```text
PelekaPro Mobile
        ↓
Laravel Sanctum API
        ↓
MySQL
        ↓
Redis
        ↓
Laravel Reverb
        ↓
Customer tracking PWA
```

The Laravel application remains the authority for users, deliveries, tracking sessions, payments, and delivery status. The mobile application must stop collecting GPS immediately after delivery, failure, or an authorized cancellation.

## Development requirements

- Flutter stable 3.44.8 or a compatible newer stable release
- Dart 3.12.2 or the version bundled with the selected Flutter SDK
- Android Studio with Android SDK, Platform, Build-Tools, Command-line Tools, and Platform-Tools
- PhpStorm with the Flutter and Dart plugins
- A physical Android phone or a separately configured emulator

Check the environment before development:

```bash
flutter doctor -v
flutter devices
adb devices
flutter pub get
flutter analyze
flutter test
```

In PhpStorm, install support through **Settings → Plugins → Marketplace → Flutter → Install**. Allow the Dart plugin to install, restart PhpStorm, and open this directory in its own window rather than nesting it inside the Laravel project.

## Physical Android phone

1. Open **Android Settings → About phone**.
2. Tap **Build number** seven times.
3. Open **Developer options** and enable **USB debugging**.
4. Connect the phone with a data-capable USB cable.
5. Accept the computer authorization prompt on the phone.
6. Confirm the device and run the app:

```bash
adb devices
flutter devices
flutter run
```

## Local Laravel API

The API base URL is a Dart compile-time value and is not stored in source control:

```bash
flutter run --dart-define=API_BASE_URL=http://MAC_LAN_IP:8000
```

Find the Mac's active LAN address without assuming a network-interface name:

```bash
DEFAULT_INTERFACE="$(route get default 2>/dev/null | awk '/interface:/{print $2}')"
MAC_LAN_IP="$(ipconfig getifaddr "$DEFAULT_INTERFACE")"
echo "$MAC_LAN_IP"
```

Run Laravel on the LAN separately from its backend repository:

```bash
php artisan serve --host=0.0.0.0 --port=8000
```

`127.0.0.1` on a physical phone means the phone itself, not the Mac. The Mac and phone must be on the same trusted local network, and macOS may ask for permission to accept incoming connections.

Debug Android builds permit cleartext HTTP for local Laravel development. Release builds do not enable unrestricted cleartext traffic and must use HTTPS.

## Verification and builds

Format, analyze, and test the project:

```bash
dart format .
flutter analyze
flutter test
```

Build a debug APK:

```bash
flutter build apk --debug
```

The generated file is normally located at:

```text
build/app/outputs/flutter-apk/app-debug.apk
```

Build output, machine-local SDK paths, changing LAN addresses, signing keys, passwords, tokens, and other secrets must never be committed.

## Planned mobile roadmap

1. Laravel Sanctum driver login
2. Secure token storage
3. Authenticated driver profile
4. Assigned-delivery list
5. Delivery details
6. Start delivery
7. Foreground GPS collection
8. GPS submissions approximately every five seconds
9. Proof capture and upload
10. Cash/payment recording
11. Mark delivered
12. Mark failed
13. Stop GPS immediately on delivered, failed, or cancelled
14. Reverb integration where required
15. Production Android configuration

The next implementation phase is Laravel Sanctum driver login. Authentication, API calls, GPS, maps, proof uploads, payments, and Reverb integration are intentionally outside this initial setup.
