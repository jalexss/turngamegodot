extends Node2D

const ENEMY_DECKS_PATH = "res://data/enemy_decks.json"
const PLAYER_DECK_PATH = "res://data/player_deck.json"

# Importar clases necesarias
const EffectManagerClass = preload("res://scripts/EffectManager.gd")

# Opciones de deck para el jugador
@export_enum("Automático", "Balanceado", "Agresivo", "Defensivo", "Inicial") var player_deck_type: int = 0
@export var testing_deck_id: int = -1  # si > 0 fuerza ese deck en vez de random

# --- NODOS ---
@onready var deck = $Deck
@onready var ui = $GameUI as Control
@onready var player_manager = get_node_or_null("Player")
@onready var enemy_manager = get_node_or_null("Enemy")
@onready var effect_manager = get_node_or_null("EffectManager")

# --- VARIABLES DE JUEGO ---
var turn_num := 0
var player_chars : Array = []
var enemy_chars  : Array = []
var char_defs    : Dictionary = {}
var enemy_defs   : Dictionary = {}

# --- SISTEMA DE TURNOS ---
enum TurnPhase { PLAYER, ENEMY }
var current_phase: TurnPhase = TurnPhase.PLAYER

func _ready() -> void:
	# Crear nodos si no existen
	_create_missing_managers()
	
	# Cargar definiciones de personajes
	char_defs  = _load_char_defs("res://data/characters.json")
	enemy_defs = _load_char_defs("res://data/enemys.json")
	player_chars = _generate_roster(char_defs, 1, 3)
	enemy_chars  = _generate_roster(enemy_defs, 1, 5)

	# Configurar managers
	if enemy_manager:
		enemy_manager.set_enemy_characters(enemy_chars)
		enemy_manager.actions_generated.connect(_on_enemy_actions_generated)
		enemy_manager.action_executed.connect(_on_enemy_action_executed)
		enemy_manager.turn_completed.connect(_on_enemy_turn_completed)
	
	if player_manager:
		player_manager.energy_changed.connect(_on_player_energy_changed)
		player_manager.hand_changed.connect(_on_player_hand_changed)
		player_manager.card_played.connect(_on_player_card_played)

	# Cargar deck del jugador (20 cartas con repeticiones)
	print("DEBUG: Cargando deck del jugador...")
	var player_card_ids: Array = _create_20_card_deck()
	print("DEBUG: IDs de cartas obtenidos: ", player_card_ids)
	print("DEBUG: Tamaño del deck: ", player_card_ids.size())
	
	if player_card_ids.is_empty():
		push_error("Game.gd: No se pudo cargar el deck del jugador.")
		deck.load_deck_from_ids([])
	else:
		print("DEBUG: Cargando ", player_card_ids.size(), " cartas en el deck...")
		deck.load_deck_from_ids(player_card_ids)
		print("DEBUG: Deck de 20 cartas cargado exitosamente")
	
	_start_turn()

func _create_missing_managers() -> void:
	"""Crea los nodos Player, Enemy y EffectManager si no existen"""
	# Actualizar referencias primero
	player_manager = get_node_or_null("Player")
	enemy_manager = get_node_or_null("Enemy")
	effect_manager = get_node_or_null("EffectManager")
	
	if not player_manager:
		print("DEBUG: Creando Player manager...")
		var new_player = preload("res://scripts/Player.gd").new()
		new_player.name = "Player"
		add_child(new_player)
		player_manager = new_player
	
	if not enemy_manager:
		print("DEBUG: Creando Enemy manager...")
		var new_enemy = preload("res://scripts/Enemy.gd").new()
		new_enemy.name = "Enemy"
		add_child(new_enemy)
		enemy_manager = new_enemy
	
	if not effect_manager:
		print("DEBUG: Creando EffectManager...")
		var new_effect_manager = EffectManagerClass.new()
		new_effect_manager.name = "EffectManager"
		add_child(new_effect_manager)
		effect_manager = new_effect_manager

