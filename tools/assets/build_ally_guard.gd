extends SceneTree
## Barracks guard: wraps assets/models/allies/guard.glb (modelled in Blender:
## tools/assets/blender/art_slice_g/blend/guard.blend, exported with vertex colours) into guard.tscn with the metas
## friendly_soldier.gd animates: gait_sign on the legs, arm_sign on the arms,
## friendly_skin on the body (hit flash), cape_sway on the cape, contact_size and
## bar_height on the root.
## Run: godot --headless --path . --script res://tools/assets/build_ally_guard.gd
const DIR := "res://assets/models/allies/"
const METAS := {"Body": ["friendly_skin", true], "LegL": ["gait_sign", 1.0], "LegR": ["gait_sign", -1.0],
	"ArmShield": ["arm_sign", 1.0], "ArmSpear": ["arm_sign", -1.0], "Cape": ["cape_sway", 1.0]}

func _initialize() -> void: call_deferred("build")

func build() -> void:
	var shared: Material = load("res://assets/models/enemies/art_g/art_g_material.tres")
	var imported := (load(DIR+"guard.glb") as PackedScene).instantiate()
	var root := Node3D.new()
	root.name = "FriendlySoldier"
	root.set_meta("contact_size", Vector2(0.38, 0.29))
	var holder := Node3D.new()
	holder.name = "Miniature"
	root.add_child(holder)
	holder.owner = root
	var top := 0.0
	for mesh: MeshInstance3D in imported.find_children("*", "MeshInstance3D", true, false):
		var title := String(mesh.name).get_slice(".", 0)
		if title.get_slice("_", 1).is_valid_int(): title = title.get_slice("_", 0)   # Blender "Body.001" imports as "Body_001"
		title = title.trim_prefix("Guard")   # Blender objects are GuardBody, GuardLegL, ...
		var part := MeshInstance3D.new()
		part.name = title
		part.transform = mesh.transform
		var path := DIR+"guard_%s.res" % title.to_lower()
		assert(ResourceSaver.save(mesh.mesh, path) == OK)
		part.mesh = load(path)
		part.material_override = shared
		if METAS.has(title): part.set_meta(METAS[title][0], METAS[title][1])
		holder.add_child(part)
		part.owner = root
		top = maxf(top, (part.transform*part.mesh.get_aabb()).end.y)
	imported.free()
	root.set_meta("bar_height", snappedf(top+0.1, 0.01))
	var packed := PackedScene.new()
	assert(packed.pack(root) == OK)
	assert(ResourceSaver.save(packed, DIR+"guard.tscn") == OK)
	root.free()
	print("ALLY_GUARD_BUILT top=", snappedf(top, 0.01))
	quit()
