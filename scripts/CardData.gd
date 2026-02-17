extends Resource
class_name CardData

enum CardType { 
	ATTACK, DEFENSE, HEAL, BUFF, DEBUFF, DRAW, DISCARD, 
	STATUS,      # Aplica efectos de estado
	SPECIAL,     # Efectos únicos/raros
	UTILITY      # Cartas de utilidad
}

enum EffectType { 
	DAMAGE, SHIELD, HEAL, BUFF, DEBUFF, DRAW, DISCARD,
	# Efectos de estado
	APPLY_STATUS,     # Aplica StatusEffect
	REMOVE_STATUS,    # Remueve StatusEffect
	# Efectos especiales
	STEAL_CARD,       # Roba carta del oponente
	COPY_CARD,        # Copia una carta
	TRANSFORM_CARD,   # Transforma una carta en otra
	SUMMON_ALLY,      # Invoca un aliado temporal
	SACRIFICE,        # Sacrifica aliado por beneficio
	CHAIN_REACTION,   # Efecto que se propaga
	CONDITIONAL,      # Efecto condicional
	RANDOM_EFFECT,    # Efecto aleatorio
	MULTI_TARGET,     # Afecta múltiples objetivos
	DELAYED_EFFECT,   # Efecto que se activa después
	CUSTOM            # Efecto personalizado
}

enum Rarity {
	COMMON,     # Cartas básicas
	UNCOMMON,   # Cartas poco comunes
	RARE,       # Cartas raras
	EPIC,       # Cartas épicas
	LEGENDARY   # Cartas legendarias
}

# --- PROPIEDADES BÁSICAS ---
@export var id: int = 0
@export var name: String = ""
@export var cost: int = 0
@export var description: String = ""
@export var artwork: Texture2D
@export var background: Texture2D
@export var card_type: CardType = CardType.ATTACK
@export var rarity: Rarity = Rarity.COMMON
@export var power: int = 0

# --- EFECTOS Y MECÁNICAS ---
@export var effects: Array[Dictionary] = []
@export var status_effects: Array[Dictionary] = []  # StatusEffects a aplicar
@export var special_mechanics: Array[String] = []   # Mecánicas especiales

# --- PROPIEDADES AVANZADAS ---
@export var targets_required: int = 1               # Cuántos objetivos necesita
@export var can_target_self: bool = false           # ¿Puede targetear al usuario?
@export var can_target_allies: bool = false         # ¿Puede targetear aliados?
@export var can_target_enemies: bool = true         # ¿Puede targetear enemigos?
@export var requires_sacrifice: bool = false        # ¿Requiere sacrificar algo?
@export var is_consumable: bool = true              # ¿Se consume al usar?
@export var max_uses_per_turn: int = -1            # Usos máximos por turno (-1 = ilimitado)
@export var cooldown: int = 0                       # Turnos de cooldown

# --- DEPENDENCIA DE PERSONAJE ---
@export var required_character_id: int = -1         # ID del personaje requerido (-1 = cualquiera)
@export var required_character_role: String = ""    # Rol requerido ("HEALER", "TANK", "CARRY", "" = cualquiera)

# --- CONDICIONES ---
@export var conditions: Array[Dictionary] = []      # Condiciones para usar la carta
@export var combo_cards: Array[int] = []           # IDs de cartas que hacen combo

# --- FUNCIONES DE UTILIDAD ---
func has_status_effects() -> bool:
	"""Verifica si la carta aplica efectos de estado"""
	return not status_effects.is_empty()

func has_special_mechanics() -> bool:
	"""Verifica si la carta tiene mecánicas especiales"""
	return not special_mechanics.is_empty()

func get_rarity_color() -> Color:
	"""Retorna el color asociado a la rareza"""
	match rarity:
		Rarity.COMMON:
			return Color.WHITE
		Rarity.UNCOMMON:
			return Color.GREEN
		Rarity.RARE:
			return Color.BLUE
		Rarity.EPIC:
			return Color.PURPLE
		Rarity.LEGENDARY:
			return Color.GOLD
		_:
			return Color.WHITE

