extends Node2D

# === NODES / SCENES ===
#region ONREADIES/EXPORTS/NODES
@onready var tilemap            = $TileMap
@onready var tilemaplayer       = $TileMap/Tilemaplayerresized
@onready var rollresult         = $rollresult
@onready var hand_container     = $UI/HandPanel/cardhancontainer
@onready var handpanel          = $UI/HandPanel
@onready var hand_button        = $showpowercardsbutton
@onready var shoppanel          = $UI/Shoppanel
@onready var shopbutton         = $Showshopbutton
@onready var shop_container     = $UI/Shoppanel/Shopcontainer1
@onready var Permcardbutton     = $permanentcardstogglebutton
@onready var permpanel          = $UI/PermanentPanel
@onready var permcontainer      = $UI/PermanentPanel/permContainer
@onready var permshopcontainer  = $UI/Shoppanel/permshopcontainer
@onready var playerswappanel    = $UI/playerswapPanel
@onready var playerswapcontainer= $UI/playerswapPanel/swapnamecontainer
@onready var colourpanel        = $UI/colourchoicePanel
@onready var red_button         = $UI/colourchoicePanel/choosebuttoncontainer/chooseRed
@onready var blue_button        = $UI/colourchoicePanel/choosebuttoncontainer/chooseBlue
@onready var green_button       = $UI/colourchoicePanel/choosebuttoncontainer/chooseGreen
@onready var yellow_button      = $UI/colourchoicePanel/choosebuttoncontainer/chooseYellow
@onready var moneylabel         = $MoneyLabel
@onready var ai_buttonspanel    = $UI/Panel
@onready var ai_buttonscontainer= $UI/Panel/aibuttonscontainer
@onready var victory_panel: Panel = $Victorypanel
@onready var victory_label: Label = $Victorypanel/victorylabel
@onready var back_button: Button = $Victorypanel/Backtomenubutton
@onready var snake_tilemaplayer: TileMapLayer = $TileMap/Snaketilelayer
@onready var snake_layer: TileMapLayer = $TileMap/Snaketilelayer # Your exact name
@onready var ladder_tilemaplayer: TileMapLayer = $TileMap/LadderTileLayer
@onready var moneylayer: TileMapLayer = $TileMap/moneylayer
@onready var card_scene: PackedScene = preload("res://spritecardscene.tscn")
@onready var money_texture      = preload("res://assets/pixil-frame-0_scaled_6x_pngcrushed.png")
@export var cards_per_shop: int = 3
@onready var debug_log: Label = $debuglabel
@onready var SnakeSpriteScene = preload("res://scenes/snakespritescene.tscn")
@export var menu_scene_path: String = "res://scenes/menusscene.tscn"  # change to your menu scene path if different
@export var auto_return_seconds: float = 3.0
@export var debug_font: Font  # assign a DynamicFont or TTF in the inspector
#endregion
"""===========================================MONEY VARS GLOBAL========================================================="""
#region MONEY VARS GLOBAL
var money_nodes_by_tile : Dictionary = {}       # maps tile_num -> Sprite2D node
var money_value : int = 5                      # how much each coin gives
var money_tiles_positions: Array[int] = []  # Track money tile numbers
const MONEY_SOURCE_ID = 0
const MONEY_ATLAS_COORD = Vector2i(2,0)
const MONEY_TILE_ID = 5
var player_money = {"R":10,"G":10,"B":10,"Y":10}
#endregion

"""===========================================AI SETUP STATE/VARS========================================================="""
#region AI VARS/SETUP
# optional AI manager preload (unused by default)
const AIManagerClass := preload("res://Gds folder/ai_managerscene.gd")
var ai_manager: Node = null
# ---------- ----------
var ai_setup: Array = []            # array of dictionaries { "color": "G", "level": 3 }
var reserved_ai_colors: Array = []  # list of colors reserved for AI
var ai_level_by_color := {"R": 0, "G": 0, "B": 0, "Y": 0}
var player_is_ai := {"R":false,"G":false,"B":false,"Y":false}
#endregion
"""===========================================OTHER GENERAL VARS========================================================="""
#region OTHER GENERAL/PLAYER VARS
# board layout (editable from Inspector)
const BOARD_ROWS: int = 10
const BOARD_COLS: int = 10
var player_effects: Dictionary = {}
var world_pos: Vector2 = Vector2.ZERO
var swap_source_player: String = ""
var swap_target_delegate: String = ""  # NEW
# === CONFIG / DATABASES ===
var game_mode: String = "pass"        # "pass" or "ai"
var player_count: int = 2             # 2..4
var desired_player_count: int = 2     # temporary store while color choice is pending
var turn_order: Array = []            # e.g. ["R","B"] or ["R","G","B","Y"]
var chosen_color : String = ""
var is_singleplayer_mode := false
var show_tile_debug := false
var game_over: bool = false
var player_nodes: Dictionary = {}
var rarity_weights = {"common":60, "rare":45, "epic":10, "legendary":1}
var board_tiles: Dictionary = {
	# Bottom row (y=0): left→right 1-10
	Vector2i(-13, 0): {"num": 1,  "type": "empty"},
	Vector2i(-12, 0): {"num": 2,  "type": "empty"},
	Vector2i(-11, 0): {"num": 3,  "type": "empty"},
	Vector2i(-10, 0): {"num": 4,  "type": "empty"},
	Vector2i(-9,  0): {"num": 5,  "type": "empty"},
	Vector2i(-8,  0): {"num": 6,  "type": "empty"},
	Vector2i(-7,  0): {"num": 7,  "type": "empty"},
	Vector2i(-6,  0): {"num": 8,  "type": "empty"},
	Vector2i(-5,  0): {"num": 9,  "type": "empty"},
	Vector2i(-4,  0): {"num": 10, "type": "empty"},
	
	# Row 2 (y=-1): right→left 11-20  
	Vector2i(-13,-1): {"num": 20, "type": "empty"},
	Vector2i(-12,-1): {"num": 19, "type": "empty"},
	Vector2i(-11,-1): {"num": 18, "type": "empty"},
	Vector2i(-10,-1): {"num": 17, "type": "empty"},
	Vector2i(-9, -1): {"num": 16, "type": "empty"},
	Vector2i(-8, -1): {"num": 15, "type": "empty"},
	Vector2i(-7, -1): {"num": 14, "type": "empty"},
	Vector2i(-6, -1): {"num": 13, "type": "empty"},
	Vector2i(-5, -1): {"num": 12, "type": "empty"},
	Vector2i(-4, -1): {"num": 11, "type": "empty"},
	
	# Row 3 (y=-2): left→right 21-30
	Vector2i(-13,-2): {"num": 21, "type": "empty"},
	Vector2i(-12,-2): {"num": 22, "type": "empty"},
	Vector2i(-11,-2): {"num": 23, "type": "empty"},
	Vector2i(-10,-2): {"num": 24, "type": "empty"},
	Vector2i(-9, -2): {"num": 25, "type": "empty"},
	Vector2i(-8, -2): {"num": 26, "type": "empty"},
	Vector2i(-7, -2): {"num": 27, "type": "empty"},
	Vector2i(-6, -2): {"num": 28, "type": "empty"},
	Vector2i(-5, -2): {"num": 29, "type": "empty"},
	Vector2i(-4, -2): {"num": 30, "type": "empty"},
	
	# Row 4 (y=-3): right→left 31-40
	Vector2i(-13,-3): {"num": 40, "type": "empty"},
	Vector2i(-12,-3): {"num": 39, "type": "empty"},
	Vector2i(-11,-3): {"num": 38, "type": "empty"},
	Vector2i(-10,-3): {"num": 37, "type": "empty"},
	Vector2i(-9, -3): {"num": 36, "type": "empty"},
	Vector2i(-8, -3): {"num": 35, "type": "empty"},
	Vector2i(-7, -3): {"num": 34, "type": "empty"},
	Vector2i(-6, -3): {"num": 33, "type": "empty"},
	Vector2i(-5, -3): {"num": 32, "type": "empty"},
	Vector2i(-4, -3): {"num": 31, "type": "empty"},
	
	# Row 5 (y=-4): left→right 41-50
	Vector2i(-13,-4): {"num": 41, "type": "empty"},
	Vector2i(-12,-4): {"num": 42, "type": "empty"},
	Vector2i(-11,-4): {"num": 43, "type": "empty"},
	Vector2i(-10,-4): {"num": 44, "type": "empty"},
	Vector2i(-9, -4): {"num": 45, "type": "empty"},
	Vector2i(-8, -4): {"num": 46, "type": "empty"},
	Vector2i(-7, -4): {"num": 47, "type": "empty"},
	Vector2i(-6, -4): {"num": 48, "type": "empty"},
	Vector2i(-5, -4): {"num": 49, "type": "empty"},
	Vector2i(-4, -4): {"num": 50, "type": "empty"},
	
	# Row 6 (y=-5): right→left 51-60
	Vector2i(-13,-5): {"num": 60, "type": "empty"},
	Vector2i(-12,-5): {"num": 59, "type": "empty"},
	Vector2i(-11,-5): {"num": 58, "type": "empty"},
	Vector2i(-10,-5): {"num": 57, "type": "empty"},
	Vector2i(-9, -5): {"num": 56, "type": "empty"},
	Vector2i(-8, -5): {"num": 55, "type": "empty"},
	Vector2i(-7, -5): {"num": 54, "type": "empty"},
	Vector2i(-6, -5): {"num": 53, "type": "empty"},
	Vector2i(-5, -5): {"num": 52, "type": "empty"},
	Vector2i(-4, -5): {"num": 51, "type": "empty"},
	
	# Row 7 (y=-6): left→right 61-70
	Vector2i(-13,-6): {"num": 61, "type": "empty"},
	Vector2i(-12,-6): {"num": 62, "type": "empty"},
	Vector2i(-11,-6): {"num": 63, "type": "empty"},
	Vector2i(-10,-6): {"num": 64, "type": "empty"},
	Vector2i(-9, -6): {"num": 65, "type": "empty"},
	Vector2i(-8, -6): {"num": 66, "type": "empty"},
	Vector2i(-7, -6): {"num": 67, "type": "empty"},
	Vector2i(-6, -6): {"num": 68, "type": "empty"},
	Vector2i(-5, -6): {"num": 69, "type": "empty"},
	Vector2i(-4, -6): {"num": 70, "type": "empty"},
	
	# Row 8 (y=-7): right→left 71-80
	Vector2i(-13,-7): {"num": 80, "type": "empty"},
	Vector2i(-12,-7): {"num": 79, "type": "empty"},
	Vector2i(-11,-7): {"num": 78, "type": "empty"},
	Vector2i(-10,-7): {"num": 77, "type": "empty"},
	Vector2i(-9, -7): {"num": 76, "type": "empty"},
	Vector2i(-8, -7): {"num": 75, "type": "empty"},
	Vector2i(-7, -7): {"num": 74, "type": "empty"},
	Vector2i(-6, -7): {"num": 73, "type": "empty"},
	Vector2i(-5, -7): {"num": 72, "type": "empty"},
	Vector2i(-4, -7): {"num": 71, "type": "empty"},
	
	# Row 9 (y=-8): left→right 81-90
	Vector2i(-13,-8): {"num": 81, "type": "empty"},
	Vector2i(-12,-8): {"num": 82, "type": "empty"},
	Vector2i(-11,-8): {"num": 83, "type": "empty"},
	Vector2i(-10,-8): {"num": 84, "type": "empty"},
	Vector2i(-9, -8): {"num": 85, "type": "empty"},
	Vector2i(-8, -8): {"num": 86, "type": "empty"},
	Vector2i(-7, -8): {"num": 87, "type": "empty"},
	Vector2i(-6, -8): {"num": 88, "type": "empty"},
	Vector2i(-5, -8): {"num": 89, "type": "empty"},
	Vector2i(-4, -8): {"num": 90, "type": "empty"},
	
	# Top row (y=-9): right→left 91-100
	Vector2i(-13,-9): {"num": 100, "type": "finish"},
	Vector2i(-12,-9): {"num": 99,  "type": "empty"},
	Vector2i(-11,-9): {"num": 98,  "type": "empty"},
	Vector2i(-10,-9): {"num": 97,  "type": "empty"},
	Vector2i(-9, -9): {"num": 96,  "type": "empty"},
	Vector2i(-8, -9): {"num": 95,  "type": "empty"},
	Vector2i(-7, -9): {"num": 94,  "type": "empty"},
	Vector2i(-6, -9): {"num": 93,  "type": "empty"},
	Vector2i(-5, -9): {"num": 92,  "type": "empty"},
	Vector2i(-4, -9): {"num": 91,  "type": "empty"}
}
var used_cells: Dictionary = {}
var DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), 
	Vector2i(0, -1), Vector2i(0, 1)
]

