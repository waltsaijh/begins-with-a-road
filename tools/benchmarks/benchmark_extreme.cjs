// Run after exporting tests/performance/extreme.tscn into .godot/extreme_web.
// Required: PLAYWRIGHT_MODULE, BENCHMARK_PYTHON, BENCHMARK_BROWSER.
const fs = require('node:fs');
const cp = require('node:child_process');
const path = require('node:path');
const os = require('node:os');
const assert = require('node:assert/strict');
const {chromium} = require(process.env.PLAYWRIGHT_MODULE || 'playwright');
const pause = ms => new Promise(resolve => setTimeout(resolve, ms));
const root = path.resolve(__dirname, '../..');
process.chdir(root);
process.env.TEMP = process.env.TMP = path.join(root, '.godot/browser_temp');
fs.mkdirSync(process.env.TEMP, {recursive: true});
fs.mkdirSync('reports/performance', {recursive: true});
const machine = {cpu: os.cpus()[0]?.model, logical_processors: os.cpus().length,
  total_memory_bytes: os.totalmem(), os: os.version(), arch: os.arch(), date: new Date().toISOString()};
const highPerformance = process.argv.includes('--high-performance-gpu');
const outputName = highPerformance ? 'extreme_web_discrete' : 'extreme_web';

(async () => {
  let browser, server;
  const errors = [], warnings = [];
  try {
    const log = fs.openSync('.godot/extreme_web_server.log', 'w');
    server = cp.spawn(process.env.BENCHMARK_PYTHON || 'python',
      ['tools/web/serve_web.py', '--port', '8996', '--directory', '.godot/extreme_web'],
      {windowsHide: true, stdio: ['ignore', log, log]});
    let ready = false;
    for (let i = 0; i < 100 && !ready; i++) {
      if (server.exitCode !== null) throw Error('Server exited: '+server.exitCode);
      try {ready = (await fetch('http://127.0.0.1:8996/index.html')).ok;} catch {}
      if (!ready) await pause(100);
    }
    assert.ok(ready, 'Server failed to start');
    browser = await chromium.launch({executablePath: process.env.BENCHMARK_BROWSER,
      headless: true, args: ['--enable-unsafe-swiftshader', '--disable-background-timer-throttling', '--disable-renderer-backgrounding', ...(highPerformance ? ['--force_high_performance_gpu'] : [])]});
    const page = await browser.newPage({viewport: {width: 1280, height: 800}, deviceScaleFactor: 1});
    let result;
    const consoleFile = '.godot/'+outputName+'_console.log';
    fs.writeFileSync(consoleFile, '');
    page.on('pageerror', error => errors.push(String(error)));
    page.on('console', message => {
      const text = message.text();
      if (!text.startsWith('EXTREME_BENCHMARK:')) fs.appendFileSync(consoleFile, message.type()+': '+text+'\n');
      if (message.type() === 'error' || /^(SCRIPT ERROR|ERROR):/.test(text)) errors.push(text);
      if (message.type() === 'warning') warnings.push(text);
      if (text.startsWith('STRESS_PROGRESS:')) {
        console.log(text);
      }
      if (text.startsWith('EXTREME_BENCHMARK:')) result = JSON.parse(text.slice(18));
    });
    await page.goto('http://127.0.0.1:8996/index.html', {timeout: 60000});
    const deadline = Date.now()+600000;
    while (!result && !errors.length && Date.now() < deadline) await pause(200);
    assert.deepEqual(errors, []);
    assert.ok(result, 'Missing benchmark after 10 minutes');
    assert.deepEqual(result.failures, []);
    result.browser = await browser.version();
    result.webgl = await page.evaluate(() => {
      const canvas = document.createElement('canvas');
      const gl = canvas.getContext('webgl2');
      if (!gl) return {available: false};
      const ext = gl.getExtension('WEBGL_debug_renderer_info');
      const info = {available: true, renderer: ext ? gl.getParameter(ext.UNMASKED_RENDERER_WEBGL) : gl.getParameter(gl.RENDERER), vendor: ext ? gl.getParameter(ext.UNMASKED_VENDOR_WEBGL) : gl.getParameter(gl.VENDOR)};
      gl.getExtension('WEBGL_lose_context')?.loseContext();
      return info;
    });
    result.machine = machine;
    result.cross_origin_isolated = await page.evaluate(() => crossOriginIsolated);
    result.browser_raf = true;
    result.high_performance_gpu_requested = highPerformance;
    result.threads = false;
    result.build = 'Web release export, release GDExtension';
    result.errors = errors;
    result.warnings = warnings;
    assert.equal(result.cross_origin_isolated, true);
    fs.writeFileSync('reports/performance/'+outputName+'.json', JSON.stringify(result, null, 2)+'\n');
    const nativeLine = fs.readFileSync('.godot/extreme_windows.out', 'utf8').split(/\r?\n/).find(line => line.startsWith('EXTREME_BENCHMARK:'));
    assert.ok(nativeLine, 'Missing native result');
    const native = JSON.parse(nativeLine.slice(18));
    native.machine = machine;
    native.build = 'Windows Godot editor runtime, debug GDExtension';
    assert.deepEqual(native.failures, []);
    const structural = entry => {
      const {geometry_bytes_estimate, ...portable} = entry.structure;
      return [entry.name, portable]; // wasm32 and x86_64 have different vector sizes.
    };
    assert.deepEqual(result.navigation.map(structural), native.navigation.map(structural));
    assert.deepEqual(result.runtime.map(entry => [entry.name, entry.enemies, entry.towers]), native.runtime.map(entry => [entry.name, entry.enemies, entry.towers]));
    fs.writeFileSync('reports/performance/extreme_windows.json', JSON.stringify(native, null, 2)+'\n');
    console.log('PASS: native/Web navigation structure, route counts and 1024-allocation fingerprints match; all runtime populations retained; no errors.');
  } finally {
    if (browser) await browser.close();
    if (server) server.kill();
  }
})().catch(error => {console.error(error); process.exitCode = 1;});
