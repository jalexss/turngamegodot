## DebugMainMenu.gd - Panel de debug para MainMenu
## Toggle con ` (backtick). Solo funciona en builds no-producción.
extends Control

var _panel: PanelContainer
var _visible: bool = false
var _cristales_label: Label

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 2000
	_build_panel()
	_panel.visible = false

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_QUOTELEFT:
		_visible = not _visible
		_panel.visible = _visible
		if _visible:
			_refresh_cristales_label()
		get_viewport().set_input_as_handled()

func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_panel.set_anchor_and_offset(SIDE_RIGHT, 1, -10)
	_panel.set_anchor_and_offset(SIDE_LEFT, 1, -280)
	_panel.set_anchor_and_offset(SIDE_TOP, 0, 10)
	_panel.set_anchor_and_offset(SIDE_BOTTOM, 0, 400)
	add_child(_panel)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.92)
	style.border_color = Color(1.0, 0.3, 0.3, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(12)
	_panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_panel.add_child(vbox)

	var title = Label.new()
	title.text = "🛠️ DEBUG (F9)"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	# Cristales display
	_cristales_label = Label.new()
	_cristales_label.text = "💎 Cristales: ..."
	_cristales_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(_cristales_label)

	# Cristales buttons
	var cristales_row1 = HBoxContainer.new()
	cristales_row1.add_theme_constant_override("separation", 6)
	vbox.add_child(cristales_row1)

	_add_btn(cristales_row1, "+100 💎", func(): _debug_add_cristales(100))
	_add_btn(cristales_row1, "+1000 💎", func(): _debug_add_cristales(1000))
	_add_btn(cristales_row1, "+10000 💎", func(): _debug_add_cristales(10000))

	var cristales_row2 = HBoxContainer.new()
	cristales_row2.add_theme_constant_override("separation", 6)
	vbox.add_child(cristales_row2)

	_add_btn(cristales_row2, "Reset 💎", _debug_reset_cristales)
	_add_btn(cristales_row2, "🔓 Unlock All", _debug_unlock_all)

	vbox.add_child(HSeparator.new())

	# Gacha buttons
	var gacha_label = Label.new()
	gacha_label.text = "Gacha"
	gacha_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(gacha_label)

	var gacha_row = HBoxContainer.new()
	gacha_row.add_theme_constant_override("separation", 6)
	vbox.add_child(gacha_row)

	_add_btn(gacha_row, "1x Pull", func(): _debug_gacha_pull(1))
	_add_btn(gacha_row, "10x Pull", func(): _debug_gacha_pull(10))

func _add_btn(parent: Control, text: String, callback: Callable) -> void:
	var btn = Button.new()
	btn.text = text
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_size_override("font_size", 14)
	btn.pressed.connect(callback)
	parent.add_child(btn)

func _refresh_cristales_label() -> void:
	var pdm = get_tree().root.get_node_or_null("PlayerDataManager")
	if pdm:
		_cristales_label.text = "💎 Cristales: %d" % pdm.get_cristales()

# ============================================================================
# DEBUG ACTIONS
# ============================================================================

func _debug_add_cristales(amount: int) -> void:
	var url = Config.BACKEND_BASE_URL + "/player/debug/cristales"
	var body = JSON.stringify({"amount": amount})
	_make_debug_request(url, HTTPClient.METHOD_POST, body, func(data: Dictionary):
		print("✅ Debug: +%d cristales → %d" % [amount, data.get("cristales", 0)])
		_on_cristales_updated(data)
	)

func _debug_reset_cristales() -> void:
	var url = Config.BACKEND_BASE_URL + "/player/debug/reset-cristales"
	_make_debug_request(url, HTTPClient.METHOD_POST, "", func(data: Dictionary):
		print("✅ Debug: cristales reseteados")
		_on_cristales_updated(data)
	)

func _debug_unlock_all() -> void:
	var url = Config.BACKEND_BASE_URL + "/player/debug/unlock-all"
	_make_debug_request(url, HTTPClient.METHOD_POST, "", func(data: Dictionary):
		print("✅ Debug: todos desbloqueados — %d personajes" % data.get("total_characters", 0))
		# Refresh player data
		var pdm = get_tree().root.get_node_or_null("PlayerDataManager")
		if pdm:
			pdm.fetch_characters()
	)

func _debug_gacha_pull(count: int) -> void:
	var pdm = get_tree().root.get_node_or_null("PlayerDataManager")
	if pdm:
		pdm.pull_gacha(count)
		# Wait a frame for response, then refresh label
		await get_tree().process_frame
		await get_tree().create_timer(1.0).timeout
		_refresh_cristales_label()

func _on_cristales_updated(data: Dictionary) -> void:
	var pdm = get_tree().root.get_node_or_null("PlayerDataManager")
	if pdm:
		pdm.fetch_inventory()
	await get_tree().process_frame
	await get_tree().create_timer(0.5).timeout
	_refresh_cristales_label()

# ============================================================================
# HTTP
# ============================================================================

func _make_debug_request(url: String, method: int, body: String, on_success: Callable) -> void:
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_result: int, response_code: int, _headers: PackedStringArray, resp_body: PackedByteArray):
		http.queue_free()
		if _result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
			print("❌ Debug request failed: HTTP ", response_code)
			return
		var text = resp_body.get_string_from_utf8()
		var data = JSON.parse_string(text)
		if data is Dictionary:
			on_success.call(data)
	)

	var session_mgr = get_tree().root.get_node("SessionManager")
	var token = session_mgr.get_access_token()
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer " + token
	]

	var error: int
	if body.is_empty():
		error = http.request(url, headers, method)
	else:
		error = http.request(url, headers, method, body)

	if error != OK:
		http.queue_free()
		print("❌ Debug request connection error")