var power_cards_db = {
	"+1 Move": {"name":"+1 Move","move_value":1,"shop_cost":0,"rarity":"common","art":"res://assets/Placeholdercard.png"},
	"-2 Move": {"name":"-2 Move","move_value":-2,"shop_cost":6,"rarity":"common","art":"res://assets/pixilart-drawing(1).png"},
	"+3 Move": {"name":"+3 Move","move_value":3,"shop_cost":2,"rarity":"rare","art":"res://assets/Placeholdercard.png"},
	"-4 Move": {"name":"-4 Move","move_value":-4,"shop_cost":2,"rarity":"rare","art":"res://assets/Placeholdercard.png"},
	"Swap":    {"name":"Swap","shop_cost":3,"rarity":"epic","art":"res://assets/Placeholdercard.png"}
	  #,"wintest": {"name":"wintest","shop_cost":0,"rarity":"common"}
}
var permanent_cards_db = {
	"D20 Upgrade": {
		"name": "D20 Upgrade",
		"effect": "upgrade_dice(20)",
		"shop_cost": 5,
		"rarity": "common",
		"type": "permanent","art":"res://assets/Placeholdercard.png"
	},
	"Odd Space Boost": {
		"name": "Odd Space Boost",
		"effect": "odd_space_move(1)",
		"shop_cost": 3,
		"rarity": "common",
		"type": "permanent","art":"res://assets/Placeholdercard.png"
	},
	"Unstoppable": {
		"name": "Unstoppable",
		"effect": "immune_to_swap_and_traps",
		"shop_cost": 5,
		"rarity": "rare",
		"type": "permanent","art":"res://assets/Placeholdercard.png"
	},
	"6 Ball": {
		"name": "6 Ball",
		"effect": "gain_money_on_six",
		"shop_cost": 3,
		"rarity": "common",
		"type": "permanent","art":"res://assets/Placeholdercard.png"
	},
	"Fibonacci": {
		"name": "Fibonacci",
		"effect": "fibonacci_bonus",
		"shop_cost": 5,
		"rarity": "rare",
		"type": "permanent","art":"res://assets/Placeholdercard.png"
	},
	"Mirror": {
	"name": "Mirror",
	"effect": "reflect_effects",
	"shop_cost": 8,
	"rarity": "epic",
	"type": "permanent","art":"res://assets/Placeholdercard.png"
  },
"Domovei":{
	"name":"Domovei",
	"effect": "+2 to the diceroll for each card held in hand",
	"shop_cost": 8,
	"rarity": "epic",
	"type": "permanent","art":"res://assets/Placeholdercard.png"
},
"Savings Account":{
	"name":"Savings Account",
	"effect": "earn $1 for every $2 at end of each turn",
	"shop_cost": 5,
	"rarity": "rare",
	"type": "permanent","art":"res://assets/Placeholdercard.png"
},
"Bank Card":{
	"name":"Bank Card",
	"effect": "Allows u to go into $10 debt",
	"shop_cost": 2,
	"rarity": "common",
	"type": "permanent","art":"res://assets/Placeholdercard.png"
},
"Tramp":{
	"name":"Tramp",
	"effect": "Generates a Powercard if u have $3 or less, at start of your turns",
	"shop_cost": 5,
	"rarity": "rare",
	"type": "permanent","art":"res://assets/Placeholdercard.png"
}
}
# Define constants for the board
const COLS = 10
const ROWS = 10
# Effective tile size used by the board (default fallback)
# Make this a var so we can adjust it in _ready() when the tilemaplayer exists.
var TILE_SIZE: Vector2 = Vector2(64, 64)
var max_hand_size: int = 3
var player_hands := {"R":[], "G":[], "B":[], "Y":[]}
var hand_nodes := {"R":[], "G":[], "B":[], "Y":[]} # store actual card nodes for each player
var player_permanents := {"R":[], "G":[], "B":[], "Y":[]}
var player_dice_sides = {"R":6,"G":6,"B":6,"Y":6}
var player_positions = {"R":1,"G":1,"B":1,"Y":1}
var BOARD_START: Vector2 = Vector2(336, 624)
var tile_map = {}
var segment_length: float = 32.0  # Adjust based on sprite size / tile size
var snake_amplitude: float = 10.0  # Reduced for less extreme curves
var snake_frequency_min: float = 1.0  # Lower minimum for smoother waves
var snake_frequency_max: float = 1.5  # Lower maximum for consistency
var current_turn_index: int = 0
var has_rolled_dice: bool = false
var offset  = {"R":Vector2(-4,-4),"G":Vector2(4,-4),"B":Vector2(-4,4),"Y":Vector2(4,4)}
var _fib_set := [1, 2, 3, 5, 8, 13, 21, 34]
var player_permanent_cards: Dictionary = {
	"R": [],
	"G": [],
	"B": [],
	"Y": []
}
#endregion

"""===============================================SNAKE CONSTS==============================================================="""
#region SNAKE VARS GLOBAL
# Global snake/ladder registry
var snake_map: Dictionary = {}  # tile_num -> destination_tile_num
const SNAKE_SOURCE_ID: int = 0  # your spritesheet source
# Small Straight Snake (3 tiles min)
const STRAIGHT_HEAD_ATLAS  := Vector2i(4, 0)
const STRAIGHT_BODY_ATLAS  := Vector2i(4, 1) 
const STRAIGHT_TAIL_ATLAS  := Vector2i(7, 2)
# Long Straight Snake (4+ tiles)
const LONG_STRAIGHT_BODY2_ATLAS := Vector2i(4, 2)  # second body type
const LONG_STRAIGHT_TAIL2_ATLAS := Vector2i(4, 4)  # tail 2
# Small Diagonal Snake
const DIAG_HEAD_ATLAS      := Vector2i(1, 0)  # head 2 / diagonal head
const DIAG_BODY_ATLAS      := Vector2i(2, 1) # diagonal body
const DIAG_CONNECTOR1_ATLAS:= Vector2i(2, 0) # connector 1
const DIAG_CONNECTOR2_ATLAS:= Vector2i(1, 1) # connector 2
const DIAG_TAIL3_ATLAS     := Vector2i(2, 2) # tail 3
# used for snake generation
const HEAD_ATLAS      := STRAIGHT_HEAD_ATLAS
const TAIL_ATLAS      := STRAIGHT_TAIL_ATLAS
const BODY_VERT_ATLAS := LONG_STRAIGHT_BODY2_ATLAS
const NECK_ATLAS      := STRAIGHT_BODY_ATLAS
# Pre-built column lists (each covers one full column top→bottom)
const COLUMN_PATHS: Array = [
	# Column 1 (left): 100, 81, 80, 61, 60, 41, 40, 21, 20, 1
	[81, 80, 61, 60, 41, 40, 21, 20, 1],
	# Column 2: 99, 82, 79, 62, 59, 42, 39, 22, 19, 2
	[99, 82, 79, 62, 59, 42, 39, 22, 19, 2],
	# Column 3: 98, 83, 78, 63, 58, 43, 38, 23, 18, 3
	[98, 83, 78, 63, 58, 43, 38, 23, 18, 3],
	# Column 4: 97, 84, 77, 64, 57, 44, 37, 24, 17, 4
	[97, 84, 77, 64, 57, 44, 37, 24, 17, 4],
	# Column 5: 96, 85, 76, 65, 56, 45, 36, 25, 16, 5
	[96, 85, 76, 65, 56, 45, 36, 25, 16, 5],
	# Column 6: 95, 86, 75, 66, 55, 46, 35, 26, 15, 6
	[95, 86, 75, 66, 55, 46, 35, 26, 15, 6],
	# Column 7: 94, 87, 74, 67, 54, 47, 34, 27, 14, 7
	[94, 87, 74, 67, 54, 47, 34, 27, 14, 7],
	# Column 8: 93, 88, 73, 68, 53, 48, 33, 28, 13, 8
	[93, 88, 73, 68, 53, 48, 33, 28, 13, 8],
	# Column 9: 92, 89, 72, 69, 52, 49, 32, 29, 12, 9
	[92, 89, 72, 69, 52, 49, 32, 29, 12, 9],
	# Column 10 (right): 91, 90, 71, 70, 51, 50, 31, 30, 11, 10
	[91, 90, 71, 70, 51, 50, 31, 30, 11, 10]
]
#endregion
"""===============================================LADDER CONSTS==============================================================="""
#region LADDER VARS REGION
var ladder_map: Dictionary = {} # tile_num -> destination_tile_num
const LADDER_SOURCE_ID: int = 0
const LADDER_HEAD_ATLAS  := Vector2i(1, 7)
const LADDER_BODY_ATLAS  := Vector2i(1, 8) 
const LADDER_TAIL_ATLAS  := Vector2i(1, 9)
# Ladder column paths (reversed snakes: low→high)
const LADDER_COLUMN_PATHS: Array = [
	# Column 1: 1 up to 81
	[20, 21, 40, 41, 60, 61, 80, 81],
	# Column 2: 2 up to 82
	[2, 19, 22, 39, 42, 59, 62, 79, 82],
	# Column 3: 3 up to 83
	[3, 18, 23, 38, 43, 58, 63, 78, 83],
	# Column 4: 4 up to 84
	[4, 17, 24, 37, 44, 57, 64, 77, 84],
	# Column 5: 5 up to 85
	[5, 16, 25, 36, 45, 56, 65, 76, 85],
	# Column 6: 6 up to 86
	[6, 15, 26, 35, 46, 55, 66, 75, 86],
	# Column 7: 7 up to 87
	[7, 14, 27, 34, 47, 54, 67, 74, 87],
	# Column 8: 8 up to 88
	[8, 13, 28, 33, 48, 53, 68, 73, 88],
	# Column 9: 9 up to 89
	[9, 12, 29, 32, 49, 52, 69, 72, 89],
	# Column 10: 10 up to 90
	[10, 11, 30, 31, 50, 51, 70, 71, 90]
]
#endregion
"""===============================================EXTRA FUNCS AND DEBUGS BEFORE READY==========================================="""
#region EXTRA FUNCS AND DEBUGS BEFORE READY
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
var blocked_tiles: Array[int] = []
# normalize various color names to single-letter codes "R","G","B","Y"
func _color_name_to_code(col: String) -> String:
	var s := col.strip_edges().to_lower()
	match s:
		"r", "red", "r_ed": # r_ed is harmless, only here to show flexibility
			return "R"
		"g", "green":
			return "G"
		"b", "blue":
			return "B"
		"y", "yellow":
			return "Y"
		_: # wildcard inside match
			# fallback: if starts with r/g/b/y use that letter
			if s.length() > 0:
				var c := s.substr(0, 1)
				if c == "r":
					return "R"
				if c == "g":
					return "G"
				if c == "b":
					return "B"
				if c == "y":
					return "Y"
	# if nothing matched, default to "R" to avoid crashing — but log it
	_perm_log("Unrecognized color string '%s', defaulting to R" % col)
	return "R"
