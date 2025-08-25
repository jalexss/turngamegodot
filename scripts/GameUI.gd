extends Control

# No necesitamos importar HandContainer ya que es una clase global

# --- NODOS DE LA ESCENA ---
# NOTA: Estas rutas asumen que los nodos son hijos directos de GameUi
@onready var player_slots_container = $PlayerChars as HBoxContainer
@onready var enemy_slots_container  = $EnemyChars as HBoxContainer
@onready var hand_container = $HandContainer as HandContainer
@onready var test_button = $TestButton as Button

# --- VARIABLES DE ESTADO ---
var player_slots_nodes: Array = []
var enemy_slots_nodes: Array = []
var hovered_card: Node2D = null
var last_hovered_card: Node2D = null

# Configuración de la mano
const MAX_HAND_SIZE: int = 8  # Reducido para mejor visibilidad

const CharacterSlotScene = preload("res://scenes/ui_elements/CharacterSlot.tscn")

# --- FUNCIONES DEL MOTOR ---
func _ready() -> void:
	# Crear nodos faltantes automáticamente
	_create_missing_nodes()
	
	# Inicializar slots de personajes
	_initialize_character_slots(player_slots_container, player_slots_nodes, 3)
	_initialize_character_slots(enemy_slots_container, enemy_slots_nodes, 5)
	
	# Configurar botón de pruebas
	if test_button:
		test_button.pressed.connect(_on_test_button_pressed)
		test_button.text = "Añadir Carta (Test)"

func _create_missing_nodes() -> void:
	# Crear HandContainer si no existe
	if not hand_container:
		print("DEBUG: Creando HandContainer automáticamente...")
		var new_hand_container = preload("res://scripts/HandContainer.gd").new()
		new_hand_container.name = "HandContainer"
		new_hand_container.position = Vector2(960, 700)  # Posición visible
		add_child(new_hand_container)
		hand_container = new_hand_container
		print("DEBUG: HandContainer creado en posición global: ", hand_container.global_position)
	
	# Crear TestButton si no existe
	if not test_button:
		print("DEBUG: Creando TestButton automáticamente...")
		var new_button = Button.new()
		new_button.name = "TestButton"
		new_button.text = "Añadir Carta (Test)"
		new_button.position = Vector2(50, 50)
		new_button.size = Vector2(200, 60)  # Más grande para ser más visible
		add_child(new_button)
		test_button = new_button
		# Conectar la señal aquí también
		test_button.pressed.connect(_on_test_button_pressed)
		print("DEBUG: TestButton creado y conectado")

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_handle_mouse_motion(event.global_position)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_mouse_click(event.global_position)

# --- MANEJO DE INPUT Y HOVER ---
func _handle_mouse_motion(mouse_pos: Vector2) -> void:
	var current_top_card = _get_top_card_at_position(mouse_pos)
	
	if current_top_card != last_hovered_card:
		if last_hovered_card:
			_apply_hover_effect(last_hovered_card, false)
		
		if current_top_card:
			_apply_hover_effect(current_top_card, true)
		
		last_hovered_card = current_top_card

func _handle_mouse_click(mouse_pos: Vector2) -> void:
	var clicked_card = _get_top_card_at_position(mouse_pos)
	if clicked_card and hand_container:
		if hand_container.is_card_focused(clicked_card):
			# Si ya está enfocada, quitar focus
			hand_container.unfocus_card()
			print("Focus removido de carta: ", clicked_card.data.name if clicked_card.data else "Sin datos")
		else:
			# Hacer focus en la carta
			hand_container.focus_card(clicked_card)
			print("Focus en carta: ", clicked_card.data.name if clicked_card.data else "Sin datos")

# --- GESTIÓN DE LA MANO (DELEGADA) ---
func clear_hand() -> void:
	if not hand_container:
		print("Warning: HandContainer no encontrado. Asegúrate de añadir el nodo HandContainer a GameUI.tscn")
		return
	hand_container.clear_cards()
	hovered_card = null
	last_hovered_card = null

