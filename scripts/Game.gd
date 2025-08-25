extends Node2D

const ENEMY_DECKS_PATH = "res://data/enemy_decks.json"
const PLAYER_DECK_PATH = "res://data/player_deck.json"

# Opciones de deck para el jugador
@export_enum("Automático", "Balanceado", "Agresivo", "Defensivo", "Inicial") var player_deck_type: int = 0
@export var testing_deck_id: int = -1  # si > 0 fuerza ese deck en vez de random
@onready var deck = $Deck
@onready var ui   = $GameUI as Control

var turn_num := 0
var energy   := 0
var player_chars : Array = []
var enemy_chars  : Array = []
var char_defs    : Dictionary = {}
var enemy_defs   : Dictionary = {}

func _ready() -> void:
	# randomize() # Descomenta si necesitas inicializar la semilla aleatoria aquí
	# cargar personajes y generar roster...
	char_defs  = _load_char_defs("res://data/characters.json")
	enemy_defs = _load_char_defs("res://data/enemys.json") # Asegúrate que este JSON y su carga funcionen bien
	player_chars = _generate_roster(char_defs, 1, 3)
	enemy_chars  = _generate_roster(enemy_defs, 1, 5) # Ajusta el rango según tus necesidades

	# Cargar deck del jugador
	print("DEBUG: Cargando deck del jugador...")
	var player_card_ids: Array = _get_player_deck()
	print("DEBUG: IDs de cartas obtenidos: ", player_card_ids)
	if player_card_ids.is_empty():
		push_error("Game.gd: No se pudo cargar el deck del jugador.")
		deck.load_deck_from_ids([])
	else:
		print("DEBUG: Cargando ", player_card_ids.size(), " cartas en el deck...")
		deck.load_deck_from_ids(player_card_ids)
		print("DEBUG: Deck cargado exitosamente")
	
	_start_turn()

func _start_turn() -> void:
	turn_num += 1
	energy = 3
	print("=== DEBUG: Iniciando turno ", turn_num, " ===")
	ui.set_turn(turn_num)
	ui.set_energy(energy)
	ui.clear_hand()
	ui.update_player_chars(player_chars)
	ui.update_enemy_chars(enemy_chars)
	print("DEBUG: Intentando robar 4 cartas...")
	for i in range(4):
		print("DEBUG: Robando carta ", i + 1, "/4")
		_draw_and_show()

func _draw_and_show() -> void:
	var cd = deck.draw()
	if cd:
		print("DEBUG: Creando carta: ID=", cd.id, " Nombre=", cd.name)
		var card = preload("res://scenes/Card.tscn").instantiate() as Node2D
		card.set_data(cd)
		ui.add_card_to_hand(card)
		print("DEBUG: Carta añadida exitosamente")
	else:
		print("DEBUG: ERROR - No hay cartas en el deck")

# --- FUNCIÓN DE PRUEBAS ---
func _create_test_card(create_damage_ally_card: bool = false, create_super_damage_card: bool = false, create_super_heal_card: bool = false) -> Node2D:
	print("DEBUG: _create_test_card() llamado - Aliados: ", create_damage_ally_card, " Súper daño: ", create_super_damage_card, " Súper curación: ", create_super_heal_card)
	
	if create_super_heal_card:
		# Crear carta súper curación
		return _create_super_heal_card()
	elif create_super_damage_card:
		# Crear carta súper poderosa
		return _create_super_damage_card()
	elif create_damage_ally_card:
		# Crear carta especial que daña aliados
		return _create_special_damage_ally_card()
	
	# Crear carta normal
	var player_cards = _get_player_available_cards()
	print("DEBUG: Cartas disponibles para test: ", player_cards.size())
	
	if player_cards.is_empty():
		print("DEBUG: ERROR - No hay cartas disponibles para crear carta de prueba")
		return null
	
	# Seleccionar ID aleatorio
	var random_id = player_cards[randi() % player_cards.size()]
	print("DEBUG: ID seleccionado para test: ", random_id, " (tipo: ", typeof(random_id), ")")
	
	# Convertir a int si es necesario
	var card_id = int(random_id)
	print("DEBUG: ID convertido a int: ", card_id)
	print("DEBUG: Claves disponibles en all_card_definitions: ", deck.all_card_definitions.keys())
	
	# Crear CardData desde las definiciones cargadas
	if deck.all_card_definitions.has(card_id):
		var card_data = deck.all_card_definitions[card_id]
		print("DEBUG: Datos de carta encontrados: ", card_data.name)
		var card = preload("res://scenes/Card.tscn").instantiate() as Node2D
		card.set_data(card_data)
		print("DEBUG: Carta de test creada exitosamente")
		return card
	
	print("DEBUG: ERROR - No se pudo encontrar definición para carta ID: ", card_id)
	print("DEBUG: Intentando buscar con ID original: ", random_id)
	if deck.all_card_definitions.has(random_id):
		var card_data = deck.all_card_definitions[random_id]
		print("DEBUG: Encontrado con ID original!")
		var card = preload("res://scenes/Card.tscn").instantiate() as Node2D
		card.set_data(card_data)
		return card
	
	return null

