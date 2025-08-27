# ai_managerscene.gd
extends Control
class_name AIManager

# AI difficulty enum
enum AILevel {
	LEVEL_0,
	LEVEL_1,
	LEVEL_2,
	LEVEL_3,
	LEVEL_4,
	LEVEL_5,
	LEVEL_6,
	LEVEL_7,
	LEVEL_8,
	LEVEL_9,
	LEVEL_10
}

# RNG instance for repeatable, safe randomness
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()

# Public entry:
# take_turn(level, board_scene, color)
# - level: either AILevel enum or int (0..10)
# - board_scene: the Scene (your boardgamescene) that exposes helper methods
# - color: the player's color string (e.g. "R")
func take_turn(ai_level, board_scene, color) -> void:
	# Defensive: normalize level to a valid integer 0..10
	var level_int: int = int(ai_level) if typeof(ai_level) in [TYPE_INT] else int(ai_level)
	level_int = clamp(level_int, int(AILevel.LEVEL_0), int(AILevel.LEVEL_10))

	# Defensive: board_scene and color checks
	if board_scene == null:
		push_warning("AIManager.take_turn: board_scene is null — aborting AI action.")
		return
	if typeof(color) != TYPE_STRING or color == "":
		push_warning("AIManager.take_turn: invalid color passed — aborting AI action.")
		return

	# Always ensure we try to roll / move the pawn (baseline action)
	# Prefer board_scene._ai_roll_and_move(color) if available, otherwise try board_scene._on_dicerollbutton_pressed()
	# But do the other decisions before rolling if you want AI to play cards before movement.
	# We'll follow the flow: *use cards / buy* THEN roll.

	# Decision stage based on level
	match level_int:
		int(AILevel.LEVEL_0):
			# baseline: do nothing extra
			pass

		int(AILevel.LEVEL_1):
			_check_use_common_card(board_scene, color, 0.5)
			_check_buy_common_card(board_scene, color, 0.4)

		int(AILevel.LEVEL_2):
			_check_use_common_card(board_scene, color, 0.9)
			_check_use_rare_card(board_scene, color, 0.1)
			_check_buy_permanent_common(board_scene, color, 0.2)

		int(AILevel.LEVEL_3):
			_check_use_common_card(board_scene, color, 0.9)
			_check_use_rare_card(board_scene, color, 0.2)
			_check_buy_permanent_common(board_scene, color, 0.3)

		int(AILevel.LEVEL_4):
			_check_use_common_card(board_scene, color, 0.95)
			_check_use_rare_card(board_scene, color, 0.25)
			_check_buy_permanent_common(board_scene, color, 0.35)

		int(AILevel.LEVEL_5):
			_check_use_common_card(board_scene, color, 0.95)
			_check_use_rare_card(board_scene, color, 0.3)
			_check_use_field_condition(board_scene, color, 0.2)
			_check_buy_permanent_rare(board_scene, color, 0.2)

		int(AILevel.LEVEL_6):
			_check_use_common_card(board_scene, color, 1.0)
			_check_use_rare_card(board_scene, color, 0.45)
			_check_use_field_condition(board_scene, color, 0.25)
			_check_buy_permanent_rare(board_scene, color, 0.3)

		int(AILevel.LEVEL_7):
			_check_use_common_card(board_scene, color, 1.0)
			_check_use_rare_card(board_scene, color, 0.6)
			_check_use_field_condition(board_scene, color, 0.4)
			_check_buy_permanent_rare(board_scene, color, 0.4)

		int(AILevel.LEVEL_8):
			_check_use_common_card(board_scene, color, 1.0)
			_check_use_rare_card(board_scene, color, 0.75)
			_check_use_field_condition(board_scene, color, 0.5)
			_check_buy_permanent_rare(board_scene, color, 0.45)

		int(AILevel.LEVEL_9):
			_check_use_common_card(board_scene, color, 1.0)
			_check_use_rare_card(board_scene, color, 0.85)
			_check_use_legendary_card(board_scene, color, 0.25)
			_check_use_field_condition(board_scene, color, 0.55)
			_check_buy_permanent_legendary(board_scene, color, 0.4)

		int(AILevel.LEVEL_10):
			_check_use_common_card(board_scene, color, 1.0)
			_check_use_rare_card(board_scene, color, 0.9)
			_check_use_legendary_card(board_scene, color, 0.7)
			_check_use_field_condition(board_scene, color, 0.6)
			_check_buy_permanent_legendary(board_scene, color, 0.5)
			_check_use_swap_card(board_scene, color, 0.5)

	# After decisions, roll/move:
	# Prefer deferred call so the board's turn state finishes updating first
	if board_scene.has_method("_ai_roll_and_move"):
		board_scene.call_deferred("_ai_roll_and_move", color)
	elif board_scene.has_method("_on_dicerollbutton_pressed"):
		# fallback to the exposed button handler if present
		board_scene.call_deferred("_on_dicerollbutton_pressed")
	else:
		# Last fallback: if board_scene exposes a generic roll method for a pawn, try it
		if board_scene.has_method("roll_dice_for_color"):
			board_scene.call_deferred("roll_dice_for_color", color)
		else:
			push_warning("AIManager.take_turn: no recognized roll/move method found on board_scene (expected _ai_roll_and_move or _on_dicerollbutton_pressed).")

