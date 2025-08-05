extends Node2D

@onready var tilemap = $TileMap
@onready var player_piece = $player1spriteGreen
@onready var rollresult = $rollresult

var tile_map = {} # to be filled with tiles 1 to 100

var current_tile = 1

func _ready():
	generate_tile_map()
	player_piece.position = tile_map[current_tile]

var snakes = {
	20: 5,
	43: 17,
	87: 24
}

# Roll dice
func _on_dicerollbutton_pressed():
	var dice_roll = randi() % 6 + 1
	rollresult.text = "You got " + str(dice_roll)

	var target_tile = current_tile + dice_roll
	if target_tile > 100:
		target_tile = 100

	# Move one step at a time
	for i in range(current_tile + 1, target_tile + 1):
		player_piece.position = tile_map[i]
		await get_tree().create_timer(0.3).timeout

	current_tile = target_tile

	# 🐍 Check for snake at current_tile
	if current_tile in snakes:
		await get_tree().create_timer(0.5).timeout # Small pause before snake triggers
		current_tile = snakes[current_tile]
		player_piece.position = tile_map[current_tile]


# Generate S-pattern tile_map with origin (336, 592)
func generate_tile_map():
	var start_x = 336
	var start_y = 592
	var tile_size = 32
	var tile_num = 1

	for row in range(10):
		var y = start_y - (row * tile_size)
		for col in range(10):
			var x = start_x + (col * tile_size)
			var real_col = col if row % 2 == 0 else 9 - col
			tile_map[tile_num] = Vector2(start_x + (real_col * tile_size), y)
			tile_num += 1
