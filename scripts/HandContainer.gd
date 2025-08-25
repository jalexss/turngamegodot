extends Node2D
class_name HandContainer

# --- CONFIGURACIÓN DE LA MANO ---
var hand_radius: float = 150.0     # Radio base de la semi-esfera
var max_spread_angle: float = 120.0 # Ángulo máximo total
var base_y_position: float = 0.0   # Posición Y base
var min_card_separation: float = 25.0  # Separación mínima entre cartas (en grados)
var max_cards_optimal: int = 7     # Cantidad óptima máxima para buena visibilidad

# --- VARIABLES INTERNAS ---
var card_original_scales: Dictionary = {}
var card_original_z_indices: Dictionary = {}  # Para recordar z-index original
var focused_card: Node2D = null
var focus_tween: Tween = null

func _ready() -> void:
	print("DEBUG: HandContainer._ready() - Posición: ", global_position)

# --- FUNCIONES PÚBLICAS ---
func add_card(card: Node2D) -> void:
	print("DEBUG: HandContainer.add_card() - Carta: ", card)
	if not card:
		print("DEBUG: ERROR - carta es null")
		return
	
	# Configurar propiedades básicas
	card.visible = true
	card.modulate = Color.WHITE
	card.scale = Vector2(0.8, 0.8)  # Escala fija más pequeña
	
	# Guardar escala original
	card_original_scales[card] = card.scale
	
	# Añadir al contenedor
	add_child(card)
	print("DEBUG: Carta añadida. Total: ", get_child_count())
	
	# Reorganizar cartas en semi-esfera (diferido para asegurar inicialización completa)
	call_deferred("_arrange_cards_in_hemisphere")

func clear_cards() -> void:
	print("DEBUG: Limpiando cartas...")
	for child in get_children():
		child.queue_free()
	card_original_scales.clear()
	card_original_z_indices.clear()

func get_card_count() -> int:
	return get_child_count()

# --- POSICIONAMIENTO EN SEMI-ESFERA ---
func _arrange_cards_in_hemisphere() -> void:
	var card_count = get_child_count()
	print("DEBUG: Organizando ", card_count, " cartas en semi-esfera")
	
	if card_count == 0:
		return
	
	# Calcular ángulos para distribución inteligente
	var angle_step: float = 0.0
	var start_angle: float = 0.0
	var current_radius: float = hand_radius
	
	if card_count == 1:
		# Una sola carta en el centro
		start_angle = 0.0
		angle_step = 0.0
	else:
		# Calcular separación óptima
		var desired_separation = max(min_card_separation, 120.0 / card_count)
		var total_spread = (card_count - 1) * desired_separation
		
		# Ajustar si excede el máximo
		if total_spread > max_spread_angle:
			total_spread = max_spread_angle
			desired_separation = total_spread / (card_count - 1)
		
		# Si hay muchas cartas, aumentar el radio para mejor visibilidad
		if card_count > max_cards_optimal:
			current_radius = hand_radius * (1.0 + (card_count - max_cards_optimal) * 0.1)
		
		angle_step = desired_separation
		start_angle = -total_spread / 2.0
		
		print("DEBUG: ", card_count, " cartas - Separación: ", desired_separation, "° - Radio: ", current_radius)
	
	# Posicionar cada carta
	var cards = get_children()
	for i in range(card_count):
		var card = cards[i] as Node2D
		if not card:
			continue
			
		var angle_rad = deg_to_rad(start_angle + i * angle_step)
		
		# Calcular posición en la semi-esfera
		var x_offset = sin(angle_rad) * current_radius
		var y_offset = -cos(angle_rad) * current_radius * 0.2  # Factor 0.2 para curva sutil
		
		var target_position = Vector2(x_offset, y_offset + base_y_position)
		
		# Animar carta a nueva posición
		var tween = create_tween()
		tween.tween_property(card, "position", target_position, 0.3)
		
		# Rotar ligeramente siguiendo la curvatura
		var rotation_angle = angle_rad * 0.3  # Rotación más sutil
		tween.parallel().tween_property(card, "rotation", rotation_angle, 0.3)
		
		# Escala con efecto de profundidad sutil
		var scale_factor = 0.75 + (cos(angle_rad) * 0.05)  # Variación mínima de escala
		var final_scale = Vector2(scale_factor, scale_factor)
		tween.parallel().tween_property(card, "scale", final_scale, 0.3)
		
		# Guardar escala original para hover
		card_original_scales[card] = final_scale
		
		# Z-index realista: cartas de izquierda a derecha se superponen naturalmente
		# La carta más a la izquierda (índice 0) está abajo, la más a la derecha (último índice) está arriba
		var original_z = 100 + i
		card.z_index = original_z
		card_original_z_indices[card] = original_z  # Guardar z-index original
		
		print("DEBUG: Carta ", i, " - posición: ", target_position, " rotación: ", rotation_angle, " escala: ", final_scale)

