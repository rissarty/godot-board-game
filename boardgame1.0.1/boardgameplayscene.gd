extends Node2D

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
@onready var card_scene = preload("res://Cards.tscn") # Path to your PowerCard scene
var player_perm_offer = { "R": "", "G": "", "B": "", "Y": "" }

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
	"-4 Move": {"name": "-4 Move", "move_value": -4, "shop_cost": 2, "rarity":"rare","effect": "Move back 4 spaces."}
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

var max_hand_size = 3
var max_perm_size = 5

var tile_map = {}
var players = { "R": null, "G": null, "B": null, "Y": null }
var player_positions = { "R": 1, "G": 1, "B": 1, "Y": 1 }
var turn_order = ["R", "G", "B", "Y"]
var current_turn_index = 0
var current_tile = 1
var has_rolled_dice = false
var snakes = { 20: 5, 43: 17, 87: 24 }
var ladders = { 3: 22, 8: 30, 28: 84 }
var offset = {
	"R": Vector2(-4, -4),
	"G": Vector2(4, -4),
	"B": Vector2(-4, 4),
	"Y": Vector2(4, 4)
}

# per-player permanent card storage (model)
var player_permanents = {
	"R": [],
	"G": [],
	"B": [],
	"Y": []
}

# placeholder currency for now
var player_money = { "R": 10, "G": 10, "B": 10, "Y": 10 }

@export var cards_per_shop: int = 3

func _ready():
	randomize()  # so first-turn shop is not identical every run
	generate_tile_map()

	players["R"] = $playerRED
	players["G"] = $player1spriteGreen
	players["B"] = $playerBLUE
	players["Y"] = $playerYELLOW

	for color in turn_order:
		players[color].position = tile_map[1] + offset[color]

	create_starting_hand_for_player(get_current_player())
	populate_shop()
	populate_permanent_shop(get_current_player())   # <-- pass arg
	refresh_permanent_panel_for_current_player()    # <-- keep perm panel per-player
	update_hand_turn_state()
# -------------------------------
# HAND
# -------------------------------
func create_starting_hand_for_player(player_color: String):
	# Temporary: Only give starting cards if the hand is empty
	if hand_container.get_child_count() == 0:
		var starting_cards = ["+1 Move", "-2 Move"]
		for card_name in starting_cards:
			var data = power_cards_db[card_name]
			var card = card_scene.instantiate()
			card.set_card_data(data)
			card.card_played.connect(_on_card_played)
			hand_container.add_child(card)

func clear_hand():
	for c in hand_container.get_children():
		c.queue_free()

func update_hand_turn_state():
	var is_my_turn = true
	for card in hand_container.get_children():
		if card.has_method("set_turn_state"):
			card.set_turn_state(is_my_turn, has_rolled_dice)

func _on_card_played(move_value: int, card_data: Dictionary):
	print("Card played:", card_data)
	apply_card_effect(move_value)
	update_hand_turn_state()

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

func populate_shop():
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

func clear_shop():
	for c in shop_container.get_children():
		c.queue_free()

func _on_shop_card_bought(card_data: Dictionary, shop_card_node: Node):
	var current_player = get_current_player()

	if hand_container.get_child_count() >= max_hand_size:
		print("⛔ Cannot buy, hand is full!")
		return

	var cost = card_data.get("shop_cost", 0)

	if player_money[current_player] >= cost:
		player_money[current_player] -= cost
		print(current_player, " bought card:", card_data, " | Remaining money:", player_money[current_player])
		add_card_to_hand(card_data)
		if is_instance_valid(shop_card_node):
			shop_card_node.queue_free() # Remove from shop after buying
	else:
		print("⛔ Not enough money to buy", card_data.get("name"))

func add_card_to_hand(card_data: Dictionary):
	if hand_container.get_child_count() >= max_hand_size:
		print("⛔ Hand is full! Can't add more cards.")
		return
	var card = card_scene.instantiate()
	card.set_card_data(card_data)
	card.card_played.connect(_on_card_played)
	hand_container.add_child(card)
	update_hand_turn_state()

# -------------------------------
# PERMANENT SHOP & PLAYER PERMANENTS
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

