extends Node
## GameManager - Autoload singleton para manejar el estado global del juego
## Gestiona transiciones de escena, estado del roguelike run, y persistencia

# Señales
signal run_started
signal run_ended(victory: bool)
signal battle_started
signal battle_ended(victory: bool)
signal node_completed(node_index: int)
signal gold_changed(new_amount: int)
signal buffs_changed

# Rutas de escenas
const MAIN_MENU_SCENE = "res://scenes/MainMenu.tscn"
const MAP_SCENE = "res://scenes/Map.tscn"
const BATTLE_SCENE = "res://scenes/Game.tscn"
const SHOP_SCENE = "res://scenes/Shop.tscn"
const REST_SCENE = "res://scenes/Rest.tscn"
const TREASURE_SCENE = "res://scenes/Treasure.tscn"
const RANDOM_EVENT_SCENE = "res://scenes/RandomEvent.tscn"

# Estado del juego
enum GameMode { NONE, ROGUELIKE, ADVENTURE, MULTIPLAYER }
enum RunState { NOT_STARTED, IN_MAP, IN_BATTLE, IN_EVENT, COMPLETED }

# Tipos de nodos del mapa
enum NodeType { BATTLE, BOSS, SHOP, REST, TREASURE, RANDOM }

var current_mode: GameMode = GameMode.NONE
var run_state: RunState = RunState.NOT_STARTED

# Estado del roguelike run
var selected_characters: Array = []  # Array de CharacterData
var current_seed: int = 0
var current_node_index: int = 0
var current_branch_index: int = 0  # Índice del nodo seleccionado en el nivel actual
var total_nodes: int = 0
var map_nodes: Array = []  # Array de arrays (niveles con múltiples nodos)

# Sistema de monedas del roguelike
var gold: int = 0

# Buffos permanentes obtenidos en la run
var run_buffs: Array = []  # Array de {character_id, buff_type, value, source}

# Buffos de tienda disponibles
var shop_buffs_data: Array = []

# Estado de batalla actual
var current_enemy_roster: Array = []  # Array de CharacterData para la batalla actual

# Nodo actual siendo procesado
var current_node_data: Dictionary = {}

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
	shop_buffs_data = _load_shop_buffs()
	print("📊 Datos cargados: ", all_characters.size(), " personajes, ", all_enemies.size(), " enemigos")
	print("🛒 Buffos de tienda cargados: ", shop_buffs_data.size())

func _load_shop_buffs() -> Array:
	"""Carga los buffos disponibles en la tienda"""
	var data = _load_json_file("res://data/shop_buffs.json")
	if data is Dictionary and data.has("buffs"):
		return data["buffs"]
	elif data is Array:
		return data
	return []

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
	current_branch_index = 0
	gold = 0  # Oro inicial = 0
	run_buffs.clear()
	
	# Generar seed para esta run
	current_seed = randi()
	seed(current_seed)
	print("🎲 Seed de la run: ", current_seed)
	
	# Generar mapa con ramificaciones
	_generate_map()
	
	run_started.emit()
	gold_changed.emit(gold)
	
	# Cambiar a escena del mapa
	get_tree().change_scene_to_file(MAP_SCENE)

