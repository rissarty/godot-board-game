extends Node2D

@onready var tilemap = $TileMap
@onready var player_piece = $player1spriteGreen
@onready var rollresult = $rollresult

var tile_map = {} # to be filled with tiles 1 to 100

var current_tile = 1
# Store player nodes by color
var players = {
	"R": null,
	"G": null,
	"B": null,
	"Y": null
}

# Store current tile number for each player
var player_positions = {
	"R": 1,
	"G": 1,
	"B": 1,
	"Y": 1
}

var turn_order = ["R", "G", "B", "Y"]
var current_turn_index = 0
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

var snakes = {
	20: 5,
	43: 17,
	87: 24
}
var ladders = {
	3: 22,
	8: 30,
	28: 84
}
# Roll dice
# 🎲 Dice roll handler
func _on_dicerollbutton_pressed():
	var current_color = turn_order[current_turn_index]
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

	# Check for snake 🐍
	if target_tile in snakes:
		await get_tree().create_timer(0.5).timeout
		player_positions[current_color] = snakes[target_tile]
		sprite.position = tile_map[snakes[target_tile]] + get_offset_if_needed(snakes[target_tile], current_color)

	# Check for ladder 🪜
	elif target_tile in ladders:
		await get_tree().create_timer(0.5).timeout
		player_positions[current_color] = ladders[target_tile]
		sprite.position = tile_map[ladders[target_tile]] + get_offset_if_needed(ladders[target_tile], current_color)

	# ➡️ Next player's turn
	current_turn_index = (current_turn_index + 1) % turn_order.size()

# Generate S-pattern tile_map with origin (336, 592)
func generate_tile_map():
	var start_x = 350
	var start_y = 630
	var tile_size = 56
	var tile_num = 1

	for row in range(10):
		var y = start_y - (row * tile_size)
		for col in range(10):
			var x = start_x + (col * tile_size)
			var real_col = col if row % 2 == 0 else 9 - col
			tile_map[tile_num] = Vector2(start_x + (real_col * tile_size), y - tile_size / 2)  # center vertically
			tile_num += 1
	
# 📦 Offset for overlapping pieces (except on tile 1)
func get_offset_if_needed(tile_number, color):
	if tile_number == 1:
		return Vector2.ZERO
	var offset_map = {
		"R": Vector2(-4, -4),
		"G": Vector2(4, -4),
		"B": Vector2(-4, 4),
		"Y": Vector2(4, 4)
	}
	return offset_map[color]
