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

var selected_mode: String = ""   # "ai" or "pass"
var game_scene_packed := preload("res://boardgameplayscene.tscn")

func _ready() -> void:
	# initial UI state
	panel2.visible = false
	PlayerCountPanel.visible = false

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
	_start_game(2)  # 2 players total

func _on_vs2_pressed() -> void:
	_start_game(3)  # 3 players total

func _on_vs3_pressed() -> void:
	_start_game(4)  # 4 players total


# --- start the game scene ---
func _start_game(player_count: int) -> void:
	# If user didn't pick a mode, default to pass & play
	if selected_mode == "":
		selected_mode = "pass"

	# instantiate the game scene
	var game_scene = game_scene_packed.instantiate()
	# add to tree BEFORE calling configure_mode so the scene exists to receive calls
	get_tree().root.add_child(game_scene)

	# call configure_mode with mode and player count (INT!) — game scene expects (mode, count)
	game_scene.configure_mode(selected_mode, player_count)

	# switch current scene to new game scene, then free old menu to avoid locked-object errors
	var old_scene = get_tree().current_scene
	# set the new current scene first
	get_tree().current_scene = game_scene
	# now free the old scene safely (it is no longer current)
	if is_instance_valid(old_scene):
		old_scene.queue_free()
