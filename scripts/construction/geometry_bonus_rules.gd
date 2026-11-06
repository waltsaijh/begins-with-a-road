extends Resource
## Only the construction playground installs these two non-stacking bonuses.
@export var straight_tower: TowerDefinition
@export_range(2,20,1) var straight_length := 5
@export_range(0,3,1) var range_extension := 1
@export var junction_tower: TowerDefinition
@export_range(0,5,0.5) var junction_radius := 2.0
@export_range(0,0.3,0.01) var damage_bonus := 0.1
