extends Control

# Señal que se emitirá cuando se haga clic en este personaje.
# Enviará sus propios datos para que el juego sepa quién fue clickeado.
signal character_clicked(character_data)

# Nodos de la escena
@onready var name_label = $VBoxContainer/NameLabel
@onready var health_bar = $VBoxContainer/HealthBar
@onready var portrait = $Portrait
@onready var hover_effect = $HoverEffect

var character_data: CharacterData

func _ready():
    # Conectar las señales del ratón a nuestras funciones
    mouse_entered.connect(_on_mouse_entered)
    mouse_exited.connect(_on_mouse_exited)
    
    # Ocultar el efecto de hover al inicio
    hover_effect.visible = false

# Función pública para que GameUI nos envíe los datos del personaje
func set_character_data(data: CharacterData):
    character_data = data
    
    # Actualizar la UI con los datos recibidos
    name_label.text = character_data.name
    health_bar.max_value = character_data.max_hp
    health_bar.value = character_data.hp
    
    # ¡Aquí está la clave para que el sprite aparezca!
    if character_data.portrait:
        portrait.texture = character_data.portrait
    else:
        portrait.texture = null # Limpiar si no hay retrato

# --- MANEJO DE INTERACTIVIDAD ---

# Se llama cuando el ratón entra en el área del Control
func _on_mouse_entered():
    hover_effect.visible = true

# Se llama cuando el ratón sale del área
func _on_mouse_exited():
    hover_effect.visible = false

# Se llama para cualquier evento de input dentro del área del Control
func _on_gui_input(event: InputEvent):
    # Comprobar si el evento es un clic izquierdo del ratón
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
        # Emitir la señal con nuestros datos
        emit_signal("character_clicked", character_data)
        print("Has hecho clic en: ", character_data.name)