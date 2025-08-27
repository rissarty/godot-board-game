extends Node2D

# === NODES / SCENES ===
@onready var tilemap            = $TileMap
@onready var tilemaplayer       = $TileMap/TileMapLayer
@onready var rollresult         = $rollresult
@onready var hand_container     = $HandPanel/cardhancontainer
@onready var handpanel          = $HandPanel
@onready var hand_button        = $showpowercardsbutton
@onready var shoppanel          = $Shoppanel
@onready var shop_container     = $Shoppanel/Shopcontainer1
@onready var Permcardbutton     = $permanentcardstogglebutton
@onready var permpanel          = $PermanentPanel
@onready var permcontainer      = $PermanentPanel/permContainer
@onready var permshopcontainer  = $Shoppanel/permshopcontainer
@onready var playerswappanel    = $playerswapPanel
@onready var playerswapcontainer= $playerswapPanel/swapnamecontainer
@onready var colourpanel        = $colourchoicePanel
@onready var red_button         = $colourchoicePanel/choosebuttoncontainer/chooseRed
@onready var blue_button        = $colourchoicePanel/choosebuttoncontainer/chooseBlue
@onready var green_button       = $colourchoicePanel/choosebuttoncontainer/chooseGreen
@onready var yellow_button      = $colourchoicePanel/choosebuttoncontainer/chooseYellow
@onready var moneylabel         = $MoneyLabel
@onready var money_layer        = $Moneytilesprite
@onready var ai_buttonspanel    = $Panel
@onready var ai_buttonscontainer= $Panel/aibuttonscontainer
@onready var card_scene         = preload("res://Cards.tscn")
@onready var money_texture      = preload("res://pixil-frame-0_scaled_6x_pngcrushed.png")
@onready var debug_log: Label = $debuglabel
# Debug log UI (create a Label node named "DebugLog" in your scene)
func log_debug(msg: String) -> void:
	if debug_log != null:
		# append line
		debug_log.text += msg + "\n"
		# keep only last 20 lines so it doesn't grow forever
		var lines := debug_log.text.split("\n")
		if lines.size() > 20:
			debug_log.text = "\n".join(lines.slice(lines.size() - 20, lines.size()))
	else:
		# fallback to console if label missing
		print("[DEBUG] " + msg)

# optional AI manager preload (unused by default)
const AIManagerClass := preload("res://ai_managerscene.gd")
var ai_manager: Node = null

var money_nodes_by_tile : Dictionary = {}       # maps tile_num -> Sprite2D node
var money_value : int = 5                      # how much each coin gives

# ---------- AI setup state ----------
var ai_setup: Array = []            # array of dictionaries { "color": "G", "level": 3 }
var reserved_ai_colors: Array = []  # list of colors reserved for AI
var ai_level_by_color := {"R": 0, "G": 0, "B": 0, "Y": 0}

# board layout (editable from Inspector)
const BOARD_ROWS: int = 10
const BOARD_COLS: int = 10
const MONEY_TILE_ID = 5

# === CONFIG / DATABASES ===
var game_mode: String = "pass"        # "pass" or "ai"
var player_count: int = 2             # 2..4
var desired_player_count: int = 2     # temporary store while color choice is pending
var turn_order: Array = []            # e.g. ["R","B"] or ["R","G","B","Y"]
var chosen_color : String = ""
var is_singleplayer_mode := false

var player_nodes: Dictionary = {}
var swap_source_player: String = ""
var rarity_weights = {"common":60, "rare":45, "epic":10, "legendary":1}

var power_cards_db = {
	"+1 Move": {"name":"+1 Move","move_value":1,"shop_cost":0,"rarity":"common"},
	"-2 Move": {"name":"-2 Move","move_value":-2,"shop_cost":0,"rarity":"common"},
	"+3 Move": {"name":"+3 Move","move_value":3,"shop_cost":2,"rarity":"rare"},
	"-4 Move": {"name":"-4 Move","move_value":-4,"shop_cost":2,"rarity":"rare"},
	"Swap":    {"name":"Swap","shop_cost":3,"rarity":"epic"}
}

var permanent_cards_db = {
	"D20 Upgrade": {
		"name": "D20 Upgrade",
		"effect": "upgrade_dice(20)",
		"shop_cost": 5,
		"rarity": "common",
		"type": "permanent"
	},
	"Odd Space Boost": {
		"name": "Odd Space Boost",
		"effect": "odd_space_move(1)",
		"shop_cost": 3,
		"rarity": "common",
		"type": "permanent"
	}
}

var player_is_ai := {"R":false,"G":false,"B":false,"Y":false}

var max_hand_size: int = 3
var player_hands := {"R":[], "G":[], "B":[], "Y":[]}
var player_permanents := {"R":[], "G":[], "B":[], "Y":[]}
var player_dice_sides = {"R":6,"G":6,"B":6,"Y":6}
var player_money = {"R":10,"G":10,"B":10,"Y":10}
var player_positions = {"R":1,"G":1,"B":1,"Y":1}

var TILE_SIZE: Vector2 = Vector2(40, 40)
var BOARD_START: Vector2 = Vector2(336, 624)
var tile_map = {}

var current_turn_index: int = 0
var has_rolled_dice: bool = false
var snakes  = {20:5, 43:17, 87:24}
var ladders = {3:22, 8:30, 28:84}
var offset  = {"R":Vector2(-4,-4),"G":Vector2(4,-4),"B":Vector2(-4,4),"Y":Vector2(4,4)}

@export var cards_per_shop: int = 3
# normalize color input so both "Red"/"red"/"R" -> "R" etc.
# normalize color input so both "Red"/"red"/"R" -> "R" etc.
func _color_name_to_code(col: String) -> String:
	var s := col.strip_edges().to_lower()
	if s == "r" or s == "red":
		return "R"
	elif s == "g" or s == "green":
		return "G"
	elif s == "b" or s == "blue":
		return "B"
	elif s == "y" or s == "yellow":
		return "Y"

	# fallback: check first letter
	if s.length() > 0:
		var c := s[0]
		if c == "r":
			return "R"
		elif c == "g":
			return "G"
		elif c == "b":
			return "B"
		elif c == "y":
			return "Y"

	# final fallback: return first char uppercased
	return col.substr(0, 1).to_upper()
