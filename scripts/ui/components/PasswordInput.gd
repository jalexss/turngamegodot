## PasswordInput.gd - Input de contraseña con validación y toggle visible
## Extiende BaseInput con validación de contraseña y botón show/hide
extends BaseInput

class_name PasswordInput

# ============================================================================
# MIEMBROS
# ============================================================================

var _show_password: bool = false

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	placeholder_text = "Contraseña"
	secret = true  # Ocultar caracteres por defecto
	super()

## Implementación específica: validar contraseña
func _is_valid_impl() -> bool:
	_validation_message = ""
	
	if text.is_empty():
		_validation_message = "Contraseña requerida"
		return false
	
	if text.length() < 6:
		_validation_message = "Mínimo 6 caracteres"
		return false
	
	return true

## Toggle para mostrar/ocultar contraseña
func toggle_visibility() -> void:
	_show_password = not _show_password
	secret = not _show_password

## Obtiene si la contraseña es visible
func is_password_visible() -> bool:
	return _show_password
