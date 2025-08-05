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
	var player_card_ids: Array = _get_player_deck()
	if player_card_ids.is_empty():
		push_error("Game.gd: No se pudo cargar el deck del jugador.")
		deck.load_deck_from_ids([])
	else:
		deck.load_deck_from_ids(player_card_ids)
	
	_start_turn()

func _start_turn() -> void:
	turn_num += 1
	energy = 3
	ui.set_turn(turn_num)
	ui.set_energy(energy)
	ui.clear_hand()
	ui.update_player_chars(player_chars)
	ui.update_enemy_chars(enemy_chars)
	for i in range(4):
		_draw_and_show()

func _draw_and_show() -> void:
	var cd = deck.draw()
	if cd:
		var card = preload("res://scenes/Card.tscn").instantiate() as Node2D
		card.set_data(cd)
		ui.add_card_to_hand(card)

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
				player_cards.append(card_data.get("id"))
	
	# Crear una lista con múltiples copias para tener suficientes cartas
	var expanded_deck: Array = []
	for card_id in player_cards:
		# Añadir 3 copias de cada carta disponible para el jugador
		for i in range(3):
			expanded_deck.append(card_id)
	
	expanded_deck.shuffle()
	return expanded_deck

func _on_character_selected(char_data: CharacterData):
	print("Personaje seleccionado en Game.gd: ", char_data.name)
	# --- AQUÍ VA TU LÓGICA ---
  # Por ejemplo, si tienes una carta seleccionada, aplicarle el efecto a este personaje.
  # if current_selected_card:
  #     play_card_on_target(current_selected_card, char_data)