func _create_special_damage_ally_card() -> Node2D:
	"""Crea una carta especial que puede dañar aliados"""
	print("DEBUG: Creando carta especial de daño a aliados")
	
	# Crear CardData personalizada
	var special_card_data = preload("res://scripts/CardData.gd").new()
	special_card_data.id = 999  # ID especial
	special_card_data.name = "Daño Aliado (TEST)"
	special_card_data.cost = 1
	special_card_data.description = "CARTA DE PRUEBA: Inflige 3 de daño a un aliado."
	special_card_data.card_type = CardData.CardType.ATTACK
	special_card_data.power = 3
	
	# Crear Array tipado correctamente para effects
	var effects_array: Array[Dictionary] = []
	effects_array.append({"type": "DAMAGE", "value": 5})  # Daño más alto para testing
	special_card_data.effects = effects_array
	
	print("DEBUG: Carta especial - Effects creados: ", effects_array)
	
	# Crear la carta visual
	var card = preload("res://scenes/Card.tscn").instantiate() as Node2D
	card.set_data(special_card_data)
	
	print("DEBUG: Carta especial creada: ", special_card_data.name)
	return card

func _create_super_damage_card() -> Node2D:
	"""Crea una carta súper poderosa para testing"""
	print("DEBUG: Creando carta súper poderosa")
	
	# Crear CardData personalizada
	var super_card_data = preload("res://scripts/CardData.gd").new()
	super_card_data.id = 998  # ID especial
	super_card_data.name = "MEGA DAÑO (TEST)"
	super_card_data.cost = 2
	super_card_data.description = "CARTA DE PRUEBA: Inflige 15 de daño puro (ignora defensa)."
	super_card_data.card_type = CardData.CardType.ATTACK
	super_card_data.power = 15
	
	# Crear Array tipado correctamente para effects
	var effects_array: Array[Dictionary] = []
	effects_array.append({"type": "DAMAGE", "value": 15})  # Daño masivo
	super_card_data.effects = effects_array
	
	print("DEBUG: Carta súper - Effects creados: ", effects_array)
	
	# Crear la carta visual
	var card = preload("res://scenes/Card.tscn").instantiate() as Node2D
	card.set_data(super_card_data)
	
	print("DEBUG: Carta súper creada: ", super_card_data.name)
	return card

func _create_super_heal_card() -> Node2D:
	"""Crea una carta súper curación para testing"""
	print("DEBUG: Creando carta súper curación")
	
	# Crear CardData personalizada
	var super_heal_data = preload("res://scripts/CardData.gd").new()
	super_heal_data.id = 997  # ID especial
	super_heal_data.name = "MEGA CURACIÓN (TEST)"
	super_heal_data.cost = 2
	super_heal_data.description = "CARTA DE PRUEBA: Cura 20 HP a un aliado."
	super_heal_data.card_type = CardData.CardType.HEAL
	super_heal_data.power = 20
	
	# Crear Array tipado correctamente para effects
	var effects_array: Array[Dictionary] = []
	effects_array.append({"type": "HEAL", "value": 20})  # Curación masiva
	super_heal_data.effects = effects_array
	
	print("DEBUG: Carta súper curación - Effects creados: ", effects_array)
	
	# Crear la carta visual
	var card = preload("res://scenes/Card.tscn").instantiate() as Node2D
	card.set_data(super_heal_data)
	
	print("DEBUG: Carta súper curación creada: ", super_heal_data.name)
	return card

# Métodos auxiliares para personajes/enemigos
func _load_char_defs(path: String) -> Dictionary:
	var data_list = _load_json(path) # Esto devolverá un Array o []
	var definitions := {}

	if not data_list is Array:
		push_error("Se esperaba un Array para las definiciones de personajes en %s, se obtuvo %s" % [path, typeof(data_list)])
		return definitions

	for char_data_item in data_list:
		if not char_data_item is Dictionary:
			push_warning("Elemento no es un diccionario en %s, omitiendo: %s" % [path, str(char_data_item)])
			continue
		if not char_data_item.has("id"):
			push_warning("Elemento sin 'id' en %s, omitiendo: %s" % [path, str(char_data_item)])
			continue
			
		var c = preload("res://scripts/CharacterData.gd").new()
		c.id       = char_data_item.get("id", -1) # Usar .get para seguridad
		c.name     = char_data_item.get("name", "N/A")
		var portrait_path = char_data_item.get("portrait", "")
		if not portrait_path.is_empty():
			c.portrait = load(portrait_path)
			if c.portrait == null:
				push_warning("No se pudo cargar el retrato: %s para ID %s" % [portrait_path, c.id])
		c.hp       = char_data_item.get("hp", 10)
		c.max_hp   = char_data_item.get("max_hp", c.hp)
		c.attack   = char_data_item.get("attack", 1)
		c.defense  = char_data_item.get("defense", 0)
		definitions[c.id] = c
	return definitions
	
