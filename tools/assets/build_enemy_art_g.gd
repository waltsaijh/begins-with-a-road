extends SceneTree
## Art Slice G enemies: wraps the Blender exports in assets/models/enemies/art_g/<troop>.glb
## into lightweight scenes driven by miniature_enemy.gd (legs swing on their hip pivots).
## Run: godot --headless --path . --script res://tools/assets/build_enemy_art_g.gd [-- --use] [--only=ravager]
##   ravager.glb comes from tools/assets/blender/art_slice_g/ravager.py (the others from Blender).
##   --use  also points assets/data/troops/<troop>.tres at the new scenes (GPU model cleared).
const DIR := "res://assets/models/enemies/art_g/"
const TROOPS := ["soldier", "heavy", "quickfeet", "rook", "bloodmage", "scout", "bomber", "rats", "winged", "ravager"]
const Miniature := preload("res://scripts/enemies/rendering/miniature_enemy.gd")
## Per-troop motion (see miniature_enemy.gd). "arms" = counter-swing radians per arm.
const MOTION := {
	"soldier": {"style": "walk", "rate": 11.0, "bob": 0.035, "sway": 0.022, "lean": 0.07, "swing": 0.5, "lift": 0.05, "arms": {"Arm-1": 0.2, "Arm1": 0.55}},
	"heavy": {"style": "walk", "rate": 7.5, "bob": 0.035, "sway": 0.09, "lean": 0.03, "swing": 0.38, "lift": 0.045, "arms": {"Arm-1": 0.18, "Arm1": 0.12}},
	"rook": {"style": "walk", "rate": 10.0, "bob": 0.03, "sway": 0.025, "lean": 0.05, "swing": 0.45, "lift": 0.045, "arms": {"Arm-1": 0.5, "Arm1": 0.12}},
	"scout": {"style": "walk", "rate": 13.0, "bob": 0.03, "sway": 0.018, "lean": 0.14, "swing": 0.55, "lift": 0.045},
	"bomber": {"style": "walk", "rate": 15.0, "bob": 0.04, "sway": 0.04, "lean": 0.1, "swing": 0.6, "lift": 0.04},
	"bloodmage": {"style": "glide", "rate": 6.0, "bob": 0.045, "sway": 0.05, "lean": 0.04, "arms": {"Arm-1": 0.15}},
	"quickfeet": {"style": "gallop", "rate": 15.0, "bob": 0.05, "sway": 0.02, "lean": 0.03, "pitch": 0.06, "swing": 0.55, "lift": 0.05, "wag": 0.3},
	"rats": {"style": "gallop", "rate": 20.0, "bob": 0.012, "sway": 0.03, "lean": 0.0, "pitch": 0.03, "swing": 0.5, "lift": 0.015, "wag": 0.25},
	"ravager": {"style": "gallop", "rate": 5.0, "bob": 0.035, "sway": 0.02, "lean": 0.0, "pitch": 0.02, "swing": 0.3, "lift": 0.06, "wag": 0.35},
	"winged": {"style": "fly", "rate": 9.0, "bob": 0.06, "sway": 0.04, "pitch": 0.04, "flap": 0.55, "wag": 0.3},
}

func _initialize() -> void: call_deferred("build")

static func gait_for(node_name: String) -> int:
	for key in ["LegFL", "LegBR"]:
		if node_name.begins_with(key): return 1
	for key in ["LegFR", "LegBL"]:
		if node_name.begins_with(key): return -1
	if node_name.begins_with("Leg-1"): return -1
	if node_name.begins_with("Leg1"): return 1
	return 0

static func root_name(troop: String) -> String: return troop.capitalize().replace(" ", "")