func _start_turn() -> void:
	turn_num += 1
	current_phase = TurnPhase.PLAYER
	
	print("=== 🎮 TURNO DEL JUGADOR ", turn_num, " ===")
	if ui and ui.has_method("set_turn"):
		ui.set_turn(turn_num)
	
	# Procesar efectos de inicio de turno para jugadores
	if effect_manager:
		for character in player_chars:
			effect_manager.process_turn_start_effects(character)
	
	# Habilitar UI para turno del jugador
	if ui and ui.has_method("set_player_turn_active"):
		ui.set_player_turn_active(true)
	
	# NO limpiar la mano aquí - el Player manager se encarga de las cartas
	if ui and ui.has_method("update_player_chars"):
		ui.update_player_chars(player_chars)
	if ui and ui.has_method("update_enemy_chars"):
		ui.update_enemy_chars(enemy_chars)
	
	# Iniciar turno del jugador (esto robará las cartas)
	if player_manager:
		player_manager.start_turn()
	
	# Generar acciones enemigas para preview
	if enemy_manager:
		enemy_manager.generate_actions()

func _draw_and_show() -> void:
	var cd = deck.draw()
	if cd:
		print("DEBUG: Creando carta: ID=", cd.id, " Nombre=", cd.name)
		var card = preload("res://scenes/Card.tscn").instantiate() as Node2D
		card.set_data(cd)
		if ui and ui.has_method("add_card_to_hand"):
			ui.add_card_to_hand(card)
			print("DEBUG: Carta añadida exitosamente")
		else:
			print("❌ UI no disponible o función add_card_to_hand no existe")
	else:
		print("DEBUG: ERROR - No hay cartas en el deck")

# --- SISTEMA DE ENERGÍA ---
# --- FUNCIONES DE ENERGÍA (DELEGADAS AL PLAYER) ---
func can_afford_card(card_cost: int) -> bool:
	"""Verifica si el jugador puede pagar una carta"""
	if player_manager:
		return player_manager.can_afford_card(card_cost)
	return false

func use_energy(cost: int) -> bool:
	"""Usa energía para jugar una carta"""
	if player_manager:
		return player_manager.use_energy(cost)
	return false

func add_energy(amount: int) -> void:
	"""Añade energía respetando el límite máximo"""
	if player_manager:
		player_manager.add_energy(amount)

func add_energy_test(amount: int) -> void:
	"""Añade energía sin límite (testing)"""
	if player_manager:
		player_manager.add_energy_test(amount)

func get_current_energy() -> int:
	"""Retorna la energía actual"""
	if player_manager:
		return player_manager.get_energy()
	return 0

# --- SISTEMA DE TURNOS ENEMIGOS ---
func end_player_turn() -> void:
	"""Termina el turno del jugador e inicia el turno enemigo"""
	print("🔄 Terminando turno del jugador...")
	
	# Procesar efectos de final de turno para jugadores
	if effect_manager:
		for character in player_chars:
			effect_manager.process_turn_end_effects(character)
	
	current_phase = TurnPhase.ENEMY
	
	# Deshabilitar UI durante turno enemigo
	ui.set_player_turn_active(false)
	
	# Procesar efectos de inicio de turno para enemigos
	if effect_manager:
		for character in enemy_chars:
			effect_manager.process_turn_start_effects(character)
	
	# Ejecutar turno enemigo
	if enemy_manager:
		enemy_manager.execute_turn()

# --- CALLBACKS DE MANAGERS ---
func _on_player_energy_changed(current: int, maximum: int) -> void:
	"""Callback cuando cambia la energía del jugador"""
	if ui and ui.has_method("set_energy"):
		ui.set_energy(current, maximum)
	else:
		print("❌ UI no disponible o función set_energy no existe")

