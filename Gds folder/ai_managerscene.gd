# ai_managerscene.gd - Fixed Version (GDScript 4.x compatible)
extends Control
class_name AIManager

# AI difficulty enum (kept for compatibility)
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

# RNG for low-level randomness (fallback)
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()

# Public entry: take_turn(level, board_scene, color)
func take_turn(ai_level, board_scene, color) -> void:
	# Normalize level
	var level_int: int = clamp(int(ai_level), int(AILevel.LEVEL_0), int(AILevel.LEVEL_10))
	
	# Defenses
	if board_scene == null or typeof(color) != TYPE_STRING or color == "":
		push_warning("AIManager.take_turn: invalid args — aborting.")
		return
	
	# Decision tree drives actions (cards/buys); roll last
	var action = _decide_action(level_int, board_scene, color)
	_execute_action(action, board_scene, color)
	
	# Roll/move (deferred)
	_deferred_roll(board_scene, color)

# Core: Traverse level-specific decision tree
func _decide_action(level: int, board_scene, color: String) -> Dictionary:
	var tree_root = _build_tree(level)
	return _traverse_tree(tree_root, board_scene, color)

# Build tree: Nested dict {condition: Callable, action: Dict, children: Array[Dict]}
# Higher levels add branches/conditions
func _build_tree(level: int) -> Dictionary:
	var root = {
		"condition": func(_bs, _c): return true,  # Always enter
		"action": {"type": "roll"},  # Fallback
		"children": []
	}
	
	match level:
		0:  # Pure tutorial: no actions
			pass
		1,2,3:
			root.children.append(_common_play_node(0.3 + level*0.1))
			root.children.append(_common_buy_node(0.1 * level))
		4,5:
			root.children.append(_common_play_node(0.8))
			root.children.append(_rare_play_node(0.1 + (level-3)*0.1))
			root.children.append(_common_perm_buy_node(0.2 + (level-3)*0.1))
		6,7,8:
			root.children.append(_common_play_node(1.0))
			root.children.append(_rare_play_node(0.3 + (level-5)*0.15))
			root.children.append(_field_play_node(0.1 + (level-5)*0.15))
			root.children.append(_rare_perm_buy_node(0.1 + (level-5)*0.1))
		9,10:
			root.children.append(_common_play_node(1.0))
			root.children.append(_rare_play_node(0.8 + (level-9)*0.1))
			root.children.append(_legendary_play_node(0.2 + (level-9)*0.25))
			root.children.append(_field_play_node(0.5 + (level-9)*0.05))
			root.children.append(_legendary_perm_buy_node(0.2 + (level-9)*0.15))
			if level == 10:
				root.children.append(_swap_play_node(0.5))
	
	return root

# Tree node factories (deterministic where possible; RNG for variety)
func _common_play_node(chance: float) -> Dictionary:
	return {
		"condition": func(bs, c): return _has_cards(bs, c, "common") and rng.randf() < chance,
		"action": {"type": "play", "rarity": "common"}
	}

func _rare_play_node(chance: float) -> Dictionary:
	return {
		"condition": func(bs, c): return _has_cards(bs, c, "rare") and rng.randf() < chance,
		"action": {"type": "play", "rarity": "rare"}
	}

func _legendary_play_node(chance: float) -> Dictionary:
	return {
		"condition": func(bs, c): return _has_cards(bs, c, "legendary") and rng.randf() < chance,
		"action": {"type": "play", "rarity": "legendary"}
	}

func _field_play_node(chance: float) -> Dictionary:
	return {
		"condition": func(bs, c): return _has_cards(bs, c, "field") and rng.randf() < chance,
		"action": {"type": "play", "rarity": "field"}
	}

func _swap_play_node(chance: float) -> Dictionary:
	return {
		"condition": func(bs, c): return _has_cards(bs, c, "swap") and rng.randf() < chance,
		"action": {"type": "play", "rarity": "swap"}
	}

func _common_buy_node(chance: float) -> Dictionary:
	return {
		"condition": func(bs, c): return _can_buy(bs, c, "common", false) and rng.randf() < chance,
		"action": {"type": "buy_card", "rarity": "common"}
	}

func _common_perm_buy_node(chance: float) -> Dictionary:
	return {
		"condition": func(bs, c): return _can_buy(bs, c, "common", true) and rng.randf() < chance,
		"action": {"type": "buy_permanent", "rarity": "common"}
	}

func _rare_perm_buy_node(chance: float) -> Dictionary:
	return {
		"condition": func(bs, c): return _can_buy(bs, c, "rare", true) and rng.randf() < chance,
		"action": {"type": "buy_permanent", "rarity": "rare"}
	}

func _legendary_perm_buy_node(chance: float) -> Dictionary:
	return {
		"condition": func(bs, c): return _can_buy(bs, c, "legendary", true) and rng.randf() < chance,
		"action": {"type": "buy_permanent", "rarity": "legendary"}
	}

# Traverse: Depth-first, first match wins (priority by order!)
func _traverse_tree(node: Dictionary, board_scene, color: String) -> Dictionary:
	if node.condition.call(board_scene, color):
		return node.action
	for child in node.children:
		var result = _traverse_tree(child, board_scene, color)
		if result.type != "roll":  # Non-fallback found
			return result
	return node.action  # Fallback roll

# Helpers (add these to board_scene for smarts; fallbacks assume false)
func _has_cards(bs, c: String, rarity: String) -> bool:
	if not bs.has_method("ai_get_card_count"):
		return false
	return bs.ai_get_card_count(c, rarity) > 0

func _can_buy(bs, c: String, rarity: String, permanent: bool) -> bool:
	if not bs.has_method("ai_can_afford"):
		return false
	return bs.ai_can_afford(c, rarity, permanent)

# Execute action safely
func _execute_action(action: Dictionary, board_scene, color: String) -> void:
	match action.type:
		"play":
			_safe_call_board(board_scene, "ai_play_random_card", [color, action.rarity])
		"buy_card":
			_safe_call_board(board_scene, "ai_buy_card", [color, action.rarity])
		"buy_permanent":
			_safe_call_board(board_scene, "ai_buy_permanent", [color, action.rarity])
		_:
			pass  # Roll handled after

# Deferred roll (unchanged)
func _deferred_roll(board_scene, color: String) -> void:
	if board_scene.has_method("_ai_roll_and_move"):
		board_scene.call_deferred("_ai_roll_and_move", color)
	elif board_scene.has_method("_on_dicerollbutton_pressed"):
		board_scene.call_deferred("_on_dicerollbutton_pressed")
	elif board_scene.has_method("roll_dice_for_color"):
		board_scene.call_deferred("roll_dice_for_color", color)
	else:
		push_warning("AIManager: no roll method on board_scene.")

# Safe call helper
func _safe_call_board(board_scene, method_name: String, args: Array = []) -> void:
	if board_scene == null:
		return
	if board_scene.has_method(method_name):
		board_scene.call_deferredv([method_name] + args)
	else:
		push_warning("AIManager: missing '%s' on board_scene." % method_name)
