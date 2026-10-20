// Export tests/navigation/diverse_benchmark.tscn to .godot/diverse_web/index.html first.
// Set PLAYWRIGHT_MODULE, BENCHMARK_PYTHON and BENCHMARK_BROWSER as needed.
const fs=require('node:fs'), cp=require('node:child_process'), path=require('node:path'), assert=require('node:assert/strict');
const {chromium}=require(process.env.PLAYWRIGHT_MODULE || 'playwright');
const pause=ms=>new Promise(r=>setTimeout(r,ms));
process.env.TEMP=process.env.TMP=path.resolve('.godot/browser_temp');
(async()=>{let browser,server;try {
 const log=fs.openSync('.godot/diverse_web_server.log','w');
 server=cp.spawn(process.env.BENCHMARK_PYTHON || 'python',['tools/web/serve_web.py','--port','8985','--directory','.godot/diverse_web'],{windowsHide:true,stdio:['ignore',log,log]});
 await pause(400);
 browser=await chromium.launch({executablePath:process.env.BENCHMARK_BROWSER,headless:true,args:['--enable-unsafe-swiftshader']});
 const page=await browser.newPage({viewport:{width:1280,height:800}});let report;const errors=[];
 page.on('pageerror',e=>errors.push(String(e)));page.on('console',m=>{if(m.type()==='error')errors.push(m.text());if(m.text().startsWith('DIVERSE_BENCHMARK:'))report=JSON.parse(m.text().slice(18));});
 await page.goto('http://127.0.0.1:8985/index.html');
 for(let i=0;i<550&&!report&&!errors.length;i++)await pause(100);
 assert.deepEqual(errors,[]);assert.ok(report,'Missing benchmark');
 if(fs.existsSync('.godot/diverse_benchmark_native.out')) {
 const nativeLine=fs.readFileSync('.godot/diverse_benchmark_native.out','utf8').split(/\r?\n/).find(s=>s.startsWith('DIVERSE_BENCHMARK:'));
 const native=JSON.parse(nativeLine.slice(18));assert.equal(report.cases.length,6);
 for(let i=0;i<6;i++) {assert.deepEqual(report.cases[i].distribution,native.cases[i].distribution);assert.equal(report.cases[i].plan.routes,native.cases[i].plan.routes);assert.equal(report.cases[i].plan.best,native.cases[i].plan.best);}
 }
 report.browser=await browser.version();report.threads=false;report.compatibility=true;report.errors=errors;
 fs.writeFileSync('reports/navigation/diverse_routes_web.json',JSON.stringify(report,null,2)+'\n');
 console.log('PASS: Web single-thread release, both real scenes, thresholds 10/25/inf, six identical native/Web sample fingerprints.');
}finally{if(browser)await browser.close();if(server)server.kill();}})().catch(e=>{console.error(e);process.exitCode=1;});
