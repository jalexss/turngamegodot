extends Node2D

const CardDataResource = preload("res://scripts/CardData.gd") # Renombrado para claridad
const CARDS_DEFINITIONS_PATH = "res://data/cards.json"

var cards: Array = [] # El mazo activo
var all_card_definitions: Dictionary = {} # Cache de todas las definiciones de cartas

func _ready() -> void:
	_preload_all_card_definitions()

# Carga y cachea todas las definiciones de cartas desde CARDS_DEFINITIONS_PATH
func _preload_all_card_definitions() -> void:
	if not all_card_definitions.is_empty():
		return # Ya cargadas

	var file = FileAccess.open(CARDS_DEFINITIONS_PATH, FileAccess.READ)
	if not FileAccess.file_exists(CARDS_DEFINITIONS_PATH) or file == null:
		push_error("Deck.gd: No se pudo abrir el archivo de definiciones de cartas: " + CARDS_DEFINITIONS_PATH)
		return
	
	var text_content = file.get_as_text()
	file.close()

	if text_content.strip_edges().is_empty():
		push_error("Deck.gd: El archivo de definiciones de cartas está vacío: " + CARDS_DEFINITIONS_PATH)
		return

	var parse_result = JSON.parse_string(text_content)

	if parse_result == null:
		push_error("Deck.gd: Error al parsear JSON de definiciones de cartas desde %s (resultado nulo)." % CARDS_DEFINITIONS_PATH)
		return
	
	# Asumiendo que el JSON raíz es un Array de objetos de carta
	if not parse_result is Array:
		push_error("Deck.gd: Se esperaba un Array en el JSON de definiciones de cartas %s, se obtuvo %s." % [CARDS_DEFINITIONS_PATH, typeof(parse_result)])
		return

	for def_data in parse_result:
		if not def_data is Dictionary:
			push_warning("Deck.gd: Elemento en definiciones de cartas no es un diccionario, omitiendo: %s" % str(def_data))
			continue

		var cd = CardDataResource.new()
		cd.id          = def_data.get("id", -1)
		if cd.id == -1:
			push_warning("Deck.gd: Definición de carta sin ID o ID inválido, omitiendo: %s" % str(def_data))
			continue
			
		cd.name        = def_data.get("name", "Sin Nombre")
		cd.cost        = def_data.get("cost", 0)
		cd.description = def_data.get("description", "")
		
		var aw_path = def_data.get("artwork", "")
				
		# La comprobación robusta:
		if aw_path is String and not aw_path.is_empty():
			# aw_path es una cadena no vacía, intentar cargar
			if ResourceLoader.exists(aw_path):
				cd.artwork = load(aw_path)
			else:
				push_warning("Deck.gd: Artwork no encontrado en '%s' para carta ID %s" % [aw_path, cd.id])

		var bg_path = def_data.get("background", "") # Misma lógica
		if bg_path is String and not bg_path.is_empty():
			if ResourceLoader.exists(bg_path):
				cd.background = load(bg_path)
			else:
				push_warning("Deck.gd: Background no encontrado en '%s' para carta ID %s" % [bg_path, cd.id])

		var card_type_str = def_data.get("card_type", "ATTACK").to_upper()
		if CardDataResource.CardType.has(card_type_str):
			cd.card_type = CardDataResource.CardType[card_type_str]
		else:
			push_warning("Deck.gd: Tipo de carta desconocido '%s' para carta ID %s. Usando ATTACK." % [def_data.get("card_type", "ATTACK"), cd.id])
			cd.card_type = CardDataResource.CardType.ATTACK # Fallback
		
		cd.power   = def_data.get("power", 0)
		 # cd.effects = def_data.get("effects", []) # Línea original problemática

		var effects_data_from_json = def_data.get("effects", [])

		if effects_data_from_json is Array:
			for item in effects_data_from_json:
				if item is Dictionary:
					cd.effects.append(item) # Añadir al Array[Dictionary] existente
				else:
					push_warning("Deck.gd: Elemento en 'effects' para la carta ID %s no es un Dictionary, omitido: %s" % [cd.id, str(item)])
		elif not effects_data_from_json == null: # Si no es Array y no es null (por si acaso)
			push_warning("Deck.gd: El campo 'effects' para la carta ID %s no es un Array, es %s. Se dejará 'effects' vacío." % [cd.id, typeof(effects_data_from_json)])
	
		
		if all_card_definitions.has(cd.id):
			push_warning("Deck.gd: ID de carta duplicado %s en definiciones. La definición anterior será sobrescrita." % cd.id)
		all_card_definitions[cd.id] = cd
	
	if all_card_definitions.is_empty() and not parse_result.is_empty():
		push_warning("Deck.gd: Se procesaron definiciones de cartas pero el diccionario 'all_card_definitions' está vacío. Verifica los IDs y la estructura del JSON.")


