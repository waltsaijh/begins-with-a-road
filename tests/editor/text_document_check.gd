extends SceneTree
const Document = preload("res://addons/text_editor/text_document.gd")
var failures := 0
var checks := 0
func _initialize() -> void: verify.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func write(path: String, text: String) -> void:
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(text)
	file.close()
func verify() -> void:
	var path := "res://.godot/text-editor/round-trip.csv"
	var source := "\ufeffkeys,en,zh_TW\r\n"+'sample,"One, two\nand ""three"".","第一行，\n第二行「引號」。"\r\n'+'number,"Damage {amount} / %02d","傷害 {amount} / %02d"\r\n'
	write(path,source)
	var document := Document.new()
	check(document.open_file(path).is_empty(),"Quoted multiline CSV failed to load")
	check(document.get_text("sample","en") == "One, two\nand \"three\".","Quotes or multiline text changed")
	check(document.save_changes().is_empty() and Document.read_text_file(path) == source,"No-op save rewrote CSV")
	document.set_text("sample","zh_TW","新文案，\n保留換行及 \"引號\"。")
	check(document.modified_count() == 1,"Dirty count is wrong")
	check(document.save_changes().is_empty(),"Atomic CSV save failed on Windows")
	var saved := Document.read_text_file(path)
	check(saved.begins_with("\ufeffkeys,en,zh_TW\r\n") and saved.ends_with('number,"Damage {amount} / %02d","傷害 {amount} / %02d"\r\n'),"Saving changed untouched records or line endings")
	var round_trip := Document.new()
	check(round_trip.open_file(path).is_empty() and round_trip.get_text("sample","zh_TW") == "新文案，\n保留換行及 \"引號\"。","Save/reload changed Unicode or quote characters")
	document.set_text("number","en","Damage without a value")
	check(not document.validation_errors().is_empty() and not document.save_changes().is_empty() and Document.read_text_file(path) == saved,"Missing placeholder was saved")
	document.set_text("number","en","Damage {amount} / %02d!")
	check(document.validation_errors().is_empty(),"Valid placeholder-preserving edit was rejected")
	write(path,saved+"\n")
	check(not document.save_changes().is_empty() and Document.read_text_file(path) == saved+"\n","External changes were overwritten")
	check(not Document.parse_csv('keys,en,zh_TW\nx,"unfinished,x').error.is_empty(),"Malformed CSV was accepted")
	write(path,"keys,en,zh_TW\na,A,甲\na,B,乙\n")
	check(not round_trip.open_file(path).is_empty(),"Duplicate keys were accepted")
	var real := Document.new()
	check(real.open_file().is_empty() and real.keys().size() >= 300,"Real unified catalog did not load")
	check(real.preview_text("relic.crew_concentration.description","zh_TW").contains("2.5"),"Resource-backed read-only preview has no real values")
	check(real.category("enemy.story.soldier") == "敵軍" and real.category("relic.gold.description") == "遺物","Catalog categories are wrong")
	for key in real.keys():
		check(not real.title_for(key).is_empty(),"Catalog entry has no readable label")
	print("TEXT_DOCUMENT_CHECK: checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)
