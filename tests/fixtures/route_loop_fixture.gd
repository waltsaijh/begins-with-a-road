extends RefCounted
## 32x32 synthetic rooms, narrow connections and obstacles; no authored map edits.
static func cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y in 32:
		for x in 32:
			if x in [7, 15, 23] and y%8 != 3: continue
			if y in [7, 15, 23] and x%8 != 3: continue
			if x%8 in [4, 5] and y%8 in [4, 5]: continue
			result.append(Vector2i(x, y))
	return result