func is_player_turn(player_color: String) -> bool:
	var current_color = get_current_player_color()
	var ai_turn = player_is_ai.get(current_color, false)
	var result = current_color == player_color and not ai_turn
	print("[is_player_turn] cur=%s chosen=%s ai_turn=%s -> %s" % [current_color, player_color, ai_turn, result])
	return result
func can_be_moved(target_color: String) -> bool:
	# Unstoppable prevents being moved by others, but snakes still apply (handled elsewhere)
	return not has_permanent(target_color, "Unstoppable")
# small safe logger used by the patch (uses your log_debug if exists)
func _perm_log(msg: String) -> void:
	if has_method("log_debug"):
		log_debug(msg)
	else:
		print(msg)
# Returns the effective tile size in world coordinates (cell size * global scale)
func get_scaled_tile_size() -> Vector2:
	# Default base
	var base := Vector2(64, 64)

	# Try to get a reliable tilemap node if one exists
	var tm: Node = null
	if "tilemaplayer" in self and tilemaplayer != null:
		tm = tilemaplayer
	elif has_node("TileMapLayer"):
		tm = get_node("TileMapLayer")

	# If we found a tilemap-like node, try to extract base cell size safely
	if tm != null:
		# 1) If the node exposes get_cell_size (TileMapLayer in some Godot setups)
		if tm.has_method("get_cell_size"):
			var cs = tm.get_cell_size()
			if typeof(cs) == TYPE_VECTOR2 and cs.x > 0 and cs.y > 0:
				base = cs
		# 2) If it has a tile_set (older or different API)
		elif tm.has_method("get_tileset") and tm.get_tileset() != null:
			var ts = tm.get_tileset()
			# tileset in Godot 4: TileSet has tile_size property or tile_get_size - but not always uniform.
			# try common property names safely:
			if typeof(ts) == TYPE_OBJECT and ts.has_method("tile_size"):
				var maybe = ts.tile_size
				if typeof(maybe) == TYPE_VECTOR2 and maybe.x > 0:
					base = maybe
			elif ts.has_method("get_used_rect"):
				# fallback: leave base as default
				pass
		# 3) If node has a `cell_size` property (some custom nodes)
		elif tm.has_method("cell_size") and typeof(tm.cell_size) == TYPE_VECTOR2:
			base = tm.cell_size

		# Determine global scale for tm (safe)
		var gscale := Vector2.ONE
		if tm.has_method("get_global_transform"):
			gscale = tm.get_global_transform().get_scale()
		elif tm.has_method("get_global_scale"):
			gscale = tm.get_global_scale()
		elif tm.has_property("scale"):
			# may be a plain property Vector2
			var s = tm.scale
			if typeof(s) == TYPE_VECTOR2:
				gscale = s

		# final effective size
		return Vector2(base.x * gscale.x, base.y * gscale.y)

	# Fallback: use TILE_SIZE variable if it's Vector2
	if typeof(TILE_SIZE) == TYPE_VECTOR2 and TILE_SIZE.x > 0 and TILE_SIZE.y > 0:
		return TILE_SIZE

	return Vector2(64, 64)
func check_snake_or_ladder(tile_num: int) -> int:
	if snake_map.has(tile_num):
		var dest = snake_map[tile_num]
		print("Hit snake! Slide from ", tile_num, " to ", dest)
		return dest
	elif ladder_map.has(tile_num):
		var dest = ladder_map[tile_num]
		print("Hit ladder! Climb from ", tile_num, " to ", dest)
		return dest
	return tile_num  # No snake/ladder

#endregion

"""===============================================SNAKE GEN CODE============================================================================"""
#region SNAKE GEN CODE
func generate_snakes(count: int):
	used_cells.clear()
	var placed = 0
	var total_attempts = 0
	var max_total = count * 50  # Safety limit
	
	while placed < count and total_attempts < max_total:
		total_attempts += 1
		
		var col_list = COLUMN_PATHS[randi() % 10]
		var start_idx = randi_range(0, col_list.size() - 3)
		var length = randi_range(3, col_list.size() - start_idx)
		
		var path_nums = col_list.slice(start_idx, start_idx + length)
		var path_pos = path_nums.map(number_to_tile)
		
		if is_valid_snake(path_pos):
			add_snake_to_board(path_pos)
			placed += 1
			print("✓ Snake ", placed, ": ", path_nums)
		else:
			print("✗ Collision, retrying...")
	
	print("Generated ", placed, "/", count, " snakes in ", total_attempts, " total attempts")

func is_valid_snake(path: Array) -> bool:
	print("Validating path size=", path.size())
	if path.size() < 3: return false
	
	var seen = {}
	for pos in path:
		if seen.has(pos) or used_cells.has(pos):
			print("FAIL: overlap at ", pos)
			return false
		seen[pos] = true
	
	var head_num = board_tiles[path[0]].num
	var tail_num = board_tiles[path[-1]].num
	print("Head=", head_num, " tail=", tail_num)
	if head_num <= tail_num or path.size() > 16:  # Allow up to 16
		print("FAIL: not downward or too long")
		return false
	print("PASS!")
	return true
func add_snake_to_board(path: Array):
	for i in range(path.size()):
		var pos = path[i]
		var info = board_tiles[pos]
		var num = info.num  # Get tile number
		if i == 0:
			info.type = "snake_head"
		elif i == path.size() - 1:
			info.type = "snake_tail"
		else:
			info.type = "snake_body"
		info.body_index = i
		info.dest = board_tiles[path[-1]].num
		board_tiles[pos] = info
		used_cells[pos] = true
		# Register snake head only
		if i == 0:
			snake_map[num] = info.dest
			print("Snake: ", num, " → ", info.dest)
func generate_snake_path() -> Array:
	var start_num = randi_range(60, 99)
	var end_num = randi_range(1, 25)
	print("Attempt path: head=", start_num, " tail=", end_num)
	var start = number_to_tile(start_num)
	var end = number_to_tile(end_num)
	var path = random_walk(start, end, 12)
	print("Generated path size=", path.size(), " nums=", path.map(func(p): return board_tiles[p].num))
	return path

func random_walk(start: Vector2i, goal: Vector2i, max_steps: int) -> Array:  # Untyped return
	var path: Array[Vector2i] = [start]
	var current = start
	var steps = 0
	while steps < max_steps:
		var neighbors = get_valid_neighbors(current, path)
		if neighbors.is_empty(): break
		var dirs_priority = [Vector2i(0,1), Vector2i(1,0), Vector2i(-1,0), Vector2i(0,-1)]
		var next_pos = null
		for dir in dirs_priority:
			var candidate = current + dir
			if candidate in neighbors:
				next_pos = candidate
				break
		if next_pos == null:
			next_pos = neighbors[randi() % neighbors.size()]
		current = next_pos
		path.append(current)
		steps += 1
	path.append(goal)
	return path
func get_valid_neighbors(pos: Vector2i, path_so_far: Array) -> Array:  # Fully untyped return
	var neighbors: Array[Vector2i] = []
	for dir in DIRECTIONS:
		var npos: Vector2i = pos + dir
		if npos.x >= -13 and npos.x <= -4 and npos.y >= -9 and npos.y <= 0:
			if board_tiles.has(npos) and not path_so_far.has(npos) and not used_cells.has(npos):
				neighbors.append(npos)
	return neighbors
# Helper from before
func number_to_tile(num: int) -> Vector2i:
	num -= 1
	var board_width = 10
	var row = num / board_width  # row 0 = 1-10, row 9 = 91-100
	var col = num % board_width
	if row % 2 == 1:
		col = board_width - 1 - col
	return Vector2i(-13 + col, -row)  # <- -row only (y=0 for row 0, y=-9 for row 9)
# Helper for snake variants (customize to your tileset)
func get_snake_atlas_coords(type: String, pos: Vector2i) -> Vector2i:
	match type:
		"snake_head": return Vector2i(0, 1)
		"snake_tail": return Vector2i(1, 1)
		"snake_straight": return Vector2i(0, 2)
	return Vector2i(0, 0)
func print_snake_status():
	var count = 0
	for pos in board_tiles:
		if board_tiles[pos].get("type") == "snake_head":
			count += 1
			print("Snake ", count, " head at ", pos, "(", board_tiles[pos].num, 
				  ") → dest ", board_tiles[pos].dest)
	print("Total snakes:", count)
func draw_snakes_on_layer():
	snake_tilemaplayer.clear()
	for pos in board_tiles:
		var info = board_tiles.get(pos, {})
		match info.get("type"):
			"snake_head":
				snake_tilemaplayer.set_cell(pos, SNAKE_SOURCE_ID, HEAD_ATLAS)
			"snake_tail":
				snake_tilemaplayer.set_cell(pos, SNAKE_SOURCE_ID, TAIL_ATLAS)
			"snake_body":
				var atlas = BODY_VERT_ATLAS
				if info.get("body_index") == 1:  # First body = neck
					atlas = NECK_ATLAS
				snake_tilemaplayer.set_cell(pos, SNAKE_SOURCE_ID, atlas)
#endregion
"""=============================================LADDER GENERATION CODE========================================================================="""
#region LADDER GEN CODE
func generate_ladders(count: int):
	var placed = 0
	var total_attempts = 0
	var max_total = count * 50
	while placed < count and total_attempts < max_total:
		total_attempts += 1
		var col_list = LADDER_COLUMN_PATHS[randi() % 10]
		var start_idx = randi_range(0, col_list.size() - 3)
		var length = randi_range(3, col_list.size() - start_idx)
		var path_nums = col_list.slice(start_idx, start_idx + length)
		var path_pos = path_nums.map(number_to_tile)
		if is_valid_ladder(path_pos):
			add_ladder_to_board(path_pos)
			placed += 1
			print("✓ Ladder ", placed, ": ", path_nums)
		else:
			print("✗ Collision, retrying...")
	print("Generated ", placed, "/", count, " ladders in ", total_attempts, " total attempts")

func is_valid_ladder(path: Array) -> bool:
	if path.size() < 3: return false
	var seen = {}
	for pos in path:
		if seen.has(pos) or used_cells.has(pos):
			return false
		seen[pos] = true
	var tail_num = board_tiles[path[0]].num  # Low end
	var head_num = board_tiles[path[-1]].num  # High end
	if tail_num >= head_num or path.size() > 16:
		return false
	print("Validating ladder size=", path.size(), " from ", tail_num, " to ", head_num)
	return true

