# Architecture V1

Date: 2026-07-18  
Architecture tag: `architecture-v1`  
Status: Frozen

## Reference

This release note is governed by [Permanent Architecture Charter](../PERMANENT_ARCHITECTURE_CHARTER.md).

## Protected Product

- Rider App

## Backend Sharing Policy

The Circum platform Backend is intentionally shared and remains the authority for Cloud Functions, Firestore Rules, Storage Rules, canonical lifecycle, payments, IRIS, authentication authority, and notification authority.

## Product Ownership Rules

- Rider App must not share product source with Website, Sender App, or Admin.
- Rider App must not import another product's UI, routing, navigation, controllers, blocs, providers, repositories, models, services, helpers, or utilities.
- Repository engineering tooling may be shared.
- Shared branding assets are allowed where intentional and where they contain no product logic.

## Certification Results

- Shared backend: allowed.
- Shared repository tooling: allowed.
- Shared branding assets: allowed where intentional.
- Shared product source: 0.
- Cross-product imports: 0.
- Transitive dependency intersections: 0.
- Product ownership violations: 0.

## Protected Architecture Files

- `docs/PERMANENT_ARCHITECTURE_CHARTER.md`
- `deploy-manifest.json`
- `scripts/absolute_product_ownership.js`

Future changes to protected architecture files require explicit architecture review, minimum two approvals, and a fresh certification run.
