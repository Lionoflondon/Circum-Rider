#!/usr/bin/env node
/* eslint-disable no-console */
const cp = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');

function fail(message, details = []) {
  console.error('RIDER DEPLOY GUARD SELF-TEST FAILED');
  console.error(message);
  for (const detail of details) console.error(`- ${detail}`);
  process.exit(1);
}

function run(command, args) {
  cp.execFileSync(command, args, {
    cwd: root,
    stdio: 'inherit',
  });
}

const manifest = JSON.parse(
  fs.readFileSync(path.join(root, 'deploy-manifest.json'), 'utf8'),
);
const riderApp = manifest.products?.['rider-app'];
const riderWeb = manifest.products?.['rider-web'];

if (!riderApp || !riderWeb) fail('manifest must define rider-app and rider-web');

const expectations = [
  ['rider-app.identity', riderApp.identity, 'circum-rider-mobile'],
  ['rider-app.surface', riderApp.surface, 'rider-mobile'],
  ['rider-app.entrypoint', riderApp.entrypoints?.[0], 'lib/main.dart'],
  ['rider-web.identity', riderWeb.identity, 'circum-rider-web'],
  ['rider-web.surface', riderWeb.surface, 'rider-web'],
  ['rider-web.entrypoint', riderWeb.entrypoints?.[0], 'lib/main_rider_web.dart'],
  ['rider-web.hostingTarget', riderWeb.hostingTarget, 'circum-rider-2797c'],
  ['rider-web.buildDirectory', riderWeb.buildDirectory, 'build/web'],
];
const mismatches = expectations
  .filter(([, actual, expected]) => actual !== expected)
  .map(([field, actual, expected]) => `${field}: ${actual} != ${expected}`);
if (mismatches.length > 0) fail('canonical Rider metadata mismatch', mismatches);

if (riderApp.entrypoints?.includes(riderWeb.entrypoints?.[0])) {
  fail('Rider Mobile and Rider Web entrypoints overlap');
}

run('node', ['scripts/absolute_product_ownership.js']);
run('node', ['--test', 'test/rider_deployment_manifest_test.js']);

console.log(JSON.stringify({
  ok: true,
  products: ['rider-app', 'rider-web'],
}, null, 2));
