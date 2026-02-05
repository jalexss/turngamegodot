extends Node
class_name EffectManager

# --- SEÑALES ---
signal effect_applied(character: CharacterData, effect: StatusEffect)
signal effect_removed(character: CharacterData, effect: StatusEffect)
signal effect_triggered(character: CharacterData, effect: StatusEffect, value: int)

# --- EFECTOS ACTIVOS ---
# Diccionario: CharacterData -> Array[StatusEffect]
var active_effects: Dictionary = {}

# --- APLICACIÓN DE EFECTOS ---
func apply_effect(character: CharacterData, effect: StatusEffect) -> void:
	"""Aplica un efecto a un personaje"""
	if not character:
		print("❌ Error: Personaje nulo al aplicar efecto")
		return
	
	print("🔮 Aplicando efecto: ", effect.get_display_text(), " a ", character.name)
	
	# Inicializar array si no existe
	if not active_effects.has(character):
		active_effects[character] = []
	
	var character_effects = active_effects[character]
	
	# Verificar si el efecto es stackeable
	if effect.stackable:
		# Buscar efecto similar para stackear
		var existing_effect = _find_similar_effect(character_effects, effect)
		if existing_effect:
			_stack_effects(existing_effect, effect)
			print("  📚 Efecto stackeado: ", existing_effect.get_display_text())
		else:
			character_effects.append(effect.duplicate_effect())
			print("  ✅ Nuevo efecto aplicado")
	else:
		# Remover efectos similares no stackeables
		_remove_similar_effects(character_effects, effect)
		character_effects.append(effect.duplicate_effect())
		print("  🔄 Efecto reemplazado")
	
	# Aplicar efecto inmediato si es necesario
	_apply_immediate_effect(character, effect)
	
	effect_applied.emit(character, effect)

func remove_effect(character: CharacterData, effect: StatusEffect) -> void:
	"""Remueve un efecto específico de un personaje"""
	if not active_effects.has(character):
		return
	
	var character_effects = active_effects[character]
	var index = character_effects.find(effect)
	
	if index >= 0:
		character_effects.remove_at(index)
		print("🗑️ Efecto removido: ", effect.get_display_text(), " de ", character.name)
		effect_removed.emit(character, effect)

func remove_all_effects(character: CharacterData) -> void:
	"""Remueve todos los efectos de un personaje"""
	if not active_effects.has(character):
		return
	
	var character_effects = active_effects[character]
	for effect in character_effects:
		effect_removed.emit(character, effect)
	
	character_effects.clear()
	print("🧹 Todos los efectos removidos de ", character.name)

func get_character_effects(character: CharacterData) -> Array:
	"""Retorna todos los efectos activos de un personaje"""
	# Primero intentar búsqueda directa por referencia
	if active_effects.has(character):
		return active_effects[character].duplicate()
	
	# Fallback: buscar por nombre e id (para cuando la referencia es diferente)
	for stored_char in active_effects.keys():
		if stored_char and character:
			if stored_char.name == character.name and stored_char.id == character.id:
				print("🔎 EffectManager: Encontrado personaje por nombre/id: ", character.name)
				return active_effects[stored_char].duplicate()
	
	return []

# --- PROCESAMIENTO POR TURNOS ---
func process_turn_start_effects(character: CharacterData) -> void:
	"""Procesa efectos al inicio del turno del personaje"""
	if not active_effects.has(character):
		return
	
	print("🔄 Procesando efectos de inicio de turno para ", character.name)
	var character_effects = active_effects[character]
	
	for effect in character_effects:
		_process_turn_start_effect(character, effect)

func process_turn_end_effects(character: CharacterData) -> void:
	"""Procesa efectos al final del turno del personaje"""
	if not active_effects.has(character):
		return
	
	print("🔄 Procesando efectos de final de turno para ", character.name)
	var character_effects = active_effects[character]
	var effects_to_remove = []
	
	for effect in character_effects:
		_process_turn_end_effect(character, effect)
		
		# Reducir duración
		if effect.reduce_duration():
			effects_to_remove.append(effect)
	
	# Remover efectos expirados
	for effect in effects_to_remove:
		remove_effect(character, effect)

