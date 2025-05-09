extends Node2D

const ENEMY_DECKS_PATH = "res://data/enemy_decks.json"

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

	# Cargar y seleccionar deck enemigo
	var all_enemy_decks: Array = _load_enemy_decks(ENEMY_DECKS_PATH)

	if all_enemy_decks.is_empty():
		push_error("Game.gd: No se cargaron mazos de enemigos desde %s. No se puede seleccionar un mazo." % ENEMY_DECKS_PATH)
		deck.load_deck_from_ids([]) # Carga un mazo vacío como fallback usando la nueva función
	else:
		var chosen_deck_definition: Dictionary
		if testing_deck_id > 0:
			chosen_deck_definition = _find_deck_by_id(all_enemy_decks, testing_deck_id)
			if chosen_deck_definition.is_empty(): # _find_deck_by_id devuelve {} si no lo encuentra
				push_warning("Game.gd: Deck de prueba ID %d no encontrado. Seleccionando uno aleatorio." % testing_deck_id)
				chosen_deck_definition = all_enemy_decks[randi() % all_enemy_decks.size()]
		else:
			chosen_deck_definition = all_enemy_decks[randi() % all_enemy_decks.size()]

		if not chosen_deck_definition.is_empty() and chosen_deck_definition.has("deck"):
			var enemy_card_ids: Array = chosen_deck_definition.deck
			if enemy_card_ids is Array: # Buena práctica verificar el tipo
				# Aquí usamos la nueva función que acepta un Array de IDs directamente
				deck.load_deck_from_ids(enemy_card_ids) 
			else:
				push_error("Game.gd: chosen_deck_definition.deck no es un Array. Tipo recibido: %s" % typeof(enemy_card_ids))
				deck.load_deck_from_ids([]) # Fallback
		else:
			push_error("Game.gd: La definición del mazo enemigo seleccionado es inválida o está vacía.")
			deck.load_deck_from_ids([]) # Carga un mazo vacío como fallback
	
	_start_turn()

func _start_turn() -> void:
	turn_num += 1
	energy = 3
	ui.set_turn(turn_num)
	ui.set_energy(energy)
	ui.clear_hand()
	ui.update_player_chars(player_chars)
	ui.update_enemy_chars(enemy_chars)
	for i in range(3):
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
