extends Node

# =========================
# PATTERNS
# =========================

const COLUMN_PATHS = [
	[81,80,61,60,41,40,21,20,1],
	[99,82,79,62,59,42,39,22,19,2],
	[98,83,78,63,58,43,38,23,18,3],
	[97,84,77,64,57,44,37,24,17,4],
	[96,85,76,65,56,45,36,25,16,5],
	[95,86,75,66,55,46,35,26,15,6],
	[94,87,74,67,54,47,34,27,14,7],
	[93,88,73,68,53,48,33,28,13,8],
	[92,89,72,69,52,49,32,29,12,9],
	[91,90,71,70,51,50,31,30,11,10]
]

# HANDMADE DIAGONAL PATHS
var DIAG_PATTERNS  = [
	[99,82,83,78,77],
	[98,83,84,77,76,65,66,55,54],
	[97,84,85,76,75,66],
	[82,79,78,63,64,57,56],
	[61,60,59,42,43,38,37]
]

# =========================
# STATE
# =========================

# IMPORTANT GAMEPLAY TILES ONLY
var occupied_tiles := {}

# FULL BODY OCCUPANCY
var diag_snake_occupied := {}
var diag_ladder_occupied := {}

# RESULT STORAGE
var generated_diag_snakes := []
var generated_diag_ladders := []

var generated_straight_snakes := []
var generated_straight_ladders := []

var free_tiles := []

# =========================
# READY
# =========================

func _ready():

	randomize()

	init_board()
	add_mirrored_patterns()

	# PRIORITY ORDER
	generate_diagonal_ladders(3)
	generate_straight_ladders(3)

	generate_diagonal_snakes(3)
	generate_straight_snakes(3)

	calculate_free_tiles()

	print_results()

# =========================
# INIT
# =========================

func init_board():

	occupied_tiles.clear()

	diag_snake_occupied.clear()
	diag_ladder_occupied.clear()

	free_tiles.clear()

	generated_diag_snakes.clear()
	generated_diag_ladders.clear()

	generated_straight_snakes.clear()
	generated_straight_ladders.clear()

	for i in range(1, 101):
		free_tiles.append(i)

# =========================
# KEY TILE HELPERS
# =========================

func can_place_key_tiles(keys:Array) -> bool:

	for n in keys:
		if occupied_tiles.has(n):
			return false

	return true


func mark_key_tiles(keys:Array):

	for n in keys:
		occupied_tiles[n] = true

# =========================
# DIAGONAL BODY HELPERS
# =========================

func can_place_diag_snake(path:Array) -> bool:

	for n in path:
		if diag_snake_occupied.has(n):
			return false

	return true


func mark_diag_snake(path:Array):

	for n in path:
		diag_snake_occupied[n] = true


func can_place_diag_ladder(path:Array) -> bool:

	for n in path:
		if diag_ladder_occupied.has(n):
			return false

	return true


func mark_diag_ladder(path:Array):

	for n in path:
		diag_ladder_occupied[n] = true

# =========================
# GENERIC PATTERN VALIDATOR
# =========================

func is_pattern_valid(
	pattern:Array,
	occupied_endpoints:Array,
	occupied_body:Array
) -> bool:

	if pattern.size() < 2:
		return false

	var start_tile = pattern[0]
	var end_tile = pattern[-1]

	# endpoint collision
	if start_tile in occupied_endpoints:
		return false

	if end_tile in occupied_endpoints:
		return false

	# body collision
	for tile in pattern:
		if tile in occupied_body:
			return false

	return true

# =========================
# GENERIC PATTERN REGISTER
# =========================

func register_pattern(
	pattern:Array,
	occupied_endpoints:Array,
	occupied_body:Array
) -> void:

	occupied_endpoints.append(pattern[0])
	occupied_endpoints.append(pattern[-1])

	for tile in pattern:
		if tile not in occupied_body:
			occupied_body.append(tile)

# =========================
# DIAGONAL SLICING
# =========================

func get_valid_diag_slice(pattern:Array) -> Array:

	var possible_slices := []

	# ONLY ODD STARTS
	for start in range(0, pattern.size(), 2):

		for length in [5,7,9,11]:

			if start + length <= pattern.size():

				var slice = pattern.slice(start, start + length)

				if slice.size() % 2 == 1:
					possible_slices.append(slice)

	if possible_slices.is_empty():
		return []

	return possible_slices.pick_random()
func tile_to_grid(tile:int) -> Vector2i:

	var row = (tile - 1) / 10
	var index = (tile - 1) % 10

	# serpentine correction
	if row % 2 == 1:
		index = 9 - index

	return Vector2i(index, row)
func grid_to_tile(pos:Vector2i) -> int:

	var x = pos.x
	var y = pos.y

	# serpentine correction
	if y % 2 == 1:
		x = 9 - x

	return y * 10 + x + 1
func mirror_path(path:Array) -> Array:

	var mirrored := []

	for tile in path:

		var pos = tile_to_grid(tile)

		# mirror horizontally
		pos.x = 9 - pos.x

		mirrored.append(
			grid_to_tile(pos)
		)

	return mirrored