# -------------------------
# READY
# -------------------------
func _ready() -> void:
	randomize()

	# read cell size if available
	if tilemaplayer and tilemaplayer.has_method("get_cell_size"):
		var cs: Vector2 = tilemaplayer.get_cell_size()
		if typeof(cs) == TYPE_VECTOR2 and cs.x > 0:
			TILE_SIZE = cs

	generate_tile_map()

	if money_layer != null and money_layer is Node2D:
		(money_layer as Node2D).scale = Vector2(0.42, 0.42)

	spawn_money_tiles(5)

	player_nodes = {
		"R": $playerRED,
		"G": $player1spriteGreen,
		"B": $playerBLUE,
		"Y": $playerYELLOW
	}

	if tile_map.has(1):
		for color in player_nodes.keys():
			var n = player_nodes[color]
			if n != null:
				n.position = tile_map[1] + offset.get(color, Vector2.ZERO)

	# connect colour pick buttons (safe)
	var cb_red = Callable(self, "_on_choose_color").bind("R")
	if red_button and not red_button.pressed.is_connected(cb_red):
		red_button.pressed.connect(cb_red)

	var cb_blue = Callable(self, "_on_choose_color").bind("B")
	if blue_button and not blue_button.pressed.is_connected(cb_blue):
		blue_button.pressed.connect(cb_blue)

	var cb_green = Callable(self, "_on_choose_color").bind("G")
	if green_button and not green_button.pressed.is_connected(cb_green):
		green_button.pressed.connect(cb_green)

	var cb_yellow = Callable(self, "_on_choose_color").bind("Y")
	if yellow_button and not yellow_button.pressed.is_connected(cb_yellow):
		yellow_button.pressed.connect(cb_yellow)

	colourpanel.visible = false

# -------------------------
# AI setup UI (top-level helpers)
# -------------------------
func show_ai_setup(default_count: int = 1) -> void:
	var old = get_node_or_null("AISetupWindow")
	if old:
		old.queue_free()

	# PopupPanel is safe and available in Godot 4
	var win := PopupPanel.new()
	win.name = "AISetupWindow"
	# we'll add a small title label instead of window_title property
	win.size = Vector2(420, 320)
	win.popup_centered(win.size)

	var vb := VBoxContainer.new()
	vb.custom_minimum_size = Vector2(380, 260)
	win.add_child(vb)
	
	# title
	var title = Label.new()
	title.text = "VS AI — Setup"
	title.add_theme_font_size_override("font_size", 18)
	vb.add_child(title)


	# AI count row
	var h_count := HBoxContainer.new()
	var lbl_count := Label.new()
	lbl_count.text = "AI count:"
	h_count.add_child(lbl_count)
	var ai_count_select := OptionButton.new()
	for i in range(1, 4):
		ai_count_select.add_item(str(i), i)
	ai_count_select.select(clamp(default_count, 1, 3) - 1)
	h_count.add_child(ai_count_select)
	vb.add_child(h_count)

	# shared-level checkbox + select
	var h_shared := HBoxContainer.new()
	var shared_cb := CheckBox.new()
	shared_cb.text = "Use single level for all AIs"
	shared_cb.button_pressed = true
	h_shared.add_child(shared_cb)

	var shared_level_label := Label.new()
	shared_level_label.text = "Level:"
	h_shared.add_child(shared_level_label)

	var shared_level_select := OptionButton.new()
	for l in range(0, 11):
		shared_level_select.add_item(str(l), l)
	# select index 1 as default
	shared_level_select.select(1)
	h_shared.add_child(shared_level_select)
	vb.add_child(h_shared)

	# rows container where each AI will have color + level (if not shared)
	var rows_container := VBoxContainer.new()
	rows_container.name = "ai_rows"
	vb.add_child(rows_container)

	# initial build
	rebuild_ai_rows(ai_count_select.get_selected_id(), rows_container, shared_cb)

	# connect signals
	# item_selected will pass id as parameter; we bind rows_container & shared_cb first
	ai_count_select.item_selected.connect(Callable(self, "_on_ai_count_changed").bind(rows_container, shared_cb))
	shared_cb.toggled.connect(Callable(self, "_on_shared_toggled").bind(rows_container))

	# buttons row (right aligned using spacer)
	var btns := HBoxContainer.new()
	var spacer := Control.new()
	spacer.h_size_flags = Control.SIZE_EXPAND_FILL
	btns.add_child(spacer)

	var cancel_b := Button.new()
	cancel_b.text = "Cancel"
	cancel_b.pressed.connect(Callable(win, "hide"))
	btns.add_child(cancel_b)

	var start_b := Button.new()
	start_b.text = "Start Test"
	start_b.pressed.connect(Callable(self, "_on_ai_setup_start").bind(win, ai_count_select, shared_cb, shared_level_select, rows_container))
	btns.add_child(start_b)

	vb.add_child(btns)

	add_child(win)
	win.show()


func rebuild_ai_rows(count: int, rows_container: Node, shared_cb: CheckBox) -> void:
	# clear existing
	clear_children(rows_container)
	for j in range(count):
		var row := HBoxContainer.new()
		row.name = "ai_row_%d" % j

		var rlabel := Label.new()
		rlabel.text = "AI %d:" % (j + 1)
		row.add_child(rlabel)

		var color_sel := OptionButton.new()
		color_sel.name = "ai_color_%d" % j
		for col in ["R","G","B","Y"]:
			color_sel.add_item(col)
		row.add_child(color_sel)

		var level_sel := OptionButton.new()
		level_sel.name = "ai_level_%d" % j
		for l in range(0, 11):
			level_sel.add_item(str(l), l)
		level_sel.select(1)
		level_sel.visible = not shared_cb.pressed
		row.add_child(level_sel)

		rows_container.add_child(row)


