## BaseInput.gd - Clase base para campos de entrada con validación
## Extiende LineEdit con validación integrada y estados visuales
extends LineEdit

class_name BaseInput

# ============================================================================
# SIGNALS
# ============================================================================

signal validation_changed(is_valid: bool)
signal value_submitted(value: String)

# ============================================================================
# PROPIEDADES
# ============================================================================

@export var placeholder_text_color: Color = Color(0.6, 0.6, 0.6, 0.7)
@export var error_color: Color = Color(0.9, 0.3, 0.3, 1.0)
@export var success_color: Color = Color(0.3, 0.9, 0.3, 1.0)
@export var normal_color: Color = Color(1.0, 1.0, 1.0, 1.0)

# ============================================================================
# MIEMBROS
# ============================================================================

var _is_valid: bool = false
var _validation_message: String = ""

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	# Conectar señales de edición
	text_changed.connect(_on_text_changed)
	text_submitted.connect(_on_text_submitted)
	focus_exited.connect(_on_focus_exited)

# ============================================================================
# MÉTODOS PÚBLICOS - VALIDACIÓN
# ============================================================================

## Realiza validación del contenido actual
## Retorna true si es válido, false si no
func validate() -> bool:
	_is_valid = _is_valid_impl()
	validation_changed.emit(_is_valid)
	_update_visual_state()
	return _is_valid

## Obtiene si el input es válido
func is_valid() -> bool:
	return _is_valid

## Obtiene el mensaje de validación
func get_validation_message() -> String:
	return _validation_message

## Marca el input como error con mensaje
func set_error(message: String) -> void:
	_validation_message = message
	_is_valid = false
	_update_visual_state()
	validation_changed.emit(false)

## Marca el input como correcto
func set_success() -> void:
	_validation_message = ""
	_is_valid = true
	_update_visual_state()
	validation_changed.emit(true)

## Limpia el estado de validación
func clear_validation() -> void:
	_validation_message = ""
	_is_valid = false
	modulate = Color.WHITE

# ============================================================================
# MÉTODOS PRIVADOS - OVERRIDE PARA SUBCLASES
# ============================================================================

## Implementación específica de validación (override en subclases)
## Por defecto, un input simple es válido si no está vacío
func _is_valid_impl() -> bool:
	_validation_message = ""
	
	if text.is_empty():
		_validation_message = "Campo requerido"
		return false
	
	if text.length() < 3:
		_validation_message = "Mínimo 3 caracteres"
		return false
	
	return true

## Actualiza el estado visual basado en validación
func _update_visual_state() -> void:
	if _is_valid:
		add_theme_color_override("font_color", success_color)
	elif _validation_message:
		add_theme_color_override("font_color", error_color)
	else:
		add_theme_color_override("font_color", normal_color)

# ============================================================================
# CALLBACKS - EVENTOS
# ============================================================================

func _on_text_changed(_new_text: String) -> void:
	# Re-validar en tiempo real (opcional, dependiendo del caso de uso)
	pass

func _on_text_submitted(_new_text: String) -> void:
	validate()
	if _is_valid:
		value_submitted.emit(text)

func _on_focus_exited() -> void:
	validate()
