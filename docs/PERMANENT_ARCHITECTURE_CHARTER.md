# Permanent Architecture Charter

This document is the permanent architecture law for Circum Rider as part of the Circum platform.

Circum is one platform composed of independent products. Product source is isolated. The platform backend is intentionally shared.

## Rider App Ownership

The Rider App owns:

- Rider mobile
- Jobs
- Tracking
- GPS
- Earnings
- Documents
- Vehicles
- Rider navigation

The Rider App must not import Website, Sender App, or Admin product source.

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
- Shared widgets, screens, routes, navigation, controllers, blocs, providers, repositories, models, services, helpers, or utilities between products.
- Product configuration imported by another product.

## Certification Standard

Architecture passes only when:

- Shared backend: allowed.
- Shared repository tooling: allowed.
- Shared branding assets: allowed where intentional.
- Shared product source: 0.
- Cross-product imports: 0.
- Transitive dependency intersections: 0, excluding backend.
- Product ownership violations: 0.

The backend is one platform. The products are independent. Shared product source code is never permitted.