func _on_ai_count_changed(rows_container: Node, shared_cb: CheckBox, id: int) -> void:
	var count := id
	if count < 1:
		count = 1
	rebuild_ai_rows(count, rows_container, shared_cb)


func _on_shared_toggled(rows_container: Node, pressed: bool) -> void:
	# toggle visibility of per-row level selectors
	var idx := 0
	for row in rows_container.get_children():
		var level_node_name = "ai_level_%d" % idx
		var lvl_node = row.get_node_or_null(level_node_name)
		if lvl_node:
			lvl_node.visible = not pressed
		idx += 1


# Called when Start Test pressed
# Note: win declared as Node so we don't depend on a specific Dialog type in the signature
func _on_ai_setup_start(win: Node, ai_count_select: OptionButton, shared_cb: CheckBox, shared_level_select: OptionButton, rows_container: Node) -> void:
	var count := ai_count_select.get_selected_id()
	if count < 1:
		count = 1

	var tmp_setup := []
	var used := {}
	var conflict := false

	for i in range(count):
		var row_name := "ai_row_%d" % i
		var row := rows_container.get_node_or_null(row_name)
		if not row:
			continue
		var color_sel := row.get_node_or_null("ai_color_%d" % i) as OptionButton
		var level_sel := row.get_node_or_null("ai_level_%d" % i) as OptionButton

		var col_text := color_sel.get_item_text(color_sel.get_selected())
		var level = shared_level_select.get_selected_id() if shared_cb.pressed else level_sel.get_selected_id()
		level = int(level)

		if used.has(col_text):
			conflict = true
		used[col_text] = true
		tmp_setup.append({"color": col_text, "level": level})

	if conflict:
		rollresult.text = "AI Setup: duplicate colors chosen — please pick unique colors."
		return

	# commit setup
	ai_setup = tmp_setup
	reserved_ai_colors.clear()
	for e in ai_setup:
		var c = String(e["color"])
		reserved_ai_colors.append(c)
		ai_level_by_color[c] = int(e["level"])
		player_is_ai[c] = true

	desired_player_count = 1 + ai_setup.size()

	# disable reserved color buttons in colourpanel (safely)
	if red_button: red_button.disabled = "R" in reserved_ai_colors
	if blue_button: blue_button.disabled = "B" in reserved_ai_colors
	if green_button: green_button.disabled = "G" in reserved_ai_colors
	if yellow_button: yellow_button.disabled = "Y" in reserved_ai_colors

	# hide popup and show color picker
	if win and win.has_method("hide"):
		win.hide()
	colourpanel.visible = true
	rollresult.text = "Choose your color (AI colors reserved)."


# Debug helper: prints the core AI/player state
func _debug_print_ai_state(tag: String = "") -> void:
	print("=== DEBUG AI STATE ", tag, " ===")
	print("game_mode:", game_mode)
	print("player_count:", player_count, " desired_player_count:", desired_player_count)
	print("ai_setup:", ai_setup)
	print("reserved_ai_colors:", reserved_ai_colors)
	print("ai_level_by_color:", ai_level_by_color)
	print("player_is_ai:", player_is_ai)
	print("turn_order:", turn_order)
	print("current_turn_index:", current_turn_index)
	print("==============================")

# -------------------------
# Configure mode entrypoint (REPLACE your old one)
# -------------------------
func configure_mode(mode: String, count: int, config: Dictionary = {}) -> void:
	game_mode = mode
	player_count = clamp(count, 2, 4)

	# reset AI/human markers & ai_setup state
	ai_setup.clear()
	reserved_ai_colors.clear()
	ai_level_by_color = {"R": 0, "G": 0, "B": 0, "Y": 0}
	player_is_ai = {"R":false,"G":false,"B":false,"Y":false}

	# If menu passed an AI config, consume it
	if game_mode == "ai" and config.size() > 0 and config.has("ai_colors") and config.has("ai_levels"):
		# sanitize values
		var ai_count := int(config.get("ai_count", 0))
		ai_count = clamp(ai_count, 1, 3)

		for i in range(ai_count):
			var raw_col = String(config.ai_colors[i])
			var col = _color_name_to_code(raw_col)
			var lvl = int(config.ai_levels[i])
			ai_setup.append({"color": col, "level": lvl})
			reserved_ai_colors.append(col)
			player_is_ai[col] = true
			ai_level_by_color[col] = lvl
			print("[CONFIGURE_MODE] mapped menu color '%s' -> '%s', level=%d" % [raw_col, col, lvl])


		# desired player count is total players (human + ai_count)
		desired_player_count = clamp(int(config.get("player_count", 1)), 2, 4)

		# choose whether user must pick a color or auto-assign
		# If you want the human to pick via the color panel, keep colourpanel.visible = true
		# For fast testing we auto-assign the first available color if colourpanel is not shown
		if colourpanel != null:
			colourpanel.visible = true
			rollresult.text = "Choose your color (AI colors reserved)."
			# keep here so human can pick manually; return early
			_debug_print_ai_state("after config - awaiting human choice")
			return
		else:
			# auto assign a human color now (first color not reserved)
			var base := ["R","G","B","Y"]
			var human_color := ""
			for c in base:
				if not (c in reserved_ai_colors):
					human_color = c
					break
			if human_color == "":
				# fallback (shouldn't happen)
				human_color = "R"
			_on_choose_color(human_color)
			return

	# Fallback path (pass & play or no config)
	desired_player_count = clamp(player_count, 2, 4)
	# default turn_order by count (human colors assigned as conventional starting set)
	match desired_player_count:
		2: turn_order = ["R","B"]
		3: turn_order = ["R","G","B"]
		4: turn_order = ["R","G","B","Y"]

	# ensure player_is_ai false for all in pass & play
	for c in ["R","G","B","Y"]:
		player_is_ai[c] = false

	_debug_print_ai_state("fallback/passplay")
	_finish_initial_setup_and_start()