func add_ladder_to_board(path: Array):
	for i in range(path.size()):
		var pos = path[i]
		var info = board_tiles[pos]
		var num = info.num
		if i == 0:
			info.type = "ladder_tail"
		elif i == path.size() - 1:
			info.type = "ladder_head"
		else:
			info.type = "ladder_body"
		info.body_index = i
		info.dest = board_tiles[path[-1]].num
		board_tiles[pos] = info
		used_cells[pos] = true
		# Register ladder tail only
		if i == 0:
			ladder_map[num] = info.dest
			print("Ladder: ", num, " → ", info.dest)

func draw_ladders_on_layer():
	ladder_tilemaplayer.clear()
	for pos in board_tiles:
		var info = board_tiles.get(pos, {})
		match info.get("type"):
			"ladder_head":
				ladder_tilemaplayer.set_cell(pos, LADDER_SOURCE_ID, LADDER_HEAD_ATLAS)
			"ladder_tail":
				ladder_tilemaplayer.set_cell(pos, LADDER_SOURCE_ID, LADDER_TAIL_ATLAS)
			"ladder_body":
				ladder_tilemaplayer.set_cell(pos, LADDER_SOURCE_ID, LADDER_BODY_ATLAS)
#endregion
# Gameplay: Check tile when player lands

"""================================================||||READY||||==========================================================================="""

#region READY
func _ready() -> void:
	print("Board bounds: min ", board_tiles.keys().min(), " max ", board_tiles.keys().max())
	print("Sample: (-13,0)=", board_tiles[Vector2i(-13,0)])
	snake_tilemaplayer.z_index = 150
	print("Snake layer Z-index:", snake_tilemaplayer.z_index)
	# 1) FIRST: Setup TILE_SIZE
	var scaled := get_scaled_tile_size()
	if typeof(scaled) == TYPE_VECTOR2 and scaled.x > 0 and scaled.y > 0:
		TILE_SIZE = scaled
		print("Using TILE_SIZE:", TILE_SIZE)

	# 2) SECOND: Generate tile_map - NOW tile_map[1] exists!
	generate_tile_map()

	# 3) NOW: Get board origin (safe)
	var origin = get_board_origin()
	print("Board origin (tile 1):", origin)
	
	# 4) Clear and test
	snake_tilemaplayer.clear()
	offset = {
	"R": Vector2(-4,-4),
	"G": Vector2(4,-4),
	"B": Vector2(-4,4),
	"Y": Vector2(4,4)
}
	# Safely boost z_index for all UI panels
	var ui_panels = [
		$UI/HandPanel,
		$UI/Shoppanel,
		$UI/PermanentPanel,
		$UI/playerswapPanel,
		$UI/colourchoicePanel,
		$UI/Panel,
		$Victorypanel
	]
	for panel in ui_panels:
		if panel != null:
			panel.z_index = 100


	# 5) Rest of your original setup...
	if victory_panel:
		victory_panel.visible = false
	else:
		push_warning("Victorypanel not found — check scene tree path!")
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
				n.global_position = get_world_center_from_tile_index(1) + offset.get(color, Vector2.ZERO)
	# Connect buttons safely
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
	back_button.pressed.connect(_on_backtomenubutton_pressed)
	used_cells.clear()
	generate_snakes(4)  # Single call
	print("Generated snakes: ", snake_map)
	print_snake_status()
	generate_ladders(4)
	draw_ladders_on_layer()
	print("Generated ladders: ", ladder_map)
	draw_snakes_on_layer()
	_recalculate_tile_size()
#endregion
"""================================================TILE/POS/PLAYER HElPERS========================================================================"""
#region TILE/POS/PLAYER HElPERS

func _recalculate_tile_size() -> void:
	var tilemap_layer = $TileMap/Tilemaplayerresized
	var tile_set = tilemap_layer.tile_set
	if tile_set == null:
		TILE_SIZE = Vector2(48, 48)
		return
	# Vector2i.tile_size * Vector2.scale → explicit Vector2 conversion
	var base_tile_size: Vector2 = Vector2(tile_set.tile_size)  # Convert Vector2i → Vector2
	var scale = tilemap_layer.scale
	TILE_SIZE = base_tile_size * scale  # Now Vector2 × Vector2 = Vector2
	print("TileSet.tile_size: ", tile_set.tile_size)
	print("Layer.scale: ", scale)
	print("TILE_SIZE: ", TILE_SIZE)
func generate_tile_map() -> void:
	tile_map.clear()
	var tile_num: int = 1

	# BOARD_START expected to be a Vector2 (top-left world origin for tile 100)
	# BOARD_ROWS, BOARD_COLS expected integers
	for row in range(BOARD_ROWS):
		# Use TILE_SIZE (Vector2) safely
		var y: float = BOARD_START.y - float(row) * TILE_SIZE.y
		for col in range(BOARD_COLS):
			var real_col: int = col if (row % 2) == 0 else (BOARD_COLS - 1 - col)
			var x: float = BOARD_START.x + float(real_col) * TILE_SIZE.x
			var world_pos: Vector2 = Vector2(x, y)
			tile_map[tile_num] = world_pos
			tile_num += 1

	# debug printing
	if tile_map.has(1): print("Tile 1 pos:", tile_map[1])
	if tile_map.has(10): print("Tile 10 pos:", tile_map[10])
	if tile_map.has(BOARD_ROWS * BOARD_COLS): print("Tile final pos:", tile_map[BOARD_ROWS * BOARD_COLS])

	# update player positions if you have that helper
	if has_method("update_player_positions"):
		update_player_positions()
# --- Helpers ---
# Get world/pixel position for a tile index (1..N).
func get_position_from_tile_index(tile_index: int) -> Vector2:
	if tile_index <= 0:
		return Vector2.ZERO
	var row := int((tile_index - 1) / COLS)
	var col := int((tile_index - 1) % COLS)
	# Handle snaking rows (reverse direction every other row)
	if row % 2 == 1:
		col = COLS - 1 - col
	# Convert to pixel position (bottom row is index 0)
	var x := float(col) * TILE_SIZE.x + TILE_SIZE.x * 0.5
	var y := float(ROWS - 1 - row) * TILE_SIZE.y + TILE_SIZE.y * 0.5
	return Vector2(x, y)
func xy_to_tile_index(xy: Vector2i) -> int:
	var col := xy.x
	var row_from_top := xy.y
	var row_from_bottom := ROWS - 1 - row_from_top
	var col_snake := col
	if row_from_bottom % 2 == 1:
		col_snake = COLS - 1 - col
	return row_from_bottom * COLS + col_snake + 1

func tile_index_to_xy(tile_num: int) -> Vector2i:
	var row = (100 - tile_num) / 10
	var col = (tile_num - 1) % 10
	if row % 2 == 1:  # Odd rows: right→left
		col = 9 - col
	return Vector2i(col, row)

func get_world_pos_from_tile_coords(cell: Vector2i) -> Vector2:
	var tm: TileMapLayer = $TileMap/Tilemaplayerresized
	var local_pos: Vector2 = tm.map_to_local(cell)
	return tm.to_global(local_pos)
func get_world_center_from_tile_coords(cell: Vector2i) -> Vector2:
	var tm: TileMapLayer = $TileMap/Tilemaplayerresized
	var local_pos: Vector2 = tm.map_to_local(cell)  # already centered
	return tm.to_global(local_pos)
func get_world_center_from_tile_index(tile_index: int) -> Vector2:
	var tm: TileMapLayer = tilemaplayer
	var logical_cell: Vector2i = tile_index_to_xy(tile_index)
	var origin = get_board_origin()
	var tilemap_cell = logical_cell + origin
	print("Tile %d: logical=%s, origin=%s, tilemap=%s" % [tile_index, logical_cell, origin, tilemap_cell])
	var local_pos: Vector2 = tm.map_to_local(tilemap_cell)
	return tm.to_global(local_pos)

func move_player_to_tile(color: String, tile_index: int) -> void:
	var n = player_nodes.get(color)
	if n == null:
		return
	n.global_position = get_world_center_from_tile_index(tile_index) + offset.get(color, Vector2.ZERO)

func get_board_origin() -> Vector2i:
	var world_pos_tile1 = tile_map[1]
	var local_pos = tilemaplayer.to_local(world_pos_tile1)
	var tm_coords: Vector2i = tilemaplayer.local_to_map(local_pos)
	return tm_coords
#endregion
"""================================================AI SETUP HELPERS==================================================================="""
#region AI SETUP/HELPERS
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
func _deferred_start_ai_turn(color: String) -> void:
	# ✅ Only one deferred AI turn at a time
	if not ai_turn_in_progress:
		ai_turn_in_progress = true
	ai_take_turn(color)


func ai_play_random_card(color: String, rarity: String = "any") -> void:
	if not player_hands.has(color):
		return

	var candidates := []
	for i in range(player_hands[color].size()):
		var cd = player_hands[color][i]
		var r = String(cd.get("rarity", "common"))
		if rarity == "any" or r == rarity or (rarity == "field" and r == "epic"):
			candidates.append(i)

	if candidates.is_empty():
		log_debug("%s (AI) tried to play %s card but had none." % [color, rarity])
		return

	candidates.shuffle()
	var idx = candidates[0]
	var card_data = player_hands[color][idx]

	# 🕒 Simulate AI "thinking" delay
	log_debug("%s (AI) is thinking about playing a card..." % color)
	await get_tree().create_timer(1.8).timeout

	# Remove card from hand
	player_hands[color].remove_at(idx)

	# 🖐️ Update UI if AI’s hand is visible (for testing)
	if get_current_player() == color:
		refresh_hand_for_current_player()

	# 🎭 Small delay before applying effect (like a card “animation”)
	log_debug("%s (AI) decided to play: %s" % [color, card_data.get("name", "Unknown")])
	await get_tree().create_timer(1.2).timeout

	# ⚡ Actually apply effect now
	apply_card_effect_by_name(color, card_data)

	# ⏳ Optional: short cooldown before AI ends its turn (for readability)
	await get_tree().create_timer(0.8).timeout
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


#endregion
"""=================================================PLAYER WIN/CONFIGURE MODE/COLOR AND RELADED CODE============================================="""

#region PLAYER WIN/CONFIGURE MODE/COLOR AND RELADED CODE

func get_current_player_color() -> String:
	return turn_order[current_turn_index]
func _finalize_setup():
	# Hide unused player sprites
	for color in ["R","G","B","Y"]:
		if color in turn_order:
			player_nodes[color].show()
		else:
			player_nodes[color].hide()

