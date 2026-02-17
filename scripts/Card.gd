extends Node2D

var data: CardData
var is_being_dragged: bool = false
var drag_offset: Vector2 = Vector2.ZERO

# --- CONSTANTS ---
const CARD_SIZE := Vector2(180, 260)

const ROLE_COLORS := {
	"CARRY": Color(0.9, 0.2, 0.2),    # Red
	"HEALER": Color(0.2, 0.8, 0.3),   # Green
	"SUPPORT": Color(0.2, 0.8, 0.3),  # Green (alias for healer)
	"TANK": Color(0.3, 0.5, 0.9)      # Blue
}

const EFFECT_CONFIG := {
	"DAMAGE": {"icon": "⚔", "color": Color(0.9, 0.2, 0.2)},
	"SHIELD": {"icon": "🛡", "color": Color(0.3, 0.5, 0.9)},
	"HEAL": {"icon": "❤", "color": Color(0.2, 0.8, 0.3)},
	"BUFF": {"icon": "✨", "color": Color(1.0, 0.9, 0.2)},
	"DEBUFF": {"icon": "💀", "color": Color(0.6, 0.2, 0.8)},
	"DRAW": {"icon": "🎴", "color": Color(0.2, 0.8, 0.8)},
	"APPLY_STATUS": {"icon": "⚡", "color": Color(0.8, 0.4, 0.1)},
	"DISCARD": {"icon": "🗑", "color": Color(0.5, 0.5, 0.5)}
}

const CARD_TYPE_COLORS := {
	CardData.CardType.ATTACK: Color(0.15, 0.08, 0.08),
	CardData.CardType.DEFENSE: Color(0.08, 0.08, 0.15),
	CardData.CardType.HEAL: Color(0.08, 0.15, 0.08),
	CardData.CardType.BUFF: Color(0.15, 0.14, 0.05),
	CardData.CardType.DEBUFF: Color(0.12, 0.06, 0.15),
	CardData.CardType.DRAW: Color(0.08, 0.12, 0.12),
	CardData.CardType.STATUS: Color(0.12, 0.08, 0.05),
	CardData.CardType.SPECIAL: Color(0.15, 0.12, 0.05),
	CardData.CardType.UTILITY: Color(0.1, 0.1, 0.1)
}

const CARD_TYPE_BORDER_COLORS := {
	CardData.CardType.ATTACK: Color(0.9, 0.2, 0.2),
	CardData.CardType.DEFENSE: Color(0.3, 0.5, 0.9),
	CardData.CardType.HEAL: Color(0.2, 0.8, 0.3),
	CardData.CardType.BUFF: Color(1.0, 0.9, 0.2),
	CardData.CardType.DEBUFF: Color(0.6, 0.2, 0.8),
	CardData.CardType.DRAW: Color(0.2, 0.8, 0.8),
	CardData.CardType.STATUS: Color(0.8, 0.4, 0.1),
	CardData.CardType.SPECIAL: Color(1.0, 0.8, 0.2),
	CardData.CardType.UTILITY: Color(0.6, 0.6, 0.6)
}

# Node references
var card_panel: Panel
var artwork_area: TextureRect
var title_label: Label
var energy_cost_container: Control
var energy_circle: Panel
var energy_cost_label: Label
var role_indicator_container: HBoxContainer
var description_label: Label
var effects_row: HBoxContainer

# Portrait cache
var _portrait_cache: Dictionary = {}

func _ready() -> void:
	_cache_node_references()
	if data:
		_update_card_display()

func _cache_node_references() -> void:
	card_panel = get_node_or_null("CardPanel")
	if card_panel:
		artwork_area = card_panel.get_node_or_null("ArtworkArea")
		title_label = card_panel.get_node_or_null("TitlePanel/TitleLabel")
		energy_cost_container = card_panel.get_node_or_null("EnergyCostContainer")
		if energy_cost_container:
			energy_circle = energy_cost_container.get_node_or_null("EnergyCircle")
			energy_cost_label = energy_cost_container.get_node_or_null("EnergyCircle/EnergyCostLabel")
		role_indicator_container = card_panel.get_node_or_null("RoleIndicatorContainer")
		description_label = card_panel.get_node_or_null("DescriptionPanel/DescriptionLabel")
		effects_row = card_panel.get_node_or_null("EffectsRow")

func set_data(d: CardData) -> void:
	data = d
	if is_inside_tree():
		_update_card_display()

func _update_card_display() -> void:
	if not data:
		return
	
	if not card_panel:
		_cache_node_references()
	
	if not card_panel:
		push_warning("Card: CardPanel not found")
		return
	
	_apply_card_type_styling()
	_setup_title()
	_setup_description()
	_setup_energy_cost()
	_setup_artwork()
	_setup_role_indicators()
	_setup_effects_row()

# --- STYLING ---
func _apply_card_type_styling() -> void:
	var bg_color = CARD_TYPE_COLORS.get(data.card_type, Color(0.1, 0.1, 0.1))
	var border_color = CARD_TYPE_BORDER_COLORS.get(data.card_type, Color(0.5, 0.5, 0.5))
	
	# Create StyleBoxFlat for card background
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	card_panel.add_theme_stylebox_override("panel", style)

# --- TITLE ---
func _setup_title() -> void:
	if title_label:
		title_label.text = _truncate_text(data.name, 20)

func _truncate_text(text: String, max_chars: int) -> String:
	if text.length() <= max_chars:
		return text
	return text.substr(0, max_chars - 2) + ".."

# --- DESCRIPTION ---
func _setup_description() -> void:
	if description_label:
		description_label.text = data.description

