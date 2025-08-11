extends Control
class_name PowerCard

var card_name: String = ""
var move_value: int = 0
var shop_cost: int = 0
var effect_description: String = ""

@onready var card_button = $CardButton
@onready var name_label = $CardButton/NameLabel
@onready var cost_label = $CardButton/CostLabel
@onready var effect_label = $CardButton/EffectLabel

signal card_played(move_value: int, card_data: Dictionary)

@export var card_width: int = 120
@export var card_height: int = 150

var is_player_turn: bool = false
var has_rolled_dice: bool = false
var original_scale: Vector2 = Vector2.ONE

func _ready() -> void:
	original_scale = scale
	_safe_setup_appearance()
	_connect_signals()
	update_card_display()

# -----------------------
# Public API
# -----------------------
func set_card_data(data: Dictionary) -> void:
	card_name = str(data.get("name", ""))
	move_value = int(data.get("move_value", 0))
	shop_cost = int(data.get("shop_cost", 0))
	effect_description = str(data.get("effect", ""))
	update_card_display()

func set_turn_state(player_turn: bool, rolled: bool) -> void:
	is_player_turn = player_turn
	has_rolled_dice = rolled
	_update_enabled_state()

func get_card_data() -> Dictionary:
	return {
		"name": card_name,
		"move_value": move_value,
		"shop_cost": shop_cost,
		"effect": effect_description
	}

# -----------------------
# Internal helpers
# -----------------------
func _connect_signals() -> void:
	if card_button:
		card_button.pressed.connect(self._on_card_pressed)
		card_button.mouse_entered.connect(self._on_card_hover_enter)
		card_button.mouse_exited.connect(self._on_card_hover_exit)

func _safe_setup_appearance() -> void:
	custom_minimum_size = Vector2(card_width, card_height)
	size = Vector2(card_width, card_height)
	if card_button:
		card_button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		card_button.position = Vector2.ZERO
		card_button.size = Vector2(card_width, card_height)
		var style_normal := StyleBoxFlat.new()
		style_normal.bg_color = Color(0.95, 0.95, 1.0, 1.0)
		style_normal.corner_radius_top_left = 8
		style_normal.corner_radius_top_right = 8
		style_normal.corner_radius_bottom_left = 8
		style_normal.corner_radius_bottom_right = 8
		style_normal.border_width_left = 2
		style_normal.border_color = Color(0.4, 0.4, 0.8, 1.0)
		card_button.add_theme_stylebox_override("normal", style_normal)

func update_card_display() -> void:
	if name_label:
		name_label.text = card_name
		if move_value > 0:
			name_label.modulate = Color(0.08, 0.5, 0.08)
		elif move_value < 0:
			name_label.modulate = Color(0.7, 0.1, 0.1)
		else:
			name_label.modulate = Color(1, 1, 1)

	if cost_label:
		if shop_cost > 0:
			cost_label.text = "$" + str(shop_cost)
			cost_label.visible = true
		else:
			cost_label.visible = false

	if effect_label:
		effect_label.text = effect_description

	if card_button:
		var tooltip := card_name + "\n"
		if shop_cost > 0:
			tooltip += "Cost: $" + str(shop_cost) + "\n"
		tooltip += "Effect: " + effect_description
		card_button.tooltip_text = tooltip

func _update_enabled_state() -> void:
	var enabled = is_player_turn and not has_rolled_dice
	if card_button:
		card_button.disabled = not enabled
		modulate = Color(1,1,1,1) if enabled else Color(0.6,0.6,0.6,1)

# -----------------------
# Input / interactions
# -----------------------
func _on_card_pressed() -> void:
	if not is_player_turn:
		print("⛔ Not your turn!")
		return
	if has_rolled_dice:
		print("⛔ Already rolled this turn.")
		return
	print("🎯 Played card:", card_name, "| Move:", move_value, "| Cost:", shop_cost)
	emit_signal("card_played", move_value, get_card_data())
	_update_enabled_state()
	play_use_animation()

func _on_card_hover_enter() -> void:
	create_tween().tween_property(self, "scale", original_scale * 1.05, 0.1)

func _on_card_hover_exit() -> void:
	create_tween().tween_property(self, "scale", original_scale, 0.1)

func play_use_animation() -> void:
	var tween = create_tween()
	tween.parallel().tween_property(self, "scale", Vector2.ZERO, 0.28)
	tween.parallel().tween_property(self, "modulate", Color(1,1,1,0), 0.28)
	await tween.finished
	queue_free()

func _gui_input(event) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if not card_button or card_button.disabled:
			if card_button and card_button.disabled:
				return
			_on_card_pressed()