# --- MODIFICADORES DE STATS ---
func get_modified_attack(character: CharacterData) -> int:
	"""Retorna el ataque modificado por efectos"""
	var base_attack = character.attack
	var modified_attack = base_attack
	
	if not active_effects.has(character):
		return modified_attack
	
	for effect in active_effects[character]:
		match effect.effect_type:
			StatusEffect.EffectType.BUFF_ATTACK:
				modified_attack = effect.get_modifier_value(modified_attack)
			StatusEffect.EffectType.DEBUFF_ATTACK:
				modified_attack = effect.get_modifier_value(modified_attack)
			StatusEffect.EffectType.STRENGTH:
				modified_attack = effect.get_modifier_value(modified_attack)
			StatusEffect.EffectType.WEAKNESS:
				modified_attack = effect.get_modifier_value(modified_attack)
	
	return max(0, modified_attack)

func get_modified_defense(character: CharacterData) -> int:
	"""Retorna la defensa modificada por efectos"""
	var base_defense = character.defense
	var modified_defense = base_defense
	
	if not active_effects.has(character):
		return modified_defense
	
	for effect in active_effects[character]:
		match effect.effect_type:
			StatusEffect.EffectType.BUFF_DEFENSE:
				modified_defense = effect.get_modifier_value(modified_defense)
			StatusEffect.EffectType.DEBUFF_DEFENSE:
				modified_defense = effect.get_modifier_value(modified_defense)
	
	return max(0, modified_defense)

func can_act(character: CharacterData) -> bool:
	"""Verifica si el personaje puede actuar (no está stunned)"""
	if not active_effects.has(character):
		return true
	
	for effect in active_effects[character]:
		if effect.effect_type == StatusEffect.EffectType.STUN:
			return false
	
	return true

func can_heal(character: CharacterData) -> bool:
	"""Verifica si el personaje puede curarse"""
	if not active_effects.has(character):
		return true
	
	for effect in active_effects[character]:
		if effect.effect_type == StatusEffect.EffectType.HEAL_BLOCK:
			return false
	
	return true

func get_speed_multiplier(character: CharacterData) -> int:
	"""Retorna cuántas veces se aplican las cartas (1 base + stacks de velocidad, máx 3)"""
	var multiplier = 1  # Base: 1 aplicación
	
	if not active_effects.has(character):
		return multiplier
	
	for effect in active_effects[character]:
		if effect.effect_type == StatusEffect.EffectType.SPEED_BOOST:
			multiplier += effect.value  # Cada stack añade aplicaciones
	
	# Máximo 3 aplicaciones (1 base + 2 stacks máximo)
	return min(multiplier, 3)

func apply_speed_effect(character: CharacterData, duration: int = 1) -> void:
	"""Aplica efecto de velocidad a un personaje (máximo 2 stacks)"""
	# Verificar cuántos stacks ya tiene
	var current_stacks = 0
	if active_effects.has(character):
		for effect in active_effects[character]:
			if effect.effect_type == StatusEffect.EffectType.SPEED_BOOST:
				current_stacks += effect.value
	
	if current_stacks >= 2:
		print("⚡ ", character.name, " ya tiene máximo de velocidad (2 stacks)")
		return
	
	# Crear y aplicar efecto de velocidad
	var speed_effect = StatusEffect.new(StatusEffect.EffectType.SPEED_BOOST, 1, duration)
	speed_effect.stackable = true
	speed_effect.source_name = "Speed Boost"
	apply_effect(character, speed_effect)
	print("🚀 ", character.name, " gana velocidad! Cartas se aplicarán ", get_speed_multiplier(character), " veces")