# Público: Carga el mazo a partir de un array de IDs de cartas.
func load_deck_from_ids(card_ids_raw: Array) -> void:
# func load_deck_from_ids(card_ids: Array) -> void:
	if all_card_definitions.is_empty():
		push_error("Deck.gd: Las definiciones de cartas no están cargadas o están vacías. No se puede crear el mazo desde IDs.")
		cards.clear()
		return

	cards.clear() # Limpiar mazo anterior

	var current_id_value # Para debugging
	for id_value_raw in card_ids_raw:
		current_id_value = id_value_raw # Guardar valor original para mensajes de error
		var final_id: int # Variable para el ID convertido a entero

		if id_value_raw is float:
			final_id = int(id_value_raw)
			# Opcional: Advertir si hay pérdida de precisión (si el float no era un entero exacto)
			if final_id != id_value_raw:
				push_warning("Deck.gd: ID de carta flotante %s fue truncado a %s." % [str(id_value_raw), str(final_id)])
		elif id_value_raw is int:
			final_id = id_value_raw
		else:
			push_warning("Deck.gd: ID de carta con tipo inesperado '%s' (valor: %s). Omitiendo." % [typeof(id_value_raw), str(id_value_raw)])
			continue # Saltar al siguiente ID en el bucle

		if all_card_definitions.has(final_id):
			cards.append(all_card_definitions[final_id])
		else:
			push_warning("Deck.gd: ID de carta '%s' (original: '%s') no encontrado en las definiciones al construir mazo. Omitiendo." % [str(final_id), str(current_id_value)])
	
	shuffle()


# Público: Carga el mazo desde un archivo JSON que define la lista de IDs.
# El archivo JSON debe tener la estructura: { "deck": [id1, id2, ...] }
func load_deck_from_file(deck_definition_file_path: String) -> void:
	if all_card_definitions.is_empty():
		push_error("Deck.gd: Las definiciones de cartas no están cargadas. No se puede crear el mazo desde archivo.")
		cards.clear() # Asegurar mazo vacío
		return

	var file = FileAccess.open(deck_definition_file_path, FileAccess.READ)
	if not FileAccess.file_exists(deck_definition_file_path) or file == null:
		push_error("Deck.gd: No se pudo abrir el archivo de definición de mazo: " + deck_definition_file_path)
		load_deck_from_ids([]) # Cargar mazo vacío como fallback
		return

	var text_content = file.get_as_text()
	file.close()

	if text_content.strip_edges().is_empty():
		push_error("Deck.gd: El archivo de definición de mazo está vacío: " + deck_definition_file_path)
		load_deck_from_ids([]) # Cargar mazo vacío
		return
		
	var parse_result = JSON.parse_string(text_content)

	if parse_result == null:
		push_error("Deck.gd: Error al parsear JSON de definición de mazo desde %s." % deck_definition_file_path)
		load_deck_from_ids([])
		return

	if not parse_result is Dictionary:
		push_error("Deck.gd: Se esperaba un Diccionario en el JSON de definición de mazo %s, se obtuvo %s." % [deck_definition_file_path, typeof(parse_result)])
		load_deck_from_ids([])
		return
		
	if not parse_result.has("deck"):
		push_error("Deck.gd: La clave 'deck' no se encontró en el JSON de definición de mazo: " + deck_definition_file_path)
		load_deck_from_ids([])
		return

	var id_list_from_json = parse_result.get("deck")

	if id_list_from_json is Array:
		load_deck_from_ids(id_list_from_json)
	else:
		# Manejar el caso donde 'deck' no es un array después de todas las verificaciones
		push_error("Deck.gd: La clave 'deck' en %s no es un Array válido después del parseo. Tipo: %s" % [deck_definition_file_path, typeof(id_list_from_json)])
		load_deck_from_ids([]) # Fallback a mazo vacío

func load_deck(source: Variant) -> void:
	if source is String: # Asume que es un path
		load_deck_from_file(source)
	elif source is Array: # Asume que es una lista de IDs
		load_deck_from_ids(source)
	else:
		push_error("Deck.gd: Tipo de 'source' no válido para load_deck. Debe ser String (path) o Array (IDs). Se recibió %s." % typeof(source))
		load_deck_from_ids([]) # Fallback a mazo vacío

func shuffle() -> void:
	cards.shuffle()

func draw() -> CardDataResource: # Tipo de retorno más específico
	return cards.pop_front() if not cards.is_empty() else null

func get_cards_remaining() -> int:
	"""Retorna la cantidad de cartas restantes en el deck"""
	return cards.size()

func is_empty() -> bool:
	"""Verifica si el deck está vacío"""
	return cards.is_empty()

func get_remaining_cards() -> Array:
	"""Retorna una copia de las cartas que quedan en el mazo"""
	var remaining_cards = []
	for card_data in cards:
		remaining_cards.append(card_data.id)
	return remaining_cards