func _load_json(path: String) -> Variant:
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("No se pudo abrir el archivo: " + path)
		return [] # Devolver un array vacío para consistencia en caso de error
	var text = file.get_as_text()
	file.close()

	# Es buena práctica verificar si el texto está vacío antes de intentar parsear
	if text.strip_edges().is_empty():
		push_error("Error parseando JSON: El archivo está vacío o solo contiene espacios en blanco: %s" % path)
		return []

	var result = JSON.parse_string(text)

	# Si JSON.parse_string devuelve null en caso de error de parseo:
	if result == null:
		push_error("Error al parsear JSON desde %s (posiblemente contenido inválido)." % path)
		return [] 

	if not (result is Array or result is Dictionary):
		push_error("El contenido parseado de %s no es un Array o Dictionary, sino %s." % [path, typeof(result)])
		return []
		
	return result


func _load_enemy_decks(path: String) -> Array:
	var decks_data = _load_json(path) # _load_json devuelve un Array (de tu JSON) o []

	if not decks_data is Array:
		push_error("Se esperaba un Array de mazos desde %s, pero se obtuvo %s." % [path, typeof(decks_data)])
		return []

	# Opcional: Validación adicional para cada elemento del mazo
	var validated_decks: Array = []
	for deck_item in decks_data:
		if deck_item is Dictionary and deck_item.has("id") and deck_item.has("deck") and deck_item.deck is Array:
			validated_decks.append(deck_item)
		else:
			push_warning("Elemento de mazo inválido encontrado en %s: %s. Omitiendo." % [path, str(deck_item)])
	return validated_decks

func _generate_roster(defs: Dictionary, min_count: int, max_count: int) -> Array:
	if defs.is_empty():
		push_warning("No se puede generar roster desde definiciones vacías.")
		return []
	var keys = defs.keys()
	keys.shuffle()
	 # Asegurar que max_count no exceda el número de definiciones disponibles
	var actual_max_count = min(max_count, keys.size())
	if min_count > actual_max_count && actual_max_count > 0 : # Si min_count es inalcanzable pero hay defs
		min_count = actual_max_count
	elif actual_max_count == 0: # No hay defs para elegir
		return []

	var count = randi_range(min_count, actual_max_count)
	
	var roster := []
	for i in range(count):
		roster.append(defs[keys[i]])
	return roster

func _find_deck_by_id(deck_list: Array, id_to_find: int) -> Dictionary:
	for deck_data in deck_list:
		if deck_data is Dictionary and deck_data.has("id") and deck_data.id == id_to_find:
			return deck_data

	return {} # Devuelve diccionario vacío si no se encuentra

func _get_player_deck() -> Array:
	match player_deck_type:
		1: # Balanceado
			return _load_deck_from_file("res://data/player_deck_balanced.json")
		2: # Agresivo  
			return _load_deck_from_file("res://data/player_deck_aggressive.json")
		3: # Defensivo
			return _load_deck_from_file("res://data/player_deck_defensive.json")
		4: # Inicial
			return _load_deck_from_file("res://data/player_deck_starter.json")
		_: # Automático (0)
			return _get_player_available_cards()

func _load_deck_from_file(file_path: String) -> Array:
	var deck_data = _load_json(file_path)
	if deck_data is Dictionary and deck_data.has("deck"):
		return deck_data.get("deck", [])
	else:
		push_warning("Game.gd: Error cargando deck desde %s" % file_path)
		return []

func _get_player_available_cards() -> Array:
	var all_cards_data = _load_json("res://data/cards.json")
	var player_cards: Array = []
	
	if not all_cards_data is Array:
		push_error("Game.gd: Error al cargar cartas desde cards.json")
		return player_cards
	
	# Filtrar cartas disponibles para el jugador
	for card_data in all_cards_data:
		if card_data is Dictionary and card_data.has("available_to") and card_data.has("id"):
			var available_to = card_data.get("available_to", [])
			if available_to is Array and "player" in available_to:
				var card_id = int(card_data.get("id"))  # Asegurar que sea entero
				player_cards.append(card_id)
	
	# Crear una lista con múltiples copias para tener suficientes cartas
	var expanded_deck: Array = []
	for card_id in player_cards:
		# Añadir 3 copias de cada carta disponible para el jugador
		for i in range(3):
			expanded_deck.append(card_id)
	
	expanded_deck.shuffle()
	return expanded_deck

func _on_character_selected(char_data: CharacterData):
	print("🎭 Personaje seleccionado: ", char_data.name)
	
	# Delegar al UI para manejar el targeting
	if ui.has_method("_on_character_targeted"):
		ui._on_character_targeted(char_data)
