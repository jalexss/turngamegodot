## BaseForm.gd - Clase base para formularios con validación grupal
## Maneja múltiples inputs y validación combinada
extends Control

class_name BaseForm

# ============================================================================
# SIGNALS
# ============================================================================

signal form_submitted(form_data: Dictionary)
signal validation_state_changed(is_valid: bool)

# ============================================================================
# MIEMBROS
# ============================================================================

var _inputs: Array[BaseInput] = []
var _submit_button: PrimaryButton = null
var _is_valid: bool = false

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	_collect_inputs()
	_setup_input_connections()

# ============================================================================
# MÉTODOS PÚBLICOS - SETUP
# ============================================================================

## Registra un input para ser monitoreado
func register_input(input: BaseInput) -> void:
	if not _inputs.has(input):
		_inputs.append(input)
		input.validation_changed.connect(_on_input_validation_changed)

## Registra el botón de submit
func register_submit_button(button: PrimaryButton) -> void:
	_submit_button = button
	if button:
		button.pressed.connect(_on_submit_button_pressed)

# ============================================================================
# MÉTODOS PÚBLICOS - VALIDACIÓN
# ============================================================================

## Valida todos los inputs
## Retorna true si todos son válidos
func validate_all() -> bool:
	_is_valid = true
	
	for input in _inputs:
		if not input.validate():
			_is_valid = false
	
	validation_state_changed.emit(_is_valid)
	return _is_valid

## Obtiene si el formulario es válido
func is_valid() -> bool:
	return _is_valid

## Obtiene los datos del formulario como diccionario
func get_form_data() -> Dictionary:
	var data = {}
	for input in _inputs:
		data[input.name] = input.text
	return data

## Limpia todos los inputs
func clear_form() -> void:
	for input in _inputs:
		input.text = ""
		input.clear_validation()
	_is_valid = false

## Muestra error en un input específico
func set_input_error(input_name: String, message: String) -> void:
	for input in _inputs:
		if input.name == input_name:
			input.set_error(message)
			break

# ============================================================================
# MÉTODOS PRIVADOS
# ============================================================================

func _collect_inputs() -> void:
	"""Busca todos los BaseInput hijos automáticamente"""
	_inputs.clear()
	
	var all_inputs = get_all_base_inputs(self)
	for input in all_inputs:
		_inputs.append(input)

func get_all_base_inputs(node: Node) -> Array[BaseInput]:
	var inputs: Array[BaseInput] = []
	
	for child in node.get_children():
		if child is BaseInput:
			inputs.append(child)
		
		# Buscar recursivamente
		var sub_inputs = get_all_base_inputs(child)
		inputs.append_array(sub_inputs)
	
	return inputs

func _setup_input_connections() -> void:
	"""Conecta señales de todos los inputs"""
	for input in _inputs:
		input.validation_changed.connect(_on_input_validation_changed)

# ============================================================================
# CALLBACKS
# ============================================================================

func _on_input_validation_changed(_validation_state: bool) -> void:
	"""Se llama cuando cualquier input cambia su estado de validación"""
	_update_submit_button_state()

func _on_submit_button_pressed() -> void:
	"""Se llama cuando se presiona el botón de submit"""
	if validate_all():
		form_submitted.emit(get_form_data())
	else:
		if _submit_button:
			_submit_button.set_error(0.5)

func _update_submit_button_state() -> void:
	"""Actualiza el estado del botón de submit basado en validación"""
	if not _submit_button:
		return
	
	# Comprobar si algún input es inválido
	var all_valid = true
	for input in _inputs:
		if input.text.is_empty() or input._validation_message != "":
			all_valid = false
			break
	
	_submit_button.disabled = not all_valid