# --- ENERGY COST ---
func _setup_energy_cost() -> void:
	if not energy_cost_container:
		return
	
	if data.cost > 0:
		energy_cost_container.visible = true
		if energy_cost_label:
			energy_cost_label.text = str(data.cost)
		if energy_circle:
			var style = StyleBoxFlat.new()
			style.bg_color = Color(0.2, 0.4, 0.8)
			style.set_corner_radius_all(20)
			energy_circle.add_theme_stylebox_override("panel", style)
	else:
		energy_cost_container.visible = false

# --- ARTWORK ---
func _setup_artwork() -> void:
	if not artwork_area:
		return
	
	if data.artwork:
		artwork_area.texture = data.artwork
	else:
		var color = CARD_TYPE_BORDER_COLORS.get(data.card_type, Color(0.5, 0.5, 0.5))
		artwork_area.texture = _make_gradient_texture(color, Vector2(160, 100))

func _make_gradient_texture(base_color: Color, size: Vector2) -> ImageTexture:
	var w := int(size.x)
	var h := int(size.y)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	
	for y in range(h):
		for x in range(w):
			var t := float(y) / float(h)
			var color := base_color.darkened(t * 0.5)
			img.set_pixel(x, y, color)
	
	return ImageTexture.create_from_image(img)

# --- ROLE INDICATORS ---
func _setup_role_indicators() -> void:
	if not role_indicator_container:
		return
	
	# Clear existing indicators
	for child in role_indicator_container.get_children():
		child.queue_free()
	
	# Check if card has character/role requirements
	var required_role = data.required_character_role if data.required_character_role != "" else ""
	var required_char_id = data.required_character_id
	
	# If card is universal (no requirements), don't show indicators
	if required_role == "" and required_char_id == -1:
		return
	
	# If specific character required
	if required_char_id != -1:
		var portrait = _load_character_portrait(required_char_id)
		if portrait:
			var indicator = _create_portrait_indicator(portrait)
			role_indicator_container.add_child(indicator)
		else:
			# Fallback to a generic indicator
			var indicator = _create_role_circle(Color(0.8, 0.6, 0.2))
			role_indicator_container.add_child(indicator)
	
	# If role required
	elif required_role != "":
		var color = ROLE_COLORS.get(required_role.to_upper(), Color(0.5, 0.5, 0.5))
		var indicator = _create_role_circle(color)
		role_indicator_container.add_child(indicator)

func _create_role_circle(color: Color) -> Panel:
	var circle := Panel.new()
	circle.custom_minimum_size = Vector2(24, 24)
	
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(12)
	style.border_color = Color.WHITE
	style.set_border_width_all(2)
	circle.add_theme_stylebox_override("panel", style)
	
	return circle

func _create_portrait_indicator(texture: Texture2D) -> Control:
	var container := Control.new()
	container.custom_minimum_size = Vector2(28, 28)
	
	# Background circle
	var bg := Panel.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.2, 0.2, 0.2)
	bg_style.set_corner_radius_all(14)
	bg_style.border_color = Color.WHITE
	bg_style.set_border_width_all(2)
	bg.add_theme_stylebox_override("panel", bg_style)
	container.add_child(bg)
	
	# Portrait texture
	var portrait_rect := TextureRect.new()
	portrait_rect.texture = texture
	portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	portrait_rect.offset_left = 3
	portrait_rect.offset_top = 3
	portrait_rect.offset_right = -3
	portrait_rect.offset_bottom = -3
	container.add_child(portrait_rect)
	
	return container

func _load_character_portrait(char_id: int) -> Texture2D:
	if _portrait_cache.has(char_id):
		return _portrait_cache[char_id]
	
	# Try to load portrait based on character data
	# This would need integration with character data loading
	# For now, return null and let fallback handle it
	return null

# --- EFFECTS ROW ---
func _setup_effects_row() -> void:
	if not effects_row:
		return
	
	# Clear existing effect badges
	for child in effects_row.get_children():
		child.queue_free()
	
	# Parse effects from card data
	for effect in data.effects:
		if not effect.has("type"):
			continue
		
		var effect_type: String = str(effect["type"])
		var effect_value: int = int(effect.get("value", 0))
		
		if effect_value > 0:
			var badge = _create_effect_badge(effect_type, effect_value)
			effects_row.add_child(badge)

func _create_effect_badge(effect_type: String, value: int) -> Control:
	var config = EFFECT_CONFIG.get(effect_type, {"icon": "?", "color": Color(0.5, 0.5, 0.5)})
	var icon: String = config["icon"]
	var color: Color = config["color"]
	
	var badge := Panel.new()
	badge.custom_minimum_size = Vector2(36, 26)
	
	var style := StyleBoxFlat.new()
	style.bg_color = color.darkened(0.3)
	style.set_corner_radius_all(6)
	style.border_color = color
	style.set_border_width_all(2)
	badge.add_theme_stylebox_override("panel", style)
	
	var label := Label.new()
	label.text = "%s%d" % [icon, value]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.add_theme_font_size_override("font_size", 11)
	badge.add_child(label)
	
	return badge

# --- UTILITY ---
func _make_color_texture(color: Color, size: Vector2) -> ImageTexture:
	var w := int(size.x)
	var h := int(size.y)
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	for x in range(w):
		for y in range(h):
			img.set_pixel(x, y, color)
	return ImageTexture.create_from_image(img)

# --- DRAG & DROP SYSTEM ---
func start_drag(mouse_pos: Vector2) -> void:
	is_being_dragged = true
	drag_offset = global_position - mouse_pos
	z_index = 2000
	modulate = Color(1.0, 1.0, 1.0, 0.8)

func update_drag(mouse_pos: Vector2) -> void:
	if is_being_dragged:
		global_position = mouse_pos + drag_offset

func end_drag() -> void:
	is_being_dragged = false
	modulate = Color.WHITE

func is_dragging() -> bool:
	return is_being_dragged
