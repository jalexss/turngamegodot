extends Control
## MainMenu - Menú principal estilo gacha
## Layout: TopBar (settings + cristales) | Title + Preview | Bottom Nav (Jugar, Personajes, Gacha)

const CharacterSelectModalScene = preload("res://scenes/CharacterSelectModal.tscn")

var _cristales_label: Label
var _username_label: Label
var _preview_texture: TextureRect
var _preview_label: Label
var _active_modal: Control = null

var _play_btn: Button
var _chars_btn: Button
var _gacha_btn: Button

var _rarity_colors := {
	"common": Color(0.6, 0.6, 0.6),
	"rare": Color(0.3, 0.5, 1.0),
	"epic": Color(0.7, 0.3, 0.9),
	"legendary": Color(1.0, 0.8, 0.2)
}

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	_build_ui()

	# Connect signals BEFORE updating UI so callbacks fire if data arrives mid-setup
	var pdm = get_tree().root.get_node("PlayerDataManager")
	pdm.inventory_loaded.connect(_on_inventory_loaded)
	pdm.characters_loaded.connect(_on_characters_loaded)
	pdm.gacha_result.connect(_on_gacha_result)
	pdm.gacha_failed.connect(_on_gacha_failed)

	# Show loading state or current data depending on PDM state
	if pdm.is_loaded():
		_update_cristales()
		_update_preview()
		_set_nav_buttons_enabled(true)
	else:
		_preview_label.text = "Cargando..."
		_set_nav_buttons_enabled(false)

	var auth_mgr = get_tree().root.get_node("AuthManager")
	print("🏠 MainMenu cargado - Usuario: %s" % auth_mgr.get_username())

	# Verificar si hay una partida activa de supervivencia
	var sm = get_tree().root.get_node_or_null("SurvivalManager")
	if sm:
		sm.check_active_run()

	# Debug panel (F12)
	var debug_panel = preload("res://scripts/ui/DebugMainMenu.gd").new()
	add_child(debug_panel)

# ============================================================================
# BUILD UI
# ============================================================================

func _build_ui() -> void:
	var main_vbox = VBoxContainer.new()
	main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_vbox.set_anchor_and_offset(SIDE_LEFT, 0, 20)
	main_vbox.set_anchor_and_offset(SIDE_RIGHT, 1, -20)
	main_vbox.set_anchor_and_offset(SIDE_TOP, 0, 10)
	main_vbox.set_anchor_and_offset(SIDE_BOTTOM, 1, -10)
	add_child(main_vbox)

	# TOP BAR
	main_vbox.add_child(_build_top_bar())

	# Spacer
	var spacer_top = Control.new()
	spacer_top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer_top.size_flags_stretch_ratio = 0.3
	main_vbox.add_child(spacer_top)

	# TITLE
	var title = Label.new()
	title.text = "TURN GAME"
	title.add_theme_font_size_override("font_size", 72)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(title)

	var subtitle = Label.new()
	subtitle.text = "Card Battle"
	subtitle.add_theme_font_size_override("font_size", 20)
	subtitle.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(subtitle)

	# CHARACTER PREVIEW
	main_vbox.add_child(_build_preview())

	# Spacer
	var spacer_bottom = Control.new()
	spacer_bottom.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer_bottom.size_flags_stretch_ratio = 1.0
	main_vbox.add_child(spacer_bottom)

	# BOTTOM NAV
	main_vbox.add_child(_build_bottom_nav())

func _build_top_bar() -> HBoxContainer:
	var hbox = HBoxContainer.new()
	hbox.custom_minimum_size = Vector2(0, 50)
	hbox.add_theme_constant_override("separation", 15)

	var settings_btn = Button.new()
	settings_btn.text = "⚙"
	settings_btn.add_theme_font_size_override("font_size", 28)
	settings_btn.custom_minimum_size = Vector2(50, 50)
	settings_btn.pressed.connect(_on_settings_pressed)
	hbox.add_child(settings_btn)

	_username_label = Label.new()
	var auth_mgr = get_tree().root.get_node("AuthManager")
	_username_label.text = auth_mgr.get_username()
	_username_label.add_theme_font_size_override("font_size", 16)
	_username_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	hbox.add_child(_username_label)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)

	var cristales_hbox = HBoxContainer.new()
	cristales_hbox.add_theme_constant_override("separation", 6)
	hbox.add_child(cristales_hbox)

	var gem_icon = Label.new()
	gem_icon.text = "💎"
	gem_icon.add_theme_font_size_override("font_size", 22)
	cristales_hbox.add_child(gem_icon)

	_cristales_label = Label.new()
	_cristales_label.text = "0"
	_cristales_label.add_theme_font_size_override("font_size", 22)
	_cristales_label.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
	cristales_hbox.add_child(_cristales_label)

	return hbox

