const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

test('Rider deployment checks out the approved ref and authenticates Firebase', () => {
  const workflow = fs.readFileSync(
    path.join(process.cwd(), '.github/workflows/deploy_rider_web.yml'),
    'utf8',
  );
  assert.match(workflow, /release_ref:/);
  assert.match(workflow, /ref: \$\{\{ inputs\.release_ref \}\}/);
  assert.match(workflow, /uses: google-github-actions\/auth@v2/);
  assert.match(
    workflow,
    /credentials_json: \$\{\{ secrets\.FIREBASE_SERVICE_ACCOUNT_CIRCUM_2797C \}\}/,
  );
  assert.match(workflow, /npm install -g firebase-tools/);
  assert.match(workflow, /firebase deploy --only hosting --project circum-2797c/);
  assert.match(workflow, /node scripts\/check_platform_isolation\.js/);
  assert.match(workflow, /test\/rider_platform_isolation_contract_test\.dart/);
  assert.match(workflow, /test\/rider_stripe_return_routing_test\.dart/);
  assert.match(workflow, /test\/platform_isolation_guard_test\.js/);
});
