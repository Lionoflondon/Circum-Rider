#!/usr/bin/env node

const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const read = (file) => fs.readFileSync(path.join(root, file), 'utf8');
const failures = [];
const expectNot = (file, text, reason) => {
  if (read(file).includes(text)) failures.push(`${file}: ${reason}`);
};
const expect = (condition, reason) => {
  if (!condition) failures.push(reason);
};

const manifest = JSON.parse(read('platform-ownership.json'));
const web = read(manifest.products.rider_web.entrypoint);
const mobile = read(manifest.products.rider_mobile.entrypoint);
const webAppCheck = read('lib/app/security/rider_app_check.dart');
const mobileAppCheck = read('lib/app/security/circum_app_check.dart');

expect(!web.includes("package:circum_rider/main.dart"),
  'Rider Web imports the mobile main entrypoint');
expect(!mobile.includes('main_rider_web.dart'),
  'Rider Mobile imports the Web entrypoint');
expectNot('lib/main.dart', 'RIDER_WEB_RECAPTCHA_ENTERPRISE_SITE_KEY',
  'mobile main contains Web App Check configuration');
expectNot('lib/main.dart', 'ReCaptchaEnterpriseProvider',
  'mobile main contains the Web App Check provider');
expect(web.includes('initializeRiderAppCheck'),
  'Rider Web does not initialize its Web App Check gate');
expect(web.includes('rider_app.dart'),
  'Rider Web does not use the isolated Rider UI root');
expect(read('lib/app/security/rider_app_check.dart')
  .includes('RIDER_WEB_RECAPTCHA_ENTERPRISE_SITE_KEY'),
  'Rider Web App Check key is not owned by the Web security module');
expect(read('lib/app/security/circum_app_check.dart')
  .includes('AndroidProvider'),
  'Rider Mobile App Check module lost its mobile provider');
expect(!webAppCheck.includes('AndroidProvider') && !webAppCheck.includes('AppleProvider'),
  'Rider Web App Check module contains mobile providers');
expect(!mobileAppCheck.includes('ReCaptchaEnterpriseProvider') &&
  !mobileAppCheck.includes('RECAPTCHA_ENTERPRISE_SITE_KEY') &&
  !mobileAppCheck.includes('webProvider'),
  'Rider Mobile App Check module contains Web provider/configuration');

if (failures.length) {
  console.error('Platform isolation guard FAILED');
  failures.forEach((failure) => console.error(`- ${failure}`));
  process.exit(1);
}
console.log('Platform isolation guard PASS');