# -------------------------
func configure_mode(mode: String, count: int, config: Dictionary = {}) -> void:
	game_mode = mode
	player_count = clamp(count, 2, 4)

	# reset AI/human markers & ai_setup state
	ai_setup.clear()
	reserved_ai_colors.clear()
	ai_level_by_color = {"R": 0, "G": 0, "B": 0, "Y": 0}
	player_is_ai = {"R":false,"G":false,"B":false,"Y":false}

	# If menu passed an AI config, consume it (normalize)
	if game_mode == "ai" and config.size() > 0 and config.has("ai_colors") and config.has("ai_levels"):
		var ai_count: int = int(config.get("ai_count", 0))
		ai_count = clamp(ai_count, 1, 3)

		ai_setup.clear()
		reserved_ai_colors.clear()
		for i in range(ai_count):
			var raw_col: String = String(config.get("ai_colors", [])[i])
			var col: String = _color_name_to_code(raw_col)
			var lvl: int = int(config.get("ai_levels", [])[i])
			ai_setup.append({"color": col, "level": lvl})
			reserved_ai_colors.append(col)
			player_is_ai[col] = true
			ai_level_by_color[col] = lvl

		# desired player count is total players (human + ai_count)
		desired_player_count = clamp(int(config.get("player_count", 1)), 2, 4)

		_perm_log("configure_mode: received AI config -> ai_setup=%s reserved=%s desired_count=%d" % [ai_setup, reserved_ai_colors, desired_player_count])

		# If Menu already provided a human color (it will call _on_choose_color later),
		# we should NOT show the board's colourpanel — just return and wait for _on_choose_color.
		# This prevents double-popups and timing issues on web builds.
		if config.has("human_color"):
			var hc = _color_name_to_code(String(config.get("human_color", "")))
			_perm_log("configure_mode: human_color present in config (%s) -> deferring final setup to _on_choose_color" % hc)
			# Do NOT set chosen_color here — only let _on_choose_color do that
			return


	# If we reach here and game_mode is AI but no human color passed by menu, show panel so player picks
	# Show color pick to human so they choose a human color (AI colors reserved)
	if game_mode == "ai" and colourpanel != null:
		colourpanel.visible = true
		if rollresult:
			rollresult.text = "Choose your color (AI colors reserved)."
		_debug_print_ai_state("after config - awaiting human choice")
		return

	# Fallback path (pass & play or no config)
	desired_player_count = clamp(player_count, 2, 4)

	# default turn_order by count (human colors assigned as conventional starting set)
	match desired_player_count:
		2:
			turn_order = ["R","B"]
		3:
			turn_order = ["R","G","B"]
		4:
			turn_order = ["R","G","B","Y"]

	# ensure player_is_ai false for all in pass & play
	for c in ["R","G","B","Y"]:
		player_is_ai[c] = false

	_debug_print_ai_state("fallback/passplay")
	_finish_initial_setup_and_start()

# -------------------------
# Colour pick chosen by human
# This is callable both from in-board UI and deferred from Menu
# -------------------------
func _on_choose_color(color_letter: String) -> void:
	# Defensive: ignore empty calls
	if color_letter == "" or color_letter == null:
		_perm_log("_on_choose_color called with empty color; ignoring.")
		return

	var color_code: String = _color_name_to_code(color_letter)
	# If we already have a chosen_color identical, ignore to avoid double-start
	if chosen_color != "" and chosen_color == color_code:
		_perm_log("_on_choose_color called but chosen_color already set to %s; ignoring duplicate." % chosen_color)
		return

	# Hide any in-board color UI (menu-driven flows will call this after configure_mode)
	if colourpanel != null:
		colourpanel.visible = false

	chosen_color = color_code
	var base := ["R","G","B","Y"]

	# If there is AI setup, ensure player_is_ai flags reflect it and human isn't AI
	if ai_setup.size() > 0:
		for c in base:
			player_is_ai[c] = false

		for e in ai_setup:
			var ccol: String = String(e["color"])
			player_is_ai[ccol] = true
			ai_level_by_color[ccol] = int(e["level"])

		# Human must not be AI
		player_is_ai[chosen_color] = false

		# Build turn_order: human first, then configured AIs (preserving their order as provided)
		var ordered: Array = [chosen_color]
		for e in ai_setup:
			var ccol = String(e["color"])
			if ccol != chosen_color:
				ordered.append(ccol)

		turn_order = ordered
		turn_order = turn_order.slice(0, clamp(desired_player_count, 1, 4))
	else:
		# pass & play style: rotate conventional base so chosen human is first
		var idx: int = base.find(chosen_color)
		if idx == -1:
			idx = 0
		var rotated: Array = base.slice(idx, base.size()) + base.slice(0, idx)
		turn_order = rotated.slice(0, clamp(desired_player_count, 1, 4))

	# Ensure player_is_ai flags are set for any players in turn_order
	for c in ["R","G","B","Y"]:
		if c in turn_order:
			if not player_is_ai.has(c):
				player_is_ai[c] = false
		else:
			player_is_ai[c] = false
	
	# 🔥 NEW CLEANUP STEP: hide unused colors + reset their state
	for c in ["R","G","B","Y"]:
		if c in turn_order:
			if player_nodes.has(c) and player_nodes[c]:
				player_nodes[c].visible = true
		else:
			if player_nodes.has(c) and player_nodes[c]:
				player_nodes[c].visible = false
			player_positions[c] = 0
			player_hands[c] = []
			player_permanents[c] = []
			player_money[c] = 0
			player_is_ai[c] = false

	# Reset starting positions (safe) and place sprites at start
	for c in player_nodes.keys():
		player_positions[c] = player_positions.get(c, 1)
		if tile_map.has(player_positions[c]) and player_nodes[c] != null:
			player_nodes[c].position = tile_map[player_positions[c]] + get_offset_if_needed(player_positions[c], c)

	_debug_print_ai_state("after human pick")
	_finish_initial_setup_and_start()

var ai_turn_in_progress := false  # 🛡️ Guard flag to prevent triple-turn bug
func start_turn(level := 0, color := "") -> void:
	if color == "":
		color = get_current_player()

	# 🛡️ Prevent re-entry if AI is already taking a turn
	if player_is_ai.get(color, false) and ai_turn_in_progress:
		if has_method("log_debug"):
			log_debug("⚠️ AI turn already in progress for %s, skipping duplicate start_turn." % color)
		return

	print("[START_TURN] current player:", color, " player_is_ai:", player_is_ai.get(color, false), " ai_level:", ai_level_by_color.get(color, 0))

	has_rolled_dice = false
	refresh_hand_for_current_player()
	refresh_permanent_panel_for_current_player()
	populate_shop()
	populate_permanent_shop(color)
	refresh_hand_for_current_player()
	update_all_hand_card_states()
	

	# --- START TURN PERMANENT EFFECTS ---
	apply_tramp_effect(color)

	if player_is_ai.get(color, false):
		ai_turn_in_progress = true
		call_deferred("_deferred_start_ai_turn", color)

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
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var screen_pos: Vector2 = event.position
		var world_pos: Vector2 = get_global_mouse_position()
		
		# Dictionary nearest tile lookup (unchanged)
		var nearest_tile: int = -1
		var min_dist: float = INF
		for key in tile_map.keys():
			var pos: Vector2 = tile_map[key] as Vector2  # Assuming tile_map[key] gives world center
			var d: float = pos.distance_to(world_pos)
			if d < min_dist:
				min_dist = d
				nearest_tile = int(key)
		
		var cell_info: String = "no-layer"
		if tilemaplayer != null:
			# FIXED: Convert world to local, then local_to_map
			var local_pos: Vector2 = tilemaplayer.to_local(world_pos)
			var cell: Vector2i = tilemaplayer.local_to_map(local_pos)
			cell_info = "cell: " + str(cell)
			print("[DEBUG_CLICK] world:", world_pos, " local:", local_pos, " cell:", cell)
		
		if nearest_tile != -1:
			print("[DEBUG_CLICK] screen:", screen_pos, " world:", world_pos,
				  " nearest_tile:", nearest_tile, " tile_pos:", tile_map[nearest_tile],
				  " dist:", min_dist, " layer_cell:", cell_info)
		else:
			print("[DEBUG_CLICK] screen:", screen_pos, " nearest_tile: none", " layer_cell:", cell_info)
func _check_victory_for_color(color: String) -> bool:
	# returns true if this color has reached the finish and handled victory UI
	if player_positions.get(color, 0) >= 100:
		_on_player_wins(color)
		return true
	return false

func _on_player_wins(color: String) -> void:
	_perm_log("%s WINS the game!" % color)
	show_victory_panel("%s won the game!" % color)
#endregion

"""================================================HANDS AND RELATED CODE==================================================================="""
#region HANDS AND RELATED
# -------------------------------
# HAND (per-player model + shared UI)
# -------------------------------
const MAX_HAND_SIZE = 5

# Create starting hand for a player
func create_starting_hand_for_player(player_color: String) -> void:
	if not player_hands.has(player_color) or player_hands[player_color].size() == 0:
		player_hands[player_color] = []
		for name in ["+1 Move", "-2 Move"]:
			# Duplicate to avoid reference issues
			player_hands[player_color].append(power_cards_db[name].duplicate(true))
	if player_color == get_current_player():
		refresh_hand_for_current_player()

# Clear all cards visually from hand container
func clear_hand() -> void:
	for c in hand_container.get_children():
		c.queue_free()

var is_refreshing_hand: bool = false

# Refresh hand UI for current player up to max hand size
func refresh_hand_for_current_player() -> void:
	
	if is_refreshing_hand:
		return
	is_refreshing_hand = true

	clear_hand()
	var cp = get_current_player()
	if cp == "":
		is_refreshing_hand = false
		return

	var hand_list = player_hands.get(cp, [])
	var hand_limit = min(hand_list.size(), MAX_HAND_SIZE)

	hand_nodes[cp] = []

	for i in range(hand_limit):
		var card_data = hand_list[i]
		var card = card_scene.instantiate()
		card.set_card_data(card_data)
		card.card_mode = "hand"              # <- required
		print_debug("HAND card mode:", card.card_mode, "name:", card_data.get("name",""))
		card.connect("card_clicked", Callable(self, "_on_card_clicked"))
		card.connect("card_sell_clicked", Callable(self, "_on_card_sell_requested").bind(card)) # if you also use this
		hand_container.add_child(card)
		hand_nodes[cp].append(card)

	update_hand_turn_state()
	refresh_money_label()

	is_refreshing_hand = false



# Handle card played signal
func _on_card_clicked(card_data):
	# Handle what happens when the card is clicked:
	# Play, remove from hand, animate, etc.
	_remove_card_from_player_hand(get_current_player(), card_data)
	refresh_hand_for_current_player()
	if card_data.get("name", "") == "Swap":
		start_swap_selection(get_current_player())
	else:
		apply_card_effect_by_name(get_current_player(), card_data)

# Remove a single matching card by unique identifier (recommend adding 'id' to cards)
func _remove_card_from_player_hand(player_color: String, card_data: Dictionary) -> void:
	if not player_hands.has(player_color):
		return
	var id_to_find = card_data.get("id", null)
	if id_to_find == null:
		# fallback to name match if no id present
		var name_to_find = String(card_data.get("name", ""))
		for i in range(player_hands[player_color].size()):
			var cd = player_hands[player_color][i]
			if String(cd.get("name", "")) == name_to_find:
				player_hands[player_color].remove_at(i)
				break
	else:
		for i in range(player_hands[player_color].size()):
			var cd = player_hands[player_color][i]
			if cd.get("id", null) == id_to_find:
				player_hands[player_color].remove_at(i)
				break

		# Also remove corresponding Visual card
	if hand_nodes.has(player_color):
		var id_to_find_visual = card_data.get("id", null)
		var name_to_find_visual = String(card_data.get("name", ""))
		for j in range(hand_nodes[player_color].size()):
			var node = hand_nodes[player_color][j]
			# node is an instance of spritecardscene.gd, so use node.card_data
			var node_id   = node.card_data.get("id", null)
			var node_name = String(node.card_data.get("name", ""))
			var is_match := false
			if id_to_find_visual != null:
				is_match = (node_id == id_to_find_visual)
			else:
				is_match = (node_name == name_to_find_visual)
			if is_match:
				node.queue_free()
				hand_nodes[player_color].remove_at(j)
				break