func _build_preview() -> CenterContainer:
	var center = CenterContainer.new()
	center.custom_minimum_size = Vector2(0, 200)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 10)
	center.add_child(vbox)

	_preview_texture = TextureRect.new()
	_preview_texture.custom_minimum_size = Vector2(128, 128)
	_preview_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview_texture.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	vbox.add_child(_preview_texture)

	_preview_label = Label.new()
	_preview_label.add_theme_font_size_override("font_size", 18)
	_preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_preview_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	vbox.add_child(_preview_label)

	return center

func _build_bottom_nav() -> CenterContainer:
	var center = CenterContainer.new()
	center.custom_minimum_size = Vector2(0, 120)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 30)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(hbox)

	var play_btn = _create_nav_button("Jugar", "🎮", Color(0.2, 0.6, 0.3))
	play_btn.pressed.connect(_on_play_pressed)
	hbox.add_child(play_btn)
	_play_btn = play_btn

	var chars_btn = _create_nav_button("Personajes", "👥", Color(0.3, 0.4, 0.7))
	chars_btn.pressed.connect(_on_characters_pressed)
	hbox.add_child(chars_btn)
	_chars_btn = chars_btn

	var gacha_btn = _create_nav_button("Gacha", "💎", Color(0.7, 0.4, 0.8))
	gacha_btn.pressed.connect(_on_gacha_pressed)
	hbox.add_child(gacha_btn)
	_gacha_btn = gacha_btn

	return center

func _create_nav_button(text: String, icon: String, bg_color: Color) -> Button:
	var btn = Button.new()
	btn.text = "%s\n%s" % [icon, text]
	btn.custom_minimum_size = Vector2(160, 100)
	btn.add_theme_font_size_override("font_size", 20)

	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	btn.add_theme_stylebox_override("normal", style)

	var hover_style = style.duplicate()
	hover_style.bg_color = bg_color.lightened(0.15)
	btn.add_theme_stylebox_override("hover", hover_style)

	var pressed_style = style.duplicate()
	pressed_style.bg_color = bg_color.darkened(0.1)
	btn.add_theme_stylebox_override("pressed", pressed_style)

	return btn

# ============================================================================
# DATA UPDATES
# ============================================================================

func _update_cristales() -> void:
	var pdm = get_tree().root.get_node("PlayerDataManager")
	if _cristales_label:
		_cristales_label.text = str(pdm.get_cristales())

func _update_preview() -> void:
	var pdm = get_tree().root.get_node("PlayerDataManager")
	var gm = get_tree().root.get_node("GameManager")
	var unlocked_ids = pdm.get_unlocked_character_ids()

	if unlocked_ids.is_empty():
		_preview_label.text = "Sin personajes"
		return

	var all_chars = gm.get_playable_characters()
	for c in all_chars:
		if c.get("id") in unlocked_ids:
			var portrait_path = c.get("portrait", "")
			if portrait_path != "" and ResourceLoader.exists(portrait_path):
				_preview_texture.texture = load(portrait_path) as Texture2D
			_preview_label.text = c.get("name", "")
			break

func _on_inventory_loaded(_cristales: int) -> void:
	_update_cristales()

func _on_characters_loaded(_chars: Array) -> void:
	_update_preview()
	_set_nav_buttons_enabled(true)

func _set_nav_buttons_enabled(enabled: bool) -> void:
	if _play_btn: _play_btn.disabled = not enabled
	if _chars_btn: _chars_btn.disabled = not enabled
	if _gacha_btn: _gacha_btn.disabled = not enabled

# ============================================================================
# BUTTON HANDLERS
# ============================================================================

func _on_play_pressed() -> void:
	_show_game_mode_modal()

func _on_characters_pressed() -> void:
	_show_character_collection_modal()

