extends RefCounted
## Presentation only; mechanics are read from the shared Troop Resource.
static func description(profile: Troop) -> String:
	var en := TranslationServer.get_locale().begins_with("en")
	var story_key := "enemy.story."+profile.troop_name
	var story := GameText.text(story_key)
	if story == story_key: story = GameText.text("enemy.story.generic")
	var abilities: Array[String] = []
	if profile.max_shield > 0: abilities.append((GameText.text("text.enemy_codex_text.1",{},en)) % profile.max_shield)
	if profile.damage_reduction > 0: abilities.append((GameText.text("text.enemy_codex_text.2",{},en)) % str(snappedf(profile.damage_reduction*100,0.01)))
	for ability in profile.abilities:
		var line := ability.describe(en) if ability != null else ""
		if not line.is_empty() and not abilities.has(line): abilities.append(line)
	if profile.has_tag(&"flying"): abilities.append(GameText.text("text.enemy_codex_text.3",{},en))
	if profile.has_tag(&"boss"): abilities.append(GameText.text("text.enemy_codex_text.4",{},en))
	var route := (GameText.text("text.enemy_codex_text.5",{},en))+profile.route_description()
	var fixed := GameText.text("text.enemy_codex_text.6",{},en)
	return story+"\n\n"+route+"\n"+fixed+("\n\n"+(GameText.text("text.enemy_codex_text.7",{},en))+"\n".join(abilities) if not abilities.is_empty() else "")