func update_all_hand_card_states() -> void:
	for color in hand_nodes.keys():
		var is_current: bool = (color == get_current_player())
		var is_ai: bool = player_is_ai.get(color, false)

		for card_node in hand_nodes[color]:
			if card_node and card_node.has_method("set_turn_state"):
				# Disable card interaction if not current player's turn OR if it's an AI hand
				card_node.set_turn_state(is_current and not is_ai, has_rolled_dice)
# Update all cards in hand container with current turn state
func update_hand_turn_state() -> void:
	var is_my_turn = (get_current_player() == get_current_player_color())
	for card in hand_container.get_children():
		if card.has_method("set_turn_state"):
			card.set_turn_state(is_my_turn, has_rolled_dice)
#endregion
"""================================================AI MOVEMENT/SETUP RELATED CODE==================================================="""

#region AI MOVEMENT/GAME SETUP RELATED CODE
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

func ai_take_turn(ai_color: String) -> void:
	log_debug("🤖 [AI TURN START] %s thinking..." % ai_color)
	await get_tree().create_timer(1.2).timeout

	# === 🃏 AI CARD USE ===
	var card_played := false
	for cd in player_hands[ai_color]:
		var mv = int(cd.get("move_value", 0))
		if mv != 0:
			log_debug("🤖 %s found card: %s (Move %+d)" % [ai_color, cd.get("name", ""), mv])
			await get_tree().create_timer(1.2).timeout  # thinking time before playing
			_remove_card_from_player_hand(ai_color, cd)
			if ai_color == get_current_player():
				refresh_hand_for_current_player()

			log_debug("🤖 %s plays %s" % [ai_color, cd.get("name", "")])
			apply_card_effect(mv)
			card_played = true
			break

	if not card_played:
		log_debug("🤖 %s had no playable move cards." % ai_color)

	await get_tree().create_timer(1.4).timeout  # short pause before rolling
	_ai_roll_and_move(ai_color)

func _ai_roll_and_move(color: String) -> void:
	var dice_sides = int(player_dice_sides.get(color, 6))
	if dice_sides <= 0:
		dice_sides = 6
	var dice_roll = randi() % dice_sides + 1

	if _check_victory_for_color(color):
		ai_turn_in_progress = false
		return

	# Money from 6 Ball
	if has_permanent(color, "6 Ball") and dice_roll == 6:
		player_money[color] += 2
		_perm_log("%s (AI) gained $2 from 6 Ball (rolled 6)." % color)
		refresh_money_label()

	# Fibonacci double-move
	var move_steps = dice_roll
	if has_permanent(color, "Fibonacci") and dice_roll in _fib_set:
		move_steps = dice_roll * 2
		_perm_log("%s (AI) Fibonacci triggered: %d -> move %d" % [color, dice_roll, move_steps])

	# DoMovei bonus (AI)
	var extra_from_domovei: int = 0
	var domovei_copies: int = int(count_permanent_copies(color, "Domovei"))
	if domovei_copies > 0:
		var hand_count: int = 0
		if player_hands.has(color):
			hand_count = int(player_hands[color].size())
		extra_from_domovei = int(hand_count * 2 * domovei_copies)
		if extra_from_domovei > 0:
			_perm_log("%s (AI) Domovei added +%d (hand %d × 2 × copies %d)" % [color, extra_from_domovei, hand_count, domovei_copies])

	move_steps += extra_from_domovei

	if has_method("log_debug"):
		log_debug("%s (AI) rolled %d (sides %d) => moving %d" % [color, dice_roll, dice_sides, move_steps])
	else:
		print("%s (AI) rolled %d" % [color, dice_roll])
	rollresult.text = color + " (AI) rolled a " + str(dice_roll)

	if has_rolled_dice:
		ai_turn_in_progress = false
		return
	has_rolled_dice = true

	var sprite: Node2D = player_nodes.get(color, null)
	if sprite == null:
		ai_turn_in_progress = false
		return

	var tile = player_positions[color]
	var target_tile = min(tile + move_steps, 100)

	for i in range(tile + 1, target_tile + 1):
		if tile_map.has(i):
			sprite.position = tile_map[i] + get_offset_if_needed(i, color)
		await get_tree().create_timer(0.25).timeout
	player_positions[color] = target_tile

	# Snakes and Ladders (CHANGED: snakes → snake_map, ladders → ladder_map)
	if snake_map.has(target_tile):
		await get_tree().create_timer(0.45).timeout
		var oldpos: int = target_tile
		var dest = snake_map[target_tile]
		player_positions[color] = dest
		if tile_map.has(dest):
			sprite.position = tile_map[dest] + get_offset_if_needed(dest, color)
		_perm_log("%s (AI) hit a SNAKE %d -> %d" % [color, oldpos, dest])

	elif ladder_map.has(target_tile):
		await get_tree().create_timer(0.45).timeout
		var oldpos: int = target_tile
		var dest = ladder_map[target_tile]
		player_positions[color] = dest
		if tile_map.has(dest):
			sprite.position = tile_map[dest] + get_offset_if_needed(dest, color)
		_perm_log("%s (AI) climbed a LADDER %d -> %d" % [color, oldpos, dest])

	check_for_money_collection(color)

	ai_turn_in_progress = false
	end_turn()



#endregion


"""================================================ SWAP UI & Logic ==================================================================="""

#region SWAP AND SWAP MOVEMENT CODE

func _on_swap_target_selected(target_player_color: String) -> void:
	if swap_source_player == "":
		playerswappanel.visible = false
		return

	# If in pass-and-play, let the target “control” the choice
	if swap_target_delegate == "":
		swap_target_delegate = target_player_color
		rollresult.text = "%s is confirming Swap for %s" % [swap_target_delegate, swap_source_player]
		# optionally: require a confirm button from the target
		return

	# Otherwise perform the swap (source -> chosen target)
	var src = swap_source_player
	var tgt = target_player_color
	var tmp = int(player_positions[src])
	player_positions[src] = int(player_positions[tgt])
	player_positions[tgt] = tmp
	update_player_positions()

	rollresult.text = "%s swapped positions with %s" % [src, tgt]
	playerswappanel.visible = false
	swap_source_player = ""
	swap_target_delegate = ""
func update_player_positions() -> void:
	for color in player_nodes.keys():
		var t: int = int(player_positions.get(color, 1))
		if tile_map.has(t):
			var base_pos: Vector2 = tile_map[t]
			player_nodes[color].position = base_pos + get_offset_if_needed(t, color)

