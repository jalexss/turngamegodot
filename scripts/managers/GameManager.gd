extends Node
## GameManager - Autoload singleton para manejar el estado global del juego
## Gestiona transiciones de escena, estado del roguelike run, y persistencia

# Señales
signal run_started
signal run_ended(victory: bool)
signal battle_started
signal battle_ended(victory: bool)
signal node_completed(node_index: int)

# Rutas de escenas
const MAIN_MENU_SCENE = "res://scenes/MainMenu.tscn"
const MAP_SCENE = "res://scenes/Map.tscn"
const BATTLE_SCENE = "res://scenes/Game.tscn"

# Estado del juego
enum GameMode { NONE, ROGUELIKE, ADVENTURE, MULTIPLAYER }
enum RunState { NOT_STARTED, IN_MAP, IN_BATTLE, COMPLETED }

var current_mode: GameMode = GameMode.NONE
var run_state: RunState = RunState.NOT_STARTED

# Estado del roguelike run
var selected_characters: Array = []  # Array de CharacterData
var current_seed: int = 0
var current_node_index: int = 0
var total_nodes: int = 0
var map_nodes: Array = []  # Array de diccionarios con info de cada nodo

# Estado de batalla actual
var current_enemy_roster: Array = []  # Array de CharacterData para la batalla actual

# Referencias a datos
var all_characters: Dictionary = {}  # Todos los personajes cargados
var all_enemies: Dictionary = {}  # Todos los enemigos cargados
var encounters_data: Dictionary = {}  # Datos de encuentros

func _ready() -> void:
	print("🎮 GameManager inicializado")
	_load_all_data()

func _load_all_data() -> void:
	"""Carga todos los datos necesarios al iniciar"""
	all_characters = _load_json_as_dict("res://data/characters.json")
	all_enemies = _load_json_as_dict("res://data/enemys.json")
	encounters_data = _load_json_file("res://data/encounters.json")
	print("📊 Datos cargados: ", all_characters.size(), " personajes, ", all_enemies.size(), " enemigos")

func _load_json_as_dict(path: String) -> Dictionary:
	"""Carga un JSON y lo convierte a Dictionary usando ID como clave"""
	var data = _load_json_file(path)
	
	if data is Dictionary:
		return data
	elif data is Array:
		var dict_data = {}
		for item in data:
			if item is Dictionary and item.has("id"):
				dict_data[item["id"]] = item
		return dict_data
	return {}

func _load_json_file(path: String) -> Variant:
	"""Carga un archivo JSON y retorna su contenido"""
	if not FileAccess.file_exists(path):
		print("⚠️ Archivo no encontrado: ", path)
		return {}
	
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		print("❌ No se pudo abrir: ", path)
		return {}
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	if json.parse(json_text) != OK:
		print("❌ Error parseando JSON: ", path)
		return {}
	
	return json.data

# ============================================================
# FUNCIONES DE PERSONAJES
# ============================================================

func get_playable_characters() -> Array:
	"""Retorna todos los personajes jugables (no enemigos)"""
	var playable = []
	for id in all_characters.keys():
		var char_def = all_characters[id]
		# Excluir si tiene is_enemy = true
		if not char_def.get("is_enemy", false):
			playable.append(char_def)
	return playable

func create_character_data(char_def: Dictionary) -> Resource:
	"""Crea un CharacterData desde un diccionario de definición"""
	var char_data = preload("res://scripts/CharacterData.gd").new()
	char_data.id = char_def.get("id", 0)
	char_data.name = char_def.get("name", "Unknown")
	char_data.description = char_def.get("description", "")
	char_data.max_hp = char_def.get("max_hp", char_def.get("hp", 100))
	char_data.hp = char_data.max_hp
	char_data.attack = char_def.get("attack", 10)
	char_data.defense = char_def.get("defense", 5)
	char_data.rate = char_def.get("rate", 1)
	char_data.role = char_def.get("role", "")
	
	var portrait_path = char_def.get("portrait", "")
	char_data.sprite_path = portrait_path
	
	if portrait_path != "" and ResourceLoader.exists(portrait_path):
		char_data.portrait = load(portrait_path) as Texture2D
	
	return char_data

# ============================================================
# FUNCIONES DE ROGUELIKE RUN
# ============================================================

func start_roguelike_run(characters: Array) -> void:
	"""Inicia una nueva partida de roguelike con los personajes seleccionados"""
	print("🎮 Iniciando Roguelike Run con ", characters.size(), " personajes")
	
	current_mode = GameMode.ROGUELIKE
	run_state = RunState.IN_MAP
	selected_characters = characters
	current_node_index = 0
	
	# Generar seed para esta run
	current_seed = randi()
	seed(current_seed)
	print("🎲 Seed de la run: ", current_seed)
	
	# Generar mapa
	_generate_map()
	
	run_started.emit()
	
	# Cambiar a escena del mapa
	get_tree().change_scene_to_file(MAP_SCENE)

