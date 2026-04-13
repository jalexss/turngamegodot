## RegisterForm.gd - Formulario de registro especializado
## Extiende BaseForm con lógica específica de registro
extends BaseForm

class_name RegisterForm

# ============================================================================
# SEÑALES
# ============================================================================

signal register_attempt(username: String, email: String, password: String)

# ============================================================================
# NODOS
# ============================================================================

var _username_input: BaseInput
var _email_input: EmailInput
var _password_input: PasswordInput
var _confirm_password_input: PasswordInput

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	# Buscar inputs por nombre
	_username_input = find_child("UsernameInput", true, false)
	_email_input = find_child("EmailInput", true, false)
	_password_input = find_child("PasswordInput", true, false)
	_confirm_password_input = find_child("ConfirmPasswordInput", true, false)
	
	super()

func _on_submit_button_pressed() -> void:
	"""Override: al hacer submit, validar y emitir register_attempt"""
	if validate_all() and _validate_passwords_match():
		register_attempt.emit(
			_username_input.text,
			_email_input.text,
			_password_input.text
		)
		if _submit_button:
			_submit_button.set_loading()
	else:
		if _submit_button:
			_submit_button.set_error(0.5)

# ============================================================================
# MÉTODOS PÚBLICOS
# ============================================================================

## Obtiene el nombre de usuario
func get_username() -> String:
	return _username_input.text if _username_input else ""

## Obtiene el email
func get_email() -> String:
	return _email_input.text if _email_input else ""

## Obtiene la contraseña
func get_password() -> String:
	return _password_input.text if _password_input else ""

## Indica que el registro fue exitoso
func set_register_success() -> void:
	if _submit_button:
		_submit_button.set_success(0.5)
	clear_form()

## Indica que el registro falló con error
func set_register_error(error_message: String) -> void:
	if _submit_button:
		_submit_button.set_error(2.0)
	
	# Mostrar error en el username input (campo principal)
	if _username_input:
		_username_input.set_error(error_message)

# ============================================================================
# MÉTODOS PRIVADOS
# ============================================================================

func _validate_passwords_match() -> bool:
	"""Valida que las dos contraseñas coincidan"""
	if not _password_input or not _confirm_password_input:
		return true  # Si no hay inputs, asumir que es válido
	
	if _password_input.text != _confirm_password_input.text:
		if _confirm_password_input:
			_confirm_password_input.set_error("Las contraseñas no coinciden")
		return false
	
	return true