func clear_children(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()
func start_swap_selection(source_player_color: String) -> void:
	swap_source_player = source_player_color
	swap_target_delegate = ""   # reset
	clear_children(playerswapcontainer)
	for col in player_nodes.keys():
		if col == source_player_color:
			continue
		var btn := Button.new()
		btn.text = col
		btn.pressed.connect(Callable(self, "_on_swap_target_selected").bind(col))
		playerswapcontainer.add_child(btn)
	playerswappanel.visible = true
	# If this is pass-and-play, show instructions
	rollresult.text = "%s, choose a target for %s's Swap!" % [get_current_player(), source_player_color]
	
func get_valid_swap_targets() -> Array:
	var targets: Array = []
	var current_color = get_current_player_color()
	for color in turn_order: # active players
		if color != current_color:
			targets.append(color)
	return targets

#endregion

"""================================================SHOP / PERMANENTS / DEBT==================================================================="""

#region SHOPS/PERMS/DEBT
# robust permanent helpers (case-insensitive)
func has_permanent(player_color: String, name: String) -> bool:
	if not player_permanents.has(player_color):
		return false
	var lname := String(name).to_lower()
	for pd in player_permanents[player_color]:
		if String(pd.get("name","")).to_lower() == lname:
			return true
	return false

func count_permanent_copies(player_color: String, name: String) -> int:
	if not player_permanents.has(player_color):
		return 0
	var lname := String(name).to_lower()
	var cnt := 0
	for pd in player_permanents[player_color]:
		if String(pd.get("name","")).to_lower() == lname:
			cnt += 1
	return cnt
func get_max_debt(color: String) -> int:
	# Each Bank Card allows $10 debt
	var copies: int = count_permanent_copies(color, "Bank Card")
	return copies * 10

func get_random_card_name() -> String:
	var weighted_list := []
	for card_name in power_cards_db.keys():
		var weight = int(rarity_weights.get(power_cards_db[card_name].get("rarity","common"),0))
		for i in range(weight):
			weighted_list.append(card_name)
	if weighted_list.size() == 0:
		return ""
	return weighted_list[randi() % weighted_list.size()]
# calculate sell value of a card
func get_sell_value(card: Dictionary) -> int:
	var cost: int = int(card.get("shop_cost", 0))
	var modifier: float = float(card.get("sell_modifier", 0.75)) # default 75% value
	return int(round(cost * modifier))
func sell_card(card_data: Dictionary, card_node: Node) -> void:
	var cp := get_current_player_color()
	if cp == "":
		return

	# Always use the helper (75% of shop_cost)
	var value := get_sell_value(card_data)
	player_money[cp] += value

	var removed := false

	# Remove from hand
	if player_hands.has(cp):
		for i in range(player_hands[cp].size()):
			var cd: Dictionary = player_hands[cp][i]
			if String(cd.get("name","")) == String(card_data.get("name","")):
				player_hands[cp].remove_at(i)
				removed = true
				break

	# Remove from permanents (if not found in hand)
	if not removed and player_permanent_cards.has(cp):
		for j in range(player_permanent_cards[cp].size()):
			var pd: Dictionary = player_permanent_cards[cp][j]
			if String(pd.get("name","")) == String(card_data.get("name","")):
				player_permanent_cards[cp].remove_at(j)
				removed = true
				break

	if is_instance_valid(card_node):
		card_node.queue_free()

	refresh_money_label()
	refresh_hand_for_current_player()
	refresh_permanent_panel_for_current_player()


func populate_shop() -> void:
	var current_color := get_current_player_color()

	# 🧩 Allow shop population only during the human player's active turn
	if player_is_ai.get(current_color, false):
		return

	for c in shop_container.get_children():
		c.queue_free()

	var shop_cards: Array = []
	while shop_cards.size() < cards_per_shop:
		var n = get_random_card_name()
		if n != "":
			shop_cards.append(n)

	for card_name in shop_cards:
		var card_data: Dictionary = power_cards_db[card_name]
		var card = card_scene.instantiate()
		card.set_card_data(card_data)
		card.card_mode = "shop"
		print_debug("SHOP card mode:", card.card_mode, "name:", card_data.get("name",""))           # <- not sellable
		card.connect("card_clicked", Callable(self, "_on_shop_card_bought").bind(card))
		shop_container.add_child(card)

func _on_shop_card_bought(card_data: Dictionary, shop_card_node: Node) -> void:
	var current_player := get_current_player_color()
	if current_player == "":
		print("⚠️ No current player color detected.");  return

	# ✅ Ensure this is the current human’s turn
	if not is_player_turn(current_player):
		print("⛔ Cannot buy cards — not your turn or AI turn.");  return

	# ✅ Prevent overfilling hand
	if player_hands.get(current_player, []).size() >= max_hand_size:
		print("🖐️ Hand full for", current_player);  return

	# ✅ Ensure affordability
	var cost := int(card_data.get("shop_cost", 0))
	if player_money.get(current_player, 0) < cost:
		print("💸 Not enough funds for card purchase.");  return

	# Apply transaction
	player_money[current_player] -= cost
	var purchased_card := card_data.duplicate(true)
	purchased_card["owner_color"] = current_player
	player_hands[current_player].append(purchased_card)

	print("🛒", current_player, "purchased", purchased_card["name"], "for $", cost)

	refresh_hand_for_current_player()
	refresh_money_label()

	if is_instance_valid(shop_card_node):
		shop_card_node.queue_free()

func populate_permanent_shop(for_player_id: String) -> void:
	for c in permshopcontainer.get_children():
		c.queue_free()
	if permanent_cards_db.size() == 0:
		return

	# build candidate list (skip ones the player already has if possible)
	var candidates := []
	for k in permanent_cards_db.keys():
		candidates.append(k)

	# filter out ones player already owns
	var filtered := []
	for name in candidates:
		if not has_permanent(for_player_id, name):
			filtered.append(name)
	if filtered.is_empty():
		filtered = candidates.duplicate(true)

	# choose up to 2 permanents to show
	filtered.shuffle()
	var show_count: int = min(2, filtered.size())
	for i in range(show_count):
		var name: String = filtered[i] as String
		var data: Dictionary = permanent_cards_db[name]
		var card = card_scene.instantiate()
		card.set_card_data(data)
		card.card_mode = "shop"                 # <- not sellable
		card.connect("card_clicked", Callable(self, "_on_permanent_card_bought").bind(card))
		permshopcontainer.add_child(card)


func refresh_permanent_panel_for_current_player() -> void:
	var cp := get_current_player_color()
	if cp == "":
		return

	if not player_permanent_cards.has(cp):
		player_permanent_cards[cp] = []

	if not is_instance_valid(permcontainer):
		print("⚠️ permcontainer not found — please confirm scene node path.")
		return
	var panel = permcontainer

	clear_children(panel)

	var card_scene = preload("res://spritecardscene.tscn")
	for card_data in player_permanent_cards[cp]:
		var card = card_scene.instantiate()
		card.set_card_data(card_data)
		card.card_mode = "permanent"         # <- required
		print_debug("PERM card mode:", card.card_mode, "name:", card_data.get("name",""))
		panel.add_child(card)

func _on_permanent_card_bought(card_data: Dictionary, shop_card_node: Node) -> void:
	var current_player := get_current_player_color()
	if current_player == "":
		print("⚠️ No current player color for permanent shop buy.");  return

	if not is_player_turn(current_player):
		print("⛔ Cannot buy permanent card during AI or other player’s turn.");  return

	var cost := int(card_data.get("shop_cost", 0))
	if player_money.get(current_player, 0) < cost:
		print("💸 Insufficient funds for permanent purchase.");  return

	player_money[current_player] -= cost
	var copy = card_data.duplicate(true)
	copy["owner_color"] = current_player
	player_permanent_cards[current_player].append(copy)
	refresh_permanent_panel_for_current_player()
	print("🏗️", current_player, "purchased permanent card:", copy["name"])
	refresh_permanent_panel_for_current_player()
	refresh_money_label()
	if is_instance_valid(shop_card_node):
		shop_card_node.queue_free()

func apply_permanent_effect(card_data: Dictionary, player_color: String) -> void:
	var name := String(card_data.get("name",""))
	match name:
		"D20 Upgrade":
			player_dice_sides[player_color] = 20
			_perm_log("%s got D20 Upgrade." % player_color)
		"Odd Space Boost":
			# keep existing or extend behavior
			_perm_log("%s got Odd Space Boost." % player_color)
		"Unstoppable":
			# no immediate numeric state to change — presence in player_permanents is checked by can_be_moved()
			_perm_log("%s bought Unstoppable (immune to swaps/traps)." % player_color)
		"6 Ball":
			_perm_log("%s bought 6 Ball (gain $2 on roll 6)." % player_color)
		"Mirror":
			_perm_log("%s bought Mirror (reflects effects back at attacker)." % player_color)
		"Fibonacci":
			_perm_log("%s bought Fibonacci (double movement on Fibonacci rolls)." % player_color)
		_:
			_perm_log("%s bought permanent %s" % [player_color, name])
		"Domovei":# DoMovei: grants +2 movement per power card in hand (stacks if multiple DoMovei permanents)
			_perm_log("%s bought Domovei (movement bonus per card in hand)." % player_color)

#endregion
"""=====================================================MONEY HELPERS======================================================================"""
#region MONEY HELPERS
var COIN_SIZE_FACTOR: float = 0.75
var COIN_OFFSET: Vector2 = Vector2(0, -8)
func add_money(color: String, amount: int) -> void:
	if not player_money.has(color):
		return

	var current_money: int = int(player_money[color])
	var max_debt: int = get_max_debt(color)

	var new_balance: int = current_money + amount
	if new_balance < -max_debt:
		new_balance = -max_debt

	player_money[color] = new_balance
	refresh_money_label()

	# Logging
	if new_balance < 0:
		_perm_log("%s is now in debt: $%d (max debt: $%d)" % [color, new_balance, max_debt])
	else:
		_perm_log("%s now has $%d" % [color, new_balance])

func set_coin_visuals(size_factor: float, offset_vec: Vector2):
	for tile_num: int in money_nodes_by_tile.keys():
		var coin: Sprite2D = money_nodes_by_tile[tile_num]
		if tile_map.has(tile_num):
			# Center coin + vertical adjustment to match players
			var center_offset = Vector2(TILE_SIZE.x * 0.5, TILE_SIZE.y * 0.5 - 6)
			coin.global_position = tile_map[tile_num] + center_offset
		coin.scale = Vector2.ONE * size_factor

func spawn_money_tiles(count: int = 5) -> void:
	clear_money_tiles()
	
	# BUILD blocked_tiles from ALL snake/ladders
	var temp_blocked: Array[int] = []
	
	# Snakes: heads + tails
	for head in snake_map.keys():
		temp_blocked.append(head)
		temp_blocked.append(snake_map[head])
	
	# Ladders: bottoms + tops  
	for bottom in ladder_map.keys():
		temp_blocked.append(bottom)
		temp_blocked.append(ladder_map[bottom])
	
	# Remove duplicates manually
	blocked_tiles.clear()
	for tile in temp_blocked:
		if not blocked_tiles.has(tile):
			blocked_tiles.append(tile)
	
	# Add start/finish
	if not blocked_tiles.has(1): blocked_tiles.append(1)
	if not blocked_tiles.has(100): blocked_tiles.append(100)
	blocked_tiles.sort()
	
	# Safe tiles only
	var available_tiles: Array[int] = []
	for tile_num: int in range(2, 100):
		if not blocked_tiles.has(tile_num):
			available_tiles.append(tile_num)
	
	available_tiles.shuffle()
	money_tiles_positions = available_tiles.slice(0, count)
	
	for tile_num in money_tiles_positions:
		var tile_coords: Vector2i = number_to_tile(tile_num)
		moneylayer.set_cell(tile_coords, MONEY_SOURCE_ID, MONEY_ATLAS_COORD)
	
	print("🚫 Blocked: ", blocked_tiles.size(), " | 💰 Safe: ", money_tiles_positions)


func clear_money_tiles() -> void:
	moneylayer.clear()
	money_tiles_positions.clear()
# Check player collection
func check_for_money_collection(player_color: String) -> void:
	var current_tile: int = player_positions[player_color]
	
	if current_tile in money_tiles_positions:
		player_money[player_color] += money_value
		money_tiles_positions.erase(current_tile)
		
		# Remove from TileMapLayer instantly
		var tile_coords: Vector2i = number_to_tile(current_tile)
		moneylayer.set_cell(tile_coords, -1)  # -1 = empty
		
		rollresult.text = player_color + " collected $" + str(money_value) + "!"
		refresh_money_label()
		print(player_color, " collected money at tile ", current_tile)


func get_tile_number_from_coords(cell: Vector2i) -> int:
	return cell.x + cell.y * 10

func get_offset_if_needed(tile_num: int, color: String) -> Vector2:
	var center = Vector2(TILE_SIZE.x * 0.5, TILE_SIZE.y * 0.5)  # (24, 24)
	
	# Move ALL players up 6 pixels for visual centering
	var vertical_adjust = Vector2(0, -6)
	
	var color_offsets = {
		"R": Vector2(-4, -4),
		"G": Vector2(4, -4), 
		"B": Vector2(-4, 4),
		"Y": Vector2(4, 4)
	}
	
	return center + vertical_adjust + color_offsets.get(color, Vector2.ZERO)


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
func apply_savings_interest(color: String) -> void:
	if not player_money.has(color):
		return

	var balance: int = int(player_money[color])

	# 🚫 No interest if in debt
	if balance <= 0:
		_perm_log("%s earns no interest (in debt or broke)." % color)
		return

	# Earn $1 for every $2
	var interest: int = balance / 2
	if interest > 0:
		add_money(color, interest)
		_perm_log("%s earned $%d in interest (Savings Account)." % [color, interest])
func try_spend_money(color: String, amount: int) -> bool:
	if not player_money.has(color):
		return false
	var current_money: int = int(player_money[color])
	var max_debt: int = get_max_debt(color)
	var min_balance_allowed: int = -max_debt
	# compute projected balance
	var projected: int = current_money - int(amount)
	if projected < min_balance_allowed:
		# can't afford even with overdraft
		_perm_log("%s cannot spend $%d (would go below allowed debt %d)" % [color, amount, min_balance_allowed])
		return false
	# commit spend
	player_money[color] = projected
	refresh_money_label()
	if projected < 0:
		_perm_log("%s spent $%d -> now in debt $%d (max %d)" % [color, amount, projected, max_debt])
	else:
		_perm_log("%s spent $%d -> $%d" % [color, amount, projected])
	return true


#endregion
"""================================================DICEROLL/CARDEFFECTS/ENDTURN/GENERATE RANDOM CARDS========================================================"""

#region DICEROLL/CARDEFFECT
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
	if _check_victory_for_color(current_color):
		return
	if game_over:
		return
func apply_tramp_effect(color: String) -> void:
	# Only trigger if player has Tramp permanent
	if not has_permanent(color, "Tramp"):
		return

	var money: int = player_money.get(color, 0)
	if money > 3:
		return # too rich, no free card this turn

	# Must have space in hand
	if not player_hands.has(color):
		return
	if player_hands[color].size() >= max_hand_size:
		_perm_log("%s's Tramp wanted to generate a card but hand is full." % color)
		return

	# ✅ Fix: safely convert keys to Array[String]
	var keys: Array[String] = []
	for k in power_cards_db.keys():
		keys.append(String(k))

	if keys.is_empty():
		return

	var random_key: String = keys[randi() % keys.size()]
	var card: Dictionary = power_cards_db[random_key]

	# Add to hand
	player_hands[color].append(card)
	_perm_log("%s's Tramp generated a free power card: %s" % [color, random_key])
	refresh_hand_for_current_player()
func _generate_random_power_card() -> Dictionary:
	# return an empty dict if no cards available
	if power_cards_db.size() == 0:
		return {}

	# explicit types to avoid "cannot infer type" errors
	var keys: Array = power_cards_db.keys()
	var idx: int = int(randi() % keys.size())
	var random_key: String = String(keys[idx])
	var card: Dictionary = power_cards_db[random_key]
	return card.duplicate(true)

func _give_random_power_card_to_player(player_color: String) -> void:
	var card_data: Dictionary = _generate_random_power_card()

	print_debug("CARD DATA CHOSEN:", card_data)  # already present

	if card_data.is_empty():
		return

	var card = card_scene.instantiate()
	card.set_card_data(card_data)
	card.connect("card_clicked", Callable(self, "_on_card_clicked"))
	hand_container.add_child(card)
	hand_nodes[player_color].append(card)
	player_hands[player_color].append(card_data)

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

	# --- 6 Ball Permanent ---
	if has_permanent(current_color, "6 Ball") and dice_roll == 6:
		player_money[current_color] += 2
		_perm_log("%s gained $2 from 6 Ball (rolled 6)." % current_color)
		refresh_money_label()

	# --- Calculate Movement Steps ---
	var move_steps = dice_roll

	# Fibonacci Permanent
	if has_permanent(current_color, "Fibonacci") and dice_roll in _fib_set:
		move_steps = dice_roll * 2
		_perm_log("%s Fibonacci triggered: %d -> %d" % [current_color, dice_roll, move_steps])

	# DoMovei Permanent — +2 per card in hand per DoMovei copy
	var extra_from_domovei := 0
	var domovei_copies := count_permanent_copies(current_color, "Domovei") # Consistent naming!
	if domovei_copies > 0:
		var hand_count := 0
		if player_hands.has(current_color):
			hand_count = player_hands[current_color].size()
		extra_from_domovei = hand_count * 2 * domovei_copies
		if extra_from_domovei > 0:
			_perm_log("%s Domovei added +%d (hand %d × 2 × copies %d)" % [current_color, extra_from_domovei, hand_count, domovei_copies])
			move_steps += extra_from_domovei

	# --- Display Result ---
	if extra_from_domovei > 0:
		rollresult.text = "%s rolled a %d (+%d Domovei bonus) → %d" % [current_color, dice_roll, extra_from_domovei, move_steps]
	else:
		rollresult.text = "%s rolled a %d" % [current_color, dice_roll]

	# --- Move Player ---
	var target_tile = min(tile + move_steps, 100)
	for i in range(tile + 1, target_tile + 1):
		if tile_map.has(i):
			sprite.position = tile_map[i] + get_offset_if_needed(i, current_color)
		await get_tree().create_timer(0.3).timeout
	
	player_positions[current_color] = target_tile

	# --- Win Check ---
	if _check_victory_for_color(current_color):
		return

# --- Snakes & Ladders (NEW: use generated maps) ---
	if snake_map.has(target_tile):  # Changed: snakes → snake_map
		await get_tree().create_timer(0.5).timeout
		var dest = snake_map[target_tile]
		player_positions[current_color] = dest
		if tile_map.has(dest):
			sprite.position = tile_map[dest] + get_offset_if_needed(dest, current_color)
		_perm_log("%s hit a SNAKE %d -> %d" % [current_color, target_tile, dest])

	elif ladder_map.has(target_tile):  # Changed: ladders → ladder_map
		await get_tree().create_timer(0.5).timeout
		var dest = ladder_map[target_tile]
		player_positions[current_color] = dest
		if tile_map.has(dest):
			sprite.position = tile_map[dest] + get_offset_if_needed(dest, current_color)
		_perm_log("%s climbed a LADDER %d -> %d" % [current_color, target_tile, dest])
		print("Target tile: ", target_tile)
		print("Snake map keys: ", snake_map.keys())
		print("Ladder map keys: ", ladder_map.keys())
		print("Has snake? ", snake_map.has(target_tile))
		print("Has ladder? ", ladder_map.has(target_tile))
	check_for_money_collection(current_color)
	# --- End Turn (once!) ---
	end_turn()

# Handle generic card effects by name
func apply_card_effect_by_name(color: String, card_data: Dictionary) -> void:
	var card_name := String(card_data.get("name", ""))

	match card_name:
		"Swap":
			var targets := []
			for c in player_nodes.keys():
				if c != color:
					targets.append(c)
			if targets.size() > 0:
				targets.shuffle()
				var tgt = targets[0]

				# ---- PERMANENT LOGIC ----
				if has_permanent(tgt, "Unstoppable"):
					_perm_log("%s tried to Swap %s but target is Unstoppable." % [color, tgt])
					rollresult.text = "%s resisted the Swap (Unstoppable)!" % tgt
					return

				if has_permanent(tgt, "Mirror"):
					# Mirror vs Mirror cancels
					if has_permanent(color, "Mirror"):
						_perm_log("Both %s and %s have Mirror — Swap canceled." % [color, tgt])
						rollresult.text = "Mirror vs Mirror! Swap canceled."
						return
					# Attacker has Unstoppable blocks reflection
					if has_permanent(color, "Unstoppable"):
						_perm_log("%s's Mirror reflection blocked by %s's Unstoppable." % [tgt, color])
						rollresult.text = "Reflection blocked!"
						return
					# Otherwise reflect
					_perm_log("%s reflected Swap back to %s!" % [tgt, color])
					rollresult.text = "%s reflected the Swap!" % tgt
					# Perform swap in reverse
					var tmp = player_positions[color]
					player_positions[color] = player_positions[tgt]
					player_positions[tgt] = tmp
					update_player_positions()
					return

				# ---- NORMAL SWAP ----
				var tmp = player_positions[color]
				player_positions[color] = player_positions[tgt]
				player_positions[tgt] = tmp
				update_player_positions()
				rollresult.text = "%s swapped with %s" % [color, tgt]
				_perm_log("%s swapped with %s" % [color, tgt])

				# win checks
				if _check_victory_for_color(color):
					return
				if _check_victory_for_color(tgt):
					return

		"wintest":
			# teleport this player to tile 99 (test winner-edge)
			player_positions[color] = 99
			if player_nodes.has(color) and tile_map.has(99):
				player_nodes[color].position = tile_map[99] + get_offset_if_needed(99, color)
			_perm_log("%s used wintest -> teleported to 99" % color)
			rollresult.text = "%s teleported to 99" % color
			# check if teleport produced a win
			if _check_victory_for_color(color):
				return

		"D20 Upgrade":
			upgrade_dice(20, color)

		"Odd Space Boost":
			odd_space_move(1, color)

		"Fibonacci Synergy":
			apply_fibonacci_synergy(color)

		_:
			# generic move cards
			var mv = int(card_data.get("move_value", 0))
			if mv != 0:
				log_debug("%s played '%s' (move %d)" % [color, card_name, mv])
				apply_card_effect(mv)
func end_turn() -> void:
	if turn_order.size() > 0:
		var current_color: String = get_current_player()

		# --- SAVINGS ACCOUNT INTEREST ---
		if has_permanent(current_color, "Savings Account"):
			var money: int = player_money.get(current_color, 0)

			# 🚫 No interest if in debt or broke
			if money > 0:
				var interest: int = int(money / 2) # $1 for every $2 owned
				if interest > 0:
					player_money[current_color] += interest
					_perm_log("%s Savings Account earned $%d interest (had $%d)" % [current_color, interest, money])
					refresh_money_label()
			else:
				_perm_log("%s earns no interest (balance $%d, in debt or broke)" % [current_color, money])

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
#endregion

"""=====================================================UI/BUTTONS TOGGLES======================================================================"""
#region UI TOGGLES/BUTTONS
# UI toggles
func _on_showpowercardsbutton_pressed() -> void:
	handpanel.visible = !handpanel.visible

func _on_showshopbutton_pressed() -> void:
	shoppanel.visible = !shoppanel.visible

func _on_permanentcardstogglebutton_pressed() -> void:
	permpanel.visible = !permpanel.visible
func _on_backtomenubutton_pressed():
	var explicit_path := "res://scenes/menuscene.tscn"
	print("Back to Menu pressed -> trying to change to:", explicit_path)
	if FileAccess.file_exists(explicit_path):
		get_tree().change_scene_to_file(explicit_path)
	else:
		push_warning("Victory popup: menu scene not found at %s" % explicit_path)
func _on_shared_toggled(rows_container: Node, pressed: bool) -> void:
	# toggle visibility of per-row level selectors
	var idx := 0
	for row in rows_container.get_children():
		var level_node_name = "ai_level_%d" % idx
		var lvl_node = row.get_node_or_null(level_node_name)
		if lvl_node:
			lvl_node.visible = not pressed
		idx += 1
func show_victory_panel(message: String) -> void:
	victory_label.text = message
	victory_panel.visible = true
	victory_panel.set_process_input(true)  # block clicks behind it
	victory_panel.grab_focus()             # focus the button/label

#endregion


"""================================================PERMS EFFECT FUNCS=============================================================="""

#region PERM EFFECTS FUNCS


func upgrade_dice(sides: int, color: String) -> void:
	player_dice_sides[color] = sides
	_perm_log("%s upgraded to a D%d permanently!" % [color, sides])

func odd_space_move(amount: int, color: String) -> void:
	var pos = player_positions[color]
	if pos % 2 == 1: # odd
		player_positions[color] = min(pos + amount, 100)
		update_player_positions()
		_perm_log("%s gained +%d move on odd space." % [color, amount])

func apply_fibonacci_synergy(color: String) -> void:
	# Example: double next Fibonacci card effect
	player_effects[color]["fibonacci_boost"] = true
	_perm_log("%s gained Fibonacci Synergy (next Fibonacci card stronger)." % color)
#endregion

"""================================================DEBUG FUNCTIONS AND RELATED=============================================================="""
#region DEBUGS AND OTHER RELATED

# --- DEBUG FUNCTIONS ---
var snake_nodes_by_tile: Dictionary = {}
# debug helpers
var _debug_click_point: Vector2 = Vector2(-10000, -10000)
func _draw_tile_debug() -> void:
	var cols = max(BOARD_COLS, 1)
	var rows = max(BOARD_ROWS, 1)
	var board_rect = $Board.get_rect() if $Board else Rect2(Vector2.ZERO, Vector2(800, 800))
	
	var tile_w = board_rect.size.x / float(cols)
	var tile_h = board_rect.size.y / float(rows)
	
	# Draw grid
	for i in range(cols + 1):
		var x = i * tile_w
		draw_line(Vector2(x, 0), Vector2(x, board_rect.size.y), Color.RED, 2)
	for j in range(rows + 1):
		var y = j * tile_h
		draw_line(Vector2(0, y), Vector2(board_rect.size.x, y), Color.RED, 2)
	
	# Draw tile numbers
	if debug_font:
		for i in range(cols):
			for j in range(rows):
				var pos = Vector2(i * tile_w + tile_w/2, j * tile_h + tile_h/2)
				draw_string(debug_font, pos, str(j * cols + i + 1))

func debug_tile_sizes():
	var base_tile_size = $TileMap/Tilemaplayerresized.cell_size  # or Vector2(64,64)
	var scale = $TileMap/Tilemaplayerresized.scale
	var tile_w = base_tile_size.x * scale.x
	var tile_h = base_tile_size.y * scale.y
	print("Tile size after scaling: ", tile_w, " x ", tile_h)
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
#endregion