func _on_gacha_pressed() -> void:
	_show_gacha_screen()

func _on_settings_pressed() -> void:
	_show_settings_modal()

# ============================================================================
# MODAL HELPERS
# ============================================================================

func _close_active_modal() -> void:
	if _active_modal and is_instance_valid(_active_modal):
		_active_modal.queue_free()
		_active_modal = null

func _create_modal_overlay() -> Control:
	_close_active_modal()
	var overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 1000
	add_child(overlay)
	_active_modal = overlay

	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.7)
	overlay.add_child(bg)
	return overlay

# ============================================================================
# GAME MODE MODAL
# ============================================================================

func _show_game_mode_modal() -> void:
	var overlay = _create_modal_overlay()

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(500, 400)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.set_anchor_and_offset(SIDE_LEFT, 0.5, -250)
	panel.set_anchor_and_offset(SIDE_RIGHT, 0.5, 250)
	panel.set_anchor_and_offset(SIDE_TOP, 0.5, -200)
	panel.set_anchor_and_offset(SIDE_BOTTOM, 0.5, 200)
	overlay.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	panel.add_child(vbox)

	var title = Label.new()
	title.text = "Selecciona Modo de Juego"
	title.add_theme_font_size_override("font_size", 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	# Botón de continuar partida (solo si hay run activa)
	var sm = get_tree().root.get_node_or_null("SurvivalManager")
	if sm and sm.has_active_run():
		var run_data = sm.get_active_run_data()
		var resume_btn = Button.new()
		resume_btn.text = "▶️ Continuar Supervivencia (Piso %d)" % run_data.get("current_floor", 0)
		resume_btn.custom_minimum_size = Vector2(0, 60)
		resume_btn.add_theme_font_size_override("font_size", 22)
		resume_btn.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))
		resume_btn.pressed.connect(_on_resume_survival)
		vbox.add_child(resume_btn)

		var restart_btn = Button.new()
		restart_btn.text = "🔄 Reiniciar Supervivencia"
		restart_btn.custom_minimum_size = Vector2(0, 45)
		restart_btn.add_theme_font_size_override("font_size", 18)
		restart_btn.add_theme_color_override("font_color", Color(1.0, 0.4, 0.3))
		restart_btn.pressed.connect(_on_restart_survival)
		vbox.add_child(restart_btn)
		vbox.add_child(HSeparator.new())

	var rogue_btn = Button.new()
	rogue_btn.text = "🎮 Supervivencia"
	rogue_btn.custom_minimum_size = Vector2(0, 60)
	rogue_btn.add_theme_font_size_override("font_size", 22)
	rogue_btn.pressed.connect(_on_survival_selected)
	vbox.add_child(rogue_btn)

	var rogue_desc = Label.new()
	rogue_desc.text = "Recorre pisos, combate y mejora tu equipo"
	rogue_desc.add_theme_font_size_override("font_size", 14)
	rogue_desc.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	rogue_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(rogue_desc)

	var adv_btn = Button.new()
	adv_btn.text = "📖 Aventura (Próximamente)"
	adv_btn.custom_minimum_size = Vector2(0, 60)
	adv_btn.add_theme_font_size_override("font_size", 22)
	adv_btn.disabled = true
	vbox.add_child(adv_btn)

	var pvp_btn = Button.new()
	pvp_btn.text = "⚔️ Multijugador PvP (Próximamente)"
	pvp_btn.custom_minimum_size = Vector2(0, 60)
	pvp_btn.add_theme_font_size_override("font_size", 22)
	pvp_btn.disabled = true
	vbox.add_child(pvp_btn)

	var close_btn = Button.new()
	close_btn.text = "Cerrar"
	close_btn.custom_minimum_size = Vector2(0, 40)
	close_btn.pressed.connect(_close_active_modal)
	vbox.add_child(close_btn)

func _on_survival_selected() -> void:
	_close_active_modal()
	_show_character_select()

func _on_resume_survival() -> void:
	_close_active_modal()
	var sm = get_tree().root.get_node_or_null("SurvivalManager")
	if sm:
		sm.resume_run()

func _on_restart_survival() -> void:
	_close_active_modal()
	# Abandon the active run, then start character select for a new one
	var sm = get_tree().root.get_node_or_null("SurvivalManager")
	if sm:
		sm.end_run("abandoned")
	_show_character_select()

