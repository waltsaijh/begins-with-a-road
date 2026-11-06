"""Independent JSONL accounting. Python 3 standard library; no game imports."""
import argparse, collections, csv, json, pathlib, statistics

def validate(path):
    rows = [json.loads(s) for s in path.read_text(encoding="utf-8-sig").splitlines() if s.strip()]
    assert rows and rows[0]["event"] == "run_start", (path, "missing start")
    assert rows[0].get('detailed', True), (path, 'Detailed trace required for independent damage accounting')
    assert rows[-1]["event"] == "run_end", (path, "missing end")
    gold = 0
    damage = healing = overkill = 0.0
    counts = collections.Counter()
    remaining = {}
    tower_damage = collections.Counter()
    waves = []
    spent = collections.Counter()
    per_wave = collections.defaultdict(lambda: collections.Counter())
    purchases = collections.Counter()
    mortar_hits = []
    for row in rows:
        kind, p = row["event"], row["payload"]
        counts[kind] += 1
        if kind == "gold":
            gold += p["delta"]
            assert gold == p["balance"], (path, "Gold mismatch", row)
            spent[p["reason"]] += p["delta"]
            per_wave[row['wave']][p['reason']] += p['delta']
            if p['reason'] == 'purchase': purchases[p['card'].split('/')[-1]] += 1
        elif kind == "spawn":
            assert row["entity"] not in remaining, (path, "duplicate spawn")
            remaining[row["entity"]] = p["hp"] + p["shield"]
        elif kind == "damage":
            damage += p["amount"]
            overkill += p["overkill"]
            tower_damage[p["source"]] += p["amount"]
            remaining[row["entity"]] -= p["amount"]
            assert abs(remaining[row["entity"]] - p["remaining"]) < 0.01, (path, "damage mismatch", row)
        elif kind == "heal":
            healing += p["amount"]
            remaining[row["entity"]] += p["amount"]
            assert abs(remaining[row["entity"]] - p["remaining"]) < 0.01, (path, "heal mismatch")
        elif kind == "death":
            assert abs(remaining[row["entity"]]) < 0.01, (path, "death without zero HP")
        elif kind == "wave_end":
            assert p["spawned"] == p["killed"] + p["leaked"], (path, "wave conservation")
            waves.append(dict(wave=row["wave"], **p))
        elif kind == 'mortar_landing': mortar_hits.append(p['hits'])
    final = rows[-1]["payload"]
    assert gold == final["gold"], (path, "final Gold mismatch")
    if "total_killed" in final:
        assert counts["death"] == final["total_killed"], (path, "kill mismatch")
    elif "killed" in final:
        assert counts["death"] == final["killed"], (path, "kill mismatch")
    if "damage_received" in final:
        assert abs(damage-final["damage_received"]) < .01, (path, "damage aggregate mismatch")
    for key, value in final['event_counts'].items():
        assert counts[key] == value, (path, 'event sample count', key, value, counts[key])
    cash = 0
    ledger = []
    for wave, amounts in sorted(per_wave.items()):
        opening = cash
        cash += sum(amounts.values())
        ledger.append(dict(wave=wave, opening=opening, closing=cash, **amounts))
    return dict(id=rows[0]["run_id"], config=rows[0]["config"], seed=rows[0]["seed"],
                kind=rows[0].get("kind"), tower=rows[0].get("tower"), geometry=rows[0].get("geometry"),
                troop=rows[0].get("troop"), policy=rows[0].get("policy"),
                gold=gold, damage=round(damage,3), healing=round(healing,3), overkill=round(overkill,3),
                spawned=counts["spawn"], killed=counts["death"], leaked=counts["leak"],
                shots=counts["attack"], hits=counts["hit"], misses=counts["miss"],
                interceptions=counts["intercept"], disables=counts["disable"],
                upgrades=counts['upgrade'], builds=counts['build'], purchases=dict(purchases),
                configuration_hash=rows[0].get('configuration_hash','not-recorded-in-early-baseline'),
                tower_seconds=final.get('tower_seconds',{}), financial_waves=ledger,
                mortar_landings=len(mortar_hits), mortar_empty=sum(v==0 for v in mortar_hits),
                mortar_mean_targets=statistics.mean(mortar_hits) if mortar_hits else None,
                remaining_health_at_leak=sum(r['payload']['remaining'] for r in rows if r['event']=='leak'),
                final_levels=final.get('levels',{}), relics=final.get('relics',{}),
                seconds=final.get('seconds'), base_health=final.get('base_health'),
                run_wave_details=final.get('waves',[]), metadata=rows[0]['payload'],
                waves=len(waves), result=final.get("outcome","encounter"),
                sources_sinks=dict(spent), wave_results=waves, tower_damage=dict(tower_damage))

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("directory",type=pathlib.Path)
    args = ap.parse_args()
    files = sorted(args.directory.glob("*.jsonl"))
    assert files, "No raw traces"
    results = [validate(f) for f in files]
    summary = args.directory/'summary.json'
    if summary.exists():
        expected = json.loads(summary.read_text(encoding='utf-8-sig'))
        assert len(results) == len(expected['results']), 'Raw sample count differs from engine summary'
        assert not expected['failures'], expected['failures']
    (args.directory/"independent.json").write_text(json.dumps(dict(samples=len(results),results=results),indent=2),encoding="utf-8")
    keys = [k for k,v in results[0].items() if not isinstance(v,(dict,list))]
    with (args.directory/"independent.csv").open("w",newline="",encoding="utf-8") as f:
        w=csv.DictWriter(f,keys,extrasaction="ignore"); w.writeheader(); w.writerows(results)
    by_tower = collections.defaultdict(list)
    for r in results: by_tower[r["tower"] or r["policy"]].append(r)
    for key, rs in by_tower.items():
        print(key,"n=",len(rs),"kills=",sum(r["killed"] for r in rs),"damage_mean=",round(statistics.mean(r["damage"] for r in rs),1),"leaks=",sum(r["leaked"] for r in rs))
    print("INDEPENDENT_LEDGER_PASS",len(results))
if __name__ == "__main__": main()
