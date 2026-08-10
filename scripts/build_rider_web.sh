#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

WEB_RECAPTCHA_SITE_KEY="${RIDER_WEB_RECAPTCHA_ENTERPRISE_SITE_KEY:-}"
WEB_MAPS_API_KEY="${RIDER_WEB_GOOGLE_MAPS_API_KEY:-}"

if [[ -z "$WEB_RECAPTCHA_SITE_KEY" ]]; then
  echo "Missing RIDER_WEB_RECAPTCHA_ENTERPRISE_SITE_KEY for Rider Web App Check." >&2
  exit 1
fi
if [[ -z "$WEB_MAPS_API_KEY" ]]; then
  echo "Missing RIDER_WEB_GOOGLE_MAPS_API_KEY for Rider Web Maps." >&2
  exit 1
fi

echo "Project: circum-2797c"
echo "Surface: Rider Web"
echo "Entrypoint: lib/main_rider_web.dart"
echo "Output: build/web"
echo "Identity: circum-rider-web"

rm -rf "$ROOT_DIR/build/web"
flutter build web \
  --release \
  --no-wasm-dry-run \
  --dart-define=RIDER_WEB_RECAPTCHA_ENTERPRISE_SITE_KEY="$WEB_RECAPTCHA_SITE_KEY" \
  --target=lib/main_rider_web.dart \
  --output="$ROOT_DIR/build/web"
sed -i.bak "s/__RIDER_WEB_GOOGLE_MAPS_API_KEY__/$WEB_MAPS_API_KEY/g" "$ROOT_DIR/build/web/index.html"
rm -f "$ROOT_DIR/build/web/index.html.bak"
if grep -q '__RIDER_WEB_GOOGLE_MAPS_API_KEY__' "$ROOT_DIR/build/web/index.html"; then
  echo "Rider Web Maps key placeholder remained in the release artifact." >&2
  exit 1
fi
node "$ROOT_DIR/scripts/rider_deployment_manifest.js" prepare
