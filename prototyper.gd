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

const DIAG_PATTERNS = [
	[99,82,83,78,77],
	[98,83,84,77,76,65,66,55,54],
	[97,84,85,76,75,66],
	[82,79,78,63,64,57,56],
	[61,60,59,42,43,38,37]
]

# =========================
# STATE
# =========================
var occupied_tiles := {}   # ONLY key tiles!
var free_tiles := []

# =========================
# MAIN
# =========================
func _ready():
	randomize()
	init_board()

	# ORDER MATTERS (priority system)
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
	free_tiles.clear()
	occupied_tiles.clear()
	for i in range(1, 101):
		free_tiles.append(i)

# =========================
# CORE
# =========================
func is_tile_free(num:int) -> bool:
	return not occupied_tiles.has(num)

# ONLY CHECK KEY TILES
func can_place_key_tiles(keys:Array) -> bool:
	for n in keys:
		if not is_tile_free(n):
			return false
	return true

func mark_key_tiles(keys:Array):
	for n in keys:
		occupied_tiles[n] = true

# =========================
# DIAGONAL GENERATOR
# =========================
func generate_diagonal(count:int, is_ladder:bool):
	var placed = 0
	var attempts = 0
	var max_attempts = count * 50

	while placed < count and attempts < max_attempts:
		attempts += 1

		var pattern = DIAG_PATTERNS.pick_random()
		if pattern.size() < 5:
			continue

		var start_idx = randi_range(0, pattern.size() - 5)
		var length = 5  # keep stable for prototype

		if start_idx + length > pattern.size():
			continue

		var path = pattern.slice(start_idx, start_idx + length)

		# =========================
		# KEY DIFFERENCE
		# =========================
		var keys = []

		if is_ladder:
			path.reverse()

			if path[0] >= path[-1]:
				continue

			# LADDER keys: bottom + top
			keys = [path[0], path[-1]]

		else:
			if path[0] <= path[1] or (path[1] + 1 == path[0]):
				continue

			# SNAKE keys: head + neck + tail
			keys = [path[0], path[1], path[-1]]

		# ONLY CHECK KEY TILES
		if can_place_key_tiles(keys):
			mark_key_tiles(keys)

			var label = "Diag Ladder:" if is_ladder else "Diag Snake:"
			print("✓ ", label, path)

			placed += 1
		else:
			var label = "Diag Ladder overlap" if is_ladder else "Diag Snake overlap"
			print("✗ ", label)

# =========================
# STRAIGHT GENERATOR
# =========================
func generate_straight(count:int, is_ladder:bool):
	var placed = 0
	var attempts = 0
	var max_attempts = count * 50

	while placed < count and attempts < max_attempts:
		attempts += 1

		var col = COLUMN_PATHS.pick_random()

		var start = randi_range(0, col.size() - 3)
		var length = randi_range(3, col.size() - start)

		var path = col.slice(start, start + length)

		if is_ladder:
			path.reverse()

			if path[0] >= path[-1]:
				continue

		# KEY TILES ONLY
		var keys = [path[0], path[-1]]

		if can_place_key_tiles(keys):
			mark_key_tiles(keys)

			var label = "Straight Ladder:" if is_ladder else "Straight Snake:"
			print("✓ ", label, path)

			placed += 1
		else:
			var label = "Straight Ladder overlap" if is_ladder else "Straight Snake overlap"
			print("✗ ", label)

# =========================
# WRAPPERS
# =========================
func generate_diagonal_snakes(c): generate_diagonal(c, false)
func generate_diagonal_ladders(c): generate_diagonal(c, true)
func generate_straight_snakes(c): generate_straight(c, false)
func generate_straight_ladders(c): generate_straight(c, true)

# =========================
# FREE TILES
# =========================
func calculate_free_tiles():
	free_tiles.clear()
	for i in range(1, 101):
		if not occupied_tiles.has(i):
			free_tiles.append(i)

# =========================
# PRINT
# =========================
func print_results():
	print("\n=== OCCUPIED (KEY TILES ONLY) ===")
	print(occupied_tiles.keys())

	print("\n=== FREE ===")
	print(free_tiles)
