const test = require('node:test');
const assert = require('node:assert/strict');
const {execFileSync} = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');

const root = path.join(__dirname, '..');

test('platform isolation guard passes for Rider production source', () => {
  const script = path.join(root, 'scripts', 'check_platform_isolation.js');
  assert.doesNotThrow(() =>
    execFileSync(process.execPath, [script], {stdio: 'pipe'}));
});

test('incident guard keeps Web out of the mobile entrypoint', () => {
  const source = fs.readFileSync(
    path.join(root, 'lib', 'main_rider_web.dart'), 'utf8');
  assert.equal(source.includes('package:circum_rider/main.dart'), false);
  assert.match(source, /package:circum_rider\/rider_app\.dart/);
});

test('App Check provider ownership stays platform-local', () => {
  const web = fs.readFileSync(path.join(root, 'lib', 'app',
    'security', 'rider_app_check.dart'), 'utf8');
  const mobile = fs.readFileSync(path.join(root, 'lib', 'app',
    'security', 'circum_app_check.dart'), 'utf8');
  assert.equal(web.includes('AndroidProvider'), false);
  assert.equal(web.includes('AppleProvider'), false);
  assert.equal(mobile.includes('ReCaptchaEnterpriseProvider'), false);
  assert.equal(mobile.includes('webProvider'), false);
});