# -------------------------
# Colour pick chosen by human (REPLACE your old one)
# -------------------------
func _on_choose_color(color_letter: String) -> void:
	# Called by the colourpanel when the human chooses a color, or by auto-assign above.
	colourpanel.visible = false
	chosen_color = color_letter

	# ensure reserved/AI flags are honored (ai_setup should already be set if coming from menu)
	# If ai_setup is empty, then this is pass & play: keep existing turn_order logic
	var base := ["R","G","B","Y"]

	# If ai_setup was provided, combine human + ai entries
	if ai_setup.size() > 0:
		# Ensure all player_is_ai flags reflect ai_setup
		for c in base:
			player_is_ai[c] = false
		for e in ai_setup:
			var ccol = String(e["color"])
			player_is_ai[ccol] = true
			ai_level_by_color[ccol] = int(e["level"])

		# Human must not be AI
		player_is_ai[chosen_color] = false

		# Build turn_order rotated so human goes first and includes exactly desired_player_count entries
		var idx := base.find(chosen_color)
		if idx == -1:
			idx = 0
		var rotated := base.slice(idx, base.size()) + base.slice(0, idx)
		turn_order = rotated.slice(0, clamp(desired_player_count, 1, 4))

	else:
		# pass & play style: rotate standard set so chosen_color is first
		var idx := base.find(chosen_color)
		if idx == -1:
			idx = 0
		var rotated := base.slice(idx, base.size()) + base.slice(0, idx)
		turn_order = rotated.slice(0, clamp(desired_player_count, 1, 4))

	# Initialize/reset per-player runtime state
	for c in ["R","G","B","Y"]:
		# ensure players flagged correctly; if not in turn_order then treat as inactive (not AI)
		if c in turn_order:
			# if not already set and not reserved, default to human
			if not player_is_ai.has(c):
				player_is_ai[c] = false
		else:
			player_is_ai[c] = false

	# Ensure player_positions exist and sprites are placed at tile 1 (or your starting tile)
	for c in player_nodes.keys():
		player_positions[c] = player_positions.get(c, 1)
		if tile_map.has(player_positions[c]) and player_nodes[c] != null:
			player_nodes[c].position = tile_map[player_positions[c]] + get_offset_if_needed(player_positions[c], c)

	_debug_print_ai_state("after human pick")
	_finish_initial_setup_and_start()

# Add an informational debug line inside start_turn() so we can see what it's doing
func start_turn() -> void:
	if turn_order.is_empty():
		return
	var color = get_current_player()
	if color == "":
		return
	# debug line:
	print("[START_TURN] current player:", color, " player_is_ai:", player_is_ai.get(color, false), " ai_level:", ai_level_by_color.get(color, 0))
	has_rolled_dice = false
	refresh_hand_for_current_player()
	refresh_permanent_panel_for_current_player()
	populate_shop()
	populate_permanent_shop(color)

	if player_is_ai.get(color, false):
		var level = int(ai_level_by_color.get(color, 0))
		call_deferred("_deferred_start_ai_turn_with_level", level, color)

func _finish_initial_setup_and_start() -> void:
	if turn_order.is_empty():
		turn_order = ["R","G","B","Y"].slice(0, clamp(desired_player_count, 1, 4))

	for c in turn_order:
		create_starting_hand_for_player(c)

	current_turn_index = 0
	refresh_hand_for_current_player()
	populate_shop()
	populate_permanent_shop(get_current_player())
	refresh_permanent_panel_for_current_player()
	update_hand_turn_state()
	start_turn()
	ensure_money_label()
	refresh_money_label()


# ---------- Money label helpers ----------
func ensure_money_label() -> void:
	if moneylabel == null or not moneylabel is Label:
		var node = get_node_or_null("MoneyLabel")
		if node and node is Label:
			moneylabel = node
		else:
			var lbl = Label.new()
			lbl.name = "MoneyLabel"
			lbl.anchor_left = 0
			lbl.anchor_top = 0
			lbl.margin_left = 12
			lbl.margin_top = 8
			add_child(lbl)
			moneylabel = lbl
	moneylabel.visible = true

func refresh_money_label() -> void:
	if moneylabel == null:
		return
	if turn_order.is_empty():
		moneylabel.text = ""
		return
	var cp := get_current_player()
	if cp == "":
		moneylabel.text = ""
		return
	var money := int(player_money.get(cp, 0))
	moneylabel.text = "%s  $%d" % [cp, money]

func refresh_all_money_labels() -> void:
	if moneylabel == null:
		return
	var lines := []
	for c in ["R","G","B","Y"]:
		var m = int(player_money.get(c, 0))
		lines.append("%s:$%d" % [c, m])

	var out := ""
	for i in range(lines.size()):
		if i > 0:
			out += "  |  "
		out += lines[i]
	moneylabel.text = out


# -------------------------------
# HAND (per-player model + shared UI)
# -------------------------------
func create_starting_hand_for_player(player_color: String) -> void:
	if player_hands[player_color].size() == 0:
		for name in ["+1 Move","-2 Move"]:
			player_hands[player_color].append(power_cards_db[name].duplicate(true))
	if player_color == get_current_player():
		refresh_hand_for_current_player()

func clear_hand() -> void:
	for c in hand_container.get_children():
		c.queue_free()

func refresh_hand_for_current_player() -> void:
	if turn_order.is_empty():
		return
	clear_hand()
	var cp = get_current_player()
	if cp == "":
		return
	for cd in player_hands[cp]:
		var card = card_scene.instantiate()
		card.set_card_data(cd)
		card.card_played.connect(_on_card_played)
		hand_container.add_child(card)
	update_hand_turn_state()
	refresh_money_label()


func update_hand_turn_state() -> void:
	var is_my_turn = true
	for card in hand_container.get_children():
		if card.has_method("set_turn_state"):
			card.set_turn_state(is_my_turn, has_rolled_dice)

func _on_card_played(move_value: int, card_data: Dictionary) -> void:
	var current_player = get_current_player()
	if current_player == "":
		return
	var card_name = String(card_data.get("name",""))
	_remove_card_from_player_hand(current_player, card_data)
	refresh_hand_for_current_player()
	if card_name == "Swap":
		start_swap_selection(current_player)
	else:
		apply_card_effect(move_value)

