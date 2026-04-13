extends Control

@onready var Menupanel: Panel = $Panel
@onready var playbutton: Button = $Playbutton
@onready var panel2: Control = $Panel2
@onready var Aibutton: Button = $Panel2/VBoxContainer/vsAIbutton
@onready var passbutton: Button = $Panel2/VBoxContainer/Passandplaybutton
@onready var PlayerCountPanel: Control = $playercountpanel
@onready var vs1button: Button = $playercountpanel/countbuttoncontainer/_2playerbutton
@onready var vs2button: Button = $playercountpanel/countbuttoncontainer/_3playerbutton
@onready var vs3button: Button = $playercountpanel/countbuttoncontainer/_4playerbutton
@onready var AISetupPanel: Control = $Aisetuppanel
@onready var ai1_color_select: OptionButton = $Aisetuppanel/VBoxContaineraibox/Buttoncolour1
@onready var ai2_color_select: OptionButton = $Aisetuppanel/VBoxContaineraibox/Button2
@onready var ai3_color_select: OptionButton = $Aisetuppanel/VBoxContaineraibox/Button3
@onready var ai_level_select: OptionButton = $Aisetuppanel/VBoxContaineraibox/Button4
@onready var ai_playtest_button: Button = $Aisetuppanel/VBoxContaineraibox/Button5

# exported / preloads
var game_scene_packed := preload("res://boardgameplayscene.tscn")

# local state
var selected_mode: String = "" # "ai" or "pass"
var pending_player_count: int = 0
var _last_ai_config: Dictionary = {}

func _ready() -> void:
	randomize()

	# initial UI state
	panel2.hide()
	PlayerCountPanel.hide()
	AISetupPanel.hide()

	# Fill color choices
	for col in ["Red","Green","Blue","Yellow"]:
		ai1_color_select.add_item(col)
		ai2_color_select.add_item(col)
		ai3_color_select.add_item(col)

	# Fill level choices
	for lvl in range(0, 11):
		ai_level_select.add_item(str(lvl), lvl)

	# connect signals safely
	_connect_button(playbutton, "_on_playbutton_pressed")
	_connect_button(Aibutton, "_on_vs_a_ibutton_pressed")
	_connect_button(passbutton, "_on_passandplaybutton_pressed")
	_connect_button(vs1button, "_on_vs1_pressed")
	_connect_button(vs2button, "_on_vs2_pressed")
	_connect_button(vs3button, "_on_vs3_pressed")
	_connect_button(ai_playtest_button, "_on_ai_playtest_pressed")

# helper
func _connect_button(btn: Button, method_name: String) -> void:
	if btn == null: return
	var cb: Callable = Callable(self, method_name)
	if not btn.pressed.is_connected(cb):
		btn.pressed.connect(cb)

# --- play button ---
func _on_playbutton_pressed() -> void:
	if panel2.is_visible():
		panel2.hide()
	else:
		panel2.show()

# --- mode selection ---
func _on_vs_a_ibutton_pressed() -> void:
	selected_mode = "ai"
	panel2.hide()
	PlayerCountPanel.show()

func _on_passandplaybutton_pressed() -> void:
	selected_mode = "pass"
	panel2.hide()
	PlayerCountPanel.show()

# --- player count selection ---
func _on_vs1_pressed() -> void:
	_handle_player_count(2)

func _on_vs2_pressed() -> void:
	_handle_player_count(3)

func _on_vs3_pressed() -> void:
	_handle_player_count(4)

func _handle_player_count(count: int) -> void:
	pending_player_count = count
	if selected_mode == "ai":
		PlayerCountPanel.hide()
		AISetupPanel.show()
	else:
		_start_game(count)