func get_rarity_name() -> String:
	"""Retorna el nombre de la rareza"""
	match rarity:
		Rarity.COMMON:
			return "Común"
		Rarity.UNCOMMON:
			return "Poco Común"
		Rarity.RARE:
			return "Rara"
		Rarity.EPIC:
			return "Épica"
		Rarity.LEGENDARY:
			return "Legendaria"
		_:
			return "Desconocida"

func can_be_played_on(target_character: CharacterData, is_ally: bool) -> bool:
	"""Verifica si la carta puede jugarse en el objetivo especificado"""
	if is_ally and not can_target_allies:
		return false
	if not is_ally and not can_target_enemies:
		return false
	
	# Verificar condiciones adicionales
	for condition in conditions:
		if not _check_condition(condition, target_character):
			return false
	
	return true

func requires_specific_character() -> bool:
	"""Retorna si la carta requiere un personaje específico vivo"""
	return required_character_id >= 0 or required_character_role != ""

func can_be_played_by_team(player_characters: Array) -> bool:
	"""Verifica si la carta puede jugarse según los personajes vivos del equipo"""
	# Si no requiere personaje específico, siempre se puede jugar
	if not requires_specific_character():
		return true
	
	# Verificar si hay al menos un personaje vivo que cumpla los requisitos
	for character in player_characters:
		if character.hp <= 0:
			continue  # Ignorar personajes muertos
		
		# Verificar por ID específico
		if required_character_id >= 0:
			if character.id == required_character_id:
				return true
		
		# Verificar por rol
		if required_character_role != "":
			if character.role == required_character_role:
				return true
	
	return false

func get_required_character_info() -> String:
	"""Retorna información legible sobre el personaje requerido"""
	if required_character_id >= 0:
		return "Requiere personaje ID: " + str(required_character_id)
	if required_character_role != "":
		return "Requiere rol: " + required_character_role
	return "Sin requisitos especiales"

func get_all_effect_values() -> Array:
	"""Retorna todos los efectos con tipo, valor e información para mostrar"""
	var result: Array = []
	for effect in effects:
		if effect.has("type") and effect.has("value"):
			result.append({
				"type": str(effect["type"]),
				"value": int(effect["value"]),
				"duration": int(effect.get("duration", 0))
			})
	return result

func get_role_requirements() -> Array:
	"""Retorna lista de roles requeridos para jugar esta carta"""
	var roles: Array = []
	if required_character_role != "":
		roles.append(required_character_role.to_upper())
	return roles

func is_universal() -> bool:
	"""Retorna true si cualquier personaje puede usar esta carta"""
	return required_character_id == -1 and required_character_role == ""

func get_primary_effect_type() -> String:
	"""Retorna el tipo de efecto principal de la carta"""
	if effects.is_empty():
		return ""
	return str(effects[0].get("type", ""))

func get_total_damage() -> int:
	"""Retorna el daño total de todos los efectos de daño"""
	var total := 0
	for effect in effects:
		if str(effect.get("type", "")) == "DAMAGE":
			total += int(effect.get("value", 0))
	return total

func get_total_shield() -> int:
	"""Retorna el escudo total de todos los efectos de escudo"""
	var total := 0
	for effect in effects:
		if str(effect.get("type", "")) == "SHIELD":
			total += int(effect.get("value", 0))
	return total

func get_total_heal() -> int:
	"""Retorna la curación total de todos los efectos de curación"""
	var total := 0
	for effect in effects:
		if str(effect.get("type", "")) == "HEAL":
			total += int(effect.get("value", 0))
	return total

func _check_condition(condition: Dictionary, target: CharacterData) -> bool:
	"""Verifica una condición específica"""
	var type = condition.get("type", "")
	var value = condition.get("value", 0)
	
	match type:
		"min_hp":
			return target.hp >= value
		"max_hp":
			return target.hp <= value
		"hp_percentage":
			return (target.hp * 100.0 / target.max_hp) >= value
		"has_status":
			# Esto requeriría acceso al EffectManager
			return true  # Por ahora siempre true
		_:
			return true
