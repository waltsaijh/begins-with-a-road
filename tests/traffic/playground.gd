extends Node
const Fixture = preload("res://tests/traffic/fixture.gd")
func _ready() -> void:
	var level := Fixture.session()
	add_child(level)
	var shop: Node = level.get_node("CardPlacement/Shop")
	shop.coins = 100
	shop.available = shop._deal()
	shop._refresh()
	shop.view.set_available(true)