# -------------------------
# Helper: safe randomness check
# -------------------------
func _rand_check(chance: float) -> bool:
	# clamp chance 0..1, use RNG
	var c = clamp(chance, 0.0, 1.0)
	return rng.randf() < c

# -------------------------
# Generic "safe call" helper (prefer board_scene helpers)
# -------------------------
func _safe_call_board(board_scene, method_name: String, args: Array = []) -> void:
	if board_scene == null:
		return
	if board_scene.has_method(method_name):
		board_scene.call_deferredv([method_name] + args)
	else:
		# method not present — log for debugging but do not crash
		push_warning("AIManager: board_scene lacks method '%s'." % method_name)

# -------------------------
# Decision helper wrappers (they call board_scene helpers if present)
# -------------------------
func _check_use_common_card(board_scene, color: String, chance: float) -> void:
	if _rand_check(chance):
		# prefer board_scene.ai_play_random_card
		if board_scene.has_method("ai_play_random_card"):
			board_scene.call_deferred("ai_play_random_card", color, "common")
		elif board_scene.has_method("play_random_card_for_color"):
			board_scene.call_deferred("play_random_card_for_color", color, "common")
		else:
			push_warning("AIManager: can't play common card; method missing on board_scene.")

func _check_use_rare_card(board_scene, color: String, chance: float) -> void:
	if _rand_check(chance):
		print("[AIManager] %s decided to play a rare card" % color)
		if board_scene.has_method("ai_play_random_card"):
			board_scene.call_deferred("ai_play_random_card", color, "rare")
		else:
			push_warning("AIManager: can't play rare card; method missing on board_scene.")

func _check_use_legendary_card(board_scene, color: String, chance: float) -> void:
	if _rand_check(chance):
		if board_scene.has_method("ai_play_random_card"):
			board_scene.call_deferred("ai_play_random_card", color, "legendary")
		else:
			push_warning("AIManager: can't play legendary card; method missing on board_scene.")

func _check_use_field_condition(board_scene, color: String, chance: float) -> void:
	if _rand_check(chance):
		if board_scene.has_method("ai_play_random_card"):
			board_scene.call_deferred("ai_play_random_card", color, "field")
		else:
			push_warning("AIManager: can't play field-condition card; method missing on board_scene.")

func _check_use_swap_card(board_scene, color: String, chance: float) -> void:
	if _rand_check(chance):
		if board_scene.has_method("ai_play_random_card"):
			board_scene.call_deferred("ai_play_random_card", color, "swap")
		else:
			push_warning("AIManager: can't play swap card; method missing on board_scene.")

# Buying checks
func _check_buy_common_card(board_scene, color: String, chance: float) -> void:
	if _rand_check(chance):
		if board_scene.has_method("ai_buy_card"):
			board_scene.call_deferred("ai_buy_card", color, "common")
		else:
			push_warning("AIManager: can't buy common card; method missing on board_scene.")

func _check_buy_permanent_common(board_scene, color: String, chance: float) -> void:
	if _rand_check(chance):
		if board_scene.has_method("ai_buy_permanent"):
			board_scene.call_deferred("ai_buy_permanent", color, "common")
		else:
			push_warning("AIManager: can't buy common permanent; method missing on board_scene.")

func _check_buy_permanent_rare(board_scene, color: String, chance: float) -> void:
	if _rand_check(chance):
		if board_scene.has_method("ai_buy_permanent"):
			board_scene.call_deferred("ai_buy_permanent", color, "rare")
		else:
			push_warning("AIManager: can't buy rare permanent; method missing on board_scene.")

func _check_buy_permanent_legendary(board_scene, color: String, chance: float) -> void:
	if _rand_check(chance):
		if board_scene.has_method("ai_buy_permanent"):
			board_scene.call_deferred("ai_buy_permanent", color, "legendary")
		else:
			push_warning("AIManager: can't buy legendary permanent; method missing on board_scene.")
