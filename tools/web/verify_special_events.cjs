// First export tests/events/regression.tscn with tools/web/export_test.ps1.
const fs = require('node:fs');
const path = require('node:path');
const cp = require('node:child_process');
const assert = require('node:assert/strict');
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || 'playwright');
const directory = process.argv.find(v => v.startsWith('--directory='))?.slice(12) || '.godot/special_events_web';
// Reuse this runner for focused gameplay regressions; each scene prints JSON.
const marker = process.argv.find(v => v.startsWith('--marker='))?.slice(9) || 'SPECIAL_EVENTS_RESULT ';
const suite = process.argv.find(v => v.startsWith('--suite='))?.slice(8) || 'events';
const output = path.resolve('.godot/test-results', suite);
fs.mkdirSync(output, { recursive: true });
(async () => {
  const log = fs.openSync(path.join(output, 'web-server.log'), 'w');
  const server = cp.spawn(process.env.TEST_PYTHON || 'python', ['tools/web/serve_web.py', '--port', '8986', '--directory', directory], { windowsHide: true, stdio: ['ignore', log, log] });
  let browser;
  try {
    for (let i = 0; i < 100; i++) {
      try { if ((await fetch('http://127.0.0.1:8986/index.html')).ok) break; } catch {}
      await new Promise(resolve => setTimeout(resolve, 100));
    }
    browser = await chromium.launch({ executablePath: process.env.TEST_BROWSER, headless: true, args: ['--use-angle=d3d11', '--ignore-gpu-blocklist'] });
    const page = await browser.newPage({ viewport: { width: 1152, height: 648 } });
    const messages = [], errors = [], warnings = [];
    let result;
    page.on('pageerror', error => errors.push(String(error)));
    page.on('console', message => {
      const text = message.text();
      messages.push(text);
      if (message.type() === 'error') errors.push(text);
      if (message.type() === 'warning') warnings.push(text);
      const index = text.indexOf(marker);
      if (index >= 0) result = JSON.parse(text.slice(index + marker.length));
    });
    await page.goto('http://127.0.0.1:8986/index.html');
    // Use a real user gesture for the normal browser audio policy, including
    // suites that otherwise drive native Godot input from their own scripts.
    await page.waitForFunction(() => document.querySelector('canvas')?.width > 0);
    await page.mouse.click(8,120);
    for (let i = 0; i < 900 && !result; i++) await page.waitForTimeout(100);
    fs.writeFileSync(path.join(output, 'web.log'), messages.join('\n'));
    fs.writeFileSync(path.join(output, 'web-result.json'), JSON.stringify({ result, errors, warnings }, null, 2));
    assert.ok(result, `Browser did not complete ${suite} regression`);
    assert.ok(Array.isArray(result.failures) ? result.failures.length === 0 : result.failures === 0, `${suite} regression failed`);
    assert.deepEqual(errors, [], 'Browser reported runtime errors');
    console.log(JSON.stringify({ platform: 'Chrome Web', ...result }));
    if (process.argv.includes('--baseline')) {
      // Export tests/cards/rotation_pivot.tscn to <directory>/baseline first.
      // Release Web templates disallow command-line scene overrides.
      assert.ok(fs.existsSync(path.join(directory, 'baseline/index.html')), 'Export the baseline scene first');
      const baseline = await browser.newPage({ viewport: { width: 1152, height: 648 } });
      const lines = [];
      let done = false;
      baseline.on('console', message => { lines.push(message.text()); if (message.text().includes('ROTATION_PIVOT_CHECK:')) done = true; });
      await baseline.goto('http://127.0.0.1:8986/baseline/index.html');
      for (let i = 0; i < 1200 && !done; i++) await baseline.waitForTimeout(100);
      fs.writeFileSync(path.join(output, 'web-baseline.log'), lines.join('\n'));
      console.log(JSON.stringify({ baselineCompleted: done, baselineWebGLWarnings: lines.filter(v => v.includes('WebGL: INVALID_OPERATION')).length, eventWebGLWarnings: warnings.filter(v => v.includes('WebGL: INVALID_OPERATION')).length }));
      assert.ok(done && lines.some(v => /ROTATION_PIVOT_CHECK:.*failures=0/.test(v)), 'Existing-card Web baseline did not pass');
    }
  } finally {
    if (browser) await browser.close();
    server.kill();
    fs.closeSync(log);
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
