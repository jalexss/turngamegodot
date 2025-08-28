extends Control

# Referencias a nodos hijos
@onready var background: ColorRect = $Background
@onready var modal_panel: Panel = $ModalPanel
@onready var title_label: Label = $ModalPanel/Content/Header/TitleLabel
@onready var close_button: Button = $ModalPanel/Content/Header/CloseButton
@onready var grid_container: GridContainer = $ModalPanel/Content/CardGrid/GridContainer

# Señales
signal modal_closed
signal card_selected(card_data)

# Variables
var cards_data: Array = []

func _ready() -> void:
	"""Inicializa el modal"""
	print("🗑️ DiscardModal inicializado")
	
	# Conectar señales
	if close_button:
		close_button.pressed.connect(_on_close_button_pressed)
	
	if background:
		background.gui_input.connect(_on_background_input)
	
	# Inicialmente oculto
	visible = false

func show_modal(cards: Array) -> void:
	"""Muestra el modal con las cartas del descarte"""
	print("🗑️ Mostrando modal del descarte con ", cards.size(), " cartas")
	
	cards_data = cards
	_update_title()
	_populate_card_grid()
	
	# Mostrar modal
	visible = true
	
	# Traer al frente
	z_index = 100

func hide_modal() -> void:
	"""Oculta el modal"""
	print("🗑️ Ocultando modal del descarte")
	visible = false
	modal_closed.emit()

func _update_title() -> void:
	"""Actualiza el título con el número de cartas"""
	if title_label:
		title_label.text = "🗑️ DESCARTE (%d cartas)" % cards_data.size()

func _populate_card_grid() -> void:
	"""Llena el grid con las cartas del descarte"""
	print("🗑️ Poblando grid con ", cards_data.size(), " cartas")
	
	# Limpiar grid existente
	_clear_grid()
	
	# Agregar cartas al grid
	for i in range(cards_data.size()):
		var card_data = cards_data[i]
		var card_panel = _create_card_panel(card_data, i)
		grid_container.add_child(card_panel)

func _clear_grid() -> void:
	"""Limpia todas las cartas del grid"""
	if grid_container:
		for child in grid_container.get_children():
			child.queue_free()

func _create_card_panel(card_data, index: int) -> Panel:
	"""Crea un panel visual para una carta del descarte"""
	var card_panel = Panel.new()
	card_panel.custom_minimum_size = Vector2(150, 200)
	
	# Estilo del panel (más rojizo para descarte)
	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(0.4, 0.2, 0.2, 0.9)
	card_style.corner_radius_top_left = 8
	card_style.corner_radius_top_right = 8
	card_style.corner_radius_bottom_left = 8
	card_style.corner_radius_bottom_right = 8
	card_style.border_width_left = 2
	card_style.border_width_right = 2
	card_style.border_width_top = 2
	card_style.border_width_bottom = 2
	card_style.border_color = Color(0.7, 0.4, 0.4, 1.0)
	card_panel.add_theme_stylebox_override("panel", card_style)
	
	# Hacer la carta clickeable
	card_panel.gui_input.connect(_on_card_clicked.bind(card_data, index))
	
	# Contenedor vertical para la información de la carta
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 5)
	card_panel.add_child(vbox)
	
	# Nombre de la carta
	var name_label = Label.new()
	name_label.text = card_data.name if card_data.has_method("get") else str(card_data)
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(name_label)
	
	# Costo de energía
	var cost_label = Label.new()
	var cost = card_data.cost if card_data.has_method("get") else 0
	cost_label.text = "⚡ " + str(cost)
	cost_label.add_theme_font_size_override("font_size", 10)
	cost_label.add_theme_color_override("font_color", Color.YELLOW)
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(cost_label)
	
	# Tipo de carta
	var type_label = Label.new()
	var card_type = card_data.card_type if card_data.has_method("get") else "UNKNOWN"
	type_label.text = str(card_type)
	type_label.add_theme_font_size_override("font_size", 9)
	type_label.add_theme_color_override("font_color", Color.CYAN)
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(type_label)
	
	# Poder/Efecto
	var power_label = Label.new()
	var power = card_data.power if card_data.has_method("get") else 0
	power_label.text = "💥 " + str(power)
	power_label.add_theme_font_size_override("font_size", 10)
	power_label.add_theme_color_override("font_color", Color.RED)
	power_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(power_label)
	
	# Descripción (truncada)
	var desc_label = Label.new()
	var description = card_data.description if card_data.has_method("get") else ""
	if description.length() > 50:
		description = description.substr(0, 47) + "..."
	desc_label.text = description
	desc_label.add_theme_font_size_override("font_size", 8)
	desc_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(desc_label)
	
	# Indicador de que es clickeable
	var click_hint = Label.new()
	click_hint.text = "🖱️ Click para recuperar"
	click_hint.add_theme_font_size_override("font_size", 7)
	click_hint.add_theme_color_override("font_color", Color.LIGHT_GREEN)
	click_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(click_hint)
	
	return card_panel

# --- CALLBACKS ---

func _on_close_button_pressed() -> void:
	"""Callback para el botón de cerrar"""
	print("🗑️ Botón cerrar presionado")
	hide_modal()

func _on_background_input(event: InputEvent) -> void:
	"""Callback para clicks en el fondo"""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("🗑️ Click en fondo - cerrando modal")
		hide_modal()

func _on_card_clicked(card_data, _index: int, event: InputEvent) -> void:
	"""Callback cuando se hace click en una carta"""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("🗑️ Carta clickeada: ", card_data.name if card_data.has_method("get") else str(card_data))
		card_selected.emit(card_data)
		hide_modal()

# --- FUNCIONES DE UTILIDAD ---

func _input(event: InputEvent) -> void:
	"""Maneja input global (ESC para cerrar)"""
	if visible and event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			print("🗑️ ESC presionado - cerrando modal")
			hide_modal()
