## LoginForm.gd - Formulario de login especializado
## Extiende BaseForm con lógica específica de login
extends BaseForm

class_name LoginForm

# ============================================================================
# SEÑALES
# ============================================================================

signal login_attempt(identity: String, password: String)

# ============================================================================
# NODOS
# ============================================================================

# Estos se asignan en _ready() buscándolos en la escena
var _identity_input: BaseInput
var _password_input: PasswordInput

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	# Buscar inputs por nombre
	_identity_input = find_child("IdentityInput", true, false)
	_password_input = find_child("PasswordInput", true, false)
	
	super()

func _on_submit_button_pressed() -> void:
	"""Override: al hacer submit, emitir login_attempt en lugar de form_submitted"""
	if validate_all():
		login_attempt.emit(_identity_input.text, _password_input.text)
		if _submit_button:
			_submit_button.set_loading()
	else:
		if _submit_button:
			_submit_button.set_error(0.5)

# ============================================================================
# MÉTODOS PÚBLICOS
# ============================================================================

## Obtiene el identity (email o username)
func get_identity() -> String:
	return _identity_input.text if _identity_input else ""

## Obtiene la contraseña
func get_password() -> String:
	return _password_input.text if _password_input else ""

## Indica que el login fue exitoso
func set_login_success() -> void:
	if _submit_button:
		_submit_button.set_success(0.5)
	clear_form()

## Indica que el login falló con error
func set_login_error(error_message: String) -> void:
	if _submit_button:
		_submit_button.set_error(2.0)
	
	# Mostrar error en el identity input
	if _identity_input:
		_identity_input.set_error(error_message)