func populate_permanent_shop(for_player_id: String):
	clear_permanent_shop()
	if permanent_cards_db.size() == 0:
		return

	# Pick a fresh random permanent every time we populate (per player/turn)
	var card_name := get_random_permanent_card_name()
	if card_name == "":
		# Fallback: pick first key if weighting somehow failed
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


func refresh_permanent_panel_for_current_player():
	# Clears the shared UI panel and shows ONLY the current player's permanents
	for c in permcontainer.get_children():
		c.queue_free()

	var owner := get_current_player()
	for perm_data in player_permanents[owner]:
		var n = card_scene.instantiate()
		n.set_card_data(perm_data)
		n.set_card_mode("permanent_active")
		permcontainer.add_child(n)


func clear_permanent_shop():
	for c in permshopcontainer.get_children():
		c.queue_free()

# When a permanent is bought, add it to current player's permanent list and update UI
func _on_permanent_card_bought(card_data: Dictionary, shop_card_node: Node):
	var current_player = get_current_player()

	if player_permanents[current_player].size() >= max_perm_size:
		print("⛔ Cannot buy, permanent slot is full!")
		return

	var cost = card_data.get("shop_cost", 0)
	if player_money[current_player] >= cost:
		player_money[current_player] -= cost

		player_permanents[current_player].append(card_data)
		apply_permanent_effect(card_data, current_player)

		shop_card_node.queue_free()

		# refresh UI for the current player
		refresh_permanent_panel_for_current_player()

		print(current_player, " bought permanent:", card_data, "| Remaining money:", player_money[current_player])
	else:
		print("⛔ Not enough money for permanent", card_data.get("name"))


# Clears shared permcontainer UI and fills with current player's permanents
func load_permanents_for_current_player():
	# clear UI
	for c in permcontainer.get_children():
		c.queue_free()

	var current_player = get_current_player()
	for perm_data in player_permanents[current_player]:
		var perm_card_display = card_scene.instantiate()
		perm_card_display.set_card_data(perm_data)
		perm_card_display.set_card_mode("permanent_active")
		permcontainer.add_child(perm_card_display)

# permanent effect hook (expand as needed)
func apply_permanent_effect(card_data: Dictionary, player_color: String):
	match card_data.get("name", ""):
		"D20 Upgrade":
			# Example: you should toggle a flag in player's state here to use D20 instead of D6
			print("🎯", player_color, "now uses a D20!")
		"Odd Space Boost":
			print("🎯", player_color, "will now move +1 on odd spaces!")
		_:
			print("⚠ Unknown permanent effect:", card_data.get("name", "Unknown"))

# -------------------------------
# GAME LOGIC
# -------------------------------
func apply_card_effect(move_value: int):
	var current_color = get_current_player()
	player_positions[current_color] += move_value
	if player_positions[current_color] < 1:
		player_positions[current_color] = 1
	if player_positions[current_color] > 100:
		player_positions[current_color] = 100
	players[current_color].position = tile_map[player_positions[current_color]] + get_offset_if_needed(player_positions[current_color], current_color)

func _on_dicerollbutton_pressed():
	if has_rolled_dice:
		return
	has_rolled_dice = true

	var current_color = get_current_player()
	var sprite = players[current_color]
	var tile = player_positions[current_color]

	var dice_roll = randi() % 6 + 1
	rollresult.text = current_color + " rolled a " + str(dice_roll)

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

func end_turn():
	current_turn_index = (current_turn_index + 1) % turn_order.size()
	has_rolled_dice = false
	update_hand_turn_state()
	populate_shop()
	populate_permanent_shop(get_current_player())   # <-- pass arg
	refresh_permanent_panel_for_current_player()    # <-- swap the shown permanents


func get_current_player() -> String:
	return turn_order[current_turn_index]

func generate_tile_map():
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
func _on_showpowercardsbutton_pressed():
	handpanel.visible = !handpanel.visible

func _on_showshopbutton_pressed():
	shoppanel.visible = !shoppanel.visible

func _on_permanentcardstogglebutton_pressed():
	permpanel.visible = !permpanel.visible
