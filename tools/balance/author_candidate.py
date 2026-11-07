"""Explicit first-pass resource proposal, not a runtime scaling formula."""
import argparse, json, pathlib
# troop, individuals, first quarter-second tick, interval ticks, batch size
WAVES = [
 [("soldier",5,0,8,1),("quickfeet",3,24,10,1)],
 [("soldier",6,0,6,1),("rats",10,12,10,1),("rook",1,0,1,1)],
 [("rats",15,12,10,1),("rook",2,0,24,1),("heavy",2,8,24,1)],
 [("soldier",10,0,6,1),("heavy",3,8,16,1),("bloodmage",2,12,24,1)],
 [("rats",25,8,8,1),("rook",3,0,20,1),("bloodmage",2,8,24,1)],
 [("heavy",5,0,14,1),("rook",3,4,20,1),("bloodmage",2,12,24,1),("bomber",1,24,1,1)],
 [("scout",8,0,6,1),("soldier",12,4,5,1),("quickfeet",6,20,7,1)],
 [("winged",10,12,7,1),("heavy",6,0,12,1)],
 [("scout",10,16,6,1),("winged",8,24,7,1),("rook",4,0,16,1),("rats",25,8,8,1)],
 [("rats",35,4,7,1),("rook",5,0,14,1),("bomber",3,12,20,1)],
 [("heavy",8,0,12,1),("bloodmage",4,8,20,1),("winged",12,24,6,1)],
 [("rook",5,0,14,1),("bloodmage",3,8,20,1),("bomber",3,16,20,1),("scout",12,24,5,1),("rats",30,8,7,1)],
 [("rats",40,4,7,1),("rook",6,0,14,1),("bloodmage",4,12,20,1),("heavy",8,8,12,1)],
 [("winged",16,24,5,1),("scout",14,0,5,1),("bomber",4,16,16,1),("quickfeet",12,12,5,1)],
 [("rook",4,0,16,1),("rats",25,8,8,1),("bloodmage",3,20,20,1),("ravager",1,56,1,1),("heavy",6,64,12,1),("scout",8,76,6,1),("winged",8,88,6,1),("bomber",2,76,20,1)],
]
PURPOSES = ["single target / speed", "cohorts / first taunt", "armor and crowds", "healing introduction", "healer and swarm cooperation", "limited disable", "newest routes", "shortest routes / anti-air", "hard-route combination", "crowds and sabotage", "healing / air coverage", "cooperation stress", "mature ground build", "mobility and disabled coverage", "staged assault / telegraphed siege"]
SPEEDS = [1.25]*3 + [1.35]*3 + [1.45]*3 + [1.5]*3 + [1.55]*3
REWARDS = [12]*3 + [14]*3 + [16]*3 + [18]*3 + [20,20,0]

def main():
    ap=argparse.ArgumentParser();ap.add_argument("--output",default=".godot/phase5/proposal.tres");ap.add_argument('--candidate',choices=['initial','final'],default='final');a=ap.parse_args()
    if a.candidate=='final':
        import math
        REWARDS[:]=[math.floor(r*.75+.5) for r in REWARDS]
        for n in range(9,15): WAVES[n]=[(t,c,s,math.floor(i*.5+.5),b) for t,c,s,i,b in WAVES[n]]
    head='[gd_resource type="Resource" script_class="LevelDefinition" format=3 uid="uid://crw7gsg3jk7ae"]\n'
    for ident,path in [("level","levels/definitions/level_definition"),("act","levels/definitions/act_definition"),("wave","levels/definitions/wave_definition"),("group","levels/definitions/wave_spawn_group")]:
        head+=f'[ext_resource type="Script" path="res://scripts/{path}.gd" id="{ident}"]\n'
    head+='[ext_resource type="PackedScene" path="res://scenes/maps/tile_map.tscn" id="terrain"]\n'
    for n,groups in enumerate(WAVES,1):
        names=[]
        for i,(troop,count,start,interval,batch) in enumerate(groups):
            name=f'W{n}G{i}';names.append(f'SubResource("{name}")')
            head+=f'\n[sub_resource type="Resource" id="{name}"]\nscript = ExtResource("group")\ntroop_path = "res://assets/data/troops/{troop}.tres"\nenemy_count = {count}\nstart_tick = {start}\ninterval_ticks = {interval}\nbatch_size = {batch}\n'
        head+=f'\n[sub_resource type="Resource" id="W{n}"]\nscript = ExtResource("wave")\nmove_speed = {SPEEDS[n-1]}\nreward = {REWARDS[n-1]}\ngroups = Array[ExtResource("group")]([{", ".join(names)}])\n'
    for act,title in enumerate(["I","II","III","IV","V"],1):
        waves=', '.join(f'SubResource("W{n}")' for n in range(act*3-2,act*3+1))
        head+=f'\n[sub_resource type="Resource" id="A{act}"]\nscript = ExtResource("act")\ntitle = "ACT {title}"\nwaves = Array[ExtResource("wave")]([{waves}])\n'
    head+='\n[resource]\nscript = ExtResource("level")\ntitle = "Frontier"\nterrain = ExtResource("terrain")\nexpand_starts_after_act = false\nbase_health = 20\nstarting_gold = 9\nopening_shop = true\nacts = Array[ExtResource("act")](['+', '.join(f'SubResource("A{i}")' for i in range(1,6))+'])\n'
    pathlib.Path(a.output).write_text(head,encoding="utf-8")
    pathlib.Path('docs/balance/phase5_wave_proposal.json').write_text(json.dumps([dict(wave=n+1,purpose=PURPOSES[n],move_speed=SPEEDS[n],reward=REWARDS[n],groups=[dict(troop=t,count=c,start_tick=s,interval_ticks=i,batch=b) for t,c,s,i,b in groups]) for n,groups in enumerate(WAVES)],indent=2),encoding="utf-8")
if __name__ == "__main__": main()