func add_mirrored_patterns():

	var extra := []

	for pattern in DIAG_PATTERNS:

		var mirrored = mirror_path(pattern)

		# avoid duplicates
		if mirrored != pattern:
			extra.append(mirrored)

	DIAG_PATTERNS.append_array(extra)
# =========================
# DIAGONAL GENERATOR
# =========================

func generate_diagonal(count:int, is_ladder:bool):

	var placed = 0
	var attempts = 0

	var max_attempts = count * 100

	while placed < count and attempts < max_attempts:

		attempts += 1

		var pattern = DIAG_PATTERNS.pick_random()

		var path = get_valid_diag_slice(pattern)

		if path.is_empty():
			continue

		print("\nTrying:", path)

		# =========================
		# BODY COLLISION
		# =========================

		if is_ladder:

			if not can_place_diag_ladder(path):
				print("✗ Diag ladder body overlap")
				continue

		else:

			if not can_place_diag_snake(path):
				print("✗ Diag snake body overlap")
				continue

		# =========================
		# DIRECTION
		# =========================

		if is_ladder:

			path.reverse()

			if path[0] >= path[-1]:
				print("✗ Invalid ladder direction")
				continue

		else:

			if path[0] <= path[-1]:
				print("✗ Invalid snake direction")
				continue

		# =========================
		# IMPORTANT TILES
		# =========================

		var keys := []

		if is_ladder:

			keys = [
				path[0],
				path[-1]
			]

		else:

			# head + neck + tail
			keys = [
				path[0],
				path[1],
				path[-1]
			]

		# =========================
		# KEY COLLISION
		# =========================

		if not can_place_key_tiles(keys):

			if is_ladder:
				print("✗ Diag ladder key overlap")
			else:
				print("✗ Diag snake key overlap")

			continue

		# =========================
		# SUCCESS
		# =========================

		mark_key_tiles(keys)

		if is_ladder:

			mark_diag_ladder(path)

			generated_diag_ladders.append(path)

			print("✓ Diag Ladder:", path)

		else:

			mark_diag_snake(path)

			generated_diag_snakes.append(path)

			print("✓ Diag Snake:", path)

		placed += 1

	print("\nGenerated ", placed, "/", count)

# =========================
# STRAIGHT GENERATOR
# =========================

func generate_straight(count:int, is_ladder:bool):

	var placed = 0
	var attempts = 0

	var max_attempts = count * 100

	while placed < count and attempts < max_attempts:

		attempts += 1

		var col = COLUMN_PATHS.pick_random()

		var start = randi_range(0, col.size() - 3)

		var length = randi_range(3, col.size() - start)

		var path = col.slice(start, start + length)

		# =========================
		# DIRECTION
		# =========================

		if is_ladder:

			path.reverse()

			if path[0] >= path[-1]:
				continue

		else:

			if path[0] <= path[-1]:
				continue

		# =========================
		# IMPORTANT TILES
		# =========================

		var keys := []

		if is_ladder:

			keys = [
				path[0],
				path[-1]
			]

		else:

			keys = [
				path[0],
				path[-1]
			]

		# =========================
		# COLLISION
		# =========================

		if not can_place_key_tiles(keys):

			if is_ladder:
				print("✗ Straight ladder overlap")
			else:
				print("✗ Straight snake overlap")

			continue

		# =========================
		# SUCCESS
		# =========================

		mark_key_tiles(keys)

		if is_ladder:

			generated_straight_ladders.append(path)

			print("✓ Straight Ladder:", path)

		else:

			generated_straight_snakes.append(path)

			print("✓ Straight Snake:", path)

		placed += 1

	print("\nGenerated ", placed, "/", count)

# =========================
# WRAPPERS
# =========================

func generate_diagonal_snakes(c):
	generate_diagonal(c, false)


func generate_diagonal_ladders(c):
	generate_diagonal(c, true)


func generate_straight_snakes(c):
	generate_straight(c, false)


func generate_straight_ladders(c):
	generate_straight(c, true)

# =========================
# FREE TILE CALCULATION
# =========================

func calculate_free_tiles():

	free_tiles.clear()

	for i in range(1, 101):

		if not occupied_tiles.has(i):
			free_tiles.append(i)

# =========================
# RESULTS
# =========================

func print_results():

	print("\n==============================")
	print("DIAGONAL LADDERS")
	print("==============================")

	for p in generated_diag_ladders:
		print(p)

	print("\n==============================")
	print("STRAIGHT LADDERS")
	print("==============================")

	for p in generated_straight_ladders:
		print(p)

	print("\n==============================")
	print("DIAGONAL SNAKES")
	print("==============================")

	for p in generated_diag_snakes:
		print(p)

	print("\n==============================")
	print("STRAIGHT SNAKES")
	print("==============================")

	for p in generated_straight_snakes:
		print(p)

	print("\n==============================")
	print("OCCUPIED KEY TILES")
	print("==============================")
	print(occupied_tiles.keys())

	print("\n==============================")
	print("DIAGONAL SNAKE BODY")
	print("==============================")
	print(diag_snake_occupied.keys())

	print("\n==============================")
	print("DIAGONAL LADDER BODY")
	print("==============================")
	print(diag_ladder_occupied.keys())

	print("\n==============================")
	print("FREE TILES")
	print("==============================")
	print(free_tiles)
