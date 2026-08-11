const test = require('node:test');
const assert = require('node:assert/strict');
const { execFileSync } = require('node:child_process');
const path = require('node:path');

test('platform isolation guard passes for the clean Rider source', () => {
  const script = path.join(__dirname, '..', 'scripts', 'check_platform_isolation.js');
  assert.doesNotThrow(() => execFileSync(process.execPath, [script], { stdio: 'pipe' }));
});

test('incident guard rejects the mobile entrypoint as a Web root', () => {
  const source = require('node:fs').readFileSync(
    path.join(__dirname, '..', 'lib', 'main_rider_web.dart'), 'utf8');
  assert.equal(source.includes("package:circum_rider/main.dart"), false);
});