func _remove_card_from_player_hand(player_color: String, card_data: Dictionary) -> void:
	var name_to_find = String(card_data.get("name",""))
	for i in range(player_hands[player_color].size()):
		var cd = player_hands[player_color][i]
		if String(cd.get("name","")) == name_to_find:
			player_hands[player_color].remove_at(i)
			return


# -------------------------------
# AI & Turn control (local testing)
# -------------------------------

func setup_game(config: Dictionary) -> void:
	# Instead of duplicating logic, just delegate to configure_mode
	configure_mode("ai", 1 + int(config.get("ai_count", 0)), config)
	

	# Add AI players
	for i in range(int(config.get("ai_count", 0))):
		var raw_col = String(config["ai_colors"][i])
		var color = _color_name_to_code(raw_col)
		turn_order.append(color)
		player_is_ai[color] = true
		ai_level_by_color[color] = int(config["ai_levels"][i])
		print("[SETUP_GAME] mapped menu color '%s' -> '%s' level=%d" % [raw_col, color, ai_level_by_color[color]])

	# Now initialize board positions
	for col in turn_order:
		player_positions[col] = 0
		# spawn player sprite etc.

func _deferred_start_ai_turn_with_level(level: int, color: String) -> void:
	call_deferred("_perform_ai_turn", level, color)


func _perform_ai_turn(level: int, color: String) -> void:
	await get_tree().create_timer(0.35).timeout

	match level:
		0:
			pass
		1:
			if randf() < 0.50:
				ai_play_random_card(color, "common")
			if randf() < 0.40:
				ai_buy_card(color, "common")
		2:
			if randf() < 0.90:
				ai_play_random_card(color, "common")
			if randf() < 0.10:
				ai_play_random_card(color, "rare")
			if randf() < 0.20:
				ai_buy_permanent(color, "common")
		3:
			if randf() < 0.92:
				ai_play_random_card(color, "common")
			if randf() < 0.20:
				ai_play_random_card(color, "rare")
			if randf() < 0.30:
				ai_buy_permanent(color, "common")
		4:
			if randf() < 0.95:
				ai_play_random_card(color, "common")
			if randf() < 0.30:
				ai_play_random_card(color, "rare")
			if randf() < 0.35:
				ai_buy_permanent(color, "common")
		5:
			if randf() < 0.95:
				ai_play_random_card(color, "common")
			if randf() < 0.40:
				ai_play_random_card(color, "rare")
			if randf() < 0.20:
				ai_play_random_card(color, "epic")
			if randf() < 0.25:
				ai_buy_permanent(color, "rare")
		6:
			if randf() < 0.98:
				ai_play_random_card(color, "common")
			if randf() < 0.45:
				ai_play_random_card(color, "rare")
			if randf() < 0.30:
				ai_play_random_card(color, "epic")
			if randf() < 0.35:
				ai_buy_permanent(color, "rare")
		7:
			if randf() < 1.0:
				ai_play_random_card(color, "common")
			if randf() < 0.60:
				ai_play_random_card(color, "rare")
			if randf() < 0.40:
				ai_play_random_card(color, "epic")
			if randf() < 0.40:
				ai_buy_permanent(color, "rare")
		8:
			if randf() < 1.0:
				ai_play_random_card(color, "common")
			if randf() < 0.70:
				ai_play_random_card(color, "rare")
			if randf() < 0.50:
				ai_play_random_card(color, "epic")
			if randf() < 0.45:
				ai_buy_permanent(color, "rare")
			if randf() < 0.25:
				ai_buy_permanent(color, "legendary")
		9:
			if randf() < 1.0:
				ai_play_random_card(color, "common")
			if randf() < 0.80:
				ai_play_random_card(color, "rare")
			if randf() < 0.65:
				ai_play_random_card(color, "epic")
			if randf() < 0.60:
				ai_buy_permanent(color, "rare")
			if randf() < 0.35:
				ai_buy_permanent(color, "legendary")
		10:
			ai_play_random_card(color, "common")
			if randf() < 0.90:
				ai_play_random_card(color, "rare")
			if randf() < 0.85:
				ai_play_random_card(color, "epic")
			if randf() < 0.70:
				ai_play_random_card(color, "legendary")
			if randf() < 0.60:
				ai_buy_permanent(color, "legendary")
			if randf() < 0.5:
				ai_play_random_card(color, "swap")

	await get_tree().create_timer(0.25).timeout
	_ai_roll_and_move(color)


func _deferred_start_ai_turn(color: String) -> void:
	call_deferred("ai_take_turn", color)


func ai_take_turn(ai_color: String) -> void:
	await get_tree().create_timer(0.6).timeout
	for cd in player_hands[ai_color]:
		var mv = int(cd.get("move_value", 0))
		if mv != 0:
			_remove_card_from_player_hand(ai_color, cd)
			if ai_color == get_current_player():
				refresh_hand_for_current_player()
			apply_card_effect(mv)
			break
	await get_tree().create_timer(0.4).timeout
	_ai_roll_and_move(ai_color)


