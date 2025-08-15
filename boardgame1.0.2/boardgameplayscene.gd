extends Node2D

# === NODES / SCENES ===
@onready var tilemap = $TileMap
@onready var rollresult = $rollresult
@onready var hand_container = $HandPanel/cardhancontainer
@onready var handpanel = $HandPanel
@onready var hand_button = $showpowercardsbutton
@onready var shoppanel = $Shoppanel
@onready var shop_container = $Shoppanel/Shopcontainer1
@onready var Permcardbutton = $permanentcardstogglebutton
@onready var permpanel = $PermanentPanel
@onready var permcontainer = $PermanentPanel/permContainer       # shared UI (shows current player's permanents)
@onready var permshopcontainer = $Shoppanel/permshopcontainer   # permanent shop slot(s)
@onready var playerswappanel = $playerswapPanel
@onready var playerswapcontainer = $playerswapPanel/swapnamecontainer
@onready var card_scene = preload("res://Cards.tscn") # Path to your PowerCard scene

# === CONFIG / DATABASES ===
var player_perm_offer = { "R": "", "G": "", "B": "", "Y": "" }
var swap_source_player: String = ""

var rarity_weights = {
	"common": 60,
	"rare": 45,
	"epic": 10,
	"legendary": 1
}

var power_cards_db = {
	"+1 Move": {"name": "+1 Move", "move_value": 1, "shop_cost": 0,"rarity":"common", "effect": "Move forward 1 space."},
	"-2 Move": {"name": "-2 Move", "move_value": -2, "shop_cost": 0, "rarity":"common","effect": "Move back 2 spaces."},
	"+3 Move": {"name": "+3 Move", "move_value": 3, "shop_cost": 2, "rarity":"rare","effect": "Move forward 3 spaces."},
	"-4 Move": {"name": "-4 Move", "move_value": -4, "shop_cost": 2, "rarity":"rare","effect": "Move back 4 spaces."},
	"Swap": {"name":"Swap","shop_cost": 3,"rarity": "epic","effect": "Swap your position with another player of your choice."}
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

# maximums
var max_hand_size: int = 3
var max_perm_size: int = 5

# === PER-PLAYER MODEL DATA ===
# each player has its own hand (array of card dictionaries)
var player_hands := {
	"R": [],
	"G": [],
	"B": [],
	"Y": []
}

# per-player permanent card storage (model)
var player_permanents = {
	"R": [],
	"G": [],
	"B": [],
	"Y": []
}

# per-player dice sides (for D20 permanent)
var player_dice_sides = { "R": 6, "G": 6, "B": 6, "Y": 6 }

# placeholder currency for now (per player)
var player_money = { "R": 10, "G": 10, "B": 10, "Y": 10 }

# tile / players
var tile_map = {}
var players = { "R": null, "G": null, "B": null, "Y": null }
var player_positions = { "R": 1, "G": 1, "B": 1, "Y": 1 }
var turn_order = ["R", "G", "B", "Y"]
var current_turn_index: int = 0

var has_rolled_dice: bool = false
var snakes = { 20: 5, 43: 17, 87: 24 }
var ladders = { 3: 22, 8: 30, 28: 84 }
var offset = {
	"R": Vector2(-4, -4),
	"G": Vector2(4, -4),
	"B": Vector2(-4, 4),
	"Y": Vector2(4, 4)
}

@export var cards_per_shop: int = 3

# -------------------------
# READY
# -------------------------
func _ready() -> void:
	randomize()  # so first-turn shop is not identical every run
	generate_tile_map()

	players["R"] = $playerRED
	players["G"] = $player1spriteGreen
	players["B"] = $playerBLUE
	players["Y"] = $playerYELLOW

	for color in turn_order:
		players[color].position = tile_map[1] + offset[color]

	# ensure each player has an initial hand (model) - separate instances
	for color in player_hands.keys():
		if player_hands[color].size() == 0:
			# give starting cards only to one player (or to all if you prefer)
			# here I give starting cards to the very first player (current)
			pass

	# create starting hand for the current player and show it
	create_starting_hand_for_player(get_current_player())
	populate_shop()
	populate_permanent_shop(get_current_player())
	refresh_permanent_panel_for_current_player()
	refresh_hand_for_current_player()
	update_hand_turn_state()

# -------------------------------
# HAND (per-player model + shared UI)
# -------------------------------
func create_starting_hand_for_player(player_color: String) -> void:
	# give starting cards to the player (model)
	if player_hands[player_color].size() == 0:
		var starting_cards = ["+1 Move", "-2 Move"]
		for card_name in starting_cards:
			var data = power_cards_db[card_name].duplicate(true)
			player_hands[player_color].append(data)
	# refresh UI if it's the current player
	if player_color == get_current_player():
		refresh_hand_for_current_player()

func clear_hand() -> void:
	for c in hand_container.get_children():
		c.queue_free()

func refresh_hand_for_current_player() -> void:
	# repopulate shared hand_container with current player's hand (model -> UI)
	clear_hand()
	var current_player = get_current_player()
	for card_data in player_hands[current_player]:
		var card = card_scene.instantiate()
		card.set_card_data(card_data)
		card.card_played.connect(_on_card_played)
		hand_container.add_child(card)
	update_hand_turn_state()

func update_hand_turn_state() -> void:
	var is_my_turn: bool = true
	for card in hand_container.get_children():
		if card.has_method("set_turn_state"):
			card.set_turn_state(is_my_turn, has_rolled_dice)

# Called when a card in the hand UI is played
# (move_value:int, card_data:Dictionary)
func _on_card_played(move_value: int, card_data: Dictionary) -> void:
	var current_player = get_current_player()
	var card_name = String(card_data.get("name", ""))

	# Remove the played card from the current player's hand model (first matching)
	_remove_card_from_player_hand(current_player, card_data)

	# Refresh UI immediately so it looks consumed
	refresh_hand_for_current_player()

	# If it's Swap, trigger the swap flow; else apply numeric effect
	if card_name == "Swap":
		start_swap_selection(current_player)
	else:
		apply_card_effect(move_value)

# Helper: remove first matching card from player's hand model
func _remove_card_from_player_hand(player_color: String, card_data: Dictionary) -> void:
	var name_to_find = String(card_data.get("name", ""))
	for i in range(player_hands[player_color].size()):
		var cd = player_hands[player_color][i]
		if String(cd.get("name","")) == name_to_find:
			player_hands[player_color].remove_at(i)
			return

# -------------------------------
# SWAP UI & Logic
# -------------------------------
func start_swap_selection(source_player_color: String) -> void:
	# show the panel and populate with other players
	swap_source_player = source_player_color
	clear_children(playerswapcontainer)

	for color in players.keys():
		if color == source_player_color:
			continue
		var btn := Button.new()
		btn.text = color  # replace or expand with name/label/avatar if you have one
		btn.pressed.connect(Callable(self, "_on_swap_target_selected").bind(color))
		playerswapcontainer.add_child(btn)

	playerswappanel.visible = true

func _on_swap_target_selected(target_player_color: String) -> void:
	# safety
	if swap_source_player == "":
		playerswappanel.visible = false
		return

	# swap positions in model (positions are ints)
	var src := swap_source_player
	var tmp: int = int(player_positions[src])
	player_positions[src] = int(player_positions[target_player_color])
	player_positions[target_player_color] = tmp

	# update sprite positions (use tile_map + offset)
	players[src].position = tile_map[player_positions[src]] + get_offset_if_needed(player_positions[src], src)
	players[target_player_color].position = tile_map[player_positions[target_player_color]] + get_offset_if_needed(player_positions[target_player_color], target_player_color)

	# announce and hide UI
	rollresult.text = src + " swapped positions with " + target_player_color
	playerswappanel.visible = false

	# reset global variable
	swap_source_player = ""

func clear_children(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()

func update_player_positions() -> void:
	for color in players.keys():
		var t: int = int(player_positions.get(color, 1))
		if tile_map.has(t):
			players[color].position = tile_map[t] + get_offset_if_needed(t, color)

# -------------------------------
# SHOP (consumables) - RNG with rarity
# -------------------------------
func get_random_card_name() -> String:
	var weighted_list := []
	for card_name in power_cards_db.keys():
		var card_data = power_cards_db[card_name]
		var weight = int(rarity_weights.get(card_data.get("rarity", "common"), 0))
		for i in range(weight):
			weighted_list.append(card_name)
	if weighted_list.size() == 0:
		return ""
	return weighted_list[randi() % weighted_list.size()]

func populate_shop() -> void:
	clear_shop()

	var shop_cards := []
	while shop_cards.size() < cards_per_shop:
		var card_name = get_random_card_name()
		if card_name != "":
			shop_cards.append(card_name)

	for card_name in shop_cards:
		var data = power_cards_db[card_name]
		var card = card_scene.instantiate()
		card.set_card_data(data)
		card.set_card_mode("shop", func(card_data):
			_on_shop_card_bought(card_data, card)
		)
		shop_container.add_child(card)

func clear_shop() -> void:
	for c in shop_container.get_children():
		c.queue_free()

func _on_shop_card_bought(card_data: Dictionary, shop_card_node: Node) -> void:
	var current_player = get_current_player()

	# add to the player's model-hand (not just UI)
	if player_hands[current_player].size() >= max_hand_size:
		print("⛔ Cannot buy, hand is full!")
		return

	var cost = int(card_data.get("shop_cost", 0))

	if player_money[current_player] >= cost:
		player_money[current_player] -= cost
		print(current_player, " bought card:", card_data, " | Remaining money:", player_money[current_player])

		# store a duplicate to avoid accidental shared reference
		player_hands[current_player].append(card_data.duplicate(true))

		# refresh UI for the current player
		refresh_hand_for_current_player()

		if is_instance_valid(shop_card_node):
			shop_card_node.queue_free() # Remove from shop after buying
	else:
		print("⛔ Not enough money to buy", card_data.get("name"))

# NOTE: legacy add_card_to_hand kept (adds to current player's model then refreshes)
func add_card_to_hand(card_data: Dictionary) -> void:
	var current_player = get_current_player()
	if player_hands[current_player].size() >= max_hand_size:
		print("⛔ Hand is full! Can't add more cards.")
		return
	player_hands[current_player].append(card_data.duplicate(true))
	refresh_hand_for_current_player()

# -------------------------------
# PERMANENT SHOP & PLAYER PERMANENTS
# (kept as you had it; refresh_permanent_panel_for_current_player is used)
# -------------------------------
func get_random_permanent_card_name() -> String:
	var weighted_list := []
	for card_name in permanent_cards_db.keys():
		var card_data = permanent_cards_db[card_name]
		var weight = int(rarity_weights.get(card_data.get("rarity", "common"), 0))
		for i in range(weight):
			weighted_list.append(card_name)
	if weighted_list.size() == 0:
		return ""
	return weighted_list[randi() % weighted_list.size()]

func populate_permanent_shop(for_player_id: String) -> void:
	clear_permanent_shop()
	if permanent_cards_db.size() == 0:
		return

	var card_name := get_random_permanent_card_name()
	if card_name == "":
		for k in permanent_cards_db.keys():
			card_name = k
			break

	var data = permanent_cards_db[card_name]
	var card = card_scene.instantiate()
	card.set_card_data(data)
	card.set_card_mode("shop", func(card_data):
		_on_permanent_card_bought(card_data, card)
	)
	permshopcontainer.add_child(card)

func refresh_permanent_panel_for_current_player() -> void:
	clear_children(permcontainer)
	var owner := get_current_player()
	for perm_data in player_permanents[owner]:
		var n = card_scene.instantiate()
		n.set_card_data(perm_data)
		n.set_card_mode("permanent_active")
		permcontainer.add_child(n)

func clear_permanent_shop() -> void:
	for c in permshopcontainer.get_children():
		c.queue_free()

func _on_permanent_card_bought(card_data: Dictionary, shop_card_node: Node) -> void:
	var current_player = get_current_player()

	# Apply persistent effects immediately (simple examples)
	match String(card_data.get("name", "")):
		"D20 Upgrade":
			player_dice_sides[current_player] = 20
		"Odd Space Boost":
			pass
		_:
			pass

	if player_permanents[current_player].size() >= max_perm_size:
		print("⛔ Cannot buy, permanent slot is full!")
		return

	var cost = int(card_data.get("shop_cost", 0))
	if player_money[current_player] >= cost:
		player_money[current_player] -= cost
		player_permanents[current_player].append(card_data.duplicate(true))
		apply_permanent_effect(card_data, current_player)
		if is_instance_valid(shop_card_node):
			shop_card_node.queue_free()
		refresh_permanent_panel_for_current_player()
		print(current_player, " bought permanent:", card_data, "| Remaining money:", player_money[current_player])
	else:
		print("⛔ Not enough money for permanent", card_data.get("name"))

func apply_permanent_effect(card_data: Dictionary, player_color: String) -> void:
	match card_data.get("name", ""):
		"D20 Upgrade":
			print("🎯", player_color, "now uses a D20!")
		"Odd Space Boost":
			print("🎯", player_color, "will now move +1 on odd spaces!")
		_:
			print("⚠ Unknown permanent effect:", card_data.get("name", "Unknown"))

# -------------------------------
# GAME LOGIC
# -------------------------------
func apply_card_effect(move_value: int) -> void:
	var current_color = get_current_player()
	player_positions[current_color] += move_value
	if player_positions[current_color] < 1:
		player_positions[current_color] = 1
	if player_positions[current_color] > 100:
		player_positions[current_color] = 100
	players[current_color].position = tile_map[player_positions[current_color]] + get_offset_if_needed(player_positions[current_color], current_color)

func _on_dicerollbutton_pressed() -> void:
	if has_rolled_dice:
		return
	has_rolled_dice = true

	var current_color = get_current_player()
	var sprite = players[current_color]
	var tile = player_positions[current_color]
	var dice_sides = int(player_dice_sides.get(current_color, 6))

	var dice_roll = randi() % dice_sides + 1
	rollresult.text = current_color + " rolled a " + str(dice_roll) + " (D" + str(dice_sides) + ")"

	var target_tile = tile + dice_roll
	if target_tile > 100:
		target_tile = 100

	for i in range(tile + 1, target_tile + 1):
		sprite.position = tile_map[i] + get_offset_if_needed(i, current_color)
		await get_tree().create_timer(0.3).timeout

	player_positions[current_color] = target_tile

	if target_tile in snakes:
		await get_tree().create_timer(0.5).timeout
		player_positions[current_color] = snakes[target_tile]
		sprite.position = tile_map[snakes[target_tile]] + get_offset_if_needed(snakes[target_tile], current_color)
	elif target_tile in ladders:
		await get_tree().create_timer(0.5).timeout
		player_positions[current_color] = ladders[target_tile]
		sprite.position = tile_map[ladders[target_tile]] + get_offset_if_needed(ladders[target_tile], current_color)

	end_turn()

func end_turn() -> void:
	current_turn_index = (current_turn_index + 1) % turn_order.size()
	has_rolled_dice = false
	update_hand_turn_state()
	populate_shop()
	populate_permanent_shop(get_current_player())
	refresh_permanent_panel_for_current_player()
	refresh_hand_for_current_player()

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
			tile_map[tile_num] = Vector2(start_x + (real_col * tile_size), y - tile_size / 2)
			tile_num += 1

func get_offset_if_needed(tile_number, color):
	if tile_number == 1:
		return Vector2.ZERO
	return offset[color]

# -------------------------------
# UI TOGGLES
# -------------------------------
func _on_showpowercardsbutton_pressed() -> void:
	handpanel.visible = !handpanel.visible

func _on_showshopbutton_pressed() -> void:
	shoppanel.visible = !shoppanel.visible

func _on_permanentcardstogglebutton_pressed() -> void:
	permpanel.visible = !permpanel.visible