func _generate_map() -> void:
	"""Genera los nodos del mapa con ramificaciones (2-4 nodos por nivel)"""
	map_nodes.clear()
	
	var common_enemies = _get_enemies_by_range("common")
	var epic_enemies = _get_enemies_by_range("epic")
	var boss_enemies = _get_enemies_by_range("boss")
	
	# 7 niveles de nodos + 1 nivel de boss = 8 niveles totales
	var num_levels = 8
	
	for level in range(num_levels):
		var level_nodes = []
		
		if level == 0:
			# Primer nivel: siempre 1 nodo de batalla para empezar
			level_nodes.append(_create_battle_node(common_enemies, "common", 1, 2))
		elif level == num_levels - 1:
			# Último nivel: siempre el boss
			level_nodes.append(_create_boss_node(epic_enemies, boss_enemies))
		else:
			# Niveles intermedios: 2-4 nodos aleatorios
			var num_nodes = randi_range(2, 4)
			for i in range(num_nodes):
				var node_type = _pick_random_node_type(level)
				var node = _create_node_by_type(node_type, level, common_enemies, epic_enemies)
				level_nodes.append(node)
		
		map_nodes.append(level_nodes)
	
	# Marcar primer nodo como actual
	if map_nodes.size() > 0 and map_nodes[0].size() > 0:
		map_nodes[0][0]["current"] = true
	
	total_nodes = num_levels
	print("🗺️ Mapa generado con ", total_nodes, " niveles (seed: ", current_seed, ")")
	_print_map_composition()

func _pick_random_node_type(level: int) -> NodeType:
	"""Selecciona un tipo de nodo aleatorio basado en el nivel"""
	var weights = {
		NodeType.BATTLE: 40,    # 40% batallas
		NodeType.SHOP: 15,      # 15% tienda
		NodeType.REST: 15,      # 15% descanso
		NodeType.TREASURE: 15,  # 15% tesoro
		NodeType.RANDOM: 15     # 15% evento aleatorio
	}
	
	# En niveles más avanzados, más probabilidad de batallas difíciles
	if level >= 4:
		weights[NodeType.BATTLE] = 50
		weights[NodeType.REST] = 10
	
	var total_weight = 0
	for w in weights.values():
		total_weight += w
	
	var roll = randi() % total_weight
	var current_weight = 0
	
	for node_type in weights.keys():
		current_weight += weights[node_type]
		if roll < current_weight:
			return node_type
	
	return NodeType.BATTLE

func _create_node_by_type(node_type: NodeType, level: int, common_enemies: Array, epic_enemies: Array) -> Dictionary:
	"""Crea un nodo según su tipo"""
	match node_type:
		NodeType.BATTLE:
			var difficulty = "common" if level < 3 else "epic"
			var pool = common_enemies if level < 3 else common_enemies + epic_enemies
			var min_enemies = 1 if level < 2 else 2
			var max_enemies = 2 if level < 4 else 3
			return _create_battle_node(pool, difficulty, min_enemies, max_enemies)
		NodeType.SHOP:
			return _create_shop_node()
		NodeType.REST:
			return _create_rest_node()
		NodeType.TREASURE:
			return _create_treasure_node()
		NodeType.RANDOM:
			return _create_random_node()
		_:
			return _create_battle_node(common_enemies, "common", 1, 2)

func _create_battle_node(enemy_pool: Array, difficulty: String, min_enemies: int, max_enemies: int) -> Dictionary:
	"""Crea un nodo de batalla"""
	return {
		"type": NodeType.BATTLE,
		"type_name": "battle",
		"difficulty": difficulty,
		"enemies": _pick_random_enemies(enemy_pool, min_enemies, max_enemies),
		"completed": false,
		"current": false
	}

func _create_boss_node(epic_enemies: Array, boss_enemies: Array) -> Dictionary:
	"""Crea un nodo de boss"""
	var boss_pool = epic_enemies + boss_enemies
	return {
		"type": NodeType.BOSS,
		"type_name": "boss",
		"difficulty": "boss",
		"enemies": _pick_random_enemies(boss_pool, 2, 3),
		"completed": false,
		"current": false
	}

func _create_shop_node() -> Dictionary:
	"""Crea un nodo de tienda"""
	return {
		"type": NodeType.SHOP,
		"type_name": "shop",
		"completed": false,
		"current": false,
		"purchased_buffs": []  # IDs de buffos ya comprados en esta tienda
	}

func _create_rest_node() -> Dictionary:
	"""Crea un nodo de descanso"""
	return {
		"type": NodeType.REST,
		"type_name": "rest",
		"completed": false,
		"current": false
	}