func _show_character_select() -> void:
	var modal = CharacterSelectModalScene.instantiate()
	modal.z_index = 1500
	add_child(modal)
	_active_modal = modal
	modal.selection_confirmed.connect(_on_characters_selected)
	modal.modal_closed.connect(_close_active_modal)
	modal.show_modal()

func _on_characters_selected(characters: Array) -> void:
	_close_active_modal()
	var gm = get_tree().root.get_node("GameManager")
	if gm:
		gm.start_survival_run(characters)

# ============================================================================
# CHARACTER COLLECTION MODAL
# ============================================================================

func _show_character_collection_modal() -> void:
	var overlay = _create_modal_overlay()

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(700, 500)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.set_anchor_and_offset(SIDE_LEFT, 0.5, -350)
	panel.set_anchor_and_offset(SIDE_RIGHT, 0.5, 350)
	panel.set_anchor_and_offset(SIDE_TOP, 0.5, -250)
	panel.set_anchor_and_offset(SIDE_BOTTOM, 0.5, 250)
	overlay.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var title = Label.new()
	title.text = "Colección de Personajes"
	title.add_theme_font_size_override("font_size", 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	var grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 15)
	grid.add_theme_constant_override("v_separation", 15)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)

	var gm = get_tree().root.get_node("GameManager")
	var pdm = get_tree().root.get_node("PlayerDataManager")
	var unlocked_ids = pdm.get_unlocked_character_ids()

	for c in gm.get_playable_characters():
		var is_unlocked = c.get("id") in unlocked_ids
		grid.add_child(_build_character_card(c, is_unlocked))

	var close_btn = Button.new()
	close_btn.text = "Cerrar"
	close_btn.custom_minimum_size = Vector2(0, 40)
	close_btn.pressed.connect(_close_active_modal)
	vbox.add_child(close_btn)

func _build_character_card(char_data: Dictionary, is_unlocked: bool) -> PanelContainer:
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(200, 220)

	var rarity = char_data.get("rarity", "common")
	var style = StyleBoxFlat.new()
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 10
	style.content_margin_bottom = 10

	if is_unlocked:
		style.bg_color = Color(0.15, 0.15, 0.2)
		style.border_color = _rarity_colors.get(rarity, Color.WHITE)
		style.border_width_bottom = 3
		style.border_width_top = 3
		style.border_width_left = 3
		style.border_width_right = 3
	else:
		style.bg_color = Color(0.08, 0.08, 0.1)

	card.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(vbox)

	# Portrait
	var tex = TextureRect.new()
	tex.custom_minimum_size = Vector2(96, 96)
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	var portrait_path = char_data.get("portrait", "")
	if portrait_path != "" and ResourceLoader.exists(portrait_path):
		tex.texture = load(portrait_path) as Texture2D
	if not is_unlocked:
		tex.modulate = Color(0.1, 0.1, 0.1)
	vbox.add_child(tex)

	# Name
	var name_label = Label.new()
	name_label.text = char_data.get("name", "???") if is_unlocked else "???"
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if not is_unlocked:
		name_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
	vbox.add_child(name_label)

	# Rarity
	var rarity_label = Label.new()
	rarity_label.text = rarity.to_upper()
	rarity_label.add_theme_font_size_override("font_size", 12)
	rarity_label.add_theme_color_override("font_color", _rarity_colors.get(rarity, Color.WHITE))
	rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(rarity_label)

	# Stats or lock
	if is_unlocked:
		var stats = Label.new()
		stats.text = "HP:%s ATK:%s DEF:%s" % [
			char_data.get("max_hp", "?"),
			char_data.get("attack", "?"),
			char_data.get("defense", "?")
		]
		stats.add_theme_font_size_override("font_size", 11)
		stats.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
		stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(stats)
	else:
		var lock_label = Label.new()
		lock_label.text = "🔒 Obtener en Gacha"
		lock_label.add_theme_font_size_override("font_size", 12)
		lock_label.add_theme_color_override("font_color", Color(0.5, 0.4, 0.6))
		lock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(lock_label)

	return card

# ============================================================================
# GACHA SCREEN
# ============================================================================