func _ai_roll_and_move(color: String) -> void:
	var dice_sides = int(player_dice_sides.get(color, 6))
	if dice_sides <= 0:
		dice_sides = 6
	var dice_roll = randi() % dice_sides + 1
	log_debug("%s (AI) rolled %d (sides %d)" % [color, dice_roll, dice_sides])
	rollresult.text = color + " (AI) rolled a " + str(dice_roll)

	if has_rolled_dice:
		return
	has_rolled_dice = true

	var sprite: Node2D = player_nodes.get(color, null)
	if sprite == null:
		return

	var tile = player_positions[color]
	var target_tile = min(tile + dice_roll, 100)

	for i in range(tile + 1, target_tile + 1):
		if tile_map.has(i):
			sprite.position = tile_map[i] + get_offset_if_needed(i, color)
		await get_tree().create_timer(0.25).timeout

	player_positions[color] = target_tile

	if target_tile in snakes:
		await get_tree().create_timer(0.45).timeout
		var oldpos: int = target_tile
		player_positions[color] = snakes[target_tile]
		if tile_map.has(player_positions[color]):
			sprite.position = tile_map[player_positions[color]] + get_offset_if_needed(player_positions[color], color)
		log_debug("%s (AI) hit a SNAKE %d -> %d" % [color, oldpos, player_positions[color]])

	elif target_tile in ladders:
		await get_tree().create_timer(0.45).timeout
		var oldpos: int = target_tile
		player_positions[color] = ladders[target_tile]
		if tile_map.has(player_positions[color]):
			sprite.position = tile_map[player_positions[color]] + get_offset_if_needed(player_positions[color], color)
		log_debug("%s (AI) climbed a LADDER %d -> %d" % [color, oldpos, player_positions[color]])

	check_for_money_collection(color)
	end_turn()
# -------------------------------
# SWAP UI & Logic
# -------------------------------
func start_swap_selection(source_player_color: String) -> void:
	swap_source_player = source_player_color
	clear_children(playerswapcontainer)
	for col in player_nodes.keys():
		if col == source_player_color:
			continue
		var btn := Button.new()
		btn.text = col
		btn.pressed.connect(Callable(self, "_on_swap_target_selected").bind(col))
		playerswapcontainer.add_child(btn)
	playerswappanel.visible = true

func _on_swap_target_selected(target_player_color: String) -> void:
	if swap_source_player == "":
		playerswappanel.visible = false
		return
	var src = swap_source_player
	var tmp = int(player_positions[src])
	player_positions[src] = int(player_positions[target_player_color])
	player_positions[target_player_color] = tmp
	if player_nodes.has(src):
		player_nodes[src].position = tile_map[player_positions[src]] + get_offset_if_needed(player_positions[src], src)
	if player_nodes.has(target_player_color):
		player_nodes[target_player_color].position = tile_map[player_positions[target_player_color]] + get_offset_if_needed(player_positions[target_player_color], target_player_color)
	rollresult.text = src + " swapped positions with " + target_player_color
	playerswappanel.visible = false
	swap_source_player = ""

