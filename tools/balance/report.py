"""Rebuild reports solely from raw traces and runtime-exported parameter tables.

Accounting is standard-library only (analyze.py). Plotting requires Matplotlib.
"""
import argparse, collections, csv, hashlib, json, math, pathlib, statistics, sys, zipfile
from analyze import validate

ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT/'.godot/phase5/python'))
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

def write_json(path, data):
    path.write_text(json.dumps(data,indent=2,ensure_ascii=False),encoding='utf-8')

def table(path, rows):
    if not rows: return
    with path.open('w',newline='',encoding='utf-8') as f:
        writer=csv.DictWriter(f,list(rows[0]));writer.writeheader();writer.writerows(rows)

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--manifest',default='tools/balance/evidence.json');ap.add_argument('--output',default='reports/phase5');ap.add_argument('--archive',action='store_true');a=ap.parse_args()
    output=ROOT/a.output;output.mkdir(parents=True,exist_ok=True)
    manifest=json.loads((ROOT/a.manifest).read_text(encoding='utf-8-sig'))
    all_rows=[];sources=[]
    for directory in manifest['directories']:
        path=ROOT/directory
        summary=json.loads((path/'summary.json').read_text(encoding='utf-8-sig'))
        assert not summary['failures'], (directory,summary['failures'])
        files=sorted(path.glob('*.jsonl'))
        assert len(files)==len(summary['results']), (directory,'sample count')
        for file in files:
            r=validate(file);r['experiment']=path.name;all_rows.append(r)
            sources.append(dict(path=str(file.relative_to(ROOT)).replace('\\','/'),sha256=hashlib.sha256(file.read_bytes()).hexdigest(),bytes=file.stat().st_size))
    write_json(output/'independent_results.json',dict(samples=len(all_rows),results=all_rows))
    write_json(output/'raw_manifest.json',sources)
    scalar=[{k:v for k,v in r.items() if not isinstance(v,(dict,list))} for r in all_rows]
    table(output/'encounters.csv',scalar)
    grouped=collections.defaultdict(list)
    for r in all_rows:
        if r['kind']=='full_run': grouped[(r['config'],r['policy'],r['metadata'].get('map','frontier'),'rendered' if r['experiment'].startswith('rendered-') else 'headless')].append(r)
    stats=[]
    for (config,policy,map_name,mode),rs in grouped.items():
        leaks=[r['leaked'] for r in rs];gold=[r['gold'] for r in rs]
        stats.append(dict(config=config,policy=policy,map=map_name,mode=mode,n=len(rs),wins=sum(r['result']=='victory' for r in rs),leaks_mean=round(statistics.mean(leaks),2),leaks_median=statistics.median(leaks),leaks_min=min(leaks),leaks_max=max(leaks),leaks_sd=round(statistics.stdev(leaks),2) if len(rs)>1 else '',gold_mean=round(statistics.mean(gold),2),seeds=' '.join(str(r['seed']) for r in rs)))
    table(output/'full_runs.csv',stats)
    ledgers=[];waves=[]
    for r in all_rows:
        if r['kind']!='full_run':continue
        for w in r['financial_waves']: ledgers.append(dict(experiment=r['experiment'],run=r['id'],wave=w['wave'],opening=w['opening'],income=sum(v for k,v in w.items() if k not in ['wave','opening','closing'] and v>0),spending=-sum(v for k,v in w.items() if k not in ['wave','opening','closing'] and v<0),closing=w['closing']))
        for w in r['run_wave_details']: waves.append(dict(experiment=r['experiment'],run=r['id'],**w))
    table(output/'gold_ledger.csv',ledgers);table(output/'wave_outcomes.csv',waves)
    params=json.loads((ROOT/'docs/balance/phase5_parameters.json').read_text(encoding='utf-8'))['parameters']
    values={p['id']:p['original_value'] for p in params}
    def troop(key,prop,default=0):return values.get(f'res://assets/data/troops/{key}.tres.{prop}',default)
    authored=json.loads((ROOT/'docs/balance/phase5_wave_proposal.json').read_text(encoding='utf-8'))
    economy=[];ca=cb=cc=cf=0
    bounty={'soldier':1,'quickfeet':1,'heavy':3,'rat_swarm':0,'shield_guardian':3,'blood_mage':1,'winged_beast':1,'scout':1,'saboteur':1,'siege_behemoth':0}
    for w in authored:
        count=sum(g['count'] for g in w['groups']);b=sum(g['count']*bounty[g['troop']] for g in w['groups'])
        # C keeps half the explicit completion reward and adds the normalized bounties.
        c=b+math.floor(w['reward']*.5+.5)
        ca+=count;cb+=b;cc+=c;cf+=w['reward']
        hp=sum(g['count']*(troop(g['troop'],'max_health')+troop(g['troop'],'max_shield')) for g in w['groups'])
        ehp=sum(g['count']*(troop(g['troop'],'max_health')+troop(g['troop'],'max_shield'))/(1-troop(g['troop'],'damage_reduction')) for g in w['groups'])
        last=0
        for g in w['groups']:
            size=troop(g['troop'],'cohort_size',1);spacing=troop(g['troop'],'cohort_interval_ticks',1)
            last=max(last,g['start_tick']+(math.floor((g['count']-1)/size)*max(g['interval_ticks'],size*spacing)+(g['count']-1)%size*spacing if size>1 else math.floor((g['count']-1)/max(1,g['batch']))*g['interval_ticks']))
        economy.append(dict(wave=w['wave'],count=count,hp=hp,static_ehp=round(ehp,1),last_spawn_seconds=last*.25,wave_speed=w['move_speed'],fixed_reward=w['reward'],A_per_enemy=count,B_normalized=b,C_mixed=c,A_cumulative=ca,B_cumulative=cb,C_cumulative=cc,fixed_cumulative=cf,fixed_card_equivalents=round((9+cf)/9,2),A_at_80pct_kills=round(count*.8,1),B_at_80pct_kills=round(b*.8,1),C_at_80pct_kills=round(b*.8+math.floor(w['reward']*.5+.5),1)))
    for row in economy:
        for policy,total in [('A',ca),('B',cb),('C',cc)]:row[policy+'_equal_budget_cumulative']=round(row[policy+'_cumulative']*cf/total,2)
        samples=[w for r in all_rows if r['config']=='candidate3' for w in r['run_wave_details'] if w['wave']==row['wave']]
        row['observed_n']=len(samples)
        row['peak_alive_mean']=round(statistics.mean(w['peak_alive'] for w in samples),1) if samples else ''
        row['leaks_mean']=round(statistics.mean(w['leaks'] for w in samples),2) if samples else ''
    table(output/'wave_design_and_economy.csv',economy)
    plt.rcParams.update({'font.size':10,'axes.spines.top':False,'axes.spines.right':False,'figure.dpi':150})
    fig,ax=plt.subplots(figsize=(9,4.5))
    for key,label in [('A_cumulative','A: 1 / enemy'),('B_cumulative','B: integer type bounties'),('C_cumulative','C: bounties + half wave'),('fixed_cumulative','Selected: fixed completion')]:ax.plot([w['wave'] for w in economy],[w[key] for w in economy],marker='o',label=label)
    ax.set(xlabel='Wave',ylabel='Potential cumulative Gold (excludes initial 9)',title='Reward alternatives on the same authored wave counts');ax.legend();fig.tight_layout();fig.savefig(output/'economy.png');plt.close(fig)
    towers=['sentry','ballista','broadside','crossfire','mortar','barracks'];geometries=['parallel','approach','away']
    fig,axes=plt.subplots(1,3,figsize=(13,4.5),sharey=True)
    for ax,experiment,label in zip(axes,['baseline-v2','tower-final','tower-lv3'],['Original Lv.1','Selected Lv.1','Selected Lv.3 (3 cards)']):
        matrix=[[statistics.mean([r['damage'] for r in all_rows if r['experiment']==experiment and r['tower']==t and r['geometry']==g]) for g in geometries] for t in towers]
        ax.imshow(matrix,cmap='YlGnBu',vmin=0,vmax=1000);ax.set_xticks(range(3),geometries,rotation=25);ax.set_yticks(range(6),towers);ax.set_title(label)
        for i,row in enumerate(matrix):
            for j,v in enumerate(row):ax.text(j,i,f'{v:.0f}',ha='center',va='center',color='white' if v>550 else 'black')
    fig.suptitle('Applied damage / encounter, mean of four matchups; zero in poor geometry is retained');fig.tight_layout();fig.savefig(output/'tower_geometry.png');plt.close(fig)
    final=[r for r in all_rows if r['config'] in ['candidate3','holdout'] and r['kind']=='full_run']
    if final:
        fig,ax=plt.subplots(figsize=(12,max(4,len(final)*.27)))
        matrix=[]
        for r in final:
            d={w['wave']:w['leaks'] for w in r['run_wave_details']};matrix.append([d.get(i,float('nan')) for i in range(1,16)])
        ax.imshow(matrix,aspect='auto',cmap='OrRd',vmin=0,vmax=10);ax.set_xticks(range(15),range(1,16));ax.set_yticks(range(len(final)),[f"{r['experiment']} : {r['result']}" for r in final],fontsize=8);ax.set_xlabel('Wave (blank = not reached)');ax.set_title('Observed leaks; boss leakage is lethal even with few ordinary leaks')
        for y,row in enumerate(matrix):
            for x,v in enumerate(row):
                if math.isfinite(v) and v>0:ax.text(x,y,str(int(v)),ha='center',va='center',fontsize=7)
        fig.tight_layout();fig.savefig(output/'progression.png');plt.close(fig)
    pairs=[]
    cf=collections.defaultdict(dict)
    for r in all_rows:
        if r['kind']=='counterfactual':cf[(r['metadata']['mechanic'],r['seed'],r['metadata']['enabled'])][r['metadata']['traffic']]=r
    for (mechanic,seed,enabled),p in sorted(cf.items()):
        if len(p)==2:pairs.append(dict(mechanic=mechanic,seed=seed,enabled=enabled,leaks_without=p[False]['leaked'],leaks_with=p[True]['leaked'],delta_leaks=p[True]['leaked']-p[False]['leaked'],healing_without=p[False]['healing'],healing_with=p[True]['healing'],disables_without=p[False]['disables'],disables_with=p[True]['disables']))
    table(output/'counterfactual_pairs.csv',pairs)
    fig,ax=plt.subplots(figsize=(10,4))
    xs=range(len(pairs));ax.bar(xs,[r['delta_leaks'] for r in pairs],color=['#426d65' if r['delta_leaks']<0 else '#b45f51' for r in pairs]);ax.axhline(0,color='black',lw=.6);ax.set_xticks(list(xs),[f"{r['mechanic']} {r['seed']} {'on' if r['enabled'] else 'off'}" for r in pairs],rotation=70,fontsize=7);ax.set(ylabel='Traffic leaks − control leaks',title='Same 50 Gold budget; control retains the unspent 6 Gold');fig.tight_layout();fig.savefig(output/'traffic_counterfactual.png');plt.close(fig)
    if a.archive:
        with zipfile.ZipFile(ROOT/'.godot/phase5/raw_evidence.zip','w',zipfile.ZIP_DEFLATED,compresslevel=9) as archive:
            for directory in manifest['directories']:
                for file in (ROOT/directory).iterdir():
                    if file.suffix in ['.jsonl','.json','.log']: archive.write(file,file.relative_to(ROOT))
            for file in manifest.get('logs',[]):archive.write(ROOT/file,file)
    print('REPORT_REBUILT',len(all_rows),'independently validated samples;',len(stats),'full-run groups')
if __name__=='__main__':main()
