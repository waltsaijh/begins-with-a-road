extends RefCounted
## Shelf packing keeps pixel coordinates stable when the texture grows.
var image := Image.create_empty(128, 128, false, Image.FORMAT_RGBA8)
var texture := ImageTexture.create_from_image(image)
var white: Rect2
var _cursor := Vector2i(1, 1)
var _row_height := 0
var _dirty := false
var _icons := {}
var _base: Image
var _base_cursor: Vector2i
var _base_row_height: int

func _init() -> void:
	var pixel := Image.create_empty(1, 1, false, Image.FORMAT_RGBA8)
	pixel.fill(Color.WHITE)
	white = add_image(pixel)

func add_image(source: Image) -> Rect2:
	var size := source.get_size()
	if size.x+2 > image.get_width(): _grow(maxi(size.x+2, image.get_height()))
	if _cursor.x+size.x+1 > image.get_width():
		_cursor = Vector2i(1, _cursor.y+_row_height+2)
		_row_height = 0
	if _cursor.y+size.y+1 > image.get_height(): _grow(_cursor.y+size.y+1)
	image.blit_rect(source, Rect2i(Vector2i.ZERO, size), _cursor)
	# Extrude edges so linear filtering never samples an adjacent sprite.
	image.blit_rect(source, Rect2i(0, 0, size.x, 1), _cursor-Vector2i(0, 1))
	image.blit_rect(source, Rect2i(0, size.y-1, size.x, 1), _cursor+Vector2i(0, size.y))
	image.blit_rect(source, Rect2i(0, 0, 1, size.y), _cursor-Vector2i(1, 0))
	image.blit_rect(source, Rect2i(size.x-1, 0, 1, size.y), _cursor+Vector2i(size.x, 0))
	image.set_pixelv(_cursor-Vector2i.ONE, source.get_pixel(0, 0))
	image.set_pixelv(_cursor+Vector2i(size.x, -1), source.get_pixel(size.x-1, 0))
	image.set_pixelv(_cursor+Vector2i(-1, size.y), source.get_pixel(0, size.y-1))
	image.set_pixelv(_cursor+size, source.get_pixel(size.x-1, size.y-1))
	var region := Rect2(_cursor, size)
	_cursor.x += size.x+2
	_row_height = maxi(_row_height, size.y)
	_dirty = true
	return region

func icon(source: Texture2D) -> Rect2:
	if _icons.has(source): return _icons[source]
	var pixels := source.get_image()
	if pixels == null or pixels.is_empty(): return Rect2()
	if pixels.is_compressed(): pixels.decompress()
	pixels.convert(Image.FORMAT_RGBA8)
	var region := add_image(pixels)
	_icons[source] = region
	return region

func upload() -> void:
	if not _dirty: return
	if texture.get_size() == Vector2(image.get_size()): texture.update(image)
	else: texture.set_image(image)
	_dirty = false

func seal() -> void:
	_base = image.duplicate()
	_base_cursor = _cursor
	_base_row_height = _row_height

func clear_icons() -> void:
	if _icons.is_empty() or _base == null: return
	_icons.clear()
	image = _base.duplicate()
	_cursor = _base_cursor
	_row_height = _base_row_height
	_dirty = true

func _grow(required: int) -> void:
	var side := image.get_width()
	while side < required: side *= 2
	var larger := Image.create_empty(side, side, false, Image.FORMAT_RGBA8)
	larger.blit_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), Vector2i.ZERO)
	image = larger