# --- AI playtest start (first phase) ---
func _on_ai_playtest_pressed() -> void:
	# build ai config from UI widgets
	var ai_count: int = max(0, pending_player_count - 1)  # human always 1
	var ai_colors: Array = []
	if ai_count >= 1 and ai1_color_select:
		ai_colors.append(ai1_color_select.get_item_text(ai1_color_select.get_selected()))
	if ai_count >= 2 and ai2_color_select:
		ai_colors.append(ai2_color_select.get_item_text(ai2_color_select.get_selected()))
	if ai_count >= 3 and ai3_color_select:
		ai_colors.append(ai3_color_select.get_item_text(ai3_color_select.get_selected()))

	var level: int = 0
	if ai_level_select:
		level = int(ai_level_select.get_selected_id())

	var ai_levels: Array = []
	for i in range(ai_count):
		ai_levels.append(level)  # all same level for now

	var config: Dictionary = {
		"mode": "ai",
		"player_count": pending_player_count,
		"ai_count": ai_count,
		"ai_colors": ai_colors,
		"ai_levels": ai_levels
	}

	# Save so if menu reopens we can inspect it
	_last_ai_config = config

	# Show in-menu color selection for the HUMAN before transitioning
	_show_human_color_selection_for_ai_config(config)

# -----------------------
# Handle chosen AI color
# -----------------------
func _on_color_selected_for_ai_config(color_name: String, ai_index: int, popup: Window) -> void:
	var color_code := _color_name_to_code(color_name)

	# ensure array exists
	if not _last_ai_config.has("ai_colors"):
		_last_ai_config["ai_colors"] = []

	var ai_colors: Array = _last_ai_config["ai_colors"]

	if ai_index < ai_colors.size():
		ai_colors[ai_index] = color_code
	else:
		push_warning("AI index %d out of range when selecting color" % ai_index)

	# close the popup once selected
	if is_instance_valid(popup):
		popup.queue_free()

func _color_name_to_code(col: String) -> String:
	var s: String = col.strip_edges().to_lower()
	match s:
		"r", "red", "r_ed":
			return "R"
		"g", "green":
			return "G"
		"b", "blue":
			return "B"
		"y", "yellow":
			return "Y"
		_:
			if s.length() > 0:
				var c: String = s.substr(0, 1)
				if c == "r": return "R"
				if c == "g": return "G"
				if c == "b": return "B"
				if c == "y": return "Y"
	# fallback if nothing matches
	push_warning("MenuScene: Unrecognized color string '%s', defaulting to R" % col)
	return "R"
# -------------------------
# Color selection popup (menu-side)
# -------------------------
# -------------------------
func _show_human_color_selection_for_ai_config(config: Dictionary) -> void:
	# create popup only once (cleanup existing)
	var old := get_node_or_null("HumanColorPickPopup")
	if old:
		old.queue_free()

	var popup := PopupPanel.new()
	popup.name = "HumanColorPickPopup"
	popup.min_size = Vector2i(420, 180)   # ✅ Window property (Vector2i)
	popup.size = Vector2i(420, 180)       # ✅ Window property (Vector2i)
	add_child(popup)
	popup.popup_centered()

	var vb := VBoxContainer.new()
	vb.custom_minimum_size = Vector2(380, 140) # ✅ Control property (Vector2)
	popup.add_child(vb)

	var lbl := Label.new()
	lbl.text = "Choose your color (AI colors reserved)"
	lbl.add_theme_font_size_override("font_size", 16)
	vb.add_child(lbl)

	var reserved := config.get("ai_colors", []) as Array
	var reserved_codes: Array = []
	for rc in reserved:
		var rc_str := String(rc)
		var code := _color_name_to_code(rc_str)
		reserved_codes.append(code)

	var colors_h := HBoxContainer.new()
	colors_h.name = "colors_h"
	colors_h.custom_minimum_size = Vector2(360, 48) # ✅ Control property
	vb.add_child(colors_h)

	# track selection (stored in popup meta)
	popup.set_meta("selected_choice", "")

	for col_name in ["Red","Blue","Green","Yellow"]:
		var btn := Button.new()
		btn.text = col_name
		btn.custom_minimum_size = Vector2(80, 40) # ✅ Control property
		var code := _color_name_to_code(col_name)
		if reserved_codes.has(code):
			btn.disabled = true
			btn.tooltip_text = "Reserved by AI"
		btn.pressed.connect(Callable(self, "_on_menu_color_choice_pressed").bind(popup, btn, code))
		colors_h.add_child(btn)

	var status_lbl := Label.new()
	status_lbl.name = "status_lbl"
	status_lbl.text = "Select a color"
	vb.add_child(status_lbl)

	var action_row := HBoxContainer.new()
	action_row.alignment = BoxContainer.ALIGNMENT_END
	vb.add_child(action_row)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.pressed.connect(Callable(popup, "hide"))
	action_row.add_child(cancel_btn)

	var start_btn := Button.new()
	start_btn.text = "Start Game"
	start_btn.disabled = true
	start_btn.name = "start_btn"
	start_btn.pressed.connect(Callable(self, "_on_menu_confirm_color_and_start").bind(popup, config))
	action_row.add_child(start_btn)

	# store references in popup metadata
	popup.set_meta("reserved_codes", reserved_codes)
	popup.set_meta("status_node", status_lbl)
	popup.set_meta("start_node", start_btn)

	# store initial UI in popup metadata so handlers can find children
	popup.set_meta("reserved_codes", reserved_codes)
	popup.set_meta("status_node", status_lbl)
	popup.set_meta("start_node", start_btn)

	# colors_h is already in vb, no need to re-add to popup


	# store initial UI in popup metadata so handlers can find children
	popup.set_meta("reserved_codes", reserved_codes)
	popup.set_meta("status_node", status_lbl)
	popup.set_meta("start_node", start_btn)

	# store initial UI in popup metadata so handlers can find children
	popup.set_meta("reserved_codes", reserved_codes)
	popup.set_meta("status_node", status_lbl)
	popup.set_meta("start_node", start_btn)


