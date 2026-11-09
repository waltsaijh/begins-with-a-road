// Windows Chrome: measure the real release audio output without autoplay overrides.
// Requires Playwright; TEST_BROWSER and --directory=<export folder> are optional.
const {chromium} = require(process.env.PLAYWRIGHT_MODULE || 'playwright');
const fs = require('node:fs'), path = require('node:path'), cp = require('node:child_process');
const assert = require('node:assert/strict');
const directory = path.resolve(process.argv.find(v => v.startsWith('--directory='))?.slice(12) || 'build/web');
const artifacts = path.resolve('.godot/test-results/audio');
fs.mkdirSync(artifacts,{recursive:true});
(async()=>{
 const log = fs.openSync(path.join(artifacts,'web-server.log'),'w');
 const server = cp.spawn('powershell.exe',['-NoProfile','-ExecutionPolicy','Bypass','-File',path.join(directory,'StartGame.ps1'),'-NoBrowser','-Port','8797'],{windowsHide:true,stdio:['ignore',log,log]});
 let browser;
 try {
  for(let i=0;i<40;i++){
   try { if((await fetch('http://127.0.0.1:8797/index.html')).ok) break; } catch {}
   await new Promise(resolve=>setTimeout(resolve,100));
  }
  browser = await chromium.launch({executablePath:process.env.TEST_BROWSER || path.join(process.env.LOCALAPPDATA,'Google/Chrome/Application/chrome.exe'),headless:true,args:['--use-angle=d3d11','--ignore-gpu-blocklist']});
  const page = await browser.newPage({viewport:{width:1152,height:648}});
  const errors=[], snapshots=[];
  page.on('pageerror',e=>errors.push(String(e)));
  page.on('console',m=>{if(m.type()==='error') errors.push(m.text());});
  await page.addInitScript(()=>{
   window.audioProbe={contexts:[],analysers:[],starts:0};
   window.AudioContext=new Proxy(window.AudioContext,{construct(target,args){const ctx=Reflect.construct(target,args);audioProbe.contexts.push(ctx);return ctx;}});
   const connect=AudioNode.prototype.connect;
   AudioNode.prototype.connect=function(dest,...args){
    if(dest instanceof AudioDestinationNode){const analyser=this.context.createAnalyser();audioProbe.analysers.push(analyser);connect.call(this,analyser);connect.call(analyser,dest);return dest;}
    return connect.call(this,dest,...args);
   };
   const start=AudioBufferSourceNode.prototype.start;
   AudioBufferSourceNode.prototype.start=function(...args){audioProbe.starts++;return start.apply(this,args);};
  });
  async function measure(label){
   const value=await page.evaluate(async()=>{
    let peak=0;
    for(let i=0;i<15;i++){
     for(const analyser of audioProbe.analysers){const data=new Float32Array(analyser.fftSize);analyser.getFloatTimeDomainData(data);for(const v of data)peak=Math.max(peak,Math.abs(v));}
     await new Promise(resolve=>setTimeout(resolve,30));
    }
    const audio=engine.rtenv.GodotAudio;
    return {peak,states:audioProbe.contexts.map(c=>c.state),starts:audioProbe.starts,sends:audio.buses.map(b=>b.getSend()?.getId()??null)};
   });
   snapshots.push({label,...value});return value;
  }
  await page.goto('http://127.0.0.1:8797/index.html');
  await page.waitForTimeout(14000);
  await measure('before_gesture');
  await page.mouse.click(130,380);
  await page.waitForTimeout(1500);
  const bgm=await measure('bgm_after_gesture');
  assert.ok(bgm.states.includes('running'),'Chrome did not unlock audio after input');
  assert.deepEqual(bgm.sends,[null,0,0],'Master/BGM/Combat form an incorrect graph');
  assert.ok(bgm.peak>0.00001,'BGM has no output');
  await page.evaluate(()=>engine.rtenv.GodotAudio.buses[1].mute(true));
  await page.waitForTimeout(250);
  assert.equal((await measure('bgm_muted')).peak,0,'BGM did not mute');
  const starts=(await measure('before_click')).starts;
  await page.mouse.click(630,602);
  const click=await measure('ui_click_without_bgm');
  assert.ok(click.starts>starts && click.peak>0.00001,'UI effect has no output');
  await page.evaluate(()=>engine.rtenv.GodotAudio.buses[1].mute(false));
  await page.waitForTimeout(250);
  assert.ok((await measure('bgm_restored')).peak>0.00001,'BGM did not resume');
  await page.evaluate(()=>engine.rtenv.GodotAudio.buses[0].mute(true));
  await page.waitForTimeout(250);
  assert.equal((await measure('master_muted')).peak,0,'Master mute does not silence output');
  await page.evaluate(()=>engine.rtenv.GodotAudio.buses[0].mute(false));
  await page.waitForTimeout(250);
  assert.ok((await measure('master_restored')).peak>0.00001,'Master unmute did not restore output');
  assert.deepEqual(errors,[]);
  fs.writeFileSync(path.join(artifacts,'web-release.json'),JSON.stringify({chrome:await browser.version(),snapshots,errors},null,2));
  console.log('WEB_RELEASE_AUDIO: '+JSON.stringify({failures:0,snapshots}));
 } finally {if(browser)await browser.close();server.kill();}
})().catch(error=>{console.error(error);process.exitCode=1;});
