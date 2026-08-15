#!/usr/bin/env node
/* eslint-disable no-console */

const fs = require('node:fs');
const http = require('node:http');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const webRoot = path.join(root, 'build', 'web');
const screenshotPath = path.join(root, 'build', 'rider-web-render-smoke.png');
const port = Number(process.env.RIDER_WEB_SMOKE_PORT || 8734);

function fail(message, details = []) {
  console.error('RIDER WEB RENDER SMOKE FAILED');
  console.error(message);
  for (const detail of details) console.error(`- ${detail}`);
  process.exitCode = 1;
}

function contentType(file) {
  if (file.endsWith('.html')) return 'text/html; charset=utf-8';
  if (file.endsWith('.js')) return 'application/javascript; charset=utf-8';
  if (file.endsWith('.json')) return 'application/json; charset=utf-8';
  if (file.endsWith('.wasm')) return 'application/wasm';
  if (file.endsWith('.png')) return 'image/png';
  if (file.endsWith('.svg')) return 'image/svg+xml';
  if (file.endsWith('.css')) return 'text/css; charset=utf-8';
  return 'application/octet-stream';
}

function serveBuild() {
  return http.createServer((req, res) => {
    const requestPath = decodeURIComponent((req.url || '/').split('?')[0]);
    const safePath = path.normalize(requestPath).replace(/^(\.\.[/\\])+/, '');
    let file = path.join(webRoot, safePath === '/' ? 'index.html' : safePath);
    if (!file.startsWith(webRoot)) file = path.join(webRoot, 'index.html');
    if (!fs.existsSync(file) || fs.statSync(file).isDirectory()) {
      file = path.join(webRoot, 'index.html');
    }
    res.setHeader('Cache-Control', 'no-store');
    res.setHeader('Content-Type', contentType(file));
    fs.createReadStream(file).pipe(res);
  });
}

function assertBuildExists() {
  for (const file of ['index.html', 'flutter_bootstrap.js', 'main.dart.js']) {
    const target = path.join(webRoot, file);
    if (!fs.existsSync(target)) {
      throw new Error(`missing Rider web build artifact: ${target}`);
    }
  }
}

async function run() {
  assertBuildExists();
  let chromium;
  let executablePath = process.env.RIDER_WEB_SMOKE_CHROME_PATH;
  try {
    ({ chromium } = require('playwright'));
  } catch (_) {
    try {
      ({ chromium } = require('playwright-core'));
      executablePath ||= '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
    } catch (_) {
      throw new Error(
        'Playwright is required for Rider web render smoke. Run `npm install --no-save playwright` before this guard.',
      );
    }
  }

  const server = serveBuild();
  await new Promise((resolve) => server.listen(port, '127.0.0.1', resolve));
  const browser = await chromium.launch(executablePath ? { executablePath } : undefined);
  const page = await browser.newPage({
    viewport: { width: 390, height: 844 },
    deviceScaleFactor: 2,
    isMobile: true,
  });
  const pageErrors = [];
  const requestFailures = [];
  page.on('pageerror', (error) => pageErrors.push(String(error.stack || error)));
  page.on('requestfailed', (request) => {
    const url = request.url();
    if (!url.startsWith(`http://127.0.0.1:${port}`)) return;
    requestFailures.push(`${url}: ${request.failure()?.errorText || 'failed'}`);
  });

  try {
    await page.goto(`http://127.0.0.1:${port}/?smoke=${Date.now()}`, {
      waitUntil: 'domcontentloaded',
      timeout: 60000,
    });
    await page.waitForTimeout(Number(process.env.RIDER_WEB_SMOKE_WAIT_MS || 20000));
    const screenshot = await page.screenshot({ path: screenshotPath, fullPage: true });
    const canvasCount = await page.locator('canvas').count();
    const html = await page.content();
    const hasFlutterHost =
      html.includes('flt-glass-pane') || html.includes('flutter-view');
    const problems = [];
    if (pageErrors.length > 0) problems.push(`startup errors: ${pageErrors.join(' | ')}`);
    if (requestFailures.length > 0) {
      problems.push(`local asset request failures: ${requestFailures.join(' | ')}`);
    }
    if (canvasCount < 1 && !hasFlutterHost) {
      problems.push('Flutter root host/canvas did not mount');
    }
    if (screenshot.length < 12000) {
      problems.push(`screenshot too small to prove nonblank render: ${screenshot.length} bytes`);
    }
    if (problems.length > 0) {
      fail('Rider web did not prove a visible mounted app.', problems);
      return;
    }
    console.log(JSON.stringify({
      ok: true,
      surface: 'rider-web',
      canvasCount,
      screenshotPath,
      screenshotBytes: screenshot.length,
    }, null, 2));
  } finally {
    await browser.close();
    await new Promise((resolve) => server.close(resolve));
  }
}

run().catch((error) => fail(error.message));
