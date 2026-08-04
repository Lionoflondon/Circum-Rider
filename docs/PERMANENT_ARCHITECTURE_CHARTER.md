# Permanent Architecture Charter

This document is the permanent architecture law for Circum Rider as part of the Circum platform.

Circum is one platform composed of independent products. Product source is isolated. The platform backend is intentionally shared.

## Canonical Rider Products

1. Rider Mobile App
   - Entrypoint: `lib/main.dart`
   - Surface identity: `circum-rider-mobile`
   - Build/deployment: native Android/iOS only
   - Must not initialize Firebase with web options.
   - Must not own Rider Web startup, hosting, Flutter bootstrap, or deployment metadata.

2. Rider Web
   - Entrypoint: `lib/main_rider_web.dart`
   - Hosting site: `circum-rider-2797c`
   - Build directory: `build/web`
   - Surface identity: `circum-rider-web`
   - Must initialize Firebase with `DefaultFirebaseOptions.web`.
   - Must not become the Android or iOS entrypoint.

The Rider Mobile App and Rider Web share Rider product domain code only inside this repository. They must never share startup paths, hosting targets, build identities, Flutter web bootstrap ownership, or deployment manifests.

## Allowed Platform Sharing

Allowed:

- Shared backend authority.
- Shared repository engineering tooling.
- Shared linting, formatting, and CI helpers.
- Shared ownership validators and deployment guards.
- Shared branding assets where duplication adds no architectural value.

## Forbidden Sharing

Forbidden:

- Shared product source between Rider App and any other product.
- Cross-product imports.
- Shared startup entrypoints between Rider Mobile App and Rider Web.
- Shared Flutter web bootstrap ownership between Rider Mobile App and Rider Web.
- Shared hosting targets between Rider Mobile App and Rider Web.
- Shared build identities between Rider Mobile App and Rider Web.
- Shared widgets, screens, routes, navigation, controllers, blocs, providers, repositories, models, services, helpers, or utilities between products.
- Product configuration imported by another product.

## Platform Product Matrix

| Product | Repository | Entrypoint | Hosting/build target | Identity |
| --- | --- | --- | --- | --- |
| Sender Mobile App | Circum- | `lib/main.dart` | Native Android/iOS | `circum-sender-mobile` |
| Sender Web | Circum- | `lib/app/sender_mobile/sender_mobile_preview.dart` | `hosting:app`, `build/sender_app_web` | `circum-sender-web` |
| Rider Mobile App | Circum-Rider | `lib/main.dart` | Native Android/iOS | `circum-rider-mobile` |
| Rider Web | Circum-Rider | `lib/main_rider_web.dart` | `circum-rider-2797c`, `build/web` | `circum-rider-web` |

## Recovery Procedure

1. Identify whether the issue belongs to Rider Mobile App or Rider Web.
2. Build only the affected surface from its canonical entrypoint.
3. Verify the generated artifact identity and `gitCommit` metadata.
4. Run Rider ownership and deployment guards.
5. Deploy only Rider Web hosting or use the native app release lane. Never do both in one release.
6. If Sender, Website, Admin, Functions, Firestore Rules, or Storage Rules are touched, stop and split the lane.

## Certification Standard

Architecture passes only when:

- Shared backend: allowed.
- Shared repository tooling: allowed.
- Shared branding assets: allowed where intentional.
- Shared product source: 0.
- Cross-product imports: 0.
- Transitive dependency intersections: 0, excluding backend.
- Product ownership violations: 0.
- Entrypoint overlap: 0.
- Build identity overlap: 0.
- Hosting target overlap: 0.
- Missing artifact metadata: 0.

The backend is one platform. The products are independent. Shared product source code is never permitted.
