extends Node3D
const Batch = preload("res://scripts/enemies/rendering/enemy_multimesh.gd")
const Enemy = preload("res://scenes/enemies/enemy.tscn")
func _ready() -> void:
	run.call_deferred()

func run() -> void:
	for detach in [false,true]:
		var batch := Batch.new()
		add_child(batch)
		var tower := DefenseTower.new()
		tower.position = Vector3(2,0,0)
		add_child(tower)
		var units: Array[Node3D] = []
		for kind in ["soldier","bomber"]:
			var enemy := Enemy.instantiate() as Node3D
			enemy.troop = TroopCatalog.find(kind)
			enemy.apply_snapshot(enemy.troop.combat_snapshot())
			add_child(enemy)
			enemy.follow(units.size(),{"cells":PackedVector2Array([Vector2.ZERO,Vector2.RIGHT])},PackedVector3Array([Vector3.ZERO,Vector3.RIGHT]))
			enemy.set_process(false)
			batch.add_enemy(enemy)
			units.append(enemy)
		var cast: SabotageAbility = units[1].ability(SabotageAbility)
		cast.marked.append(weakref(tower))
		cast.remaining = cast.windup * 0.85
		batch.update_enemy(units[1])
		if detach: remove_child(tower)
		print("CASE_BEGIN detached=",detach," valid=",is_instance_valid(tower)," inside=",tower.is_inside_tree())
		batch.remove_enemy(units[0])
		print("CASE_END slots=",batch.units.size()," moved_is_bomber=",batch.units[0]==units[1])
		cast.stop()
		batch.remove_enemy(units[1])
		tower.free()
		for enemy in units: enemy.free()
		batch.free()
	print("PROBE_FINISHED")
	get_tree().quit()
