"""Consolidate the latest executed evidence, preserving earlier failure logs."""
import json,pathlib,re
ROOT=pathlib.Path(__file__).resolve().parents[2]
base=ROOT/'.godot/phase5'; out=ROOT/'reports/phase5';out.mkdir(parents=True,exist_ok=True)
latest={}
for directory in ['regression-v2','repairs','rendered-regression','final-regression','trace-final-checks']:
    rows=json.loads((base/directory/'results.json').read_text(encoding='utf-8-sig'))
    if isinstance(rows,dict):rows=[rows]
    for r in rows:
        text=(ROOT/r['log']).read_text(encoding='utf-8-sig')
        assert re.search(r'(CHECK|PASS|failures|checks|assertions|regression)',text,re.I),r
        latest[(r['case'],r['rendered'])]=r
for name,log,marker in [('balance/rendered_final','rendered-final.log','FULL_RUN_LAB '),('balance/defeat_input','defeat-input.log','PHASE5_DEFEAT_INPUT ')]:
    text=(base/log).read_text(encoding='utf-8-sig')
    errors=[line for line in text.splitlines() if re.match(r'^(SCRIPT ERROR:|ERROR:)',line) and 'shader cache' not in line]
    assert marker in text and not errors,(name,errors)
    if name.endswith('rendered_final'):
        info=json.loads((base/'rendered-final/rendered.json').read_text())
        assert not info['failures'] and info['choice_clicks']==4 and info['restart_verified']
    else:assert '"failures":[]' in text
    latest[(name,True)]=dict(case=name,rendered=True,status='Current PASS',log=str((base/log).relative_to(ROOT)),completed=True,errors=errors)
not_run=[dict(case=name,status='NOT RUN') for name in ['Windows release export','Web wasm build and browser','Performance / memory benchmark','Human playtesting','Wave editor interaction after Phase 5']]
report=dict(current=list(latest.values()),other=not_run,notes=['Previous failed attempts retained in their original logs, superseded only by an actual successful rerun.','Phase 1–4 historical results not rerun in this session remain Historical PASS only; see their acceptance documents.','A game defeat in a sensitivity experiment is a valid measured outcome, not a regression-test failure.'])
(out/'verification.json').write_text(json.dumps(report,indent=2,ensure_ascii=False),encoding='utf-8')
assert all(r['status']=='Current PASS' for r in latest.values()),report
print('CURRENT_CHECKS',len(latest),'PASS; NOT RUN',len(not_run))