func modify_damage_dealt(character: CharacterData, damage: int) -> int:
	"""Modifica el daño que hace un personaje"""
	var modified_damage = damage
	
	if not active_effects.has(character):
		return modified_damage
	
	for effect in active_effects[character]:
		match effect.effect_type:
			StatusEffect.EffectType.DOUBLE_DAMAGE:
				modified_damage *= 2
				# Remover efecto después de usar
				remove_effect(character, effect)
				print("⚡ Golpe crítico activado! Daño duplicado")
			StatusEffect.EffectType.VULNERABILITY:
				modified_damage = effect.get_modifier_value(modified_damage)
	
	return max(0, modified_damage)

func modify_damage_received(character: CharacterData, damage: int) -> int:
	"""Modifica el daño que recibe un personaje"""
	var modified_damage = damage
	
	if not active_effects.has(character):
		return modified_damage
	
	# Procesar escudos primero
	for effect in active_effects[character]:
		if effect.effect_type == StatusEffect.EffectType.SHIELD:
			var absorbed = min(modified_damage, effect.value)
			modified_damage -= absorbed
			effect.value -= absorbed
			
			print("🛡️ Escudo absorbe ", absorbed, " daño (", effect.value, " restante)")
			
			if effect.value <= 0:
				remove_effect(character, effect)
			
			if modified_damage <= 0:
				return 0
	
	# Procesar vulnerabilidad
	for effect in active_effects[character]:
		if effect.effect_type == StatusEffect.EffectType.VULNERABILITY:
			modified_damage = effect.get_modifier_value(modified_damage)
	
	return max(0, modified_damage)

# --- FUNCIONES PRIVADAS ---
func _find_similar_effect(effects: Array, target_effect: StatusEffect) -> StatusEffect:
	"""Busca un efecto similar en la lista"""
	for effect in effects:
		if effect.effect_type == target_effect.effect_type:
			return effect
	return null

func _stack_effects(existing: StatusEffect, new_effect: StatusEffect) -> void:
	"""Stackea dos efectos similares"""
	existing.value += new_effect.value
	existing.duration = max(existing.duration, new_effect.duration)

func _remove_similar_effects(effects: Array, target_effect: StatusEffect) -> void:
	"""Remueve efectos similares no stackeables"""
	var to_remove = []
	for effect in effects:
		if effect.effect_type == target_effect.effect_type:
			to_remove.append(effect)
	
	for effect in to_remove:
		effects.erase(effect)

func _apply_immediate_effect(character: CharacterData, effect: StatusEffect) -> void:
	"""Aplica efectos inmediatos"""
	match effect.effect_type:
		StatusEffect.EffectType.BUFF_HP:
			character.max_hp += effect.value
			character.hp += effect.value
			print("💗 HP máximo aumentado en ", effect.value)
		
		StatusEffect.EffectType.DEBUFF_HP:
			character.max_hp = max(1, character.max_hp + effect.value)
			character.hp = min(character.hp, character.max_hp)
			print("💔 HP máximo reducido en ", abs(effect.value))

func _process_turn_start_effect(character: CharacterData, effect: StatusEffect) -> void:
	"""Procesa un efecto al inicio del turno"""
	match effect.effect_type:
		StatusEffect.EffectType.POISON:
			var damage = effect.value
			character.hp = max(0, character.hp - damage)
			print("☠️ ", character.name, " recibe ", damage, " daño por veneno")
			effect_triggered.emit(character, effect, damage)
		
		StatusEffect.EffectType.REGENERATION:
			var heal = effect.value
			var old_hp = character.hp
			character.hp = min(character.max_hp, character.hp + heal)
			var actual_heal = character.hp - old_hp
			print("💚 ", character.name, " se regenera ", actual_heal, " HP")
			effect_triggered.emit(character, effect, actual_heal)

func _process_turn_end_effect(_character: CharacterData, _effect: StatusEffect) -> void:
	"""Procesa un efecto al final del turno"""
	# Aquí se pueden agregar efectos que se activen al final del turno
	pass
