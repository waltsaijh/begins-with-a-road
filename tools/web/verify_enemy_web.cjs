// Export tests/enemies/enemies.tscn to .godot/enemy_web/index.html first.
const fs = require('node:fs'), cp = require('node:child_process'), path = require('node:path');
const assert = require('node:assert/strict');
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || 'playwright');
const pause = ms => new Promise(resolve => setTimeout(resolve, ms));
const reportDomains = {
  enemies: 'enemies', enemy_status: 'enemies', enemy_multimesh: 'enemies',
  enemy_visual_separation: 'enemies', enemy_walk_render: 'enemies', troop_profiles: 'enemies',
  shop: 'cards', cards: 'cards', cards_render: 'cards',
  combat: 'combat', combat_render: 'combat', towers: 'combat', tower_obstacles: 'combat',
  route_distribution: 'navigation', debug_overlay: 'navigation', waypoint_routes_web: 'navigation', dead_end_edits: 'navigation'
};
process.env.TEMP = process.env.TMP = path.resolve('.godot/browser_temp');
const directory = process.argv.find(arg => arg.startsWith('--directory='))?.slice(12) || '.godot/enemy_web';
(async () => {
  let browser, server;
  try {
    const log = fs.openSync('.godot/enemy_web_server.log', 'w');
    server = cp.spawn(process.env.BENCHMARK_PYTHON || 'python',
      ['tools/web/serve_web.py', '--port', '8984', '--directory', directory],
      { windowsHide: true, stdio: ['ignore', log, log] });
    let ready = false;
    for (let i = 0; i < 100 && !ready; i++) {
      if (server.exitCode !== null) throw new Error('Test server exited: '+server.exitCode);
      try { ready = (await fetch('http://127.0.0.1:8984/index.html')).ok; } catch {}
      if (!ready) await pause(100);
    }
    assert.ok(ready, 'Test server did not start');
    browser = await chromium.launch({ executablePath: process.env.BENCHMARK_BROWSER,
      headless: true, args: ['--enable-unsafe-swiftshader'] });
    const suites = [{ page: 'index.html', prefix: 'ENEMY_CHECK:', log: 'enemy_tests', report: 'enemies' }];
    if (process.argv.includes('--shop')) suites.push({ page: 'shop.html', prefix: 'CARD_SHOP_CHECK:', log: 'shop_render', report: 'shop', screenshot: '.godot/test-results/cards/shop_web.png' });
    if (process.argv.includes('--distribution')) suites.push({ page: 'distribution.html', prefix: 'ROUTE_DISTRIBUTION_CHECK:', log: 'route_distribution_tests', report: 'route_distribution', timing: true });
    if (process.argv.includes('--status')) suites.push({ page: 'status.html', prefix: 'ENEMY_STATUS_CHECK:', log: 'enemy_status_render', report: 'enemy_status', screenshot: '.godot/test-results/enemies/enemy_status_web.png' });
    if (process.argv.includes('--multimesh')) suites.push({ page: 'multimesh.html', prefix: 'ENEMY_MULTIMESH_CHECK:', log: 'enemy_multimesh_gpu', report: 'enemy_multimesh' });
    if (process.argv.includes('--separation')) suites.push({ page: 'separation.html', prefix: 'ENEMY_SEPARATION_CHECK:', log: 'enemy_separation', report: 'enemy_visual_separation', timing: true });
    if (process.argv.includes('--troops')) suites.push({ page: 'troops.html', prefix: 'TROOP_CHECK:', log: 'troop_tests', report: 'troop_profiles', timing: true });
    if (process.argv.includes('--walk-render')) suites.push({ page: 'walk.html', prefix: 'ENEMY_WALK_RENDER_CHECK:', log: 'enemy_walk_render', report: 'enemy_walk_render', screenshot: '.godot/test-results/enemies/enemy_walk_web.png' });
    if (process.argv.includes('--tower-obstacles')) suites.push({ page: 'obstacles.html', prefix: 'TOWER_OBSTACLE_CHECK:', log: 'tower_obstacle_tests', report: 'tower_obstacles' });
    if (process.argv.includes('--towers')) suites.push({ page: 'towers.html', prefix: 'TOWER_CHECK:', log: 'towers_tests', report: 'towers' });
    if (process.argv.includes('--debug')) suites.push({ page: 'debug.html', prefix: 'DEBUG_CHECK:', log: 'debug_overlay_tests', report: 'debug_overlay' });
    if (process.argv.includes('--waypoint')) suites.push({ page: 'waypoint.html', prefix: 'WAYPOINT_CHECK:', log: 'waypoint_current', report: 'waypoint_routes_web', timing: true });
    if (process.argv.includes('--dead-end')) suites.push({ page: 'dead_end.html', prefix: 'DEAD_END_CHECK:', log: 'dead_end_edits', report: 'dead_end_edits' });
    if (process.argv.includes('--cards')) {
      suites.push({ page: 'cards.html', prefix: 'CARD_CHECK:', log: 'cards_tests', report: 'cards' });
      suites.push({ page: 'card_preview.html', prefix: 'CARD_RENDER_CHECK:', log: 'cards_render', report: 'cards_render', screenshot: '.godot/test-results/cards/cards_web.png' });
    }
    if (process.argv.includes('--combat')) {
      suites.push({ page: 'combat.html', prefix: 'COMBAT_CHECK:', log: 'combat_tests', report: 'combat' });
      suites.push({ page: 'combat_preview.html', prefix: 'COMBAT_RENDER_CHECK:', log: 'combat_render', report: 'combat_render', screenshot: '.godot/test-results/combat/combat_web.png' });
    }
    const only = process.argv.find(arg => arg.startsWith('--only='))?.slice(7);
    const selected = only ? suites.filter(suite => suite.report === only) : suites;
    assert.ok(selected.length, 'Unknown test suite: '+only);
    for (const suite of selected) {
    const page = await browser.newPage({ viewport: { width: 1280, height: 800 } });
    let report; const errors = [];
    const consolePath = '.godot/'+suite.report+'_web_console.log';
    fs.writeFileSync(consolePath, '');
    page.on('pageerror', e => errors.push(String(e)));
    page.on('console', m => {
      fs.appendFileSync(consolePath, m.type()+': '+m.text()+'\n');
      if (m.type() === 'error' || /^(SCRIPT ERROR|ERROR):/.test(m.text())) errors.push(m.text());
      if (m.text().startsWith(suite.prefix)) report = JSON.parse(m.text().slice(suite.prefix.length));
    });
    await page.goto('http://127.0.0.1:8984/'+suite.page);
    for (let i = 0; i < 900 && !report && !errors.length; i++) await pause(100);
    if (!report || errors.length) await page.screenshot({ path: '.godot/'+suite.report+'_web_failure.png' });
    assert.deepEqual(errors, []); assert.ok(report, 'Missing enemy test report');
    if (suite.screenshot) {
      fs.mkdirSync(path.dirname(suite.screenshot), { recursive: true });
      await page.screenshot({ path: suite.screenshot });
    }
    const native = JSON.parse(fs.readFileSync('.godot/'+suite.log+'.out', 'utf8')
      .split(/\r?\n/).find(s => s.startsWith(suite.prefix)).slice(suite.prefix.length));
    if (suite.timing) {
      const comparable = value => {
        const copy = structuredClone(value); delete copy.platform;
        for (const entry of copy.cases) { delete entry.raw_plan_us; delete entry.solve_us; delete entry.distribution_build_us; delete entry.weighted64_us; delete entry.old_shuffle64_us; }
        return copy;
      };
      assert.deepEqual(comparable(report), comparable(native));
    } else assert.deepEqual(report, native);
    const reportPath = path.join('.godot/test-results', reportDomains[suite.report] || 'project', suite.report+'.json');
    fs.mkdirSync(path.dirname(reportPath), { recursive: true });
    fs.writeFileSync(reportPath, JSON.stringify({
      ...report, platforms: ['Windows', 'Web'], compatibility: true, threads: false,
      browser: await browser.version(), build: 'release', errors
    }, null, 2)+'\n');
    console.log('PASS: '+suite.report+' native/Web identical; no console errors.');
    await page.close();
    }
  } finally {
    if (browser) await browser.close();
    if (server) server.kill();
  }
})().catch(e => { console.error(e); process.exitCode = 1; });