# handler for color button inside menu popup
func _on_menu_color_choice_pressed(popup: PopupPanel, btn: Button, code: String) -> void:
	if popup == null:
		return
	# store chosen code
	popup.set_meta("selected_choice", code)
	var status_lbl: Label = popup.get_meta("status_node") as Label
	if status_lbl:
		status_lbl.text = "Chosen: %s" % code
	# visually mark buttons (simple approach: update all children)
	var colors_h: HBoxContainer = popup.get_node_or_null("colors_h") as HBoxContainer
	if colors_h:
		for b in colors_h.get_children():
			if b is Button:
				var b_code: String = _color_name_to_code(String(b.text))
				if b_code == code:
					# highlight the chosen button (font color)
					b.add_theme_color_override("font_color", Color(1, 1, 0))
				else:
					# remove override if present
					b.remove_theme_color_override("font_color")
	# enable start button
	var start_btn: Button = popup.get_meta("start_node") as Button
	if start_btn:
		start_btn.disabled = false

# When user confirms color selection in menu, start the board scene deferred
func _on_menu_confirm_color_and_start(popup: PopupPanel, config: Dictionary) -> void:
	if popup == null:
		return
	var human_code: String = String(popup.get_meta("selected_choice"))
	if human_code == "" or human_code == null:
		var status_lbl: Label = popup.get_meta("status_node") as Label
		if status_lbl:
			status_lbl.text = "Please pick a color first"
		return

	# close popup
	popup.hide()
	popup.queue_free()

	# embed the human color into config
	config["human_color"] = human_code

	# Hide menu UI immediately to avoid any overlap/flicker
	if panel2: panel2.hide()
	if PlayerCountPanel: PlayerCountPanel.hide()
	if AISetupPanel: AISetupPanel.hide()
	if Menupanel: Menupanel.hide()

	# instantiate board scene and add to root
	var game_scene: Node = game_scene_packed.instantiate()
	get_tree().root.add_child(game_scene)

	# make it the current scene (so input/focus goes to it)
	get_tree().current_scene = game_scene

	# free the menu scene (deferred so current call finishes cleanly)
	self.call_deferred("queue_free")

	# configure the game scene (deferred calls to be safe)
	game_scene.call_deferred("configure_mode", config["mode"], int(config.get("player_count",2)), config)
	game_scene.call_deferred("_on_choose_color", human_code)


# --- direct start for pass & play ---
func _start_game(player_count: int) -> void:
	var config: Dictionary = {
		"mode": "pass",
		"player_count": player_count
	}

	# hide menu UI right away
	if panel2: panel2.hide()
	if PlayerCountPanel: PlayerCountPanel.hide()
	if AISetupPanel: AISetupPanel.hide()
	if Menupanel: Menupanel.hide()

	# instantiate and add new scene
	var game_scene: Node = game_scene_packed.instantiate()
	get_tree().root.add_child(game_scene)

	# make it the current scene
	get_tree().current_scene = game_scene

	# free the menu scene after switching
	self.call_deferred("queue_free")

	# deferred configure call
	game_scene.call_deferred("configure_mode", config["mode"], int(config.get("player_count",2)), config)
