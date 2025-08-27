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