func _create_treasure_node() -> Dictionary:
	"""Crea un nodo de tesoro"""
	var gold_reward = randi_range(30, 60)
	return {
		"type": NodeType.TREASURE,
		"type_name": "treasure",
		"gold_reward": gold_reward,
		"completed": false,
		"current": false
	}

func _create_random_node() -> Dictionary:
	"""Crea un nodo de evento aleatorio"""
	return {
		"type": NodeType.RANDOM,
		"type_name": "random",
		"completed": false,
		"current": false
	}

func _print_map_composition() -> void:
	"""Imprime la composición del mapa para debugging"""
	for level_idx in range(map_nodes.size()):
		var level_nodes = map_nodes[level_idx]
		print("  Nivel ", level_idx + 1, ":")
		for node_idx in range(level_nodes.size()):
			var node = level_nodes[node_idx]
			var type_name = _get_node_type_name(node.get("type", NodeType.BATTLE))
			var extra_info = ""
			
			if node.get("type") == NodeType.BATTLE or node.get("type") == NodeType.BOSS:
				var enemies_info = []
				for enemy_id in node.get("enemies", []):
					if all_enemies.has(enemy_id):
						var enemy_def = all_enemies[enemy_id]
						enemies_info.append(enemy_def.get("name", "Unknown"))
				extra_info = " - Enemigos: " + ", ".join(enemies_info)
			elif node.get("type") == NodeType.TREASURE:
				extra_info = " - Oro: " + str(node.get("gold_reward", 0))
			
			print("    [", node_idx + 1, "] ", type_name, extra_info)

func _get_node_type_name(node_type) -> String:
	"""Retorna el nombre legible del tipo de nodo"""
	match node_type:
		NodeType.BATTLE: return "⚔️ Batalla"
		NodeType.BOSS: return "💀 Boss"
		NodeType.SHOP: return "🛒 Tienda"
		NodeType.REST: return "🏕️ Descanso"
		NodeType.TREASURE: return "💰 Tesoro"
		NodeType.RANDOM: return "❓ Evento Aleatorio"
		_: return "❓ Desconocido"

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
		var level_nodes = map_nodes[current_node_index]
		if current_branch_index >= 0 and current_branch_index < level_nodes.size():
			return level_nodes[current_branch_index]
	return {}

func start_node(branch_index: int = 0) -> void:
	"""Inicia el nodo seleccionado en el nivel actual"""
	if current_node_index >= map_nodes.size():
		print("❌ No hay más niveles")
		return
	
	var level_nodes = map_nodes[current_node_index]
	if branch_index >= level_nodes.size():
		print("❌ Índice de rama inválido")
		return
	
	current_branch_index = branch_index
	current_node_data = level_nodes[branch_index]
	
	# Marcar todos como no actuales, luego marcar el seleccionado
	for node in level_nodes:
		node["current"] = false
	current_node_data["current"] = true
	
	var node_type = current_node_data.get("type", NodeType.BATTLE)
	print("🎯 Iniciando nodo tipo: ", _get_node_type_name(node_type))
	
	match node_type:
		NodeType.BATTLE:
			_start_battle_node()
		NodeType.BOSS:
			_start_battle_node()
		NodeType.SHOP:
			_start_shop_node()
		NodeType.REST:
			_start_rest_node()
		NodeType.TREASURE:
			_start_treasure_node()
		NodeType.RANDOM:
			_start_random_node()

func _start_battle_node() -> void:
	"""Inicia un nodo de batalla"""
	run_state = RunState.IN_BATTLE
	
	# Preparar roster de enemigos
	current_enemy_roster.clear()
	for enemy_id in current_node_data.get("enemies", []):
		if all_enemies.has(enemy_id):
			var enemy_data = create_character_data(all_enemies[enemy_id])
			current_enemy_roster.append(enemy_data)
	
	print("👾 Enemigos en batalla: ", current_enemy_roster.size())
	battle_started.emit()
	get_tree().change_scene_to_file(BATTLE_SCENE)

