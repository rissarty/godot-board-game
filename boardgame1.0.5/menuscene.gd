extends Control

@onready var Menupanel = $Panel
@onready var playbutton = $Playbutton
@onready var panel2 = $Panel2
@onready var Aibutton = $Panel2/VBoxContainer/vsAIbutton
@onready var passbutton = $Panel2/VBoxContainer/Passandplaybutton
@onready var PlayerCountPanel = $playercountpanel
@onready var vs1button = $playercountpanel/countbuttoncontainer/_2playerbutton
@onready var vs2button = $playercountpanel/countbuttoncontainer/_3playerbutton
@onready var vs3button = $playercountpanel/countbuttoncontainer/_4playerbutton
@onready var AISetupPanel = $Aisetuppanel
@onready var ai1_color_select = $Aisetuppanel/VBoxContaineraibox/Buttoncolour1
@onready var ai2_color_select = $Aisetuppanel/VBoxContaineraibox/Button2
@onready var ai3_color_select = $Aisetuppanel/VBoxContaineraibox/Button3
@onready var ai_level_select = $Aisetuppanel/VBoxContaineraibox/Button4
@onready var ai_playtest_button = $Aisetuppanel/VBoxContaineraibox/Button5


var selected_mode: String = ""   # "ai" or "pass"
var game_scene_packed := preload("res://boardgameplayscene.tscn")
var pending_player_count: int = 0  # store chosen count before setup
func _ready() -> void:
	# initial UI state
	panel2.visible = false
	PlayerCountPanel.visible = false
	AISetupPanel.visible = false
	
	# Hook up PlayTest button
	ai_playtest_button.pressed.connect(_on_ai_playtest_pressed)

	# Fill color choices
	for col in ["Red","Green","Blue","Yellow"]:
		ai1_color_select.add_item(col)
		ai2_color_select.add_item(col)
		ai3_color_select.add_item(col)

	# Fill level choices
	for lvl in range(0, 11):
		ai_level_select.add_item(str(lvl), lvl)

	# connect signals safely using Callables (avoid duplicate connections)
	var cb_play = Callable(self, "_on_playbutton_pressed")
	if not playbutton.pressed.is_connected(cb_play):
		playbutton.pressed.connect(cb_play)

	var cb_ai = Callable(self, "_on_vs_a_ibutton_pressed")
	if not Aibutton.pressed.is_connected(cb_ai):
		Aibutton.pressed.connect(cb_ai)

	var cb_pass = Callable(self, "_on_passandplaybutton_pressed")
	if not passbutton.pressed.is_connected(cb_pass):
		passbutton.pressed.connect(cb_pass)

	var cb_vs1 = Callable(self, "_on_vs1_pressed")
	if not vs1button.pressed.is_connected(cb_vs1):
		vs1button.pressed.connect(cb_vs1)

	var cb_vs2 = Callable(self, "_on_vs2_pressed")
	if not vs2button.pressed.is_connected(cb_vs2):
		vs2button.pressed.connect(cb_vs2)

	var cb_vs3 = Callable(self, "_on_vs3_pressed")
	if not vs3button.pressed.is_connected(cb_vs3):
		vs3button.pressed.connect(cb_vs3)


# --- play button ---
func _on_playbutton_pressed() -> void:
	panel2.visible = !panel2.visible


# --- mode selection ---
func _on_vs_a_ibutton_pressed() -> void:
	selected_mode = "ai"
	panel2.visible = false
	PlayerCountPanel.visible = true

func _on_passandplaybutton_pressed() -> void:
	selected_mode = "pass"
	panel2.visible = false
	PlayerCountPanel.visible = true

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
		# Show AI setup panel
		PlayerCountPanel.visible = false
		AISetupPanel.visible = true
	else:
		# Directly start pass & play
		_start_game(count)

# --- AI playtest start ---
func _on_ai_playtest_pressed() -> void:
	var ai_count = pending_player_count - 1  # human always 1
	var ai_colors: Array = []
	if ai_count >= 1:
		ai_colors.append(ai1_color_select.get_item_text(ai1_color_select.get_selected()))
	if ai_count >= 2:
		ai_colors.append(ai2_color_select.get_item_text(ai2_color_select.get_selected()))
	if ai_count >= 3:
		ai_colors.append(ai3_color_select.get_item_text(ai3_color_select.get_selected()))

	var level = int(ai_level_select.get_selected_id())
	var ai_levels: Array = []
	for i in range(ai_count):
		ai_levels.append(level)  # all same level for now

	var config = {
		"mode": "ai",
		"player_count": pending_player_count,
		"ai_count": ai_count,
		"ai_colors": ai_colors,
		"ai_levels": ai_levels
	}

	_start_game_with_config(config)


# --- updated start function ---
func _start_game_with_config(config: Dictionary) -> void:
	var game_scene = game_scene_packed.instantiate()
	get_tree().root.add_child(game_scene)
	game_scene.configure_mode(config.mode, config.player_count, config)
	var old_scene = get_tree().current_scene
	get_tree().current_scene = game_scene
	if is_instance_valid(old_scene):
		old_scene.queue_free()
# --- pass & play start ---
func _start_game(player_count: int) -> void:
	var config = {
		"mode": "pass",
		"player_count": player_count
	}
	_start_game_with_config(config)