# --- FUNCIONES DE UTILIDAD ---
func get_card_at_position(global_pos: Vector2) -> Node2D:
	"""Obtiene la carta con mayor z-index en la posición dada"""
	var top_card: Node2D = null
	var highest_z_index: int = -999999
	
	for card in get_children():
		if card is Node2D and card.visible:
			# Convertir a posición local del HandContainer
			var local_pos = to_local(global_pos)
			
			# Calcular área de la carta considerando rotación
			var card_size = Vector2(200, 280) * card.scale
			var card_rect = Rect2(
				card.position - card_size / 2.0,
				card_size
			)
			
			# Para cartas rotadas, usar un área un poco más grande para facilitar el hover
			card_rect = card_rect.grow(20)
			
			if card_rect.has_point(local_pos) and card.z_index > highest_z_index:
				top_card = card
				highest_z_index = card.z_index
	
	return top_card

func get_original_scale(card: Node2D) -> Vector2:
	return card_original_scales.get(card, Vector2(0.8, 0.8))

# --- SISTEMA DE FOCUS ---
func focus_card(card: Node2D) -> void:
	"""Hace focus en una carta, mostrándola más grande y centrada"""
	if focused_card == card:
		return  # Ya está enfocada
	
	# Deshacer focus anterior
	if focused_card:
		unfocus_card()
	
	focused_card = card
	if not focused_card:
		return
	
	print("DEBUG: Haciendo focus en carta: ", card)
	
	# Cancelar tween anterior si existe
	if focus_tween:
		focus_tween.kill()
	
	focus_tween = create_tween()
	focus_tween.set_parallel(true)
	
	# Calcular posición central del viewport
	var viewport_size = get_viewport().get_visible_rect().size
	var viewport_center_y = viewport_size.y / 2.0
	
	# Calcular posición Y relativa al HandContainer
	# HandContainer está en global_position, queremos que la carta vaya al centro del viewport
	var hand_global_y = global_position.y
	var target_global_y = viewport_center_y
	var relative_y = target_global_y - hand_global_y
	
	# Ajustar ligeramente hacia arriba para mejor visibilidad
	var focus_position = Vector2(0, relative_y - 50)  # Centrado en Y del viewport, ligeramente arriba
	var focus_scale = Vector2(1.3, 1.3)   # Un poco más grande para mejor visibilidad
	var focus_rotation = 0.0               # Sin rotación
	
	print("DEBUG: Focus - Viewport Y: ", viewport_center_y, " HandContainer Y: ", hand_global_y, " Relativo Y: ", relative_y, " Posición focus: ", focus_position)
	
	# Animar transformaciones
	focus_tween.tween_property(card, "position", focus_position, 0.4)
	focus_tween.tween_property(card, "scale", focus_scale, 0.4)
	focus_tween.tween_property(card, "rotation", focus_rotation, 0.4)
	focus_tween.tween_property(card, "modulate", Color(1.15, 1.15, 1.05), 0.4)  # Más brillo
	
	# Traer al frente
	card.z_index = 1000
	
	# Opcional: Añadir un efecto de sombra/glow sutil
	# (Esto se podría implementar más adelante con un shader o nodo adicional)

func unfocus_card() -> void:
	"""Quita el focus de la carta actual"""
	if not focused_card:
		return
	
	print("DEBUG: Quitando focus de carta")
	
	# Cancelar tween si existe
	if focus_tween:
		focus_tween.kill()
	
	# Restaurar carta a su posición original
	var _card = focused_card  # Variable no usada pero necesaria para el flujo
	focused_card = null
	
	# Reorganizar todas las cartas para restaurar posiciones
	_arrange_cards_in_hemisphere()

func get_focused_card() -> Node2D:
	"""Retorna la carta actualmente enfocada"""
	return focused_card

func is_card_focused(card: Node2D) -> bool:
	"""Verifica si una carta está enfocada"""
	return focused_card == card

# --- SISTEMA DE HOVER MEJORADO ---
func apply_hover_effect(card: Node2D, is_hovered: bool) -> void:
	"""Aplica efecto de hover manteniendo el z-index natural"""
	if not card or is_card_focused(card):
		return
	
	var original_scale = get_original_scale(card)
	var original_z = card_original_z_indices.get(card, card.z_index)
	
	if is_hovered:
		# Elevar temporalmente por encima de todas las cartas
		var hover_z = 500  # Z-index temporal para hover
		var hover_scale = original_scale * 1.1
		
		var tween = create_tween().set_parallel()
		tween.tween_property(card, "scale", hover_scale, 0.15)
		tween.tween_property(card, "modulate", Color(1.1, 1.1, 1.0), 0.15)
		card.z_index = hover_z
	else:
		# Restaurar a valores originales
		var tween = create_tween().set_parallel()
		tween.tween_property(card, "scale", original_scale, 0.15)
		tween.tween_property(card, "modulate", Color.WHITE, 0.15)
		card.z_index = original_z  # Restaurar z-index original

func get_original_z_index(card: Node2D) -> int:
	"""Obtiene el z-index original de una carta"""
	return card_original_z_indices.get(card, 100)