func _start_shop_node() -> void:
	"""Inicia un nodo de tienda"""
	run_state = RunState.IN_EVENT
	get_tree().change_scene_to_file(SHOP_SCENE)

func _start_rest_node() -> void:
	"""Inicia un nodo de descanso"""
	run_state = RunState.IN_EVENT
	get_tree().change_scene_to_file(REST_SCENE)

func _start_treasure_node() -> void:
	"""Inicia un nodo de tesoro"""
	run_state = RunState.IN_EVENT
	get_tree().change_scene_to_file(TREASURE_SCENE)

func _start_random_node() -> void:
	"""Inicia un nodo de evento aleatorio"""
	run_state = RunState.IN_EVENT
	get_tree().change_scene_to_file(RANDOM_EVENT_SCENE)

func start_node_battle() -> void:
	"""Inicia la batalla del nodo actual (compatibilidad)"""
	start_node(current_branch_index)

func on_battle_victory() -> void:
	"""Llamado cuando el jugador gana una batalla"""
	print("🏆 Victoria en batalla!")
	
	# Dar oro por victoria (20-70 según dificultad)
	var node = get_current_node()
	var gold_reward = _calculate_battle_gold_reward(node)
	add_gold(gold_reward)
	print("💰 Oro ganado: ", gold_reward)
	
	# Marcar nodo como completado
	_complete_current_node()
	
	# Restaurar HP de personajes para siguiente batalla (parcial)
	for character in selected_characters:
		# Recuperar 30% del HP perdido
		var hp_lost = character.max_hp - character.hp
		var hp_recovered = int(hp_lost * 0.3)
		character.hp = min(character.hp + hp_recovered, character.max_hp)
	
	battle_ended.emit(true)
	node_completed.emit(current_node_index)
	
	# Avanzar al siguiente nivel
	_advance_to_next_level()

func _calculate_battle_gold_reward(node: Dictionary) -> int:
	"""Calcula el oro ganado según el tipo de combate"""
	var difficulty = node.get("difficulty", "common")
	match difficulty:
		"common":
			return randi_range(20, 40)
		"epic":
			return randi_range(35, 55)
		"boss":
			return randi_range(50, 70)
		_:
			return randi_range(20, 40)

func _complete_current_node() -> void:
	"""Marca el nodo actual como completado"""
	if current_node_index < map_nodes.size():
		var level_nodes = map_nodes[current_node_index]
		if current_branch_index < level_nodes.size():
			level_nodes[current_branch_index]["completed"] = true
			level_nodes[current_branch_index]["current"] = false

func _advance_to_next_level() -> void:
	"""Avanza al siguiente nivel del mapa"""
	current_node_index += 1
	current_branch_index = 0
	
	if current_node_index >= total_nodes:
		# Run completada!
		_complete_run(true)
	else:
		# Marcar primer nodo del siguiente nivel como disponible
		run_state = RunState.IN_MAP
		get_tree().change_scene_to_file(MAP_SCENE)

func on_event_completed() -> void:
	"""Llamado cuando se completa un evento (tienda, descanso, tesoro, etc.)"""
	print("✅ Evento completado")
	
	_complete_current_node()
	node_completed.emit(current_node_index)
	
	_advance_to_next_level()

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
	current_branch_index = 0
	total_nodes = 0
	current_seed = 0
	gold = 0
	run_buffs.clear()
	current_node_data.clear()

# ============================================================
# SISTEMA DE ORO
# ============================================================

func add_gold(amount: int) -> void:
	"""Añade oro al jugador"""
	gold += amount
	print("💰 Oro actualizado: ", gold, " (+", amount, ")")
	gold_changed.emit(gold)

