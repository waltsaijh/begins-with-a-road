extends RefCounted
## Presentation only; mechanics are read from the shared Troop Resource.
static func description(profile: Troop) -> String:
	var en := TranslationServer.get_locale().begins_with("en")
	var stories := {
		"soldier":["沿道路推進的前線步兵，是敵軍隊伍的中堅。","Frontline infantry, the backbone of the advancing force."],
		"quickfeet":["輕裝斥候善於穿過防線空隙，迅速向終點推進。","A lightly equipped runner that slips through gaps in the defense."],
		"heavy":["沉重裝甲掩護著緩慢推進的戰士。","An armored warrior that advances slowly toward the goal."],
		"rats":["成群奔竄的小型敵人，沿同一條道路湧向防線。","Small creatures that surge down the same road in packs."],
		"rook":["舉盾前行的守衛，以自身掩護周圍的隊伍。","A shield bearer that draws fire away from nearby allies."],
		"bloodmage":["隨軍行進的施法者，讓附近受傷的同伴再次站穩腳步。","A marching spellcaster that restores nearby wounded allies."],
		"winged":["盤旋於道路上方的飛獸，仍沿進攻路線接近終點。","A winged creature that follows the attack road from above."],
		"scout":["尋找新通路的偵查兵，會利用最近接通的道路。","A scout that takes advantage of newly completed roads."],
		"bomber":["潛入火線的破壞者，會讓附近的防禦塔短暫失去作用。","A saboteur that briefly disables nearby defenses."],
		"ravager":["向終點緩慢逼近的攻城巨獸，足以撕開整條防線。","A siege beast whose arrival at the goal breaks the defense."]}
	var story: String = stories.get(profile.troop_name,["沿道路接近防線的敵軍。","An enemy advancing along the road."])[1 if en else 0]
	var abilities: Array[String] = []
	if profile.max_shield > 0: abilities.append(("Shield %d" if en else "護盾 %d") % profile.max_shield)
	if profile.damage_reduction > 0: abilities.append("Armor reduces incoming damage." if en else "裝甲可減少受到的傷害。")
	if profile.taunt_radius > 0: abilities.append("Draws nearby single-target attacks." if en else "吸引附近可命中的單體攻擊。")
	if profile.heal_amount > 0: abilities.append("Periodically heals nearby allies." if en else "定期治療附近的友軍。")
	if profile.sabotage_radius > 0: abilities.append("Charges, then briefly disables nearby towers." if en else "蓄力後短暫癱瘓附近防禦塔。")
	if profile.has_tag(&"flying"): abilities.append("Travels above the road; ground-only attacks cannot hit it." if en else "在道路上方飛行，僅限地面的攻擊無法命中。")
	return story+("\n\n"+"\n".join(abilities) if not abilities.is_empty() else "")