func _show_gacha_screen() -> void:
	var overlay = _create_modal_overlay()

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(600, 500)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.set_anchor_and_offset(SIDE_LEFT, 0.5, -300)
	panel.set_anchor_and_offset(SIDE_RIGHT, 0.5, 300)
	panel.set_anchor_and_offset(SIDE_TOP, 0.5, -250)
	panel.set_anchor_and_offset(SIDE_BOTTOM, 0.5, 250)
	overlay.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	panel.add_child(vbox)

	var title = Label.new()
	title.text = "✨ Invocación de Personajes ✨"
	title.add_theme_font_size_override("font_size", 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	# Banner
	var banner = ColorRect.new()
	banner.color = Color(0.12, 0.1, 0.2)
	banner.custom_minimum_size = Vector2(0, 150)
	vbox.add_child(banner)

	var banner_text = Label.new()
	banner_text.text = "Banner de Invocación\nTodos los personajes disponibles"
	banner_text.add_theme_font_size_override("font_size", 18)
	banner_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner_text.set_anchors_preset(Control.PRESET_FULL_RECT)
	banner.add_child(banner_text)

	# Rates
	var rates_label = Label.new()
	rates_label.text = "Común: 60% | Raro: 30% | Épico: 8% | Legendario: 2%"
	rates_label.add_theme_font_size_override("font_size", 13)
	rates_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	rates_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(rates_label)

	# Balance
	var pdm = get_tree().root.get_node("PlayerDataManager")
	var balance_label = Label.new()
	balance_label.text = "💎 %d Cristales" % pdm.get_cristales()
	balance_label.add_theme_font_size_override("font_size", 20)
	balance_label.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
	balance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(balance_label)

	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	# Pull buttons
	var btn_hbox = HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 20)
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_hbox)

	var single_btn = Button.new()
	single_btn.text = "1x Invocación\n💎 100"
	single_btn.custom_minimum_size = Vector2(180, 70)
	single_btn.add_theme_font_size_override("font_size", 18)
	single_btn.disabled = not pdm.can_pull_single()
	single_btn.pressed.connect(_on_gacha_pull.bind(1))
	btn_hbox.add_child(single_btn)

	var multi_btn = Button.new()
	multi_btn.text = "10x Invocación\n💎 900"
	multi_btn.custom_minimum_size = Vector2(180, 70)
	multi_btn.add_theme_font_size_override("font_size", 18)
	multi_btn.disabled = not pdm.can_pull_multi()
	multi_btn.pressed.connect(_on_gacha_pull.bind(10))
	btn_hbox.add_child(multi_btn)

	# Close
	var close_btn = Button.new()
	close_btn.text = "Cerrar"
	close_btn.custom_minimum_size = Vector2(0, 40)
	close_btn.pressed.connect(_close_active_modal)
	vbox.add_child(close_btn)

func _on_gacha_pull(count: int) -> void:
	var pdm = get_tree().root.get_node("PlayerDataManager")
	pdm.pull_gacha(count)

func _on_gacha_result(results: Array, cristales: int, _pity: int) -> void:
	_update_cristales()
	_close_active_modal()
	_show_gacha_results(results, cristales)

