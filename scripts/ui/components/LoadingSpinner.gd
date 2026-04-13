## LoadingSpinner.gd - Animación de carga visual
## Muestra rotación continua mientras está activa
extends Control

class_name LoadingSpinner

# ============================================================================
# PROPIEDADES
# ============================================================================

@export var spinner_color: Color = Color(0.2, 0.6, 1.0, 1.0)
@export var spinner_size: float = 40.0
@export var rotation_speed: float = 3.0  # revoluciones por segundo
@export var line_width: float = 3.0

@export var show_text: bool = true
@export var spinner_text: String = "Cargando..."
@export var text_color: Color = Color(0.7, 0.7, 0.7, 1.0)

# ============================================================================
# MIEMBROS
# ============================================================================

var _is_spinning: bool = false
var _rotation_angle: float = 0.0
var _label: Label = null

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	custom_minimum_size = Vector2(spinner_size * 2, spinner_size * 2 + (40 if show_text else 0))
	
	# Crear label si se muestra texto
	if show_text:
		_label = Label.new()
		_label.text = spinner_text
		_label.add_theme_color_override("font_color", text_color)
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(_label)

func _process(delta: float) -> void:
	if _is_spinning:
		_rotation_angle += rotation_speed * 360.0 * delta
		queue_redraw()

# ============================================================================
# MÉTODOS PÚBLICOS
# ============================================================================

## Inicia la animación de carga
func start_spinning() -> void:
	_is_spinning = true
	visible = true

## Detiene la animación de carga
func stop_spinning() -> void:
	_is_spinning = false
	visible = false

## Alterna estado de spinning
func toggle_spinning() -> void:
	if _is_spinning:
		stop_spinning()
	else:
		start_spinning()

## Establece el texto mostrado
func set_text(new_text: String) -> void:
	spinner_text = new_text
	if _label:
		_label.text = new_text

# ============================================================================
# DIBUJO
# ============================================================================

func _draw() -> void:
	if not _is_spinning:
		return
	
	var center = Vector2(spinner_size, spinner_size)
	var radius = spinner_size * 0.4
	
	# Dibujar un arc de círculo (las 3/4 partes) que rota
	# Simulamos esto dibujando varios arcos pequeños
	var arc_length = TAU * 0.75  # 270 grados
	var segments = 20
	
	for i in range(segments):
		var angle1 = (i / float(segments)) * arc_length + deg_to_rad(_rotation_angle)
		var angle2 = ((i + 1) / float(segments)) * arc_length + deg_to_rad(_rotation_angle)
		
		var point1 = center + Vector2(cos(angle1), sin(angle1)) * radius
		var point2 = center + Vector2(cos(angle2), sin(angle2)) * radius
		
		# Fade out del color según progreso
		var fade = 1.0 - (i / float(segments))
		var color = spinner_color
		color.a = fade * 0.8
		
		draw_line(point1, point2, color, line_width)