func add_card_to_hand(card: Node2D) -> void:
	print("DEBUG: GameUI.add_card_to_hand() llamado con carta: ", card)
	if not hand_container:
		print("ERROR: HandContainer no encontrado. No se puede añadir carta.")
		card.queue_free()
		return
	
	print("DEBUG: HandContainer encontrado: ", hand_container)
		
	# Verificar límite máximo de cartas
	if get_hand_size() >= MAX_HAND_SIZE:
		print("¡Mano llena! Máximo ", MAX_HAND_SIZE, " cartas permitidas.")
		card.queue_free()  # Eliminar la carta si no se puede añadir
		return
	
	print("DEBUG: Enviando carta a HandContainer...")
	hand_container.add_card(card)
	print("DEBUG: Carta añadida. Cartas en mano: ", get_hand_size(), "/", MAX_HAND_SIZE)

func get_hand_size() -> int:
	if not hand_container:
		return 0
	return hand_container.get_card_count()

# --- FUNCIÓN DE PRUEBAS ---
func _on_test_button_pressed() -> void:
	print("DEBUG: Botón de test presionado!")
	print("DEBUG: Cartas actuales en mano: ", get_hand_size(), "/", MAX_HAND_SIZE)
	
	# Verificar si ya está llena la mano
	if get_hand_size() >= MAX_HAND_SIZE:
		print("DEBUG: Mano llena, no se puede añadir más cartas")
		return
	
	# Crear una carta de prueba aleatoria
	var game_node = get_parent()
	if game_node and game_node.has_method("_create_test_card"):
		print("DEBUG: Creando carta de test...")
		var test_card = game_node._create_test_card()
		if test_card:
			print("DEBUG: Carta de test creada exitosamente")
			add_card_to_hand(test_card)
		else:
			print("DEBUG: ERROR - No se pudo crear carta de test")
	else:
		print("DEBUG: ERROR - No se encontró el método _create_test_card en el nodo padre")

# --- LÓGICA DE HOVER ---
func _get_top_card_at_position(global_pos: Vector2) -> Node2D:
	if not hand_container:
		return null
	return hand_container.get_card_at_position(global_pos)

func _apply_hover_effect(card: Node2D, is_hovered: bool) -> void:
	if not card or not hand_container: 
		return
	
	# Delegar el hover al HandContainer que maneja el z-index correctamente
	hand_container.apply_hover_effect(card, is_hovered)

# --- OTRAS FUNCIONES DE UI ---
func _initialize_character_slots(container: HBoxContainer, slots_array: Array, count: int):
	for child in container.get_children(): child.queue_free()
	slots_array.clear()
	for i in range(count):
		var slot_instance = CharacterSlotScene.instantiate()

		# Conectar la señal del slot a una función del nodo Game
		# Asumimos que GameUI es hijo de Game
		var game_node = get_parent()
		if game_node and game_node.has_method("_on_character_selected"):
			slot_instance.character_clicked.connect(game_node._on_character_selected)

		container.add_child(slot_instance)
		slots_array.append(slot_instance)
		slot_instance.visible = false

# Estas funciones ahora no hacen nada, ya que no tenemos los labels de Turno/Energía
# en esta versión simplificada. Puedes volver a añadirlos si lo necesitas.
func set_turn(_turn_num: int):
	pass # print("Turno: ", _turn_num)

func set_energy(_energy: int):
	pass # print("Energía: ", _energy)

func update_player_chars(chars_data: Array):
	_update_character_slots(player_slots_nodes, chars_data)

func update_enemy_chars(chars_data: Array):
	_update_character_slots(enemy_slots_nodes, chars_data)

func _update_character_slots(slots: Array, data: Array):
	for i in range(slots.size()):
		var slot_node = slots[i]
		if i < data.size():
			var d = data[i]
			slot_node.visible = true
			if slot_node.has_method("set_character_data"):
				slot_node.set_character_data(d)
		else:
			slot_node.visible = false
