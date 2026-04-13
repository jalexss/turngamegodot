## PrimaryButton.gd - Botón con estados (loading, disabled, normal)
## Manaja feedback visual para operaciones asincrónicas
extends Button

class_name PrimaryButton

# ============================================================================
# ENUMS
# ============================================================================

enum ButtonState {
	NORMAL,      # Estado normal
	LOADING,     # Operación en progreso
	DISABLED,    # Deshabilitado
	SUCCESS,     # Operación exitosa (feedback visual corto)
	ERROR        # Error en operación (feedback visual)
}

# ============================================================================
# PROPIEDADES
# ============================================================================

@export var loading_text: String = "Cargando..."
@export var success_text: String = "✓ Éxito"
@export var error_text: String = "✗ Error"

@export var normal_color: Color = Color(0.2, 0.6, 1.0, 1.0)
@export var loading_color: Color = Color(1.0, 0.8, 0.0, 1.0)
@export var success_color: Color = Color(0.2, 1.0, 0.3, 1.0)
@export var error_color: Color = Color(1.0, 0.3, 0.3, 1.0)
@export var disabled_color: Color = Color(0.5, 0.5, 0.5, 1.0)

# ============================================================================
# MIEMBROS
# ============================================================================

var _current_state: ButtonState = ButtonState.NORMAL
var _original_text: String = ""
var _state_timer: Timer = null
var _can_interact: bool = true

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	_original_text = text
	_update_visual_state()
	
	# Crear timer para revertir estados temporales
	_state_timer = Timer.new()
	add_child(_state_timer)
	_state_timer.one_shot = true
	_state_timer.timeout.connect(_on_state_timer_timeout)

func _exit_tree() -> void:
	if _state_timer:
		_state_timer.queue_free()

# ============================================================================
# MÉTODOS PÚBLICOS - ESTADO
# ============================================================================

## Obtiene el estado actual del botón
func get_state() -> ButtonState:
	return _current_state

## Establece el estado del botón a LOADING (cargando)
func set_loading() -> void:
	_set_state(ButtonState.LOADING)
	disabled = true
	_can_interact = false

## Establece el estado del botón a NORMAL
func set_normal() -> void:
	_set_state(ButtonState.NORMAL)
	disabled = false
	_can_interact = true

## Establece el estado del botón a DISABLED (deshabilitado)
func set_button_disabled(show_feedback: bool = false) -> void:
	_set_state(ButtonState.DISABLED if show_feedback else ButtonState.NORMAL)
	disabled = true
	_can_interact = false

## Establece el estado del botón a SUCCESS (éxito)
## revert_after_seconds > 0: revierte a NORMAL después de X segundos
func set_success(revert_after_seconds: float = 2.0) -> void:
	_set_state(ButtonState.SUCCESS)
	disabled = true
	
	if revert_after_seconds > 0:
		_state_timer.wait_time = revert_after_seconds
		_state_timer.start()

## Establece el estado del botón a ERROR (error)
## revert_after_seconds > 0: revierte a NORMAL después de X segundos
func set_error(revert_after_seconds: float = 2.0) -> void:
	_set_state(ButtonState.ERROR)
	disabled = true
	_can_interact = false
	
	if revert_after_seconds > 0:
		_state_timer.wait_time = revert_after_seconds
		_state_timer.start()

## Verifica si el botón puede interactuar
func can_interact() -> bool:
	return _can_interact

# ============================================================================
# MÉTODOS PRIVADOS
# ============================================================================

func _set_state(new_state: ButtonState) -> void:
	_current_state = new_state
	_update_visual_state()

func _update_visual_state() -> void:
	match _current_state:
		ButtonState.NORMAL:
			text = _original_text
			add_theme_color_override("font_color", Color.WHITE)
			add_theme_color_override("modulate", normal_color)
		
		ButtonState.LOADING:
			text = loading_text
			add_theme_color_override("font_color", Color.WHITE)
			add_theme_color_override("modulate", loading_color)
		
		ButtonState.SUCCESS:
			text = success_text
			add_theme_color_override("font_color", Color.WHITE)
			add_theme_color_override("modulate", success_color)
		
		ButtonState.ERROR:
			text = error_text
			add_theme_color_override("font_color", Color.WHITE)
			add_theme_color_override("modulate", error_color)
		
		ButtonState.DISABLED:
			text = _original_text
			add_theme_color_override("font_color", Color.WHITE)
			add_theme_color_override("modulate", disabled_color)

func _on_state_timer_timeout() -> void:
	set_normal()
