# PelekaPro

PelekaPro is the Android driver application for the PelekaPro delivery-management and live-tracking platform. This Flutter project is maintained separately from the Laravel backend and targets Android only.

## Architecture

```text
PelekaPro Android app
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

While developing over an authorized USB connection, `adb reverse` can forward the phone's port 8000 to a Laravel server listening on the Mac's localhost. This avoids exposing the development server to the LAN:

```bash
adb -s DEVICE_ID reverse tcp:8000 tcp:8000
flutter run -d DEVICE_ID --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

The forwarding rule is temporary. Run `adb reverse` again after reconnecting or restarting the phone.

Debug Android builds permit cleartext HTTP for local Laravel development. Release builds do not enable unrestricted cleartext traffic and must use HTTPS.

## Driver authentication

The login screen consumes `POST /api/auth/login` with the phone number or email, password, and Android device name. Start the app with the API URL supplied at build time:

```bash
flutter run -d DEVICE_ID --dart-define=API_BASE_URL=http://MAC_LAN_IP:8000
```

The authentication code is separated by responsibility under `lib/features/auth`:

- `data` sends login, current-user, and logout requests and implements the repository.
- `domain` contains the session, user, driver-profile, repository, and failure types.
- `presentation` contains the startup auth flow, controllers, login UI, and retry state.
- `lib/features/account` renders the current driver returned by `GET /api/auth/me` and current-device security actions.
- `lib/features/shell` owns the Deliveries, Active, and Account navigation.
- `lib/features/deliveries/demo` contains isolated Tanzanian UI fixtures and local-only transitions.
- `lib/features/deliveries/presentation` contains the approved delivery workflow screens without delivery networking.
- `lib/shared/widgets` contains the PelekaPro brand mark, card, button, and status components.
- `lib/core/network` contains the shared JSON API client.
- `lib/core/storage` stores session credentials with Android secure storage.

The app accepts only a response whose authenticated user has the `driver` role. A token issued for another role is revoked immediately and is not stored. Driver tokens are never printed or included in UI messages. API validation errors are shown beside the matching form fields.

On startup, the app reads the encrypted token and consumes `GET /api/auth/me`. A valid driver opens the driver workspace and Account tab, an expired or revoked token is removed before returning to login, and a temporary server or network failure preserves the token and offers Retry.

The Account tab consumes `POST /api/auth/logout`. It asks for confirmation, revokes only the current bearer token, removes it from secure storage, clears private in-memory state, and returns to login. A recoverable server failure keeps the secure session so the driver can retry.

## Delivery UI approval build

After authentication, delivery content currently comes only from `lib/features/deliveries/demo`. It does not fetch assignments, change Laravel state, collect GPS, open the camera, upload proof, or record money. The complete UI journey is available locally for approval:

- assigned deliveries → details → start → active navigation;
- active navigation → mark delivered → delivered result;
- active navigation → report issue → failed result;
- either result → back to deliveries.

Start, delivered, and failed transitions update only the in-memory demo store. The UI does not invent accept, mark-arrived, cancel, assign, or unassign actions. The custom navigation composition follows an OpenStreetMap visual direction with a top-down motorcycle marker; no map, routing, location, or navigation SDK is connected yet.

The approved screenshots remain in `UI/` as design references. That directory is deliberately absent from `pubspec.yaml` assets and is not bundled into the Android application.

Android Auto Backup is disabled so encrypted storage keys cannot become detached from restored ciphertext. Local HTTP remains limited to debug builds; use an HTTPS API URL for production.

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

## Mobile roadmap

Implemented:

- Laravel Sanctum driver login
- Driver-role enforcement
- Secure token storage
- Stored-session restoration through `GET /api/auth/me`
- Deliveries, Active, and Account application shell
- Authenticated Account profile and manual refresh
- Current-device logout through `POST /api/auth/logout`
- Complete local UI journey for delivery design approval
- API, repository, controller, and UI error handling

Next phases:

1. Consume assigned-delivery list and detail APIs in the prepared UI
2. Connect the start transition
3. Add foreground GPS collection and submissions approximately every five seconds
4. Connect proof capture and upload
5. Connect delivered, failed, PIN, and payment workflows
6. Stop GPS immediately on delivered, failed, or cancelled
7. Connect authorized tracking history
8. Consume logout-all when required
9. Add Reverb integration where required
10. Add production Android signing and configuration
