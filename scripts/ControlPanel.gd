extends Control

# Referencias a botones
@onready var test_button: Button = $ButtonsContainer/TopRow/TestButton
@onready var energy_button: Button = $ButtonsContainer/TopRow/EnergyButton
@onready var end_turn_button: Button = $ButtonsContainer/TopRow/EndTurnButton
@onready var deck_button: Button = $ButtonsContainer/BottomRow/DeckButton
@onready var overflow_button: Button = $ButtonsContainer/BottomRow/OverflowButton
@onready var discard_button: Button = $ButtonsContainer/BottomRow/DiscardButton

# Señales para comunicarse con GameUI
signal test_card_requested
signal energy_boost_requested
signal end_turn_requested
signal deck_view_requested
signal overflow_cards_requested
signal discard_view_requested

# Variables de estado
var deck_count: int = 0
var overflow_count: int = 0
var discard_count: int = 0

func _ready() -> void:
	"""Inicializa el ControlPanel"""
	print("🎮 ControlPanel inicializado")
	
	# Conectar señales de botones
	_connect_button_signals()
	
	# Actualizar displays iniciales
	_update_button_displays()
	
	print("✅ ControlPanel configurado correctamente")

func _connect_button_signals() -> void:
	"""Conecta las señales de todos los botones"""
	if test_button:
		test_button.pressed.connect(_on_test_button_pressed)
	
	if energy_button:
		energy_button.pressed.connect(_on_energy_button_pressed)
	
	if end_turn_button:
		end_turn_button.pressed.connect(_on_end_turn_button_pressed)
	
	if deck_button:
		deck_button.pressed.connect(_on_deck_button_pressed)
	
	if overflow_button:
		overflow_button.pressed.connect(_on_overflow_button_pressed)
	
	if discard_button:
		discard_button.pressed.connect(_on_discard_button_pressed)

# --- FUNCIONES PÚBLICAS PARA GAMEUI ---

func update_deck_count(count: int) -> void:
	"""Actualiza el contador del botón de mazo"""
	deck_count = count
	if deck_button:
		deck_button.text = "📚 Mazo (%d)" % count

func update_overflow_count(count: int) -> void:
	"""Actualiza el contador del botón de overflow"""
	overflow_count = count
	if overflow_button:
		overflow_button.text = "📥 +%d" % count
		overflow_button.visible = count > 0  # Solo mostrar si hay cartas pendientes

func update_discard_count(count: int) -> void:
	"""Actualiza el contador del botón de descarte"""
	discard_count = count
	if discard_button:
		discard_button.text = "🗑️ %d" % count

func set_buttons_enabled(enabled: bool) -> void:
	"""Habilita/deshabilita todos los botones"""
	if test_button:
		test_button.disabled = not enabled
	if energy_button:
		energy_button.disabled = not enabled
	if end_turn_button:
		end_turn_button.disabled = not enabled
	if deck_button:
		deck_button.disabled = not enabled
	if overflow_button:
		overflow_button.disabled = not enabled
	if discard_button:
		discard_button.disabled = not enabled

func set_end_turn_enabled(enabled: bool) -> void:
	"""Habilita/deshabilita específicamente el botón de terminar turno"""
	if end_turn_button:
		end_turn_button.disabled = not enabled
		end_turn_button.modulate = Color.WHITE if enabled else Color(0.5, 0.5, 0.5)

func set_test_buttons_visible(show_buttons: bool) -> void:
	"""Muestra/oculta los botones de prueba (test y energy)"""
	if test_button:
		test_button.visible = show_buttons
	if energy_button:
		energy_button.visible = show_buttons

func _update_button_displays() -> void:
	"""Actualiza todos los displays de botones"""
	update_deck_count(deck_count)
	update_overflow_count(overflow_count)
	update_discard_count(discard_count)

# --- CALLBACKS DE BOTONES ---

func _on_test_button_pressed() -> void:
	"""Callback para el botón de test"""
	print("🧪 ControlPanel: Botón de test presionado")
	test_card_requested.emit()

func _on_energy_button_pressed() -> void:
	"""Callback para el botón de energía"""
	print("⚡ ControlPanel: Botón de energía presionado")
	energy_boost_requested.emit()

func _on_end_turn_button_pressed() -> void:
	"""Callback para el botón de terminar turno"""
	print("🔄 ControlPanel: Botón de terminar turno presionado")
	end_turn_requested.emit()

func _on_deck_button_pressed() -> void:
	"""Callback para el botón del mazo"""
	print("📚 ControlPanel: Botón del mazo presionado")
	deck_view_requested.emit()

func _on_overflow_button_pressed() -> void:
	"""Callback para el botón de overflow"""
	print("📥 ControlPanel: Botón de overflow presionado")
	overflow_cards_requested.emit()

func _on_discard_button_pressed() -> void:
	"""Callback para el botón de descarte"""
	print("🗑️ ControlPanel: Botón de descarte presionado")
	discard_view_requested.emit()
