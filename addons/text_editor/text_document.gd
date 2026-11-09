@tool
extends Resource
## Draft-only string edits. No ResourceSaver or gameplay resource writes.
const DEFAULT_PATH := "res://assets/translations/card_names.csv"
const LOCALES := {"en":1,"zh_TW":2}
var path := DEFAULT_PATH
var rows: Array = []
var saved_rows: Array = []
var records: Array = []
var indices := {}
var load_error := ""
var _hash := ""
var _newline := "\n"
var _trailing_newline := true

func open_file(source := DEFAULT_PATH) -> String:
	if not FileAccess.file_exists(source): return "找不到文本資料："+source
	var raw := read_text_file(source)
	var parsed := parse_csv(raw)
	if not parsed.error.is_empty(): return parsed.error
	var next_indices := {}
	for i in range(1,parsed.rows.size()):
		var row: Array = parsed.rows[i]
		if row.size() == 1 and row[0].is_empty(): continue
		if row.size() != 3: return "第 %d 筆資料不是三欄。" % (i+1)
		if row[0].is_empty() or next_indices.has(row[0]): return "文字識別碼空白或重複："+row[0]
		next_indices[row[0]] = i
	if parsed.rows.is_empty() or parsed.rows[0] != ["keys","en","zh_TW"]: return "文本欄位必須是 keys、en、zh_TW。"
	path = source
	rows = parsed.rows
	saved_rows = rows.duplicate(true)
	records = parsed.records
	indices = next_indices
	_hash = raw.sha256_text()
	_newline = "\r\n" if raw.contains("\r\n") else "\n"
	_trailing_newline = raw.ends_with("\n") or raw.ends_with("\r")
	load_error = ""
	emit_changed()
	return ""

func keys() -> Array:
	return indices.keys()

func get_text(key: String, locale: String) -> String:
	return rows[indices[key]][LOCALES[locale]] if indices.has(key) and LOCALES.has(locale) else ""

func set_text(key: String, locale: String, value: String) -> void:
	if not indices.has(key) or not LOCALES.has(locale) or get_text(key,locale) == value: return
	rows[indices[key]][LOCALES[locale]] = value
	emit_changed()

func entry_dirty(key: String) -> bool:
	return indices.has(key) and rows[indices[key]] != saved_rows[indices[key]]

func modified_count() -> int:
	var count := 0
	for key in indices:
		if entry_dirty(key): count += 1
	return count

static func tokens(value: String) -> Array[String]:
	var result: Array[String] = []
	var matcher := RegEx.create_from_string("\\{[A-Za-z_][A-Za-z0-9_]*\\}|%[-+0#]*[0-9]*(?:\\.[0-9]+)?[sdifxX]")
	for found in matcher.search_all(value): result.append(found.get_string())
	result.sort()
	return result

func validation_errors() -> Array[String]:
	var errors: Array[String] = []
	for key in indices:
		if not entry_dirty(key): continue
		var index: int = indices[key]
		for locale in LOCALES:
			var value := get_text(key,locale)
			if tokens(value) != tokens(saved_rows[index][LOCALES[locale]]): errors.append("%s（%s）：請保留原本的數值／名稱參數。" % [title_for(key),locale])
			var cleaned := value
			for token in tokens(value): cleaned = cleaned.replace(token,"")
			if cleaned.contains("{") or cleaned.contains("}"): errors.append("%s（%s）：參數的大括號不完整。" % [title_for(key),locale])
	return errors

func save_changes() -> String:
	if modified_count() == 0: return ""
	var errors := validation_errors()
	if not errors.is_empty(): return errors[0]
	if read_text_file(path).sha256_text() != _hash: return "檔案已被其他工具修改；未覆寫。請先保留草稿，再重新載入。"
	var output := ""
	for i in rows.size():
		if rows[i] == saved_rows[i]:
			output += records[i]
		else:
			var encoded: Array[String] = []
			for field in rows[i]: encoded.append(encode_field(field))
			output += ",".join(encoded)
			if i < rows.size()-1 or _trailing_newline: output += _newline
	var parsed := parse_csv(output)
	if not parsed.error.is_empty(): return "儲存前檢查失敗："+parsed.error
	var temporary := path+".text-editor-tmp"
	var file := FileAccess.open(temporary,FileAccess.WRITE)
	if file == null: return "無法寫入文本暫存檔。"
	file.store_string(output)
	file.close()
	if read_text_file(temporary) != output:
		DirAccess.remove_absolute(temporary)
		return "暫存檔驗證失敗，原檔未變更。"
	var error := DirAccess.rename_absolute(temporary,path)
	if error != OK:
		DirAccess.remove_absolute(temporary)
		return "無法替換文本檔案（%s），原檔未變更。" % error_string(error)
	_hash = output.sha256_text()
	saved_rows = rows.duplicate(true)
	records = parsed.records
	emit_changed()
	return ""

