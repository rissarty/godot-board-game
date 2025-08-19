extends Node2D

# === NODES / SCENES ===
@onready var tilemap            = $TileMap
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
@onready var card_scene         = preload("res://Cards.tscn")

# === CONFIG / DATABASES ===
var game_mode: String = "pass"        # "pass" or "ai"
var player_count: int = 2             # 2..4
var desired_player_count: int = 2     # temporary store while color choice is pending
var turn_order: Array = []            # e.g. ["R","B"] or ["R","G","B","Y"]
var chosen_color : String = ""
var is_singleplayer_mode := false
# Map color letter -> Sprite2D node from this scene
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

# per-player AI flag (by color)
var player_is_ai := {"R":false,"G":false,"B":false,"Y":false}

# model data
var max_hand_size: int = 3
var player_hands := {"R":[], "G":[], "B":[], "Y":[]}
var player_permanents := {"R":[], "G":[], "B":[], "Y":[]}
var player_dice_sides = {"R":6,"G":6,"B":6,"Y":6}
var player_money = {"R":10,"G":10,"B":10,"Y":10}
var player_positions = {"R":1,"G":1,"B":1,"Y":1}

var tile_map = {}
var current_turn_index: int = 0
var has_rolled_dice: bool = false
var snakes  = {20:5, 43:17, 87:24}
var ladders = {3:22, 8:30, 28:84}
var offset  = {"R":Vector2(-4,-4),"G":Vector2(4,-4),"B":Vector2(-4,4),"Y":Vector2(4,4)}

@export var cards_per_shop: int = 3

# -------------------------
# READY
# -------------------------
func _ready() -> void:
	randomize()
	generate_tile_map()

	# map scene nodes
	player_nodes = {
		"R": $playerRED,
		"G": $player1spriteGreen,
		"B": $playerBLUE,
		"Y": $playerYELLOW
	}

	# Place all player sprites at tile 1 initially
	if tile_map.has(1):
		for color in player_nodes.keys():
			player_nodes[color].position = tile_map[1] + offset.get(color, Vector2.ZERO)

	# connect colour pick buttons (safe connect)
	# NOTE: if you already connected these in the editor, remove those editor connections to avoid duplicates.
	var cb_red = Callable(self, "_on_choose_color").bind("R")
	if not red_button.pressed.is_connected(cb_red):
		red_button.pressed.connect(cb_red)

	var cb_blue = Callable(self, "_on_choose_color").bind("B")
	if not blue_button.pressed.is_connected(cb_blue):
		blue_button.pressed.connect(cb_blue)

	var cb_green = Callable(self, "_on_choose_color").bind("G")
	if not green_button.pressed.is_connected(cb_green):
		green_button.pressed.connect(cb_green)

	var cb_yellow = Callable(self, "_on_choose_color").bind("Y")
	if not yellow_button.pressed.is_connected(cb_yellow):
		yellow_button.pressed.connect(cb_yellow)

	# If the menu hasn't called configure_mode yet, stop here.
	# configure_mode will finish setup and start the first turn.
	if turn_order.is_empty():
		colourpanel.visible = false
		return

	_finish_initial_setup_and_start()


# Called by menu to configure mode & player count, then start
# Example: game_scene.configure_mode("ai", 3) or ("pass", 4)
# Called by menu to configure mode & player count, then start
# Example: game_scene.configure_mode("ai", 3) or ("pass", 4)
func configure_mode(mode: String, count: int) -> void:
	game_mode = mode
	player_count = clamp(count, 2, 4)

	# If AI mode, show colour selection and wait for user
	if game_mode == "ai":
		colourpanel.visible = true
		# keep desired player_count in case user picks a colour
		desired_player_count = player_count
		return

	# pass-and-play: choose default turn_order sets per your request and continue immediately
	match player_count:
		2: turn_order = ["R","B"]
		3: turn_order = ["R","G","B"]
		4: turn_order = ["R","G","B","Y"]

	# mark everyone human
	for c in ["R","G","B","Y"]:
		player_is_ai[c] = false

	_finish_initial_setup_and_start()
	

# called when player picks color in AI mode; bound when connecting the buttons
func _on_choose_color(color_letter: String) -> void:
	colourpanel.visible = false
	chosen_color = color_letter

	# build rotated sequence starting at chosen_color
	var base := ["R","G","B","Y"]
	var idx := base.find(chosen_color)
	if idx == -1:
		idx = 0
	var rotated := base.slice(idx, base.size()) + base.slice(0, idx)
	turn_order = rotated.slice(0, desired_player_count)

	# mark AI/human: first is human, rest AI
	for c in base:
		player_is_ai[c] = false
	for i in range(1, turn_order.size()):
		player_is_ai[turn_order[i]] = true

	_finish_initial_setup_and_start()

func _finish_initial_setup_and_start() -> void:
	# give starting hands to used players
	for c in turn_order:
		create_starting_hand_for_player(c)

	current_turn_index = 0
	refresh_hand_for_current_player()
	populate_shop()
	populate_permanent_shop(get_current_player())
	refresh_permanent_panel_for_current_player()
	update_hand_turn_state()
	start_turn()

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
	for cd in player_hands[cp]:
		var card = card_scene.instantiate()
		card.set_card_data(cd)
		card.card_played.connect(_on_card_played)
		hand_container.add_child(card)
	update_hand_turn_state()

