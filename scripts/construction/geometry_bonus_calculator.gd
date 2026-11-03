extends RefCounted
const DIRS := [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]

static func evaluate(snapshot: Dictionary, definition: TowerDefinition, anchor: Vector2i, turns: int, rules: Resource) -> Dictionary:
	var result := {"range_extension":0,"damage_bonus":0.0,"messages":[],"qualifying_cells":[]}
	var ports := {}
	for i in snapshot.ports.size(): ports[Vector2i(snapshot.cells[2*i],snapshot.cells[2*i+1])] = int(snapshot.ports[i])
	if definition == rules.straight_tower:
		var direction := posmod(turns,4)
		var forward: Vector2i = DIRS[direction]
		var valid := true
		var qualifying: Array = []
		for step in range(1,int(rules.straight_length)+1):
			var cell := anchor+forward*step
			if not ports.has(cell):
				valid = false
				break
			if step > 1 and not connected(ports,cell-forward,direction):
				valid = false
				break
			qualifying.append(cell)
		if valid:
			result.range_extension = rules.range_extension
			result.messages.append("長直線：弩砲射程 +%d" % rules.range_extension)
			result.qualifying_cells = qualifying
	if definition == rules.junction_tower:
		for cell: Vector2i in ports:
			if Vector2(cell-anchor).length() > float(rules.junction_radius): continue
			var degree := 0
			for direction in 4:
				if connected(ports,cell,direction): degree += 1
			if degree >= 3:
				result.damage_bonus = rules.damage_bonus
				result.messages.append("交會：交叉火力傷害 +%d%%" % roundi(float(rules.damage_bonus)*100))
				result.qualifying_cells.append(cell)
				break
	return result

static func connected(ports: Dictionary, cell: Vector2i, direction: int) -> bool:
	return bool(int(ports.get(cell,0)) & (1<<direction)) and bool(int(ports.get(cell+DIRS[direction],0)) & (1<<((direction+2)%4)))

static func extend(cells: Array[Vector2i], anchor: Vector2i, turns: int, amount: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = cells.duplicate()
	if amount <= 0 or cells.is_empty(): return result
	var forward: Vector2i = DIRS[posmod(turns,4)]
	var furthest := -2147483648
	for cell in cells: furthest = maxi(furthest,(cell-anchor).x*forward.x+(cell-anchor).y*forward.y)
	for cell in cells:
		if (cell-anchor).x*forward.x+(cell-anchor).y*forward.y != furthest: continue
		for step in range(1,amount+1):
			var next := cell+forward*step
			if not next in result: result.append(next)
	return result
