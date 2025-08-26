extends Resource
class_name StatusEffect

# --- TIPOS DE EFECTOS ---
enum EffectType {
	BUFF_ATTACK,      # +ataque
	DEBUFF_ATTACK,    # -ataque
	BUFF_DEFENSE,     # +defensa
	DEBUFF_DEFENSE,   # -defensa
	BUFF_HP,          # +hp máximo
	DEBUFF_HP,        # -hp máximo
	STUN,             # No puede actuar
	POISON,           # Daño por turno
	REGENERATION,     # Curación por turno
	SHIELD,           # Absorbe daño
	VULNERABILITY,    # Recibe más daño
	STRENGTH,         # Hace más daño
	WEAKNESS,         # Hace menos daño
	ENERGY_BOOST,     # +energía por turno
	ENERGY_DRAIN,     # -energía por turno
	CARD_DRAW,        # Roba cartas extra
	CARD_BLOCK,       # No puede robar cartas
	REFLECT_DAMAGE,   # Refleja daño
	IMMUNITY,         # Inmune a efectos
	DOUBLE_DAMAGE,    # Próximo ataque hace doble daño
	HEAL_BLOCK,       # No puede curarse
	CUSTOM            # Efecto personalizado con función
}

enum ModifierType {
	FLAT,        # Valor fijo (+5, -3)
	PERCENTAGE   # Porcentaje (+10%, -5%)
}

# --- PROPIEDADES DEL EFECTO ---
@export var effect_type: EffectType
@export var modifier_type: ModifierType = ModifierType.FLAT
@export var value: int = 0                    # Valor del efecto
@export var duration: int = 1                 # Turnos restantes
@export var max_duration: int = 1             # Duración original
@export var name: String = ""                 # Nombre del efecto
@export var description: String = ""          # Descripción
@export var icon: String = "🔮"              # Icono para UI
@export var stackable: bool = false           # ¿Se puede acumular?
@export var removable: bool = true            # ¿Se puede remover?
@export var custom_function: String = ""     # Función personalizada

# --- METADATOS ---
@export var source_name: String = ""         # Quién aplicó el efecto
@export var applied_turn: int = 0             # En qué turno se aplicó

func _init(type: EffectType = EffectType.BUFF_ATTACK, val: int = 0, dur: int = 1):
	effect_type = type
	value = val
	duration = dur
	max_duration = dur
	_setup_effect_data()

func _setup_effect_data():
	"""Configura datos básicos según el tipo de efecto"""
	match effect_type:
		EffectType.BUFF_ATTACK:
			name = "Fuerza"
			description = "Aumenta el ataque"
			icon = "⚔️"
			stackable = true
		
		EffectType.DEBUFF_ATTACK:
			name = "Debilidad"
			description = "Reduce el ataque"
			icon = "🔻"
			stackable = true
		
		EffectType.BUFF_DEFENSE:
			name = "Fortaleza"
			description = "Aumenta la defensa"
			icon = "🛡️"
			stackable = true
		
		EffectType.DEBUFF_DEFENSE:
			name = "Fragilidad"
			description = "Reduce la defensa"
			icon = "💔"
			stackable = true
		
		EffectType.STUN:
			name = "Aturdimiento"
			description = "No puede actuar"
			icon = "😵"
			stackable = false
		
		EffectType.POISON:
			name = "Veneno"
			description = "Recibe daño cada turno"
			icon = "☠️"
			stackable = true
		
		EffectType.REGENERATION:
			name = "Regeneración"
			description = "Se cura cada turno"
			icon = "💚"
			stackable = true
		
		EffectType.SHIELD:
			name = "Escudo"
			description = "Absorbe daño"
			icon = "🛡️"
			stackable = true
		
		EffectType.VULNERABILITY:
			name = "Vulnerabilidad"
			description = "Recibe más daño"
			icon = "🎯"
			stackable = false
		
		EffectType.STRENGTH:
			name = "Poder"
			description = "Hace más daño"
			icon = "💪"
			stackable = true
		
		EffectType.WEAKNESS:
			name = "Debilidad"
			description = "Hace menos daño"
			icon = "😴"
			stackable = false
		
		EffectType.DOUBLE_DAMAGE:
			name = "Golpe Crítico"
			description = "Próximo ataque hace doble daño"
			icon = "⚡"
			stackable = false
		
		EffectType.HEAL_BLOCK:
			name = "Herida Grave"
			description = "No puede curarse"
			icon = "🚫"
			stackable = false

func get_display_text() -> String:
	"""Retorna texto para mostrar en UI"""
	var modifier_text = ""
	
	if modifier_type == ModifierType.PERCENTAGE:
		modifier_text = str(value) + "%"
	else:
		modifier_text = str(value) if value != 0 else ""
	
	var duration_text = ""
	if duration > 1:
		duration_text = " (" + str(duration) + " turnos)"
	elif duration == 1:
		duration_text = " (1 turno)"
	
	return icon + " " + name + " " + modifier_text + duration_text

func reduce_duration() -> bool:
	"""Reduce la duración en 1. Retorna true si el efecto debe removerse"""
	duration -= 1
	return duration <= 0

func get_modifier_value(base_value: int) -> int:
	"""Calcula el valor modificado según el tipo"""
	if modifier_type == ModifierType.PERCENTAGE:
		return int(base_value * (100 + value) / 100.0)
	else:
		return base_value + value

func duplicate_effect() -> StatusEffect:
	"""Crea una copia del efecto"""
	var new_effect = StatusEffect.new(effect_type, value, duration)
	new_effect.modifier_type = modifier_type
	new_effect.name = name
	new_effect.description = description
	new_effect.icon = icon
	new_effect.stackable = stackable
	new_effect.removable = removable
	new_effect.custom_function = custom_function
	new_effect.source_name = source_name
	new_effect.applied_turn = applied_turn
	new_effect.max_duration = max_duration
	return new_effect
