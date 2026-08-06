#!/usr/bin/env node
const fs = require("fs");

function read(path) {
  return fs.readFileSync(path, "utf8");
}

function assertContains(path, needle, label) {
  const source = read(path);
  if (!source.includes(needle)) {
    throw new Error(`${label}: missing ${needle} in ${path}`);
  }
}

function assertNoRuntimeMapsKey(path) {
  const source = read(path);
  const executable = source
    .split(/\r?\n/)
    .map((line) => line.trimStart())
    .filter((line) => !line.startsWith("//"))
    .join("\n");
  if (/AIza[0-9A-Za-z_-]+/.test(executable)) {
    throw new Error(`Hardcoded Google Maps API key found in ${path}`);
  }
}

assertContains(
  "android/app/build.gradle",
  'applicationId "com.circum.rider"',
  "Rider Android package",
);
assertContains(
  "android/app/build.gradle",
  "GOOGLE_MAPS_API_KEY",
  "Rider Android Maps key injection",
);
assertContains(
  "android/app/src/main/AndroidManifest.xml",
  'android:value="${googleMapsApiKey}"',
  "Rider Android Maps manifest placeholder",
);
assertContains(
  "ios/Runner/Info.plist",
  "$(GOOGLE_MAPS_API_KEY)",
  "Rider iOS Maps key build setting",
);
assertContains(
  "ios/Runner/AppDelegate.swift",
  "GoogleMapsApiKey",
  "Rider iOS Maps key lookup",
);
assertContains(
  "docs/google-maps-production-architecture.md",
  "RIDER_IOS_GOOGLE_MAPS_API_KEY",
  "Future Rider iOS CI Maps secret contract",
);
assertContains(
  "docs/google-maps-production-architecture.md",
  "GOOGLE_MAPS_API_KEY",
  "Future Rider iOS CI build setting mapping",
);
assertContains(
  ".github/workflows/rc1_release_build.yml",
  "RIDER_ANDROID_GOOGLE_MAPS_API_KEY",
  "Rider Android CI Maps secret",
);
assertContains(
  ".github/workflows/rc1_release_build.yml",
  "GOOGLE_MAPS_DIRECTIONS_API_KEY",
  "Rider Directions CI key",
);
assertContains(
  "lib/app/home/bloc/home_bloc.dart",
  "String.fromEnvironment('GOOGLE_MAPS_DIRECTIONS_API_KEY')",
  "Rider route preview Directions key",
);
assertContains(
  "lib/app/home/repo/direction_service.dart",
  "String.fromEnvironment('GOOGLE_MAPS_DIRECTIONS_API_KEY')",
  "Rider turn-by-turn Directions key",
);

for (const path of [
  "android/app/src/main/AndroidManifest.xml",
  "ios/Runner/AppDelegate.swift",
  "ios/Runner/Info.plist",
]) {
  assertNoRuntimeMapsKey(path);
}

console.log(JSON.stringify({
  ok: true,
  surface: "rider-app",
  checks: [
    "android-package",
    "android-maps-config",
    "ios-maps-config",
    "directions-config",
    "ci-secret",
    "no-hardcoded-runtime-maps-keys",
  ],
}, null, 2));