func _generate_map() -> void:
	"""Genera los nodos del mapa basado en la seed"""
	map_nodes.clear()
	
	# Estructura simple: 2 batallas normales + 1 boss
	var common_enemies = _get_enemies_by_range("common")
	var epic_enemies = _get_enemies_by_range("epic")
	var boss_enemies = _get_enemies_by_range("boss")
	
	# Nodo 1: Batalla común (1-2 enemigos common)
	map_nodes.append({
		"type": "battle",
		"difficulty": "common",
		"enemies": _pick_random_enemies(common_enemies, 1, 2),
		"completed": false,
		"current": true
	})
	
	# Nodo 2: Batalla épica (1-3 enemigos, pueden ser common o epic)
	var mixed_pool = common_enemies + epic_enemies
	map_nodes.append({
		"type": "battle",
		"difficulty": "epic",
		"enemies": _pick_random_enemies(mixed_pool, 1, 3),
		"completed": false,
		"current": false
	})
	
	# Nodo 3: Boss
	map_nodes.append({
		"type": "boss",
		"difficulty": "boss",
		"enemies": _pick_random_enemies(boss_enemies, 1, 1),
		"completed": false,
		"current": false
	})
	
	total_nodes = map_nodes.size()
	print("🗺️ Mapa generado con ", total_nodes, " nodos")

func _get_enemies_by_range(range_type: String) -> Array:
	"""Obtiene enemigos filtrados por su rango (common, epic, boss)"""
	var filtered = []
	for id in all_enemies.keys():
		var enemy_def = all_enemies[id]
		if enemy_def.get("range", "common") == range_type:
			filtered.append(enemy_def)
	
	# Si no hay enemigos del tipo, usar todos
	if filtered.is_empty():
		for id in all_enemies.keys():
			filtered.append(all_enemies[id])
	
	return filtered

func _pick_random_enemies(pool: Array, min_count: int, max_count: int) -> Array:
	"""Selecciona enemigos aleatorios del pool"""
	if pool.is_empty():
		return []
	
	var count = randi_range(min_count, max_count)
	var selected = []
	
	for i in range(count):
		var random_enemy = pool[randi() % pool.size()]
		selected.append(random_enemy.get("id", 1))
	
	return selected

func get_current_node() -> Dictionary:
	"""Retorna el nodo actual del mapa"""
	if current_node_index >= 0 and current_node_index < map_nodes.size():
		return map_nodes[current_node_index]
	return {}

func start_node_battle() -> void:
	"""Inicia la batalla del nodo actual"""
	var node = get_current_node()
	if node.is_empty():
		print("❌ No hay nodo actual válido")
		return
	
	print("⚔️ Iniciando batalla del nodo ", current_node_index + 1)
	run_state = RunState.IN_BATTLE
	
	# Preparar roster de enemigos
	current_enemy_roster.clear()
	for enemy_id in node.get("enemies", []):
		if all_enemies.has(enemy_id):
			var enemy_data = create_character_data(all_enemies[enemy_id])
			current_enemy_roster.append(enemy_data)
	
	print("👾 Enemigos en batalla: ", current_enemy_roster.size())
	
	battle_started.emit()
	
	# Cambiar a escena de batalla
	get_tree().change_scene_to_file(BATTLE_SCENE)

func on_battle_victory() -> void:
	"""Llamado cuando el jugador gana una batalla"""
	print("🏆 Victoria en batalla!")
	
	# Marcar nodo como completado
	if current_node_index < map_nodes.size():
		map_nodes[current_node_index]["completed"] = true
		map_nodes[current_node_index]["current"] = false
	
	# Restaurar HP de personajes para siguiente batalla (parcial)
	for character in selected_characters:
		# Recuperar 30% del HP perdido
		var hp_lost = character.max_hp - character.hp
		var hp_recovered = int(hp_lost * 0.3)
		character.hp = min(character.hp + hp_recovered, character.max_hp)
	
	battle_ended.emit(true)
	node_completed.emit(current_node_index)
	
	# Avanzar al siguiente nodo
	current_node_index += 1
	
	if current_node_index >= total_nodes:
		# Run completada!
		_complete_run(true)
	else:
		# Marcar siguiente nodo como actual
		map_nodes[current_node_index]["current"] = true
		run_state = RunState.IN_MAP
		
		# Volver al mapa
		get_tree().change_scene_to_file(MAP_SCENE)

func on_battle_defeat() -> void:
	"""Llamado cuando el jugador pierde una batalla"""
	print("💀 Derrota en batalla!")
	battle_ended.emit(false)
	_complete_run(false)

func _complete_run(victory: bool) -> void:
	"""Completa la run actual"""
	run_state = RunState.COMPLETED
	print("🎮 Run completada - Victoria: ", victory)
	run_ended.emit(victory)
	
	# Volver al menú principal después de un delay
	await get_tree().create_timer(2.0).timeout
	return_to_main_menu()

func return_to_main_menu() -> void:
	"""Vuelve al menú principal y resetea el estado"""
	print("🏠 Volviendo al menú principal")
	_reset_run_state()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)

func _reset_run_state() -> void:
	"""Resetea el estado de la run"""
	current_mode = GameMode.NONE
	run_state = RunState.NOT_STARTED
	selected_characters.clear()
	current_enemy_roster.clear()
	map_nodes.clear()
	current_node_index = 0
	total_nodes = 0
	current_seed = 0

# ============================================================
# GETTERS PARA OTRAS ESCENAS
# ============================================================

func get_player_roster() -> Array:
	"""Retorna el roster de personajes del jugador para la batalla"""
	return selected_characters

func get_enemy_roster() -> Array:
	"""Retorna el roster de enemigos para la batalla actual"""
	return current_enemy_roster

func is_roguelike_mode() -> bool:
	"""Verifica si estamos en modo roguelike"""
	return current_mode == GameMode.ROGUELIKE

func get_current_node_index() -> int:
	"""Retorna el índice del nodo actual"""
	return current_node_index

func get_map_nodes() -> Array:
	"""Retorna todos los nodos del mapa"""
	return map_nodes
