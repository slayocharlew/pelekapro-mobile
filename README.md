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
- `lib/features/deliveries/data` fetches and validates assigned-list and selected-delivery responses.
- `lib/features/deliveries/domain` contains the server-authoritative delivery models, repository contract, statuses, and failures.
- `lib/features/deliveries/presentation` contains assigned-list state, server-to-UI mapping, and the approved delivery workflow screens.
- `lib/features/navigation` owns real map-route models, OSRM parsing, route refresh policy, and navigation state.
- `lib/shared/widgets` contains the PelekaPro brand mark, card, button, and status components.
- `lib/core/network` contains the shared JSON API client.
- `lib/core/storage` stores session credentials with Android secure storage.

The app accepts only a response whose authenticated user has the `driver` role. A token issued for another role is revoked immediately and is not stored. Driver tokens are never printed or included in UI messages. API validation errors are shown beside the matching form fields.

On startup, the app reads the encrypted token and consumes `GET /api/auth/me`. A valid driver opens the driver workspace and Account tab, an expired or revoked token is removed before returning to login, and a temporary server or network failure preserves the token and offers Retry.

The Account tab consumes `POST /api/auth/logout`. It asks for confirmation, revokes only the current bearer token, removes it from secure storage, clears private in-memory state, and returns to login. A recoverable server failure keeps the secure session so the driver can retry.

## Assigned deliveries and workflow

After authentication, the app consumes `GET /api/driver/deliveries` with the bearer token held in secure storage. It validates the complete documented driver-delivery resource, deliberately parses decimal strings, and renders only deliveries assigned by Laravel to the current driver. The list supports loading, empty, retry, pull-to-refresh, and non-destructive refresh-error states. A `401` response clears the expired secure token and returns to login.

The list response is currently unpaginated and newest-first. The app does not manufacture statuses or add client-side API filters. Opening a delivery consumes `GET /api/driver/deliveries/{delivery}`, refreshes that selected item with the server response, and uses the returned active `failure_reasons` in the Report issue form. Detail loading, retry, malformed-response, and expired-session states are handled without exposing raw exceptions.

Start Delivery consumes `POST /api/driver/deliveries/{delivery}/start` without a request body. The button is disabled while submitting, navigation opens only after Laravel returns the full delivery with `on_the_way`, and the selected delivery is replaced with that server response. A failed or `409` response triggers a detail refetch before another attempt, preventing a blind duplicate start after an ambiguous timeout or conflict. A `401` clears the secure session and returns to login.

After Laravel starts a delivery, foreground GPS starts with Android permission and service checks. The app submits the documented location sample approximately every five seconds, follows the rider on the map, pauses when the app is covered, and reconciles Laravel state when connectivity or foreground activity returns.

The navigation view uses the real `dropoff.latitude` and `dropoff.longitude` returned by Laravel. It never substitutes a customer name or written address for geographic coordinates. Google Maps SDK for Android provides only the visible map, while the independently configured OSRM-compatible routing service supplies road geometry, distance, duration, and the next maneuver. If a drop-off pin, GPS fix, map key, or routing response is unavailable, the app shows that limitation and does not draw a fabricated route.

## Google Maps SDK for Android

The Flutter map requires its own Android-restricted Google Maps key. It must not reuse the Laravel browser key or JavaScript Map ID. In Google Cloud, enable only **Maps SDK for Android**, create a separate key, and apply both restrictions:

- Android application package `tz.co.pelekapro.mobile`
- the SHA-1 fingerprint from the signing certificate used for that build

Obtain the local debug fingerprint with Android Studio's bundled Java:

```bash
cd android
JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew signingReport
cd ..
```

The current development machine's debug SHA-1 is:

```text
88:FF:FF:24:B6:5C:68:02:75:1F:C7:69:9C:48:B9:FF:31:F2:C2:2E
```

Keep the real key only in the ignored `android/local.properties` file. Preserve its existing `sdk.dir` line and add:

```properties
MAPS_API_KEY=YOUR_ANDROID_RESTRICTED_MAPS_SDK_KEY
```

`android/local.properties.example` provides the safe placeholder. Gradle injects the value into `AndroidManifest.xml`; Dart never reads, prints, or stores the key. If the key is absent, the navigation screen renders a safe map-unavailable state. Release signing requires its own real certificate fingerprint and appropriately restricted key before distribution.

Configure development routing separately from the PelekaPro API:

```bash
flutter run \
  --dart-define=API_BASE_URL=http://127.0.0.1:8000 \
  --dart-define=ROUTING_BASE_URL=https://router.project-osrm.org
```

`router.project-osrm.org` is a best-effort demo service suitable for development verification, not a production SLA. Configure a controlled OSRM deployment or supported provider for production. The Google SDK remains a renderer only: the app does not add Google Places, Routes, Navigation, Geocoding, or Street View services. Device GPS samples continue to go exclusively to Laravel through `POST /api/driver/deliveries/{delivery}/locations`.

Mark Delivered consumes `POST /api/driver/deliveries/{delivery}/deliver`, including optional photo proof and the actual collected amount when Laravel requires collection. The current backend contract has no delivery PIN field, so the mobile app neither requests nor submits one. Report Issue remains the next local-only outcome workflow:

- assigned deliveries → details → start → active navigation;
- active navigation → mark delivered API → delivered result;
- active navigation → report issue → failed result;
- either result → back to deliveries.

The failed transition still updates only presentation memory and is replaced by the next server refresh. No fail, tracking-history, or Reverb endpoint is called yet. The UI does not invent accept, mark-arrived, cancel, assign, or unassign actions.

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
- Assigned deliveries through `GET /api/driver/deliveries`
- Selected delivery and active failure reasons through `GET /api/driver/deliveries/{delivery}`
- Start delivery through `POST /api/driver/deliveries/{delivery}/start`
- Foreground device location through `POST /api/driver/deliveries/{delivery}/locations`
- Google Maps SDK for Android rendering with the rider and server-provided drop-off coordinates
- Android-local, manifest-placeholder map-key injection with a safe missing-key state
- Configurable OSRM road geometry, ETA, distance, and maneuver guidance
- Delivery completion through `POST /api/driver/deliveries/{delivery}/deliver`
- Optional JPEG/PNG/WebP proof capture and multipart upload
- PIN-free completion aligned with the current Laravel schema
- Assigned-list loading, empty, retry, refresh, and session-expiry handling
- Delivery-detail loading, retry, validation, and session-expiry handling
- Duplicate-start protection and ambiguous-start reconciliation
- Complete local UI journey for delivery design approval
- API, repository, controller, and UI error handling

Next phases:

1. Connect the failed-delivery API and optional failure proof
2. Verify terminal GPS shutdown for every authoritative failed/cancelled response
3. Deploy production-grade motorcycle-aware routing and release map credentials
4. Connect authorized tracking history
5. Consume logout-all when required
6. Add Reverb integration where required
7. Add production Android signing and configuration