func update_hand_turn_state() -> void:
	var is_my_turn = true
	for card in hand_container.get_children():
		if card.has_method("set_turn_state"):
			card.set_turn_state(is_my_turn, has_rolled_dice)

func _on_card_played(move_value: int, card_data: Dictionary) -> void:
	var current_player = get_current_player()
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
# AI & Turn control
# -------------------------------
func start_turn() -> void:
	if turn_order.is_empty():
		return
	var color = get_current_player()
	has_rolled_dice = false
	refresh_hand_for_current_player()
	refresh_permanent_panel_for_current_player()
	populate_shop()
	populate_permanent_shop(color)

	if player_is_ai.get(color, false):
		call_deferred("_deferred_start_ai_turn", color)

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
	if has_rolled_dice:
		return
	has_rolled_dice = true
	var sprite: Node2D = player_nodes.get(color, null)
	if sprite == null:
		return
	var tile = player_positions[color]
	var dice_sides = int(player_dice_sides.get(color, 6))
	var dice_roll = randi() % dice_sides + 1
	rollresult.text = color + " (AI) rolled a " + str(dice_roll)
	var target_tile = min(tile + dice_roll, 100)
	for i in range(tile + 1, target_tile + 1):
		sprite.position = tile_map[i] + get_offset_if_needed(i, color)
		await get_tree().create_timer(0.25).timeout
	player_positions[color] = target_tile
	if target_tile in snakes:
		await get_tree().create_timer(0.45).timeout
		player_positions[color] = snakes[target_tile]
		sprite.position = tile_map[player_positions[color]] + get_offset_if_needed(player_positions[color], color)
	elif target_tile in ladders:
		await get_tree().create_timer(0.45).timeout
		player_positions[color] = ladders[target_tile]
		sprite.position = tile_map[player_positions[color]] + get_offset_if_needed(player_positions[color], color)
	end_turn()

# -------------------------------
# SWAP UI & Logic
# -------------------------------
func start_swap_selection(source_player_color: String) -> void:
	swap_source_player = source_player_color
	clear_children(playerswapcontainer)
	for color in player_nodes.keys():
		if color == source_player_color:
			continue
		var btn := Button.new()
		btn.text = color
		btn.pressed.connect(Callable(self, "_on_swap_target_selected").bind(color))
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
	# simple: just show one random or first
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
	for perm in player_permanents[owner]:
		var n = card_scene.instantiate()
		n.set_card_data(perm)
		n.set_card_mode("permanent_active")
		permcontainer.add_child(n)

func _on_permanent_card_bought(card_data: Dictionary, shop_card_node: Node) -> void:
	var current_player = get_current_player()
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
	player_positions[current_color] += move_value
	player_positions[current_color] = clamp(player_positions[current_color], 1, 100)
	if player_nodes.has(current_color):
		player_nodes[current_color].position = tile_map[player_positions[current_color]] + get_offset_if_needed(player_positions[current_color], current_color)

func _on_dicerollbutton_pressed() -> void:
	if has_rolled_dice:
		return
	has_rolled_dice = true
	var current_color = get_current_player()
	var sprite: Node2D = player_nodes.get(current_color, null)
	if sprite == null:
		return
	var tile = player_positions[current_color]
	var dice_sides = int(player_dice_sides.get(current_color,6))
	var dice_roll = randi() % dice_sides + 1
	rollresult.text = current_color + " rolled a " + str(dice_roll)
	var target_tile = min(tile + dice_roll, 100)
	for i in range(tile + 1, target_tile + 1):
		sprite.position = tile_map[i] + get_offset_if_needed(i, current_color)
		await get_tree().create_timer(0.3).timeout
	player_positions[current_color] = target_tile
	if target_tile in snakes:
		await get_tree().create_timer(0.5).timeout
		player_positions[current_color] = snakes[target_tile]
		sprite.position = tile_map[player_positions[current_color]] + get_offset_if_needed(player_positions[current_color], current_color)
	elif target_tile in ladders:
		await get_tree().create_timer(0.5).timeout
		player_positions[current_color] = ladders[target_tile]
		sprite.position = tile_map[player_positions[current_color]] + get_offset_if_needed(player_positions[current_color], current_color)
	end_turn()

func end_turn() -> void:
	current_turn_index = (current_turn_index + 1) % turn_order.size()
	has_rolled_dice = false
	update_hand_turn_state()
	populate_shop()
	populate_permanent_shop(get_current_player())
	refresh_permanent_panel_for_current_player()
	refresh_hand_for_current_player()
	start_turn()

func get_current_player() -> String:
	return turn_order[current_turn_index]

func generate_tile_map() -> void:
	var start_x = 350
	var start_y = 630
	var tile_size = 56
	var tile_num = 1
	for row in range(10):
		var y = start_y - (row * tile_size)
		for col in range(10):
			var real_col = col if row % 2 == 0 else 9 - col
			tile_map[tile_num] = Vector2(start_x + (real_col * tile_size), y - tile_size/2)
			tile_num += 1

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