func build() -> void:
	# Shared muted grade (assets/shaders/enemy_muted.gdshader) keeps enemies in the towers' dusty palette.
	var material := ShaderMaterial.new()
	material.shader = load("res://assets/shaders/enemy_muted.gdshader")
	assert(ResourceSaver.save(material, DIR+"art_g_material.tres") == OK)
	var shared: Material = load(DIR+"art_g_material.tres")
	var report := {}
	var only := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="): only = arg.trim_prefix("--only=")
	for troop: String in TROOPS:
		if not only.is_empty() and troop != only: continue
		var source: PackedScene = load(DIR+troop+".glb")
		assert(source != null, "Missing "+troop+".glb")
		var imported := source.instantiate()
		var root := Node3D.new()
		root.name = root_name(troop)
		root.set_script(Miniature)
		var motion: Dictionary = MOTION.get(troop, {})
		for key in motion:
			if key != "arms": root.set(key, motion[key])
		if troop == "winged": root.set("flying", true)
		var rig := Node3D.new()
		rig.name = "Rig"
		root.add_child(rig)
		rig.owner = root
		var legs_ride: bool = motion.get("style", "") in ["hop", "fly"]
		var parts := 0
		var height := 0.0
		for mesh: MeshInstance3D in imported.find_children("*", "MeshInstance3D", true, false):
			var part := MeshInstance3D.new()
			var title := String(mesh.name).get_slice("_", 0).get_slice(".", 0)
			part.name = title
			part.transform = imported.global_transform.affine_inverse()*mesh.global_transform if mesh.is_inside_tree() else mesh.transform
			var path := DIR+"%s_%s.res" % [troop, title.to_lower().replace("-", "m")]
			assert(ResourceSaver.save(mesh.mesh, path) == OK)
			part.mesh = load(path)
			part.material_override = shared
			var gait := gait_for(title)
			if gait != 0: part.set_meta("gait", gait)
			if title.begins_with("Wing"):
				var centre := (part.transform*part.mesh.get_aabb()).get_center()
				part.set_meta("wing_tip" if title.begins_with("WingTip") else "wing", 1 if centre.x > 0.0 else -1)  # sign by which side the wing reaches
			if title.begins_with("Arm"):
				var arms: Dictionary = motion.get("arms", {})
				part.set_meta("arm", float(arms.get(title, 0.5))*(-1.0 if title == "Arm-1" else 1.0))
			if title == "Tail": part.set_meta("tail", 1)
			if title == "Cape": part.set_meta("cape", 1)
			var holder: Node3D = root if (gait != 0 and not legs_ride) else rig
			holder.add_child(part)
			part.owner = root
			height = maxf(height, (part.transform*part.mesh.get_aabb()).end.y)
			parts += 1
		imported.free()
		# Two-joint wings: the outer panel (from the wrist) rides on the inner wing.
		for tip: Node3D in rig.get_children().filter(func(n): return String(n.name).begins_with("WingTip")):
			var inner := rig.get_node_or_null(String(tip.name).replace("WingTip", "Wing")) as Node3D
			if inner == null: continue
			var local := inner.transform.affine_inverse()*tip.transform
			rig.remove_child(tip); inner.add_child(tip); tip.transform = local; tip.owner = root
		var packed := PackedScene.new()
		assert(packed.pack(root) == OK)
		assert(ResourceSaver.save(packed, DIR+troop+".tscn") == OK)
		root.free()
		report[troop] = {"parts": parts, "height": snappedf(height, 0.01)}
		# High-detail catalog version (single mesh, no decimation).
		var detail_source: PackedScene = load(DIR+troop+"_detail.glb") if ResourceLoader.exists(DIR+troop+"_detail.glb") else null
		if detail_source != null:
			var detail_imported := detail_source.instantiate()
			var detail_root := Node3D.new()
			detail_root.name = root_name(troop)+"Detail"
			for mesh: MeshInstance3D in detail_imported.find_children("*", "MeshInstance3D", true, false):
				var part := MeshInstance3D.new()
				part.name = "Detail"
				part.transform = Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)*mesh.transform  # catalog camera sits on +Z: face it
				var mesh_path := DIR+troop+"_detail.res"
				assert(ResourceSaver.save(mesh.mesh, mesh_path, ResourceSaver.FLAG_COMPRESS) == OK)
				part.mesh = load(mesh_path)
				part.material_override = shared
				detail_root.add_child(part)
				part.owner = detail_root
			detail_imported.free()
			var detail_packed := PackedScene.new()
			assert(detail_packed.pack(detail_root) == OK)
			assert(ResourceSaver.save(detail_packed, DIR+troop+"_detail.tscn") == OK)
			detail_root.free()
	if "--use" in OS.get_cmdline_user_args():
		for troop: String in TROOPS:
			if not only.is_empty() and troop != only: continue
			var path := "res://assets/data/troops/%s.tres" % troop
			var text := FileAccess.get_file_as_string(path)
			var lines := text.split("\n")
			var model_id := ""
			var kept: PackedStringArray = []
			for line in lines:
				if line.begins_with("model = ExtResource(\""): model_id = line.get_slice("\"", 1)
			for line in lines:
				if line.begins_with("gpu_model = ") or line.begins_with("detail_model = ") or line.contains("id=\"detail\""): continue
				if not model_id.is_empty() and line.begins_with("[ext_resource type=\"PackedScene\"") and line.contains("id=\"%s\"" % model_id):
					line = "[ext_resource type=\"PackedScene\" path=\"%s%s.tscn\" id=\"%s\"]" % [DIR, troop, model_id]
				kept.append(line)
				if line.begins_with("[ext_resource type=\"PackedScene\"") and line.contains("id=\"%s\"" % model_id) and FileAccess.file_exists(DIR+troop+"_detail.tscn"):
					kept.append("[ext_resource type=\"PackedScene\" path=\"%s%s_detail.tscn\" id=\"detail\"]" % [DIR, troop])
				if line.begins_with("model = ExtResource(") and FileAccess.file_exists(DIR+troop+"_detail.tscn"):
					kept.append("detail_model = ExtResource(\"detail\")")
			FileAccess.open(path, FileAccess.WRITE).store_string("\n".join(kept))
	print("ENEMY_ART_G_BUILT ", JSON.stringify(report))
	quit()
