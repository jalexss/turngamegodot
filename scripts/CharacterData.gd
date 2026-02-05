extends Resource
class_name CharacterData

@export var id: int = 0
@export var name: String = ""
@export var description: String = ""  # Descripción del personaje
@export var portrait: Texture2D
@export var sprite_path: String = ""  # Ruta al sprite del personaje
@export var hp: int = 1
@export var max_hp: int = 1
@export var attack: int = 0      # potencia al atacar
@export var defense: int = 0     # mitigación de daño
@export var rate: int = 1        # Velocidad o prioridad
@export var role: String = ""    # Rol del personaje (HEALER, TANK, etc.)
@export var deck_id: int = 1     # ID del deck de cartas para enemigos
@export var range: String = "common"  # Rango del enemigo: common, epic, boss

# Stats base (antes de buffos permanentes)
var base_attack: int = 0
var base_defense: int = 0
var base_max_hp: int = 0
var base_rate: int = 0

# Buffos permanentes aplicados (para tracking)
var permanent_buffs: Array = []  # Array de {type, value, source}

func _init():
	# Guardar stats base al crear
	base_attack = attack
	base_defense = defense
	base_max_hp = max_hp
	base_rate = rate

func initialize_base_stats() -> void:
	"""Inicializa los stats base después de cargar desde JSON"""
	base_attack = attack
	base_defense = defense
	base_max_hp = max_hp
	base_rate = rate

func apply_permanent_buff(stat_type: String, value: int, source: String = "unknown") -> void:
	"""Aplica un buff permanente que dura el resto de la run"""
	match stat_type:
		"attack":
			attack += value
		"defense":
			defense += value
		"max_hp":
			max_hp += value
			hp += value  # También aumentar HP actual
		"rate":
			rate += value
	
	permanent_buffs.append({
		"type": stat_type,
		"value": value,
		"source": source
	})

func get_permanent_buff_total(stat_type: String) -> int:
	"""Retorna el total de buffos permanentes para un stat"""
	var total = 0
	for buff in permanent_buffs:
		if buff.get("type") == stat_type:
			total += buff.get("value", 0)
	return total

func reset_to_base_stats() -> void:
	"""Resetea los stats a sus valores base (para nueva run)"""
	attack = base_attack
	defense = base_defense
	max_hp = base_max_hp
	hp = max_hp
	rate = base_rate
	permanent_buffs.clear()
