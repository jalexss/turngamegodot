extends Node
class_name Enemy

# --- VARIABLES ENEMIGAS ---
var enemy_characters: Array = []
var planned_actions: Array = []

# Referencias
var game_node: Node = null
var ui_node: Control = null

signal actions_generated(actions: Array)
signal action_executed(action: Dictionary)
signal turn_completed()

func _ready() -> void:
	# Buscar referencias
	game_node = get_parent()
	ui_node = game_node.get_node("GameUI") if game_node else null

func set_enemy_characters(characters: Array) -> void:
	"""Establece los personajes enemigos"""
	enemy_characters = characters

# --- GENERACIÓN DE ACCIONES ---
func generate_actions() -> void:
	"""Genera acciones aleatorias para todos los enemigos vivos"""
	planned_actions.clear()
	
	print("🤖 Generando acciones enemigas...")
	
	var living_enemies = 0
	var dead_enemies = 0
	
	for i in range(enemy_characters.size()):
		var enemy = enemy_characters[i]
		if enemy.hp <= 0:
			print("  - ", enemy.name, " está muerto ☠️ - SALTADO")
			dead_enemies += 1
			continue
		
		living_enemies += 1
		
		# Generar 1-3 acciones por enemigo
		var num_actions = randi_range(1, 3)
		print("  - ", enemy.name, " generará ", num_actions, " acciones")
		
		for j in range(num_actions):
			var action = _generate_random_action(enemy, i)
			planned_actions.append(action)
			print("    → ", action.type, " ", action.value, " (Target: ", action.target_type, ")")
	
	print("📊 Resumen: ", living_enemies, " enemigos vivos | ", dead_enemies, " enemigos muertos")
	
	if planned_actions.is_empty():
		print("⚠️ No se generaron acciones - Todos los enemigos están muertos o sin acciones")
	
	actions_generated.emit(planned_actions)

func _generate_random_action(enemy_character, enemy_index: int) -> Dictionary:
	"""Genera una acción aleatoria para un enemigo"""
	var action_types = ["ATTACK", "HEAL", "DEFEND"]
	var chosen_type = action_types[randi() % action_types.size()]
	
	var action = {
		"enemy_index": enemy_index,
		"enemy_name": enemy_character.name,
		"type": chosen_type,
		"value": 0,
		"target_type": "",
		"target_index": -1
	}
	
	match chosen_type:
		"ATTACK":
			action.value = randi_range(3, 12)
			action.target_type = "PLAYER"
			action.target_index = _get_random_alive_player_index()
		
		"HEAL":
			action.value = randi_range(5, 15)
			action.target_type = "ENEMY"
			action.target_index = _get_random_wounded_enemy_index(enemy_index)
		
		"DEFEND":
			action.value = randi_range(2, 6)
			action.target_type = "ENEMY"
			action.target_index = enemy_index
	
	return action

func _get_random_alive_player_index() -> int:
	"""Obtiene un índice aleatorio de jugador vivo"""
	if not game_node or not game_node.has_method("get_player_characters"):
		return -1
	
	var player_chars = game_node.get_player_characters()
	var alive_players = []
	
	for i in range(player_chars.size()):
		if player_chars[i].hp > 0:
			alive_players.append(i)
	
	if alive_players.is_empty():
		return -1
	
	return alive_players[randi() % alive_players.size()]

func _get_random_wounded_enemy_index(self_index: int) -> int:
	"""Obtiene un índice aleatorio de enemigo herido"""
	var wounded_enemies = []
	
	for i in range(enemy_characters.size()):
		var enemy = enemy_characters[i]
		if enemy.hp > 0 and enemy.hp < enemy.max_hp:
			wounded_enemies.append(i)
	
	if wounded_enemies.is_empty():
		return self_index  # Se cura a sí mismo
	
	return wounded_enemies[randi() % wounded_enemies.size()]

# --- EJECUCIÓN DE ACCIONES ---
func execute_turn() -> void:
	"""Ejecuta todas las acciones planeadas"""
	print("=== 🤖 TURNO ENEMIGO ===")
	
	# Verificar si hay enemigos vivos
	var living_enemies = 0
	for enemy in enemy_characters:
		if enemy.hp > 0:
			living_enemies += 1
	
	if living_enemies == 0:
		print("💀 Todos los enemigos están muertos - Saltando turno")
		turn_completed.emit()
		return
	
	if planned_actions.is_empty():
		print("⚠️ No hay acciones para ejecutar - Enemigos sin acciones")
		turn_completed.emit()
		return
	
	print("🎯 Ejecutando ", planned_actions.size(), " acciones...")
	
	# Ejecutar acciones secuencialmente
	_execute_next_action(0)

