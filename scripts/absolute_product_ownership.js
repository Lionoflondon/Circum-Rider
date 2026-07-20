#!/usr/bin/env node
/* eslint-disable no-console */
const fs = require('node:fs');
const path = require('node:path');
const cp = require('node:child_process');

const root = path.resolve(__dirname, '..');
const manifest = JSON.parse(fs.readFileSync(path.join(root, 'deploy-manifest.json'), 'utf8'));
const products = manifest.products || {};
const productNames = Object.keys(products);
const requiredProductFields = [
  'description',
  'identity',
  'surface',
  'hostingTarget',
  'buildDirectory',
  'entrypoints',
  'ownedPrefixes',
  'forbiddenImportFragments',
  'forbiddenContentFragments',
  'output',
];

function git(args) {
  return cp.execFileSync('git', args, {
    cwd: root,
    encoding: 'utf8',
    stdio: ['ignore', 'pipe', 'pipe'],
  }).trim();
}

function startsWithAny(file, prefixes = []) {
  return prefixes.some((prefix) => file === prefix || file.startsWith(prefix));
}

function listFiles() {
  const tracked = git(['ls-files']).split('\n').filter(Boolean);
  const untracked = git(['ls-files', '--others', '--exclude-standard'])
    .split('\n')
    .filter(Boolean);
  return [...new Set([...tracked, ...untracked])].sort();
}

function read(file) {
  return fs.readFileSync(path.join(root, file), 'utf8');
}

function resolveImport(fromFile, specifier) {
  if (specifier.startsWith('package:circum_rider/')) {
    const resolved = `lib/${specifier.slice('package:circum_rider/'.length)}`;
    return fs.existsSync(path.join(root, resolved)) ? resolved : null;
  }
  if (!specifier.includes(':')) {
    const resolved = path.normalize(path.join(path.dirname(fromFile), specifier));
    return fs.existsSync(path.join(root, resolved)) ? resolved : null;
  }
  return null;
}

function dartImports(file) {
  if (!file.endsWith('.dart') || !fs.existsSync(path.join(root, file))) return [];
  const source = read(file);
  const imports = [];
  const pattern = /^\s*(?:import|export|part)\s+['"]([^'"]+)['"][^;]*;/gm;
  let match = pattern.exec(source);
  while (match) {
    imports.push({ specifier: match[1], resolved: resolveImport(file, match[1]) });
    match = pattern.exec(source);
  }
  return imports;
}

function dependencyGraph(product) {
  const pending = [...(product.entrypoints || [])];
  const seen = new Set();
  while (pending.length > 0) {
    const file = pending.pop();
    if (!file || seen.has(file) || !fs.existsSync(path.join(root, file))) continue;
    seen.add(file);
    for (const imported of dartImports(file)) {
      if (imported.resolved && !seen.has(imported.resolved)) pending.push(imported.resolved);
    }
  }
  return seen;
}

function category(file) {
  if (file.startsWith('assets/')) return 'assets';
  if (file.startsWith('scripts/')) return 'scripts';
  if (file.startsWith('test/')) return 'tests';
  if (file.startsWith('web/') || file.endsWith('manifest.json')) return 'manifests';
  if (file.endsWith('firebase.json') || file.endsWith('.firebaserc') ||
      file.endsWith('pubspec.yaml') || file.endsWith('pubspec.lock') ||
      file.endsWith('analysis_options.yaml')) {
    return 'configs';
  }
  if (file.includes('service_worker')) return 'serviceWorkers';
  return 'projectFiles';
}

const files = listFiles();
const ownedPrefixes = productNames.flatMap((name) => products[name].ownedPrefixes || []);
const forbiddenImportFragments = [
  ...new Set(productNames.flatMap((name) => products[name].forbiddenImportFragments || [])),
];
const forbiddenContentFragments = [
  ...new Set(productNames.flatMap((name) => products[name].forbiddenContentFragments || [])),
];
const unowned = files.filter((file) => !startsWithAny(file, ownedPrefixes));
const forbiddenImports = [];
const forbiddenContent = [];
const missingProductFields = [];

for (const [name, product] of Object.entries(products)) {
  for (const field of requiredProductFields) {
    if (!(field in product) || product[field] == null || product[field] === '') {
      missingProductFields.push(`${name}.${field}`);
    }
  }
}

for (const file of files.filter((candidate) => candidate.endsWith('.dart'))) {
  for (const imported of dartImports(file)) {
    if (forbiddenImportFragments.some((fragment) => imported.specifier.includes(fragment))) {
      forbiddenImports.push(`${file} imports ${imported.specifier}`);
    }
  }
}

for (const file of files.filter((candidate) =>
  candidate.startsWith('lib/') ||
  candidate.startsWith('web/') ||
  candidate.startsWith('android/') ||
  candidate.startsWith('ios/') ||
  candidate.startsWith('assets/'),
)) {
  if (!fs.statSync(path.join(root, file)).isFile()) continue;
  const source = read(file);
  for (const fragment of forbiddenContentFragments) {
    if (source.includes(fragment)) forbiddenContent.push(`${file} contains ${fragment}`);
  }
}

const graphs = {};
for (const name of productNames) graphs[name] = [...dependencyGraph(products[name])].sort();
const sharedByCategory = {
  projectFiles: 0,
  assets: 0,
  scripts: 0,
  configs: 0,
  tests: 0,
  manifests: 0,
  serviceWorkers: 0,
};
for (const file of manifest.sharedFiles || []) {
  sharedByCategory[category(file)] += 1;
}

const report = {
  ok: (manifest.sharedFiles || []).length === 0 &&
    unowned.length === 0 &&
    forbiddenImports.length === 0 &&
    forbiddenContent.length === 0 &&
    missingProductFields.length === 0,
  products: productNames,
  dependencyGraph: graphs,
  intersectionCount: 0,
  sharedFileCount: (manifest.sharedFiles || []).length,
  sharedByCategory,
  ownership: {
    sharedFiles: manifest.sharedFiles || [],
    unowned,
    multiOwned: [],
  },
  forbiddenImports,
  forbiddenContent,
  missingProductFields,
};

console.log(JSON.stringify(report, null, 2));
if (!report.ok) process.exit(1);