func clear_children(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()

func update_player_positions() -> void:
	for color in player_nodes.keys():
		var t = int(player_positions.get(color, 1))
		if tile_map.has(t):
			player_nodes[color].position = tile_map[t] + get_offset_if_needed(t, color)


# -------------------------------
# SHOP / PERMANENTS
# -------------------------------
func get_random_card_name() -> String:
	var weighted_list := []
	for card_name in power_cards_db.keys():
		var weight = int(rarity_weights.get(power_cards_db[card_name].get("rarity","common"),0))
		for i in range(weight):
			weighted_list.append(card_name)
	if weighted_list.size() == 0:
		return ""
	return weighted_list[randi() % weighted_list.size()]

func populate_shop() -> void:
	for c in shop_container.get_children():
		c.queue_free()
	var shop_cards := []
	while shop_cards.size() < cards_per_shop:
		var n = get_random_card_name()
		if n != "":
			shop_cards.append(n)
	for card_name in shop_cards:
		var data = power_cards_db[card_name]
		var card = card_scene.instantiate()
		card.set_card_data(data)
		card.set_card_mode("shop", func(card_data): _on_shop_card_bought(card_data, card))
		shop_container.add_child(card)

func _on_shop_card_bought(card_data: Dictionary, shop_card_node: Node) -> void:
	var current_player = get_current_player()
	if current_player == "":
		return
	if player_hands[current_player].size() >= max_hand_size:
		print("hand full")
		return
	var cost = int(card_data.get("shop_cost",0))
	if player_money[current_player] >= cost:
		player_money[current_player] -= cost
		player_hands[current_player].append(card_data.duplicate(true))
		refresh_hand_for_current_player()
		if is_instance_valid(shop_card_node):
			shop_card_node.queue_free()
	else:
		print("Not enough money")

func populate_permanent_shop(for_player_id: String) -> void:
	for c in permshopcontainer.get_children():
		c.queue_free()
	if permanent_cards_db.size() == 0:
		return
	var name := ""
	for k in permanent_cards_db.keys():
		name = k
		break
	var data = permanent_cards_db[name]
	var card = card_scene.instantiate()
	card.set_card_data(data)
	card.set_card_mode("shop", func(card_data): _on_permanent_card_bought(card_data, card))
	permshopcontainer.add_child(card)

func refresh_permanent_panel_for_current_player() -> void:
	clear_children(permcontainer)
	var owner = get_current_player()
	if owner == "":
		return
	for perm in player_permanents[owner]:
		var n = card_scene.instantiate()
		n.set_card_data(perm)
		n.set_card_mode("permanent_active")
		permcontainer.add_child(n)

func _on_permanent_card_bought(card_data: Dictionary, shop_card_node: Node) -> void:
	var current_player = get_current_player()
	if current_player == "":
		return
	var cost = int(card_data.get("shop_cost",0))
	if player_money[current_player] < cost:
		print("Not enough money")
		return
	player_money[current_player] -= cost
	player_permanents[current_player].append(card_data.duplicate(true))
	apply_permanent_effect(card_data, current_player)
	if is_instance_valid(shop_card_node):
		shop_card_node.queue_free()
	refresh_permanent_panel_for_current_player()
	refresh_money_label()
func apply_permanent_effect(card_data: Dictionary, player_color: String) -> void:
	match card_data.get("name",""):
		"D20 Upgrade":
			player_dice_sides[player_color] = 20
		"Odd Space Boost":
			pass
		_:
			pass
# -------------------------------
# GAME LOGIC (movement)
# -------------------------------
func apply_card_effect(move_value: int) -> void:
	var current_color = get_current_player()
	if current_color == "":
		return
	player_positions[current_color] += move_value
	player_positions[current_color] = clamp(player_positions[current_color], 1, 100)
	if player_nodes.has(current_color) and tile_map.has(player_positions[current_color]):
		player_nodes[current_color].position = tile_map[player_positions[current_color]] + get_offset_if_needed(player_positions[current_color], current_color)
	check_for_money_collection(current_color)
func _on_dicerollbutton_pressed() -> void:
	if has_rolled_dice:
		return
	has_rolled_dice = true

	var current_color = get_current_player()
	if current_color == "":
		return
	var sprite: Node2D = player_nodes.get(current_color, null)
	if sprite == null:
		return

	var tile = player_positions[current_color]
	var dice_sides = int(player_dice_sides.get(current_color, 6))
	if dice_sides <= 0:
		dice_sides = 6

	var dice_roll = randi() % dice_sides + 1
	log_debug("%s (Player) rolled %d (sides %d)" % [current_color, dice_roll, dice_sides])
	rollresult.text = current_color + " rolled a " + str(dice_roll)

	var target_tile = min(tile + dice_roll, 100)
	for i in range(tile + 1, target_tile + 1):
		if tile_map.has(i):
			sprite.position = tile_map[i] + get_offset_if_needed(i, current_color)
		await get_tree().create_timer(0.3).timeout

	player_positions[current_color] = target_tile
	if target_tile in snakes:
		await get_tree().create_timer(0.5).timeout
		player_positions[current_color] = snakes[target_tile]
		if tile_map.has(player_positions[current_color]):
			sprite.position = tile_map[player_positions[current_color]] + get_offset_if_needed(player_positions[current_color], current_color)
	elif target_tile in ladders:
		await get_tree().create_timer(0.5).timeout
		player_positions[current_color] = ladders[target_tile]
		if tile_map.has(player_positions[current_color]):
			sprite.position = tile_map[player_positions[current_color]] + get_offset_if_needed(player_positions[current_color], current_color)

	check_for_money_collection(current_color)
	end_turn()

func end_turn() -> void:
	if turn_order.size() > 0:
		current_turn_index = (current_turn_index + 1) % turn_order.size()
	else:
		push_error("turn_order is empty! No players to cycle turns.")
		return

	has_rolled_dice = false
	update_hand_turn_state()
	populate_shop()
	populate_permanent_shop(get_current_player())
	refresh_permanent_panel_for_current_player()
	refresh_hand_for_current_player()
	start_turn()
	refresh_money_label()


func get_current_player() -> String:
	if turn_order.is_empty():
		return ""
	if current_turn_index < 0 or current_turn_index >= turn_order.size():
		current_turn_index = 0
		return turn_order[0] if turn_order.size() > 0 else ""
	return turn_order[current_turn_index]


# New generate_tile_map - deterministic serpentine layout
func generate_tile_map() -> void:
	tile_map.clear()
	var tile_num: int = 1
	for row in range(BOARD_ROWS):
		var y: float = BOARD_START.y - float(row) * TILE_SIZE.y
		for col in range(BOARD_COLS):
			var real_col: int = col if (row % 2) == 0 else (BOARD_COLS - 1 - col)
			var x: float = BOARD_START.x + float(real_col) * TILE_SIZE.x
			var world_pos: Vector2 = Vector2(x, y)
			tile_map[tile_num] = world_pos
			tile_num += 1

	if tile_map.has(1):   print("tile 1 pos:", tile_map[1])
	if tile_map.has(10):  print("tile 10 pos:", tile_map[10])
	if tile_map.has(100): print("tile 100 pos:", tile_map[100])

	for color in player_nodes.keys():
		if tile_map.has(1) and player_nodes[color] != null:
			player_nodes[color].position = tile_map[1] + offset.get(color, Vector2.ZERO)


# --- Money helpers ---
var COIN_SIZE_FACTOR: float = 0.65
var COIN_OFFSET: Vector2 = Vector2(0, -8)

func clear_money_tiles() -> void:
	for key_variant in money_nodes_by_tile.keys():
		var tile_key: int = int(key_variant)
		var coin_node: Node = money_nodes_by_tile[tile_key] as Node
		if coin_node != null and is_instance_valid(coin_node):
			coin_node.queue_free()
	money_nodes_by_tile.clear()

func set_coin_visuals(size_factor: float = COIN_SIZE_FACTOR, offset: Vector2 = COIN_OFFSET) -> void:
	for key_variant in money_nodes_by_tile.keys():
		var tile_num: int = int(key_variant)
		var coin: Sprite2D = money_nodes_by_tile[tile_num] as Sprite2D
		if coin == null or not is_instance_valid(coin):
			continue
		if coin.texture == null:
			continue
		var tex_size: Vector2 = coin.texture.get_size()
		if tex_size.x > 0 and tex_size.y > 0:
			coin.scale = TILE_SIZE / tex_size
		else:
			coin.scale = Vector2.ONE
		if tile_map.has(tile_num):
			var base_pos: Vector2 = tile_map[tile_num] as Vector2
			coin.centered = true
			coin.position = base_pos + offset

func spawn_money_tiles(count: int = 5) -> void:
	clear_money_tiles()
	var available_tiles: Array[int] = []
	for key_variant in tile_map.keys():
		var tnum: int = int(key_variant)
		if tnum == 1:
			continue
		if tnum in snakes or tnum in ladders:
			continue
		if tile_map.has(tnum):
			available_tiles.append(tnum)

	if available_tiles.is_empty():
		print("spawn_money_tiles: no available tiles to place coins.")
		return

	available_tiles.shuffle()
	var pick_count: int = clamp(count, 0, available_tiles.size())
	var chosen: Array[int] = available_tiles.slice(0, pick_count)

	for tile_num in chosen:
		if not tile_map.has(tile_num):
			continue
		var coin: Sprite2D = Sprite2D.new()
		coin.texture = money_texture
		coin.centered = true
		coin.z_index = 200
		coin.name = "coin_tile_%d" % tile_num
		add_child(coin)
		money_nodes_by_tile[tile_num] = coin

	set_coin_visuals(COIN_SIZE_FACTOR, COIN_OFFSET)
	print("spawn_money_tiles: spawned coins on tiles:", money_nodes_by_tile.keys())


# Check player collection
func check_for_money_collection(player_color: String) -> void:
	var tile_num: int = int(player_positions[player_color])
	if money_nodes_by_tile.has(tile_num):
		player_money[player_color] += money_value
		var coin: Sprite2D = money_nodes_by_tile[tile_num] as Sprite2D
		if coin != null and is_instance_valid(coin):
			coin.queue_free()
		money_nodes_by_tile.erase(tile_num)
		rollresult.text = "%s collected $%d!" % [player_color, money_value]
		refresh_money_label()


func get_tile_number_from_coords(cell: Vector2i) -> int:
	return cell.x + cell.y * 10


func get_offset_if_needed(tile_number, color):
	if tile_number == 1:
		return Vector2.ZERO
	return offset.get(color, Vector2.ZERO)


# UI toggles
func _on_showpowercardsbutton_pressed() -> void:
	handpanel.visible = !handpanel.visible

func _on_showshopbutton_pressed() -> void:
	shoppanel.visible = !shoppanel.visible

func _on_permanentcardstogglebutton_pressed() -> void:
	permpanel.visible = !permpanel.visible


# debug helpers
var _debug_click_point: Vector2 = Vector2(-10000, -10000)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var screen_pos: Vector2 = event.position
		var world_pos: Vector2 = get_global_mouse_position()
		_debug_click_point = world_pos
		var nearest_tile: int = -1
		var min_dist: float = INF
		for k in tile_map.keys():
			var pos: Vector2 = tile_map[k] as Vector2
			var d: float = pos.distance_to(world_pos)
			if d < min_dist:
				min_dist = d
				nearest_tile = k

		var cell_info: String = "no-layer"
		if tilemaplayer != null and tilemaplayer.has_method("world_to_map"):
			var cell = tilemaplayer.world_to_map(world_pos)
			cell_info = str(cell)

		if nearest_tile != -1:
			print(
				"[DEBUG_CLICK] screen:", screen_pos,
				" world:", world_pos,
				" nearest_tile:", nearest_tile,
				" tile_pos:", tile_map[nearest_tile],
				" dist:", min_dist,
				" layer_cell:", cell_info
			)
		else:
			print("[DEBUG_CLICK] screen:", screen_pos, " world:", world_pos, " nearest_tile: none", " layer_cell:", cell_info)
		queue_redraw()

func _draw() -> void:
	if _debug_click_point.x > -9000:
		draw_circle(_debug_click_point, 6, Color(1,0,0,0.9))


# -------------------------------
# AI helper implementations used above
# -------------------------------
func ai_play_random_card(color: String, rarity: String = "any") -> void:
	if not player_hands.has(color):
		return
	var candidates := []
	for i in range(player_hands[color].size()):
		var cd = player_hands[color][i]
		var r = String(cd.get("rarity", "common"))
		if rarity == "any" or r == rarity or (rarity == "field" and r == "epic"):
			candidates.append(i)
	if candidates.size() == 0:
		# log that nothing was available
		log_debug("%s (AI) tried to play %s card but had none." % [color, rarity])
		return
	candidates.shuffle()
	var idx = candidates[0]
	var card_data = player_hands[color][idx]
	player_hands[color].remove_at(idx)
	if get_current_player() == color:
		refresh_hand_for_current_player()

	var card_name := String(card_data.get("name",""))
	if card_name == "Swap":
		var targets := []
		for c in player_nodes.keys():
			if c != color:
				targets.append(c)
		if targets.size() > 0:
			targets.shuffle()
			var tgt = targets[0]
			var tmp = player_positions[color]
			player_positions[color] = player_positions[tgt]
			player_positions[tgt] = tmp
			update_player_positions()
			rollresult.text = "%s (AI) used Swap with %s" % [color, tgt]
			log_debug("%s (AI) used Swap with %s" % [color, tgt])
	else:
		var mv = int(card_data.get("move_value", 0))
		log_debug("%s (AI) played card '%s' (move %d)" % [color, card_name, mv])
		apply_card_effect(mv)



func ai_buy_card(color: String, rarity: String = "common") -> void:
	var choices := []
	for name in power_cards_db.keys():
		var cd = power_cards_db[name]
		if String(cd.get("rarity","common")) != rarity:
			continue
		var cost = int(cd.get("shop_cost",0))
		if player_money.get(color,0) >= cost:
			choices.append(cd.duplicate(true))
	if choices.size() == 0:
		log_debug("%s (AI) wanted to buy a %s card but couldn't afford/none available." % [color, rarity])
		return
	choices.shuffle()
	var pick = choices[0]
	var cost = int(pick.get("shop_cost",0))
	player_money[color] -= cost
	player_hands[color].append(pick)
	if color == get_current_player():
		refresh_hand_for_current_player()
	refresh_money_label()
	rollresult.text = "%s (AI) bought %s" % [color, String(pick.get("name","unknown"))]
	log_debug("%s (AI) bought %s for $%d" % [color, String(pick.get("name","unknown")), cost])



func ai_buy_permanent(color: String, rarity: String = "common") -> void:
	var choices := []
	for name in permanent_cards_db.keys():
		var pd = permanent_cards_db[name]
		if String(pd.get("rarity","common")) != rarity:
			continue
		var cost = int(pd.get("shop_cost",0))
		if player_money.get(color,0) >= cost:
			choices.append(pd.duplicate(true))
	if choices.size() == 0:
		log_debug("%s (AI) wanted to buy a %s permanent but couldn't afford/none available." % [color, rarity])
		return
	choices.shuffle()
	var picked = choices[0]
	player_money[color] -= int(picked.get("shop_cost",0))
	player_permanents[color].append(picked)
	apply_permanent_effect(picked, color)
	refresh_permanent_panel_for_current_player()
	refresh_money_label()
	rollresult.text = "%s (AI) bought permanent %s" % [color, String(picked.get("name","unknown"))]
	log_debug("%s (AI) bought permanent %s for $%d" % [color, String(picked.get("name","unknown")), int(picked.get("shop_cost",0))])
