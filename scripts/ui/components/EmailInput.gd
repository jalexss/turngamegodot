## EmailInput.gd - Input de email con validación específica
## Extiende BaseInput con validación de formato email
extends BaseInput

class_name EmailInput

# Patrón simple de email (no es RFC5322 completo, pero funciona)
const EMAIL_PATTERN = "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$"

func _ready() -> void:
	placeholder_text = "tu@email.com"
	super()

## Implementación especifica: validar formato email
func _is_valid_impl() -> bool:
	_validation_message = ""
	
	if text.is_empty():
		_validation_message = "Email requerido"
		return false
	
	# Usar RegEx para validar formato
	var regex = RegEx.new()
	regex.compile(EMAIL_PATTERN)
	
	if not regex.search(text):
		_validation_message = "Email inválido"
		return false
	
	return true