func _on_player_hand_changed(cards: Array) -> void:
	"""Callback cuando cambia la mano del jugador"""
	print("🔄 Mano del jugador cambió - Cartas de datos: ", cards.size())
	
	# Mostrar nombres de las cartas para debug
	var card_names = []
	for card_data in cards:
		card_names.append(card_data.name)
	print("📋 Cartas en datos: ", card_names)
	
	# SIEMPRE sincronizar la mano visual con los datos
	var current_hand_size = ui.get_current_hand_size()
	print("📊 Tamaño visual actual: ", current_hand_size, " | Tamaño de datos: ", cards.size())
	
	print("🔄 SINCRONIZANDO mano visual con datos...")
	
	# Limpiar mano actual SIEMPRE
	ui.clear_hand()
	print("🧹 Mano visual limpiada")
	
	# Crear cartas visuales para TODOS los datos
	for i in range(cards.size()):
		var card_data = cards[i]
		print("🃏 Procesando carta ", i+1, "/", cards.size(), ": ", card_data.name)
		
		# Crear nodo visual de carta
		var card_node = preload("res://scenes/Card.tscn").instantiate() as Node2D
		card_node.set_data(card_data)
		
		# Añadir a la mano visual
		ui.add_card_to_hand(card_node)
		print("✅ Carta visual creada y añadida: ", card_data.name)
	
	print("✅ Sincronización completada - Cartas visuales: ", ui.get_current_hand_size())

func _on_player_card_played(card_data: CardData) -> void:
	"""Callback cuando el jugador juega una carta"""
	print("🃏 Jugador jugó carta: ", card_data.name)

func _on_enemy_actions_generated(actions: Array) -> void:
	"""Callback cuando el enemigo genera sus acciones"""
	print("🤖 Enemigo generó ", actions.size(), " acciones")
	if ui and ui.has_method("show_enemy_action_previews"):
		ui.show_enemy_action_previews(actions)
	else:
		print("❌ UI no disponible o función show_enemy_action_previews no existe")

func _on_enemy_action_executed(action: Dictionary) -> void:
	"""Callback cuando el enemigo ejecuta una acción"""
	print("⚔️ Enemigo ejecutó acción: ", action.get("type", "UNKNOWN"))

func _on_enemy_turn_completed() -> void:
	"""Callback cuando el enemigo completa su turno"""
	print("✅ Turno enemigo completado")
	
	# Procesar efectos de final de turno para enemigos
	if effect_manager:
		for character in enemy_chars:
			effect_manager.process_turn_end_effects(character)
	
	# Verificar condiciones de victoria/derrota
	_check_game_over()
	
	# Si el juego no terminó, iniciar nuevo turno del jugador
	if not _is_game_over():
		_start_turn()

# --- SISTEMA DE DECK DE 20 CARTAS ---
func _create_20_card_deck() -> Array:
	"""Crea un deck de exactamente 20 cartas con repeticiones"""
	var base_cards = _get_player_available_cards()
	var deck_20_cards = []
	
	print("🃏 Creando deck de 20 cartas...")
	print("📊 Cartas base disponibles: ", base_cards.size())
	
	if base_cards.is_empty():
		print("❌ No hay cartas disponibles para el jugador")
		return []
	
	# Llenar el deck hasta 20 cartas
	while deck_20_cards.size() < 20:
		for card_id in base_cards:
			if deck_20_cards.size() >= 20:
				break
			deck_20_cards.append(card_id)
	
	# Mezclar el deck
	deck_20_cards.shuffle()
	
	print("✅ Deck de 20 cartas creado y mezclado")
	print("📋 Composición del deck: ", deck_20_cards)
	
	return deck_20_cards

