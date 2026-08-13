#!/usr/bin/env node

const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const read = (file) => fs.readFileSync(path.join(root, file), 'utf8');
const failures = [];
const expect = (condition, reason) => {
  if (!condition) failures.push(reason);
};
const expectNot = (file, text, reason) => {
  if (read(file).includes(text)) failures.push(`${file}: ${reason}`);
};

const manifest = JSON.parse(read('platform-ownership.json'));
const webOwner = manifest.products.rider_web;
const mobileOwner = manifest.products.rider_mobile;
const web = read(webOwner.entrypoint);
const mobile = read(mobileOwner.entrypoint);
const rootApp = read(webOwner.compositionRoot);
const app = read('lib/app.dart');
const returnRoute = read('lib/app/stripe/rider_stripe_return.dart');
const returnView = read('lib/app/stripe/rider_stripe_return_view.dart');
const onboardingLauncher = read(
  'lib/app/stripe/rider_stripe_onboarding_launcher.dart');
const earnings = read('lib/app/account/view/earnings.dart');
const applicationCentre = read(
  'lib/app/onboarding/rider_application_centre.dart');
const webAppCheck = read(webOwner.appCheckModule);
const mobileAppCheck = read(mobileOwner.appCheckModule);
const productionDartFiles = [];
const collectDart = (relativePath) => {
  for (const entry of fs.readdirSync(path.join(root, relativePath), {
    withFileTypes: true,
  })) {
    const child = path.join(relativePath, entry.name);
    if (entry.isDirectory()) collectDart(child);
    if (entry.isFile() && child.endsWith('.dart')) productionDartFiles.push(child);
  }
};
collectDart('lib');

for (const forbiddenImport of webOwner.forbiddenImports) {
  expectNot(webOwner.entrypoint, forbiddenImport,
    'Rider Web imports the mobile startup/composition root');
}
for (const file of productionDartFiles) {
  if (file !== mobileOwner.entrypoint && read(file).includes("import '../main.dart'")) {
    failures.push(`${file}: production code imports the mobile startup root`);
  }
}
for (const forbiddenSymbol of mobileOwner.forbiddenSymbols) {
  expectNot(mobileOwner.entrypoint, forbiddenSymbol,
    `Rider Mobile contains Web-owned symbol ${forbiddenSymbol}`);
}

expect(web.includes("package:circum_rider/rider_app.dart"),
  'Rider Web does not use the isolated Rider composition root');
expect(mobile.includes("import 'rider_app.dart'"),
  'Rider Mobile does not use the shared UI composition root');
expect(mobile.includes('CircumRider(homeBloc: homeBloc)') &&
  !web.includes('homeBloc: homeBloc') &&
  rootApp.includes('widget.homeBloc ?? HomeBloc()'),
  'Rider Web and Mobile do not own separate HomeBloc instances');
expect(!rootApp.includes('initializeRiderAppCheck') &&
  !rootApp.includes('initializeCircumAppCheck'),
  'shared Rider UI composition root owns platform App Check startup');
expect(web.includes('initializeRiderAppCheck'),
  'Rider Web does not initialize its Web App Check gate');
expect(web.includes('RiderStripeReturnIntent.fromUri(Uri.base)'),
  'Rider Web does not restore Stripe path/query intent');

for (const returnPath of webOwner.stripeReturnPaths) {
  expect(returnRoute.includes(`'${returnPath}'`),
    `Rider Stripe return resolver is missing ${returnPath}`);
}
expect(app.includes('state.currentState == AppState.authenticated') &&
  app.includes('RiderStripeReturnView'),
  'Stripe return is not gated behind restored Rider authentication');
expect(returnView.includes("httpsCallable('syncStripeConnectStatus')"),
  'Stripe return does not synchronize the Rider Connect account');
expect(returnView.includes("httpsCallable('refreshStripeOnboardingLink')"),
  'Stripe refresh does not create a new Rider-owned onboarding link');
expect(!returnView.includes("'riderId':") &&
  !returnView.includes('returnedRiderId!'),
  'Stripe return trusts a caller-controlled Rider ID');
expect(onboardingLauncher.includes('FirebaseAuth.instance.currentUser') &&
  onboardingLauncher.includes("httpsCallable('createStripeOnboardingLink')"),
  'Rider payout setup does not use the authenticated onboarding callable');
expect(onboardingLauncher.includes('const <String, dynamic>{}') &&
  !onboardingLauncher.includes("'riderId':"),
  'Rider payout setup sends a caller-controlled Rider ID');
expect(onboardingLauncher.includes('static Future<void>? _opening') &&
  onboardingLauncher.includes('if (active != null) return active'),
  'Rider payout setup is not guarded against duplicate client launches');
expect(onboardingLauncher.includes("url.scheme != 'https'") &&
  onboardingLauncher.includes("kIsWeb ? '_self' : null"),
  'Rider payout setup does not enforce HTTPS and same-app Web navigation');
expect(earnings.includes('RiderStripeOnboardingLauncher.open()') &&
  earnings.includes('setupRequired ? onPayoutSetup'),
  'Rider Earnings does not expose authenticated payout setup');
expect(applicationCentre.includes('RiderStripeOnboardingLauncher.open()'),
  'Rider Application Centre does not open Stripe payout setup');

expect(webAppCheck.includes('RIDER_WEB_RECAPTCHA_ENTERPRISE_SITE_KEY'),
  'Rider Web App Check key is not owned by the Web security module');
expect(webAppCheck.includes('ReCaptchaEnterpriseProvider'),
  'Rider Web App Check provider is missing');
expect(!webAppCheck.includes('AndroidProvider') &&
  !webAppCheck.includes('AppleProvider'),
  'Rider Web App Check module contains mobile providers');
expect(mobileAppCheck.includes('AndroidProvider') &&
  mobileAppCheck.includes('AppleProvider'),
  'Rider Mobile App Check module lost its mobile providers');
expect(!mobileAppCheck.includes('ReCaptchaEnterpriseProvider') &&
  !mobileAppCheck.includes('webProvider'),
  'Rider Mobile App Check module contains Web provider/configuration');

if (failures.length) {
  console.error('Platform isolation guard FAILED');
  failures.forEach((failure) => console.error(`- ${failure}`));
  process.exit(1);
}
console.log('Platform isolation guard PASS');
