extends Node2D

@onready var tilemap = $TileMap
@onready var rollresult = $rollresult
@onready var hand_container = $HandPanel/cardhancontainer
@onready var handpanel = $HandPanel
@onready var hand_button = $showpowercardsbutton
@onready var shoppanel = $Shoppanel
@onready var Shopcontainer1 = $Shoppanel/Shopcontainer1
@onready var card_scene = preload("res://Cards.tscn") # Path to your PowerCard scene

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

func _ready():
	generate_tile_map()

	players["R"] = $playerRED
	players["G"] = $player1spriteGreen
	players["B"] = $playerBLUE
	players["Y"] = $playerYELLOW

	for color in turn_order:
		players[color].position = tile_map[1] + offset[color]

	create_starting_hand_for_player(get_current_player())
	update_hand_turn_state()

func create_starting_hand_for_player(player_color: String):
	clear_hand()
	var cards_data = [
		{"name": "+1 Move", "move_value": 1, "shop_cost": 0, "effect": "Move forward 1 space."},
		{"name": "-2 Move", "move_value": -2, "shop_cost": 0, "effect": "Move back 2 spaces."}
	]
	for data in cards_data:
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
	create_starting_hand_for_player(get_current_player())
	update_hand_turn_state()

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


func _on_showpowercardsbutton_pressed():
	hand_container.visible = !hand_container.visible
	handpanel.visible = !handpanel.visible
func _on_showshopbutton_pressed():
	shoppanel.visible = !shoppanel.visible