func _get_player_available_cards() -> Array:
	"""Obtiene las cartas disponibles para el jugador según el tipo de deck seleccionado"""
	var deck_path: String
	
	match player_deck_type:
		1:  # Balanceado
			deck_path = "res://data/player_deck_balanced.json"
		2:  # Agresivo
			deck_path = "res://data/player_deck_aggressive.json"
		3:  # Defensivo
			deck_path = "res://data/player_deck_defensive.json"
		4:  # Inicial
			deck_path = "res://data/player_deck_starter.json"
		_:  # Automático (0) o cualquier otro valor
			deck_path = "res://data/player_deck.json"
	
	print("🎯 Cargando deck del jugador desde: ", deck_path)
	
	if not FileAccess.file_exists(deck_path):
		print("❌ Archivo de deck no encontrado: ", deck_path)
		print("🔄 Usando deck por defecto...")
		deck_path = "res://data/player_deck.json"
	
	var file = FileAccess.open(deck_path, FileAccess.READ)
	if not file:
		print("❌ No se pudo abrir el archivo: ", deck_path)
		return []
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_text)
	
	if parse_result != OK:
		print("❌ Error al parsear JSON: ", deck_path)
		return []
	
	var data = json.data
	if not data is Dictionary:
		print("❌ El archivo JSON no contiene un Dictionary: ", deck_path)
		return []
	
	var deck_data = data as Dictionary
	var card_ids = []
	
	# Verificar diferentes estructuras posibles
	if deck_data.has("cards"):
		card_ids = deck_data["cards"]
		print("DEBUG: Usando estructura 'cards'")
	elif deck_data.has("deck"):
		card_ids = deck_data["deck"]
		print("DEBUG: Usando estructura 'deck'")
	else:
		print("❌ El archivo no tiene la estructura esperada (falta 'cards' o 'deck')")
		print("DEBUG: Claves disponibles: ", deck_data.keys())
		return []
	print("✅ Cartas cargadas del deck: ", card_ids.size())
	
	return card_ids

# --- CARGA DE DATOS ---
func _load_char_defs(path: String) -> Dictionary:
	"""Carga definiciones de personajes desde un archivo JSON"""
	if not FileAccess.file_exists(path):
		print("❌ Archivo no encontrado: ", path)
		return {}
	
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		print("❌ No se pudo abrir archivo: ", path)
		return {}
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_text)
	
	if parse_result != OK:
		print("❌ Error al parsear JSON: ", path)
		return {}
	
	var data = json.data
	if data is Dictionary:
		return data
	elif data is Array:
		# Convertir Array a Dictionary usando el ID como clave
		print("DEBUG: Convirtiendo Array a Dictionary para: ", path)
		var dict_data = {}
		for item in data:
			if item is Dictionary and item.has("id"):
				dict_data[item["id"]] = item
				print("DEBUG: Añadido personaje ID ", item["id"], ": ", item.get("name", "Sin nombre"))
		print("DEBUG: Dictionary creado con ", dict_data.size(), " personajes")
		return dict_data
	else:
		print("❌ El archivo JSON no contiene un Dictionary ni Array: ", path)
		return {}

func _generate_roster(defs: Dictionary, min_chars: int, max_chars: int) -> Array:
	"""Genera un roster de personajes aleatorios"""
	var roster = []
	var char_keys = defs.keys()
	
	if char_keys.is_empty():
		print("❌ No hay definiciones de personajes disponibles")
		return roster
	
	var num_chars = randi_range(min_chars, max_chars)
	
	for i in range(num_chars):
		var random_key = char_keys[randi() % char_keys.size()]
		var char_def = defs[random_key]
		
		# Crear CharacterData
		var char_data = preload("res://scripts/CharacterData.gd").new()
		char_data.id = random_key
		char_data.name = char_def.get("name", "Personaje " + str(i+1))
		char_data.description = char_def.get("description", "")
		char_data.max_hp = char_def.get("hp", 100)
		char_data.hp = char_data.max_hp
		char_data.attack = char_def.get("attack", 10)
		char_data.defense = char_def.get("defense", 5)
		char_data.rate = char_def.get("rate", 1)
		char_data.role = char_def.get("role", "")
		var portrait_path = char_def.get("portrait", "")
		char_data.sprite_path = portrait_path
		
		# Cargar la textura desde la ruta
		print("DEBUG: Intentando cargar textura para ", char_data.name)
		print("DEBUG: Ruta: ", portrait_path)
		print("DEBUG: ResourceLoader.exists(): ", ResourceLoader.exists(portrait_path))
		
		if portrait_path != "":
			if ResourceLoader.exists(portrait_path):
				var loaded_texture = load(portrait_path) as Texture2D
				char_data.portrait = loaded_texture
				print("DEBUG: ✅ Textura cargada exitosamente: ", loaded_texture)
			else:
				print("❌ ResourceLoader.exists() = false para: ", portrait_path)
				# Intentar cargar de todas formas
				var loaded_texture = load(portrait_path) as Texture2D
				if loaded_texture:
					char_data.portrait = loaded_texture
					print("DEBUG: ✅ Textura cargada a pesar de ResourceLoader.exists() = false")
				else:
					char_data.portrait = null
					print("❌ No se pudo cargar textura: ", portrait_path)
		else:
			char_data.portrait = null
			print("DEBUG: No hay ruta de portrait especificada")
		
		roster.append(char_data)
	
	return roster

