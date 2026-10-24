// Web startup UI contract: neither promise completion nor a draw alone hides it.
const fs = require('fs');
const path = require('path');
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || 'playwright');
const root = path.resolve(__dirname, '../..');
const artifacts = path.join(root, '.godot/test-results/menus/loading_labels');
fs.mkdirSync(artifacts, { recursive: true });
const source = fs.readFileSync(path.join(root, 'assets/web/shell.html'), 'utf8')
  .replace(/<script src="\$GODOT_URL"><\/script>/, '')
  .replaceAll('$GODOT_CONFIG', '{}').replaceAll('$GODOT_THREADS_ENABLED', 'false')
  .replaceAll('$GODOT_HEAD_INCLUDE', '');
const result = { checks: 0, live: false, errors: [] };
let browser;
function check(value, message) {
  result.checks++;
  if (!value) throw Error(message);
}
async function fixture(context) {
  const page = await context.newPage();
  page.on('pageerror', error => result.errors.push(String(error)));
  await page.evaluate(() => {
    window.Engine = class {
      static getMissingFeatures() { return []; }
      startGame(options) {
        window.testOptions = options;
        return new Promise((resolve, reject) => { window.testResolve = resolve; window.testReject = reject; });
      }
    };
  });
  await page.setContent(source);
  return page;
}
(async () => {
  try {
    browser = await chromium.launch({ executablePath: process.env.BROWSER_EXECUTABLE, headless: false,
      args: ['--disable-background-timer-throttling', '--disable-renderer-backgrounding', '--disable-features=CalculateNativeWinOcclusion'] });
    const context = await browser.newContext({ viewport: { width: 1280, height: 800 }, locale: 'zh-TW' });
    let page = await fixture(context);
    check(await page.locator('#status-stage').textContent() === '載入遊戲資源…', 'Missing initial resource message');
    check(!await page.locator('#status-progress').isVisible(), 'Unknown work displayed a progress bar');
    await page.evaluate(() => window.testOptions.onProgress(20, 100));
    check(await page.locator('#status-progress').isVisible(), 'Known download progress was not shown');
    await page.evaluate(() => window.testResolve());
    await page.waitForTimeout(50);
    check(await page.locator('#status').isVisible(), 'Engine promise exposed canvas before its first draw');
    check(await page.locator('#status-stage').textContent() === '啟動遊戲…', 'Missing engine startup message');
    await page.evaluate(() => window.roadStartupPresented());
    await page.waitForFunction(() => !document.getElementById('status'));
    await page.close();
    page = await fixture(context);
    await page.evaluate(() => window.roadStartupPresented());
    await page.waitForTimeout(50);
    check(await page.locator('#status').isVisible(), 'Early draw notification hid a pending engine');
    await page.evaluate(() => window.testResolve());
    await page.waitForFunction(() => !document.getElementById('status'));
    await page.close();
    page = await fixture(context);
    await page.evaluate(() => window.testReject(new Error('Expected startup failure')));
    await page.waitForFunction(() => document.getElementById('status-notice').textContent.includes('Expected startup failure'));
    await page.evaluate(() => window.roadStartupPresented());
    check(await page.locator('#status').isVisible(), 'A failed engine lost its error notice');
    check(await page.locator('#status-stage').textContent() === '無法啟動遊戲', 'Missing failure stage');
    await page.close();
    if (process.argv.includes('--live')) {
      page = await context.newPage();
      const logs = [];
      result.logs = logs;
      page.on('console', message => logs.push(message.text()));
      page.on('pageerror', error => result.errors.push(String(error)));
      await page.addInitScript(() => {
        let callback;
        Object.defineProperty(window, 'roadStartupPresented', {
          configurable: true,
          set(value) { callback = value; },
          get() { return () => { window.testNativePresented = performance.now(); callback?.(); }; }
        });
      });
      const url = process.argv.find(value => value.startsWith('--url='))?.slice(6) || 'http://127.0.0.1:8765/index.html';
      await page.goto(url);
      await page.bringToFront();
      const cdp = await page.context().newCDPSession(page);
      await cdp.send('Emulation.setFocusEmulationEnabled', { enabled: true });
      await page.screenshot({ path: path.join(artifacts, 'web_resources.png'), timeout: 45000 });
      await page.waitForFunction(() => window.testNativePresented && !document.getElementById('status'), undefined, { timeout: 120000 });
      await page.screenshot({ path: path.join(artifacts, 'web_native_loading.png'), timeout: 45000 });
      await page.waitForTimeout(800);
      await page.screenshot({ path: path.join(artifacts, 'web_menu_loading.png'), timeout: 45000 });
      await page.waitForTimeout(16000);
      await page.screenshot({ path: path.join(artifacts, 'web_menu_ready.png'), timeout: 45000 });
      check(!await page.locator('#status').count(), 'Web shell cover leaked into the main menu');
      result.live = true;
      result.logs = logs;
    }
    check(result.errors.length === 0, 'Unexpected browser errors');
  } catch (error) {
    result.failure = String(error);
    process.exitCode = 1;
  } finally {
    fs.writeFileSync(path.join(artifacts, 'web_shell.json'), JSON.stringify(result, null, 2));
    console.log('WEB_LOADING_SHELL_CHECK:' + JSON.stringify(result));
    if (browser) await browser.close();
  }
})();
