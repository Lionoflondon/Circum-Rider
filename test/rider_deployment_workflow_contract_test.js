const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

test('Rider deployment checks out the approved ref and deploys Cloud Run', () => {
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
  assert.match(workflow, /gcloud builds submit/);
  assert.match(workflow, /--async/);
  assert.match(workflow, /gcloud builds describe/);
  assert.match(workflow, /Cloud Build did not finish within the bounded wait/);
  assert.match(workflow, /gcloud run deploy circum-rider-web/);
  assert.match(workflow, /--allow-unauthenticated/);
  assert.match(workflow, /CIRCUM_SOURCE_SHA=\$\{\{ github\.sha \}\}/);
});

test('Cloud Build upload includes the generated Rider Web bundle', () => {
  const ignore = fs.readFileSync(
    path.join(process.cwd(), '.gcloudignore'),
    'utf8',
  );
  assert.match(ignore, /!build\/web\/\*\*/);
});
