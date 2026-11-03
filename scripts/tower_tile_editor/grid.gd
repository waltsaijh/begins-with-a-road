extends Control
signal edited(before: TilePreset)
signal hover_cell(cell: Vector2i)
var preset: TilePreset
var brush := 0
var cells := 11
var turns := 0
var manual := false
var port_mask := 15
var dragging := false
var before: TilePreset
var last := Vector2i(999,999)
var hovered := Vector2i.ZERO
const COLORS := [Color("5eaaae"),Color("d6bb79")]

func unit() -> float: return floorf(minf(size.x,size.y)/cells)
func origin() -> Vector2: return (size-Vector2.ONE*unit()*cells)*0.5
func center(cell: Vector2i) -> Vector2:
	return origin()+(Vector2(BuildCard.rotate_cell(cell,turns))+Vector2.ONE*(cells/2)+Vector2(0.5,0.5))*unit()
func at(point: Vector2) -> Vector2i:
	var drawn := Vector2i(((point-origin())/unit()).floor())-Vector2i.ONE*(cells/2)
	return BuildCard.rotate_cell(drawn,-turns)

func _gui_input(event: InputEvent) -> void:
	if preset == null: return
	if event is InputEventMouseMotion:
		hovered = at(event.position); hover_cell.emit(hovered)
		if dragging: paint(hovered)
		queue_redraw()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			before = preset.duplicate(true); dragging = true; last = Vector2i(999,999)
			paint(at(event.position))
		else: finish_stroke()
		accept_event()

func _input(event: InputEvent) -> void:
	if dragging and event is InputEventMouseButton and not event.pressed: finish_stroke()
	if dragging and event is InputEventKey and event.keycode == KEY_ESCAPE: finish_stroke()

func finish_stroke() -> void:
	if not dragging: return
	dragging = false
	edited.emit(before)

func paint(cell: Vector2i) -> void:
	if cell == last or absi(cell.x) > cells/2 or absi(cell.y) > cells/2: return
	if brush <= 2 and last.x != 999:
		var cursor := last
		while cursor != cell:
			if cursor.x != cell.x: cursor.x += signi(cell.x-cursor.x)
			else: cursor.y += signi(cell.y-cursor.y)
			_paint_cell(cursor)
	else: _paint_cell(cell)

func _paint_cell(cell: Vector2i) -> void:
	last = cell
	match brush:
		0:
			preset.road_offsets.erase(cell); preset.explicit_road_ports.erase(cell)
			if not cell in preset.tower_footprint: preset.tower_footprint.append(cell)
		1:
			preset.tower_footprint.erase(cell)
			if not cell in preset.road_offsets: preset.road_offsets.append(cell)
			if manual: _ports(cell,port_mask)
		2:
			preset.tower_footprint.erase(cell); preset.road_offsets.erase(cell); preset.explicit_road_ports.erase(cell)
		3: preset.tower_offset = cell
		4: if cell in preset.road_offsets and manual: _ports(cell,port_mask)
		5:
			var body: Array[Vector2i] = []; var roads: Array[Vector2i] = []; var ports: Dictionary[Vector2i,int] = {}
			for pos in preset.tower_footprint: body.append(pos-cell)
			for pos in preset.road_offsets: roads.append(pos-cell)
			for pos in preset.explicit_road_ports: ports[pos-cell] = preset.explicit_road_ports[pos]
			preset.tower_footprint = body; preset.road_offsets = roads; preset.explicit_road_ports = ports
			preset.tower_offset -= cell; preset.home_offset -= cell
			dragging = false; edited.emit(before)
		6: preset.home_offset = cell; preset.custom_home = true
	preset.occupied_offsets.clear()
	queue_redraw()

func _ports(cell: Vector2i, mask: int) -> void:
	preset.explicit_road_ports[cell] = mask
	var directions := [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]
	for i in 4:
		var neighbor: Vector2i = cell+directions[i]
		if not neighbor in preset.road_offsets: continue
		var reciprocal := 1<<((i+2)%4)
		var other: int = preset.explicit_road_ports.get(neighbor,15)
		preset.explicit_road_ports[neighbor] = (other | reciprocal) if mask & (1<<i) else (other & ~reciprocal)

func _draw() -> void:
	if preset == null or unit() <= 0: return
	var invalid := not preset.configuration_error().is_empty()
	var half := cells/2
	for y in range(-half,half+1):
		for x in range(-half,half+1):
			var cell := Vector2i(x,y)
			var point := center(cell)
			var rect := Rect2(point-Vector2.ONE*(unit()*0.5-1),Vector2.ONE*(unit()-2))
			var color := Color("263840")
			if cell in preset.tower_footprint: color = COLORS[0]
			elif cell in preset.road_offsets: color = COLORS[1]
			draw_rect(rect,color)
			if cell in preset.road_offsets:
				var mask: int = preset.explicit_road_ports.get(cell,15)
				for i in 4:
					if mask & (1<<i):
						var offset: Vector2i = [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT][i]
						var delta := Vector2(BuildCard.rotate_cell(offset,turns))
						var neighbor := cell+offset
						if neighbor in preset.road_offsets and int(preset.explicit_road_ports.get(neighbor,15)) & (1<<((i+2)%4)):
							draw_line(point,point+delta*unit()*0.5,Color("584a31"),3)
						elif manual:
							for part in [0.15,0.35]: draw_line(point+delta*unit()*part,point+delta*unit()*(part+0.08),Color("847758"),2)
			if cell == hovered: draw_rect(rect,Color.WHITE,false,2)
			if invalid and (cell in preset.tower_footprint or cell in preset.road_offsets): draw_rect(rect,Color("ef846c"),false,2)
	var zero := center(Vector2i.ZERO)
	draw_line(zero-Vector2(8,0),zero+Vector2(8,0),Color.WHITE,2)
	draw_line(zero-Vector2(0,8),zero+Vector2(0,8),Color.WHITE,2)
	var anchor := center(preset.tower_offset)
	draw_circle(anchor,7,Color("f5f3df") if preset.tower_offset in preset.tower_footprint else Color("ff685a"),false,2)
	var facing := Vector2(BuildCard.rotate_cell(Vector2i.UP,preset.facing_steps+turns))
	draw_line(anchor,anchor+facing*unit()*0.4,Color.WHITE,3)
	if preset.custom_home: draw_circle(center(preset.home_offset),6,Color("a4ed78"),false,3)