func _execute_next_action(action_index: int) -> void:
	"""Ejecuta la siguiente acción en la secuencia"""
	if action_index >= planned_actions.size():
		print("✅ Turno enemigo completado")
		turn_completed.emit()
		return
	
	var action = planned_actions[action_index]
	
	# Verificar si el enemigo que iba a ejecutar la acción sigue vivo
	var enemy_character = enemy_characters[action.enemy_index]
	if enemy_character.hp <= 0:
		print("💀 ", action.enemy_name, " murió durante el turno - SALTANDO acción: ", action.type, " ", action.value)
		# Saltar a la siguiente acción
		_continue_to_next_action(action_index)
		return
	
	print("🎬 Acción ", action_index + 1, "/", planned_actions.size(), ": ", action.enemy_name, " → ", action.type, " ", action.value)
	
	# Ejecutar la acción
	_execute_single_action(action)
	
	# Emitir señal para remover preview
	action_executed.emit(action)
	
	# Continuar con la siguiente acción después de una pausa
	await get_tree().create_timer(1.0).timeout
	_execute_next_action(action_index + 1)

func _continue_to_next_action(action_index: int) -> void:
	"""Continúa con la siguiente acción sin pausa (para acciones saltadas)"""
	# Emitir señal para remover preview de la acción saltada
	var action = planned_actions[action_index]
	action_executed.emit(action)
	
	# Continuar inmediatamente con la siguiente acción
	_execute_next_action(action_index + 1)

func _execute_single_action(action: Dictionary) -> void:
	"""Ejecuta una acción específica"""
	var enemy = enemy_characters[action.enemy_index]
	
	# Verificar si el enemigo sigue vivo
	if enemy.hp <= 0:
		print("💀 ", enemy.name, " está muerto, no puede actuar")
		return
	
	match action.type:
		"ATTACK":
			_execute_attack_action(action, enemy)
		"HEAL":
			_execute_heal_action(action, enemy)
		"DEFEND":
			_execute_defend_action(action, enemy)

func _execute_attack_action(action: Dictionary, enemy) -> void:
	"""Ejecuta una acción de ataque"""
	if not game_node or not game_node.has_method("get_player_characters"):
		return
	
	var player_chars = game_node.get_player_characters()
	if action.target_index >= 0 and action.target_index < player_chars.size():
		var target = player_chars[action.target_index]
		if target.hp > 0:
			print("⚔️ ", enemy.name, " ataca a ", target.name, " por ", action.value, " de daño")
			_apply_damage_to_character(target, action.value)
		else:
			print("💀 Objetivo ", target.name, " ya está muerto")

func _execute_heal_action(action: Dictionary, enemy) -> void:
	"""Ejecuta una acción de curación"""
	if action.target_index >= 0 and action.target_index < enemy_characters.size():
		var target = enemy_characters[action.target_index]
		if target.hp > 0:
			print("💚 ", enemy.name, " cura a ", target.name, " por ", action.value, " HP")
			_apply_heal_to_character(target, action.value)

func _execute_defend_action(action: Dictionary, enemy) -> void:
	"""Ejecuta una acción de defensa"""
	print("🛡️ ", enemy.name, " se defiende, ganando ", action.value, " de defensa")
	_apply_shield_to_character(enemy, action.value)

# --- APLICACIÓN DE EFECTOS ---
func _apply_damage_to_character(character, damage: int) -> void:
	"""Aplica daño a un personaje"""
	var actual_damage = max(0, damage - character.defense)
	character.hp = max(0, character.hp - actual_damage)
	
	print("💥 ", character.name, " recibe ", actual_damage, " de daño → HP: ", character.hp, "/", character.max_hp)
	
	# Actualizar UI
	if ui_node and ui_node.has_method("_update_character_display"):
		ui_node._update_character_display(character)

func _apply_heal_to_character(character, heal: int) -> void:
	"""Aplica curación a un personaje"""
	var old_hp = character.hp
	character.hp = min(character.max_hp, character.hp + heal)
	var actual_heal = character.hp - old_hp
	
	print("💚 ", character.name, " se cura ", actual_heal, " HP → HP: ", character.hp, "/", character.max_hp)
	
	# Actualizar UI
	if ui_node and ui_node.has_method("_update_character_display"):
		ui_node._update_character_display(character)

func _apply_shield_to_character(character, shield: int) -> void:
	"""Aplica escudo a un personaje"""
	character.defense += shield
	print("🛡️ ", character.name, " gana ", shield, " de escudo (Defensa: ", character.defense, ")")
	
	# Actualizar UI
	if ui_node and ui_node.has_method("_update_character_display"):
		ui_node._update_character_display(character)

# --- GETTERS ---
func get_planned_actions() -> Array:
	return planned_actions.duplicate()

func get_enemy_characters() -> Array:
	return enemy_characters.duplicate()
