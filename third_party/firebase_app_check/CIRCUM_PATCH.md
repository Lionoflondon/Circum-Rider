# Compatibility patch

Upstream: firebase_app_check 0.3.2 from https://pub.dev/packages/firebase_app_check/versions/0.3.2 (FlutterFire, BSD license retained).

Android-only patch removes the discontinued SafetyNet dependency and factory. Selecting SafetyNet fails explicitly; debug and Play Integrity behaviour is unchanged. Rider already selects Play Integrity for release. iOS, macOS and Dart sources are unchanged. This keeps the existing Firebase Core 3 cohort compatible rather than mixing incompatible plugin majors.

Remove this local override when upgrading the entire FlutterFire cohort to an upstream version that removes SafetyNet. Native release compilation and physical Play Integrity attestation remain required at the next authorized build.
