const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const test = require('node:test');

const {
  CONFIG,
  validateBundle,
  validateFirebaseConfiguration,
  validateIdentity,
  validateManifest,
} = require('../scripts/rider_deployment_manifest.js');

function fixture() {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'circum-rider-manifest-'));
  fs.writeFileSync(path.join(root, '.firebaserc'), JSON.stringify({
    projects: { default: 'circum-2797c' },
  }));
  fs.writeFileSync(path.join(root, 'firebase.json'), JSON.stringify({
    hosting: {
      site: 'circum-rider-2797c',
      public: 'build/web',
    },
  }));
  return root;
}

test('Rider Hosting configuration targets only the Rider site', () => {
  assert.equal(validateFirebaseConfiguration(fixture()), true);
});

test('wrong Firebase project blocks Rider deployment', () => {
  const root = fixture();
  fs.writeFileSync(path.join(root, '.firebaserc'), JSON.stringify({
    projects: { default: 'circum-2797c-dev' },
  }));
  assert.throws(() => validateFirebaseConfiguration(root), /circum-2797c/);
});

test('wrong Hosting site blocks Rider deployment', () => {
  const root = fixture();
  fs.writeFileSync(path.join(root, 'firebase.json'), JSON.stringify({
    hosting: {
      site: 'circum-app-2797c',
      public: 'build/web',
    },
  }));
  assert.throws(() => validateFirebaseConfiguration(root), /circum-rider-2797c/);
});

test('Rider build identity is exact', () => {
  assert.equal(validateIdentity('CIRCUM_BUILD_ID=circum-rider-web\n'), true);
  assert.throws(() => validateIdentity('CIRCUM_BUILD_ID=sender-app'), /identity/);
});

test('Rider Web bundle markers must be present', () => {
  assert.equal(
    validateBundle(
      'const title = "Circum Rider"; const ref = "RDR-WEB-START-001";',
      "window.CIRCUM_RIDER_BUILD = 'rider-web-cache-v2';",
    ),
    true,
  );
  assert.throws(
    () => validateBundle(
      'const title = "Circum Rider"; const ref = "RDR-WEB-START-001";',
      'window.OTHER_BUILD = true;',
    ),
    /bootstrap marker/,
  );
  assert.throws(
    () => validateBundle(
      'const title = "Circum Rider";',
      "window.CIRCUM_RIDER_BUILD = 'rider-web-cache-v2';",
    ),
    /Rider Web entrypoint marker/,
  );
});

test('manifest must match Rider target and remain fresh', () => {
  const now = new Date('2026-07-13T10:00:00.000Z');
  const expected = {
    product: CONFIG.product,
    buildIdentity: CONFIG.buildIdentity,
    gitCommit: 'abc123',
    gitCommitTimestamp: '2026-07-13T09:55:00.000Z',
    branch: 'main',
    firebaseProject: CONFIG.firebaseProject,
    hostingSiteId: CONFIG.hostingSiteId,
    entrypoint: CONFIG.entrypoint,
    outputDirectory: CONFIG.outputDirectory,
  };
  assert.equal(
    validateManifest({
      ...expected,
      buildTimestamp: now.toISOString(),
      buildChecksum: 'checksum',
    }, expected, now, 'checksum'),
    true,
  );
  assert.throws(
    () => validateManifest({
      ...expected,
      hostingSiteId: 'circum-app-2797c',
      buildTimestamp: now.toISOString(),
      buildChecksum: 'checksum',
    }, expected, now, 'checksum'),
    /hostingSiteId/,
  );
  assert.throws(
    () => validateManifest({
      ...expected,
      buildTimestamp: '2026-07-13T07:30:00.000Z',
      buildChecksum: 'checksum',
    }, expected, now, 'checksum'),
    /stale/,
  );
});
