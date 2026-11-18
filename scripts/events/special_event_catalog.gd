@tool
class_name SpecialEventCatalog
extends Resource
@export var entries: Array[SpecialEventDefinition] = []
@export_range(2,32,1) var road_margin := 8
@export_range(100,50000,100) var road_search_limit := 12000
