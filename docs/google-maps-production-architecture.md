# Google Maps Production Architecture

Status: repository prepared, console verification pending.

## Current Repository Flow

| Surface | Runtime | Key source | APIs used | Failure behaviour |
| --- | --- | --- | --- | --- |
| Rider Android | `google_maps_flutter` native Android SDK | `GOOGLE_MAPS_API_KEY` manifest placeholder from shared `SENDER_ANDROID_GOOGLE_MAPS_API_KEY` in CI | Maps SDK for Android | Build now fails if the Android Maps key secret is missing. |
| Rider iOS | `google_maps_flutter` native iOS SDK | `$(GOOGLE_MAPS_API_KEY)` read from `Info.plist` by `AppDelegate`; future CI secret name `RIDER_IOS_GOOGLE_MAPS_API_KEY` | Maps SDK for iOS | `GMSServices` is called only when the build setting is present. |
| Rider mobile directions | Direct HTTPS from Flutter | `GOOGLE_MAPS_DIRECTIONS_API_KEY` | Directions API | Direction steps return empty on failure and log the error. |

Routes API is not used.

## Direct REST API Audit

| File | Function/area | API | Purpose | Authentication | Should remain client-side? |
| --- | --- | --- | --- | --- | --- |
| `lib/app/home/bloc/home_bloc.dart` | selected offer route preview | Directions API | Rider-to-pickup and pickup-to-drop-off route preview | `GOOGLE_MAPS_DIRECTIONS_API_KEY` | Short term yes; long term move behind Firebase Functions for stronger key restriction and consistent routing policy. |
| `lib/app/home/repo/direction_service.dart` | `getDetailedDirections` | Directions API | Rider turn-by-turn route steps and polylines | `GOOGLE_MAPS_DIRECTIONS_API_KEY` | Short term yes; long term move behind Firebase Functions for stronger key restriction and consistent routing policy. |

## Recommended Key Architecture

Required repository secrets today:

- `SENDER_ANDROID_GOOGLE_MAPS_API_KEY`: shared Sender/Rider Android native map SDK secret, with both package/SHA restrictions, Maps SDK for Android only.
- `GOOGLE_MAPS_DIRECTIONS_API_KEY`: temporary shared client-side route preview key, API restricted to Directions API.

Reserved future iOS CI secret:

- `RIDER_IOS_GOOGLE_MAPS_API_KEY`: Rider iOS native map SDK, iOS bundle restricted to `com.circum.rider`, Maps SDK for iOS only.

iOS builds currently consume `GOOGLE_MAPS_API_KEY` through Xcode build settings and there is no active iOS CI workflow. When iOS CI is enabled, the repository command should pass the product-specific secret into the existing build setting without code changes:

```bash
GOOGLE_MAPS_API_KEY="$RIDER_IOS_GOOGLE_MAPS_API_KEY" flutter build ipa --release --target=lib/main.dart
```

## Recommended Firebase Function Proxy

Long-term target:

1. Create a backend rider directions function.
2. Store the Google Directions key only in Cloud Functions secrets.
3. Apply App Check, auth, online-rider checks, rate limits, and per-rider quota.
4. Cache route responses by rounded origin/destination and mode for short TTLs.
5. Return direction steps and polyline data to Rider.
6. Remove Rider client-side Directions API usage after parity tests pass.

## Manual Console Actions

These cannot be completed from the repository.

1. Google Cloud Console -> APIs & Services -> Library -> Enable APIs.
   Button: Enable.
   Values: Maps SDK for Android, Maps SDK for iOS, Directions API.
   Why: Rider uses native maps and direct Directions API.
   Blocking: yes.
   Estimate: 3 minutes.

2. Google Cloud Console -> APIs & Services -> Credentials -> Rider Android key.
   Button: Edit API key.
   Values: package `com.circum.rider`; upload SHA-1 `96:2E:01:F3:B1:AA:DF:96:C1:23:62:CB:4A:7F:83:42:9D:F5:08:8E`; API restriction Maps SDK for Android.
   Why: Android SDK key must match app package and signing certificate.
   Blocking: yes.
   Estimate: 3 minutes.

3. Google Play Console -> Circum Rider -> Setup -> App integrity.
   Button: copy App signing certificate SHA-1.
   Values: add the Play app-signing SHA-1 to the Rider Android Google Cloud key and Firebase Android app if it differs from the upload SHA-1.
   Why: Play Store installs are signed by Play App Signing, not necessarily the upload key.
   Blocking: yes for Play installs.
   Estimate: 5 minutes.

4. Firebase Console -> Project settings -> Your apps -> Android app `com.circum.rider`.
   Button: Add fingerprint.
   Values: Rider SHA-1 `96:2E:01:F3:B1:AA:DF:96:C1:23:62:CB:4A:7F:83:42:9D:F5:08:8E`; plus Play app-signing SHA-1 if different.
   Why: Firebase Android app identity must match release certificates.
   Blocking: yes.
   Estimate: 3 minutes.

5. GitHub -> Rider repository Settings -> Secrets and variables -> Actions.
   Button: New repository secret.
   Values: `SENDER_ANDROID_GOOGLE_MAPS_API_KEY`, `GOOGLE_MAPS_DIRECTIONS_API_KEY`.
   Why: Rider Android CI now fails if either required Maps secret is absent.
   Blocking: yes.
   Estimate: 2 minutes.

6. Future only, when iOS CI is enabled -> GitHub -> Rider repository Settings -> Secrets and variables -> Actions.
   Button: New repository secret.
   Value: `RIDER_IOS_GOOGLE_MAPS_API_KEY`.
   Why: iOS already reads `GOOGLE_MAPS_API_KEY`; future CI should map the Rider-specific secret into that existing Xcode build setting.
   Blocking: no until iOS CI is enabled.
   Estimate: 1 minute.