static func read_text_file(source: String) -> String:
	var bytes := FileAccess.get_file_as_bytes(source)
	var text := bytes.get_string_from_utf8()
	# Godot's UTF-8 decoder strips the BOM; preserve it for byte-stable saves.
	if bytes.size() >= 3 and bytes[0] == 239 and bytes[1] == 187 and bytes[2] == 191 and not text.begins_with("\ufeff"): text = "\ufeff"+text
	return text

static func encode_field(value: String) -> String:
	if value.contains(",") or value.contains("\n") or value.contains("\r") or value.contains('"'):
		return '"'+value.replace('"','""')+'"'
	return value

static func parse_csv(raw: String) -> Dictionary:
	var result: Array = []
	var raw_records: Array[String] = []
	var row: Array = []
	var field := ""
	var quoted := false
	var closed := false
	var start := 0
	var i := 1 if raw.begins_with("\ufeff") else 0
	while i < raw.length():
		var c := raw[i]
		if quoted:
			if c == '"':
				if i+1 < raw.length() and raw[i+1] == '"':
					field += '"'
					i += 1
				else:
					quoted = false
					closed = true
			else: field += c
		elif c == ",":
			row.append(field)
			field = ""
			closed = false
		elif c == "\n" or c == "\r":
			row.append(field)
			result.append(row)
			if c == "\r" and i+1 < raw.length() and raw[i+1] == "\n": i += 1
			raw_records.append(raw.substr(start,i-start+1))
			start = i+1
			row = []
			field = ""
			closed = false
		elif c == '"':
			if not field.is_empty() or closed: return {"error":"CSV 引號位置錯誤。","rows":[],"records":[]}
			quoted = true
		elif closed: return {"error":"CSV 引號後有非分隔字元。","rows":[],"records":[]}
		else: field += c
		i += 1
	if quoted: return {"error":"CSV 有未關閉的引號。","rows":[],"records":[]}
	if start < raw.length():
		row.append(field)
		result.append(row)
		raw_records.append(raw.substr(start))
	return {"error":"","rows":result,"records":raw_records}

func category(key: String) -> String:
	if key.begins_with("relic."): return "遺物"
	if key.begins_with("tower.") or key.begins_with("card.") or key.begins_with("text.card_"): return "防禦塔與卡牌"
	if key.begins_with("troop.") or key.begins_with("enemy.") or key.begins_with("text.troop.") or key.contains("_ability.") or key.begins_with("text.enemy_"): return "敵軍"
	if key.begins_with("tutorial."): return "教學"
	if key.begins_with("result.") or key.begins_with("text.run_status."): return "結算"
	if key.begins_with("ui.maps.") or key.begins_with("text.map_"): return "關卡"
	if key.begins_with("ui.progress."): return "進度頁"
	if key.begins_with("text.unit_inspection_"): return "單位資訊"
	if key.begins_with("text.wave_timeline.") or key.begins_with("text.level_hud."): return "戰場介面"
	if key.begins_with("ui.settings.") or key.begins_with("settings."): return "設定"
	if key.begins_with("ui.menu."): return "主選單"
	return "其他介面"

func title_for(key: String) -> String:
	if key.ends_with(".description"):
		var name_key := key.trim_suffix(".description")+".name"
		if indices.has(name_key): return get_text(name_key,"zh_TW")+"／說明"
	if key.begins_with("enemy.story.") or key.begins_with("enemy.intelligence."):
		var name_key := "troop."+key.get_slice(".",2)+".name"
		if indices.has(name_key): return get_text(name_key,"zh_TW")+("／介紹" if key.begins_with("enemy.story.") else "／單位資訊")
	return get_text(key,"zh_TW").get_slice("\n",0).left(38) if not get_text(key,"zh_TW").is_empty() else key

func preview_text(key: String, locale: String) -> String:
	var value := get_text(key,locale)
	if key.begins_with("relic.") and key.ends_with(".description"):
		var catalog: Resource = load("res://assets/data/relics/catalog.tres")
		for relic in catalog.entries:
			if relic.description_key == key: return value.format(relic.description_values())
	for token in tokens(value): value = value.replace(token,"〈動態內容〉")
	return value
