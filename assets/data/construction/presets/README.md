# Construction prototype presets

These resources are used only by the construction playground. Formal tower candidates and Frontier are unchanged.

All five presets use one tower at placement anchor `(0, 0)`, allow four clockwise quarter turns and provide exact road masks. `#` is a road, `T` is the tower, `.` is empty. Diagrams show the unrotated X/Z footprint; north is up.

| Resource | Stable ID | Roads / ground cells | Bounds |
|---|---|---:|---|
| straight.tres | construction.straight.v1 | 7 / 8 | X -3..3, Z -1..0 |
| corner.tres | construction.corner.v1 | 9 / 10 | X -2..2, Z -4..0 |
| tee.tres | construction.tee.v1 | 9 / 10 | X -3..3, Z -3..0 |
| cross.tres | construction.cross.v1 | 9 / 10 | X -1..3, Z -3..1 |
| pocket.tres | construction.pocket.v1 | 13 / 14 | X -3..3, Z -3..0 |

```text
straight           corner          tee            cross        pocket
#######             #####          ...#...        ..#..        #######
...T...             #....          ...#...        ..#..        #.....#
                    #....          #######        #####        #.....#
                    #....          ...T...        .T#..        #..T..#
                    #.T..
                                                  ..#..
```

Each resource's `road_offsets` is the road set, `occupied_offsets` is its complete ground set, and `explicit_road_ports` uses N/E/S/W bits 1/2/4/8. Roads and tower footprints must not overlap. Non-road ground has no road ports. Ports facing empty space declare permitted future attachment; the runtime draws only actual reciprocal connections. The same cell can merge road masks with bitwise OR, but neighboring cells connect only when both ports agree.

All preset towers are at offset zero for easy pointing. `BuildCard.tower_anchor(anchor, turns)` also supports a nonzero authored offset; tower models, occupancy and attack previews must use that resolved position. `ground_cells`, `tower_cells`, `road_cells` and `road_ports` return world grid coordinates and rotate around the recipe anchor. `allows_rotation` gates legal turns.

Legacy resources without `explicit_road_ports` retain automatic adjacent-road behavior, inferred tower ground and four legal rotations. Their file path supplies the fallback stable identity, so no old resource migration is needed. Old road offsets overlapping tower ground remain valid only in legacy mode.

## Deterministic two-card construction case

Begin with a horizontal road from `(-7, 0)` to `(7, 0)`. Endpoints are at the extremes.

1. Stage `corner.tres` at `(-2, 0)`, turn 0. Its tower blocks the old road; its roads run from `(-4, 0)` north to `(-4, -4)`, then east to `(0, -4)`. This intermediate state is disconnected.
2. Stage another `corner.tres` at `(1, -2)`, turn 1. Its tower is inside the new pocket; its roads run from `(1, -4)` east to `(5, -4)`, then south to `(5, 0)`.
3. The first card's east port and second card's west port meet between `(0, -4)` and `(1, -4)`. The combined road reconnects the initial road at X -4 and 5. Both towers are distinct and clear of every road.

This is a final-connectivity case: individual immediate placement rejects card 1; staging both can produce one valid commit. Route generation, history and atomicity are tested by the construction integration suite; `tests/construction/shapes.tscn` verifies the authored geometry, rotation, compatibility and resource roundtrip only.

The U (`pocket`) has a six-cell span and three-cell depth. At anchor zero its lower ends overlap the initial straight at `(-3, 0)` and `(3, 0)`, allowing a single compound card to form a complete bypass around its central tower.
