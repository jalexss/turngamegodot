@tool
extends Node2D

# Radio del arco donde se posicionan las cartas
@export var hand_radius: float = 400.0
# Ángulo total que ocupará el abanico de cartas
@export var spread_angle_degrees: float = 40.0

# Función para añadir una carta y reorganizar la mano
func add_card(card_node: Node2D) -> void:
	add_child(card_node)
	_arrange()

# Función para limpiar todas las cartas de la mano
func clear_cards() -> void:
	for card in get_children():
		card.queue_free()

# La lógica principal para organizar las cartas en un arco
func _arrange() -> void:
	var card_count = get_child_count()
	if card_count == 0:
		return

	var angle_step_rad: float
	var start_angle_rad: float
	var spread_angle_rad = deg_to_rad(spread_angle_degrees)

	if card_count == 1:
		angle_step_rad = 0
		start_angle_rad = -PI / 2 # Apuntando hacia abajo
	else:
		angle_step_rad = spread_angle_rad / (card_count - 1)
		start_angle_rad = -PI / 2 - spread_angle_rad / 2.0

	for i in range(card_count):
		var card = get_child(i) as Node2D
		var angle = start_angle_rad + i * angle_step_rad
		
		# Calcular posición en el arco
		var x = cos(angle) * hand_radius
		var y = sin(angle) * hand_radius
		card.position = Vector2(x, y)
		
		# Rotar la carta para que apunte hacia afuera
		card.rotation = angle + PI / 2

# Esto permite que los cambios en el editor se reflejen visualmente
func _notification(what: int) -> void:
	if Engine.is_editor_hint():
		if what == NOTIFICATION_CHILD_ORDER_CHANGED:
			_arrange()
