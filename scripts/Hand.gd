extends Node2D

func add_card(card_node: Node2D) -> void:
	add_child(card_node)
	_arrange()

func _arrange() -> void:
	for i in range(get_child_count()):
		var c = get_child(i)
		c.position = Vector2(i * 80, 0)