func spend_gold(amount: int) -> bool:
	"""Gasta oro si hay suficiente, retorna true si tuvo éxito"""
	if gold >= amount:
		gold -= amount
		print("💰 Oro gastado: ", amount, " | Restante: ", gold)
		gold_changed.emit(gold)
		return true
	print("❌ Oro insuficiente: ", gold, " < ", amount)
	return false

func get_gold() -> int:
	"""Retorna el oro actual"""
	return gold

# ============================================================
# SISTEMA DE BUFFOS PERMANENTES
# ============================================================

func apply_buff_to_character(character_id: int, buff_type: String, value: int, source: String = "unknown") -> void:
	"""Aplica un buff permanente a un personaje para el resto de la run"""
	# Buscar el personaje
	var character = null
	for char_data in selected_characters:
		if char_data.id == character_id:
			character = char_data
			break
	
	if not character:
		print("❌ Personaje no encontrado: ", character_id)
		return
	
	# Aplicar el buff según tipo
	match buff_type:
		"attack":
			character.attack += value
			print("⚔️ ", character.name, " +", value, " ATK")
		"defense":
			character.defense += value
			print("🛡️ ", character.name, " +", value, " DEF")
		"max_hp":
			character.max_hp += value
			character.hp += value  # También aumentar HP actual
			print("❤️ ", character.name, " +", value, " HP máximo")
		"rate":
			character.rate += value
			print("⚡ ", character.name, " +", value, " Velocidad")
	
	# Registrar el buff
	run_buffs.append({
		"character_id": character_id,
		"character_name": character.name,
		"buff_type": buff_type,
		"value": value,
		"source": source
	})
	
	buffs_changed.emit()

func get_run_buffs() -> Array:
	"""Retorna todos los buffos obtenidos en esta run"""
	return run_buffs

func get_character_buffs(character_id: int) -> Array:
	"""Retorna los buffos de un personaje específico"""
	var char_buffs = []
	for buff in run_buffs:
		if buff["character_id"] == character_id:
			char_buffs.append(buff)
	return char_buffs

# ============================================================
# SISTEMA DE TIENDA
# ============================================================

func get_random_shop_buffs(count: int = 4) -> Array:
	"""Retorna buffos aleatorios para la tienda"""
	if shop_buffs_data.is_empty():
		print("⚠️ No hay buffos de tienda cargados")
		return []
	
	var available = shop_buffs_data.duplicate()
	available.shuffle()
	
	var result = []
	for i in range(min(count, available.size())):
		result.append(available[i])
	
	return result

func mark_buff_purchased_in_current_shop(buff_id: int) -> void:
	"""Marca un buff como comprado en la tienda actual"""
	var node = get_current_node()
	if node.has("purchased_buffs"):
		node["purchased_buffs"].append(buff_id)

func is_buff_purchased_in_current_shop(buff_id: int) -> bool:
	"""Verifica si un buff ya fue comprado en la tienda actual"""
	var node = get_current_node()
	if node.has("purchased_buffs"):
		return buff_id in node["purchased_buffs"]
	return false

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

func get_current_branch_index() -> int:
	"""Retorna el índice de la rama actual"""
	return current_branch_index

func get_map_nodes() -> Array:
	"""Retorna todos los nodos del mapa"""
	return map_nodes

func get_total_levels() -> int:
	"""Retorna el número total de niveles"""
	return total_nodes

func get_level_nodes(level_index: int) -> Array:
	"""Retorna los nodos de un nivel específico"""
	if level_index >= 0 and level_index < map_nodes.size():
		return map_nodes[level_index]
	return []

func get_node_type_enum() -> Dictionary:
	"""Retorna el enum NodeType para uso externo"""
	return {
		"BATTLE": NodeType.BATTLE,
		"BOSS": NodeType.BOSS,
		"SHOP": NodeType.SHOP,
		"REST": NodeType.REST,
		"TREASURE": NodeType.TREASURE,
		"RANDOM": NodeType.RANDOM
	}
