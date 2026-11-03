extends RefCounted
const Data = preload("res://scripts/tower_tile_editor/catalog_data.gd")
const KEYS := ["sentry","ballista","broadside","crossfire","mortar","barracks"]
var root := "res://assets/data/tower_tiles/user"
var data: Resource = Data.new()
var error := ""

func _init(folder := "res://assets/data/tower_tiles/user") -> void:
	root = folder
	if FileAccess.file_exists(root+"/catalog.tres"):
		data = ResourceLoader.load(root+"/catalog.tres","",ResourceLoader.CACHE_MODE_IGNORE)
		if data == null: data = Data.new(); error = "候選索引無法讀取"

static func tower(key: String) -> TowerDefinition:
	return load("res://assets/data/towers/"+key+".tres")

static func fresh_id() -> String:
	return "user_"+Crypto.new().generate_random_bytes(16).hex_encode()

static func title(row: Dictionary) -> String:
	var name: String = row.preset.localized_prefix()
	return name if not name.is_empty() else String(row.path).get_file().get_basename()

func rows(key: String, include_archived := false) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for option in tower(key).tile_preset_candidates:
		var preset: TilePreset = option.resolve_preset()
		if preset != null: result.append({"id":preset.stable_id(),"path":option.preset_path,"weight":option.weight,"default":false,"builtin":true,"preset":preset})
	for entry in data.entries:
		if entry.tower != key or (entry.get("archived",false) and not include_archived): continue
		if not FileAccess.file_exists(entry.path): continue
		var row: Dictionary = entry.duplicate()
		row.builtin = false
		row.preset = ResourceLoader.load(entry.path,"",ResourceLoader.CACHE_MODE_IGNORE)
		if row.preset is TilePreset: result.append(row)
	return result

func save(key: String, preset: TilePreset, weight: float, is_default: bool) -> bool:
	error = BuildCard.from_parts(tower(key),preset).configuration_error()
	if preset.tower_footprint.is_empty(): error = "自訂配置必須畫出至少一格塔體"
	if preset.display_name.strip_edges().is_empty(): error = "請輸入配置名稱"
	if not is_finite(weight) or weight < 0: error = "權重必須是有限非負數"
	if not preset.preset_id.begins_with("user_") or not preset.preset_id.is_valid_identifier(): error = "只能儲存具有獨立 ID 的使用者配置"
	if not error.is_empty(): return false
	var path := root+"/"+preset.preset_id+".tres"
	for entry in data.entries:
		if entry.id == preset.preset_id and entry.tower != key:
			error = "配置已屬於其他塔；請先複製"
			return false
	var previous: Resource = data.duplicate(true)
	var backup: PackedByteArray = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()
	var found := false
	for entry in data.entries:
		if is_default and entry.tower == key: entry.default = false
		if entry.id == preset.preset_id:
			entry.weight = weight; entry.default = is_default; entry.archived = false; found = true
	if not found: data.entries.append({"id":preset.preset_id,"tower":key,"path":path,"weight":weight,"default":is_default,"archived":false})
	if not _write(preset,path): data = previous; return false
	if not _write(data,root+"/catalog.tres"):
		data = previous
		if not backup.is_empty():
			var file := FileAccess.open(path,FileAccess.WRITE)
			if file != null: file.store_buffer(backup)
		else: DirAccess.remove_absolute(path)
		return false
	# Existing cards hold copies; future weighted draws must see the saved revision.
	ResourceLoader.load(path,"",ResourceLoader.CACHE_MODE_REPLACE)
	return true

func archive(id: String) -> bool:
	error = "只能刪除使用者配置"
	var previous: Resource = data.duplicate(true)
	for entry in data.entries:
		if entry.id != id: continue
		entry.archived = true
		entry.default = false
		if _write(data,root+"/catalog.tres"): error = ""; return true
		data = previous
		return false
	return false

func _write(resource: Resource, path: String) -> bool:
	var result := DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if result != OK: error = "無法建立儲存目錄："+error_string(result); return false
	var temp := path.get_basename()+".pending.tres"
	result = ResourceSaver.save(resource,temp)
	if result == OK: result = DirAccess.rename_absolute(temp,path)
	if result != OK: error = "儲存失敗："+error_string(result); return false
	if path.ends_with("/catalog.tres"): ResourceLoader.load(path,"",ResourceLoader.CACHE_MODE_REPLACE)
	return true

func apply(shop: Node) -> void:
	for key in KEYS:
		var pool: Array[TilePresetCandidate] = []
		for row in rows(key):
			if not permits(key,row): continue
			var option := TilePresetCandidate.new()
			option.preset_path = row.path
			option.weight = row.weight
			pool.append(option)
		shop.tile_preset_overrides[tower(key)] = pool

static func member_key(key: String, id: String) -> String: return key+"|"+id

func combination(id: String) -> Dictionary:
	for item in data.combinations:
		if item.id == id: return item
	return {}

func permits(key: String, row: Dictionary) -> bool:
	var active := combination(data.active_combination)
	# The accepted base group explicitly retains the one existing barracks recipe.
	if active.get("variant_group","") == "base" and key == "barracks":
		return member_key(key,row.id) in active.get("members",[])
	if data.exclude_builtins and row.builtin: return false
	if data.active_combination.is_empty(): return true
	return member_key(key,row.id) in combination(data.active_combination).get("members",[])

func playable_rows(key: String) -> Array[Dictionary]:
	return rows(key).filter(func(row): return permits(key,row))

func card_error(card: BuildCard) -> String:
	if card == null: return "缺少卡牌"
	if card.traffic != null: return ""
	for key in KEYS:
		if card.tower != tower(key): continue
		for row in playable_rows(key):
			if card.tile_preset != null and row.id == card.tile_preset.stable_id(): return ""
	return "此配置不在目前測試組合內"

func save_settings(exclude: bool, hidden: bool) -> bool:
	var previous: Resource = data.duplicate(true)
	data.exclude_builtins = exclude; data.hide_builtins = hidden
	var active := combination(data.active_combination)
	if not active.is_empty(): active.exclude_builtins = exclude
	return _save_index(previous)

func save_combination(id: String, title_text: String, members: Array[String], exclude: bool) -> String:
	error = ""
	if title_text.strip_edges().is_empty(): error = "請輸入組合名稱"; return ""
	var previous: Resource = data.duplicate(true)
	if id.is_empty(): id = fresh_id()
	var item := combination(id)
	if item.is_empty():
		item = {"id":id}; data.combinations.append(item)
	item.name = title_text.strip_edges(); item.members = members.duplicate(); item.exclude_builtins = exclude
	data.active_combination = id; data.exclude_builtins = exclude
	return id if _save_index(previous) else ""

func activate(id: String) -> bool:
	var item := combination(id)
	if not id.is_empty() and item.is_empty(): error = "找不到組合"; return false
	var previous: Resource = data.duplicate(true)
	data.active_combination = id
	if not item.is_empty(): data.exclude_builtins = item.get("exclude_builtins",false)
	return _save_index(previous)

func _save_index(previous: Resource) -> bool:
	if _write(data,root+"/catalog.tres"): error = ""; return true
	data = previous
	return false
