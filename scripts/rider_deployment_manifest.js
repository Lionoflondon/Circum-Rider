#!/usr/bin/env node

const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
const childProcess = require('child_process');

const CONFIG = Object.freeze({
  product: 'Circum Rider Web',
  buildIdentity: 'CIRCUM_BUILD_ID=circum-rider-web',
  entrypoint: 'lib/main_rider_web.dart',
  firebaseProject: 'circum-2797c',
  hostingSiteId: 'circum-rider-2797c',
  targetAlias: 'rider',
  outputDirectory: 'build/web',
});

function fail(message) {
  throw new Error(`Rider deployment manifest blocked: ${message}`);
}

function readJson(file) {
  return JSON.parse(fs.readFileSync(file, 'utf8'));
}

function gitValue(args) {
  return childProcess.execFileSync('git', args, { encoding: 'utf8' }).trim();
}

function sha256Files(files) {
  const hash = crypto.createHash('sha256');
  for (const file of files) {
    hash.update(path.basename(file));
    hash.update(fs.readFileSync(file));
  }
  return hash.digest('hex');
}

function artifactFiles(root = process.cwd()) {
  const output = path.join(root, CONFIG.outputDirectory);
  return {
    output,
    index: path.join(output, 'index.html'),
    bundle: path.join(output, 'main.dart.js'),
    bootstrap: path.join(output, 'flutter_bootstrap.js'),
    identity: path.join(output, 'circum-build-identity.txt'),
    manifest: path.join(output, 'deployment-manifest.json'),
  };
}

function validateFirebaseConfiguration(root = process.cwd()) {
  const firebaserc = readJson(path.join(root, '.firebaserc'));
  const firebase = readJson(path.join(root, 'firebase.json'));
  if (firebaserc.projects?.default !== CONFIG.firebaseProject) {
    fail(`default Firebase project must be ${CONFIG.firebaseProject}`);
  }
  const hosting = firebase.hosting;
  if (!hosting || hosting.site !== CONFIG.hostingSiteId) {
    fail(`Firebase Hosting site must be ${CONFIG.hostingSiteId}`);
  }
  if (hosting.public !== CONFIG.outputDirectory) {
    fail(`Firebase Hosting public directory must be ${CONFIG.outputDirectory}`);
  }
  return true;
}

function validateBundle(bundleSource, bootstrapSource) {
  if (!bootstrapSource.includes("window.CIRCUM_RIDER_BUILD = 'rider-web-cache-v2'")) {
    fail('Rider bootstrap marker is missing');
  }
  if (!bundleSource.includes('RDR-WEB-START-001')) {
    fail('Rider Web entrypoint marker is missing from the compiled bundle');
  }
  if (!bundleSource.includes('Circum Rider')) {
    fail('Rider app marker is missing from the compiled bundle');
  }
  return true;
}

function validateIdentity(identity) {
  if (identity.trim() !== CONFIG.buildIdentity) {
    fail('build identity does not match Rider');
  }
  return true;
}

function validateManifest(manifest, expected, now, checksum) {
  for (const [key, value] of Object.entries(expected)) {
    if (manifest[key] !== value) fail(`manifest ${key} does not match Rider build`);
  }
  const age = now.getTime() - Date.parse(manifest.buildTimestamp);
  if (!Number.isFinite(age) || age < 0 || age > 2 * 60 * 60 * 1000) {
    fail('deployment manifest is stale');
  }
  if (manifest.buildChecksum !== checksum) {
    fail('deployment manifest checksum mismatch');
  }
  return true;
}

function expectedManifest(root = process.cwd()) {
  return {
    product: CONFIG.product,
    buildIdentity: CONFIG.buildIdentity,
    entrypoint: CONFIG.entrypoint,
    gitCommit: gitValue(['rev-parse', 'HEAD']),
    gitCommitTimestamp: gitValue(['show', '-s', '--format=%cI', 'HEAD']),
    branch: gitValue(['branch', '--show-current']),
    firebaseProject: CONFIG.firebaseProject,
    hostingSiteId: CONFIG.hostingSiteId,
    targetAlias: CONFIG.targetAlias,
    outputDirectory: CONFIG.outputDirectory,
  };
}

function prepare(root = process.cwd(), now = new Date()) {
  validateFirebaseConfiguration(root);
  const files = artifactFiles(root);
  if (!fs.existsSync(files.index) || !fs.existsSync(files.bundle) || !fs.existsSync(files.bootstrap)) {
    fail(`${CONFIG.outputDirectory} is not a complete Rider web build`);
  }
  validateBundle(
    fs.readFileSync(files.bundle, 'utf8'),
    fs.readFileSync(files.bootstrap, 'utf8'),
  );
  fs.writeFileSync(files.identity, `${CONFIG.buildIdentity}\n`);
  const checksum = sha256Files([files.index, files.bundle, files.bootstrap, files.identity]);
  const manifest = {
    ...expectedManifest(root),
    buildTimestamp: now.toISOString(),
    buildChecksum: checksum,
  };
  fs.writeFileSync(files.manifest, `${JSON.stringify(manifest, null, 2)}\n`);
  return manifest;
}

function verify(root = process.cwd(), now = new Date()) {
  validateFirebaseConfiguration(root);
  const files = artifactFiles(root);
  for (const file of [files.index, files.bundle, files.bootstrap, files.identity, files.manifest]) {
    if (!fs.existsSync(file)) fail(`required artifact is missing: ${file}`);
  }
  validateIdentity(fs.readFileSync(files.identity, 'utf8'));
  validateBundle(
    fs.readFileSync(files.bundle, 'utf8'),
    fs.readFileSync(files.bootstrap, 'utf8'),
  );
  const checksum = sha256Files([files.index, files.bundle, files.bootstrap, files.identity]);
  const manifest = readJson(files.manifest);
  validateManifest(manifest, expectedManifest(root), now, checksum);
  return manifest;
}

if (require.main === module) {
  try {
    const [command] = process.argv.slice(2);
    const result = command === 'prepare'
      ? prepare()
      : command === 'verify'
        ? verify()
        : fail('use prepare|verify');
    process.stdout.write(`${JSON.stringify(result)}\n`);
  } catch (error) {
    process.stderr.write(`${error.message}\n`);
    process.exit(1);
  }
}

module.exports = {
  CONFIG,
  prepare,
  verify,
  validateBundle,
  validateFirebaseConfiguration,
  validateIdentity,
  validateManifest,
};
