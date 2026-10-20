extends RefCounted
## Bounded local sampling: O(N) work and memory even when one tile holds everyone.
## Positions/offsets are in tile coordinates; output is a render-only lateral shift.
var candidate_checks := 0
const EMPTY_BUCKET: Array = []

func solve(positions: PackedVector2Array, normals: PackedVector2Array, ids: PackedInt64Array, previous: PackedFloat32Array, ignored: PackedByteArray = PackedByteArray()) -> PackedFloat32Array:
	var count := positions.size()
	var result := previous.duplicate()
	result.resize(count)
	candidate_checks = 0
	var groups := {}
	for i in count:
		# Exclude from buckets as well as queries: neither member of a turning
		# pair should push the other, even if the other enemy is going straight.
		if not ignored.is_empty() and ignored[i]: continue
		var tile := Vector2i(positions[i].floor())
		if not groups.has(tile):
			groups[tile] = []
		groups[tile].append(i)
	var pushes := PackedFloat32Array()
	var contacts := PackedInt32Array()
	pushes.resize(count)
	contacts.resize(count)
	var spacing := EnemyRenderConstants.VISUAL_SPACING
	for iteration in EnemyRenderConstants.VISUAL_SEPARATION_ITERATIONS:
		pushes.fill(0.0)
		contacts.fill(0)
		var visited := {}
		for i in count:
			if not ignored.is_empty() and ignored[i]: continue
			var tile := Vector2i(positions[i].floor())
			for y in range(-1, 2):
				for x in range(-1, 2):
					var bucket: Array = groups.get(tile+Vector2i(x, y), EMPTY_BUCKET)
					if bucket.is_empty():
						continue
					var samples := mini(bucket.size(), EnemyRenderConstants.VISUAL_SAMPLES_PER_TILE)
					var first := posmod(ids[i]*17+x*7+y*13, bucket.size())
					var stride := maxi(1, bucket.size()/samples)
					for sample in samples:
						candidate_checks += 1
						var j: int = bucket[(first+sample*stride)%bucket.size()]
						if i == j:
							continue
						var key := Vector2i(mini(i, j), maxi(i, j))
						if visited.has(key):
							continue
						visited[key] = true
						# Stable IDs break coincident-position ties independently of slot order.
						var a := i if ids[i] < ids[j] else j
						var b := j if a == i else i
						var delta := positions[a]+normals[a]*result[a]-positions[b]-normals[b]*result[b]
						var distance_squared := delta.length_squared()
						if distance_squared >= spacing*spacing:
							continue
						var distance := sqrt(distance_squared)
						var axis := delta/distance if distance > 0.00001 else Vector2.ZERO
						var pa := axis.dot(normals[a])
						var pb := axis.dot(normals[b])
						var denominator := pa*pa+pb*pb
						var amount := spacing-distance
						if denominator < 0.1:
							axis = (normals[a]+normals[b]).normalized()
							if axis.is_zero_approx():
								axis = normals[a]
							axis *= -1.0 if (ids[a]+ids[b])%2 == 0 else 1.0
							var projected := delta.dot(axis)
							# Solve lateral clearance while leaving forward progress untouched.
							amount = sqrt(maxf(0.0, spacing*spacing-distance_squared+projected*projected))-projected
							pa = axis.dot(normals[a])
							pb = axis.dot(normals[b])
							denominator = pa*pa+pb*pb
						if denominator > 0.0001:
							pushes[a] += pa*amount/denominator
							pushes[b] -= pb*amount/denominator
							contacts[a] += 1
							contacts[b] += 1
		for i in count:
			if contacts[i] > 0:
				result[i] = clampf(result[i]+pushes[i]/contacts[i], -EnemyRenderConstants.VISUAL_MAX_OFFSET, EnemyRenderConstants.VISUAL_MAX_OFFSET)
	return result