func _show_gacha_results(results: Array, cristales: int) -> void:
	var overlay = _create_modal_overlay()

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(600, 500)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.set_anchor_and_offset(SIDE_LEFT, 0.5, -300)
	panel.set_anchor_and_offset(SIDE_RIGHT, 0.5, 300)
	panel.set_anchor_and_offset(SIDE_TOP, 0.5, -250)
	panel.set_anchor_and_offset(SIDE_BOTTOM, 0.5, 250)
	overlay.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var title = Label.new()
	title.text = "✨ Resultado de Invocación ✨"
	title.add_theme_font_size_override("font_size", 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	var grid = GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(grid)

	for r in results:
		var rarity = r.get("rarity", "common")
		var card = PanelContainer.new()
		card.custom_minimum_size = Vector2(100, 130)

		var style = StyleBoxFlat.new()
		style.corner_radius_top_left = 6
		style.corner_radius_top_right = 6
		style.corner_radius_bottom_left = 6
		style.corner_radius_bottom_right = 6
		style.bg_color = Color(0.12, 0.12, 0.18)
		style.border_color = _rarity_colors.get(rarity, Color.WHITE)
		style.border_width_bottom = 2
		style.border_width_top = 2
		style.border_width_left = 2
		style.border_width_right = 2
		style.content_margin_left = 5
		style.content_margin_right = 5
		style.content_margin_top = 5
		style.content_margin_bottom = 5
		card.add_theme_stylebox_override("panel", style)

		var cvbox = VBoxContainer.new()
		cvbox.alignment = BoxContainer.ALIGNMENT_CENTER
		cvbox.add_theme_constant_override("separation", 4)
		card.add_child(cvbox)

		var name_l = Label.new()
		name_l.text = r.get("name", "???")
		name_l.add_theme_font_size_override("font_size", 13)
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cvbox.add_child(name_l)

		var rarity_l = Label.new()
		rarity_l.text = rarity.to_upper()
		rarity_l.add_theme_font_size_override("font_size", 11)
		rarity_l.add_theme_color_override("font_color", _rarity_colors.get(rarity, Color.WHITE))
		rarity_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cvbox.add_child(rarity_l)

		var status_l = Label.new()
		if r.get("is_new", false):
			status_l.text = "¡NUEVO!"
			status_l.add_theme_color_override("font_color", Color(0.2, 1.0, 0.3))
		else:
			status_l.text = "Duplicado\n+💎%d" % r.get("duplicate_refund", 20)
			status_l.add_theme_color_override("font_color", Color(0.8, 0.6, 0.3))
		status_l.add_theme_font_size_override("font_size", 12)
		status_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cvbox.add_child(status_l)

		grid.add_child(card)

	# Balance
	var balance = Label.new()
	balance.text = "💎 %d Cristales restantes" % cristales
	balance.add_theme_font_size_override("font_size", 18)
	balance.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
	balance.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(balance)

	# Buttons
	var btn_hbox = HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_hbox.add_theme_constant_override("separation", 15)
	vbox.add_child(btn_hbox)

	var again_btn = Button.new()
	again_btn.text = "Invocar de nuevo"
	again_btn.custom_minimum_size = Vector2(180, 45)
	again_btn.pressed.connect(func(): _close_active_modal(); _show_gacha_screen())
	btn_hbox.add_child(again_btn)

	var close_btn = Button.new()
	close_btn.text = "Cerrar"
	close_btn.custom_minimum_size = Vector2(120, 45)
	close_btn.pressed.connect(_close_active_modal)
	btn_hbox.add_child(close_btn)

func _on_gacha_failed(reason: String) -> void:
	print("❌ Gacha falló: %s" % reason)

# ============================================================================
# SETTINGS MODAL
# ============================================================================

func _show_settings_modal() -> void:
	var overlay = _create_modal_overlay()

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(400, 300)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.set_anchor_and_offset(SIDE_LEFT, 0.5, -200)
	panel.set_anchor_and_offset(SIDE_RIGHT, 0.5, 200)
	panel.set_anchor_and_offset(SIDE_TOP, 0.5, -150)
	panel.set_anchor_and_offset(SIDE_BOTTOM, 0.5, 150)
	overlay.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	panel.add_child(vbox)

	var title = Label.new()
	title.text = "⚙ Configuración"
	title.add_theme_font_size_override("font_size", 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	var audio_label = Label.new()
	audio_label.text = "🔊 Audio (Próximamente)"
	audio_label.add_theme_font_size_override("font_size", 18)
	audio_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	audio_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(audio_label)

	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	var logout_btn = Button.new()
	logout_btn.text = "Cerrar Sesión"
	logout_btn.custom_minimum_size = Vector2(0, 45)
	logout_btn.pressed.connect(_on_logout_pressed)
	vbox.add_child(logout_btn)

	var quit_btn = Button.new()
	quit_btn.text = "Salir del Juego"
	quit_btn.custom_minimum_size = Vector2(0, 45)
	quit_btn.pressed.connect(func(): get_tree().quit())
	vbox.add_child(quit_btn)

	var close_btn = Button.new()
	close_btn.text = "Cerrar"
	close_btn.custom_minimum_size = Vector2(0, 40)
	close_btn.pressed.connect(_close_active_modal)
	vbox.add_child(close_btn)

func _on_logout_pressed() -> void:
	var auth_mgr = get_tree().root.get_node("AuthManager")
	auth_mgr.logout()
	await get_tree().process_frame
	get_tree().change_scene_to_file("res://scenes/Gateway.tscn")