# --- GAME OVER ---
func _check_game_over() -> void:
	"""Verifica las condiciones de victoria/derrota"""
	var player_alive = false
	var enemy_alive = false
	
	# Verificar si hay jugadores vivos
	for character in player_chars:
		if character.hp > 0:
			player_alive = true
			break
	
	# Verificar si hay enemigos vivos
	for character in enemy_chars:
		if character.hp > 0:
			enemy_alive = true
			break
	
	# Determinar resultado
	if not player_alive and not enemy_alive:
		_end_game("EMPATE")
	elif not player_alive:
		_end_game("DERROTA")
	elif not enemy_alive:
		_end_game("VICTORIA")

func _is_game_over() -> bool:
	"""Verifica si el juego ha terminado"""
	var player_alive = false
	var enemy_alive = false
	
	for character in player_chars:
		if character.hp > 0:
			player_alive = true
			break
	
	for character in enemy_chars:
		if character.hp > 0:
			enemy_alive = true
			break
	
	return not player_alive or not enemy_alive

func _end_game(result: String) -> void:
	"""Termina el juego con el resultado especificado"""
	print("🎮 Juego terminado: ", result)
	
	# Mostrar pantalla de game over (esto ya detiene los cronómetros internamente)
	if ui and ui.has_method("show_game_over"):
		var victory = (result == "VICTORIA")
		ui.show_game_over(victory)
	
	# Aquí puedes agregar lógica adicional como:
	# - Guardar estadísticas
	# - Reiniciar el juego
	# - etc.

# --- TARGETING SYSTEM ---
func _on_character_targeted(char_data: CharacterData) -> void:
	"""Maneja cuando se selecciona un personaje como objetivo"""
	print("🎯 Personaje seleccionado como objetivo: ", char_data.name)
	
	# Delegar al UI para manejar el targeting
	if ui.has_method("_on_character_targeted"):
		ui._on_character_targeted(char_data)

# --- GETTERS PARA UI ---
func get_player_characters() -> Array:
	"""Retorna los personajes del jugador"""
	return player_chars

func get_enemy_characters() -> Array:
	"""Retorna los personajes enemigos"""
	return enemy_chars

func get_deck_cards() -> Array:
	"""Retorna las cartas del mazo"""
	if deck and deck.has_method("get_remaining_cards"):
		var cards = deck.get_remaining_cards()
		print("DEBUG: get_deck_cards() - Cartas obtenidas: ", cards.size())
		if cards.size() > 0:
			print("DEBUG: Primer carta tipo: ", typeof(cards[0]), " - Es CardData: ", cards[0] is CardData)
			if cards[0] is CardData:
				print("DEBUG: Nombre de primera carta: ", cards[0].name)
		return cards
	return []

func get_discard_cards() -> Array:
	"""Retorna las cartas de descarte"""
	if player_manager and player_manager.has_method("get_discard_pile"):
		return player_manager.get_discard_pile()
	return []

func get_player_manager():
	"""Retorna el player manager"""
	return player_manager
