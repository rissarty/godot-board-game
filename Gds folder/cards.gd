'''extends Control
class_name PowerCard

var card_name: String = ""
var move_value: int = 0
var shop_cost: int = 0
var effect_description: String = ""
var card_type: String = "consumable"  # <-- ADD THIS
var card_mode: String = "hand" # "hand", "permanent", "shop"
var buy_callback: Callable = Callable()
var owner_color: String = ""  # "R", "G", "B", "Y" etc
@onready var card_button: Button = $CardButton
@onready var name_label: Label = $CardButton/NameLabel
@onready var cost_label: Label = $CardButton/CostLabel
@onready var effect_label: Label = $CardButton/EffectLabel
@onready var sell_button: Button = $CardButton/Sellbutton

signal card_played(move_value: int, card_data: Dictionary)

@export var card_width: int = 120
@export var card_height: int = 150
@export var art_path: String = ""
@onready var art_texture: TextureRect = $CardButton/TextureRect

var is_player_turn: bool = false
var has_rolled_dice: bool = false
var original_scale: Vector2 = Vector2.ONE
var sell_value: int = 0    

func _ready() -> void:
	

	if art_texture:
		# only use fallback art if no custom art_path is defined yet
		if art_path == "" or art_path == null:
			art_texture.texture = load("res://assets/pixil-frame-0(1)_scaled_2x_pngcrushed.png")
	if sell_button:
		sell_button.visible = false
	original_scale = scale
	_safe_setup_appearance()
	_connect_signals()
	update_card_display()
	# 🔑 Ensure permanents also catch right-clicks on the root
	mouse_filter = Control.MOUSE_FILTER_STOP
	print_debug("🎨 art_texture node found:", art_texture)

func _connect_signals() -> void:
	if card_button:
		if not card_button.pressed.is_connected(_on_card_pressed):
			card_button.pressed.connect(_on_card_pressed)
		if not card_button.mouse_entered.is_connected(_on_card_hover_enter):
			card_button.mouse_entered.connect(_on_card_hover_enter)
		if not card_button.mouse_exited.is_connected(_on_card_hover_exit):
			card_button.mouse_exited.connect(_on_card_hover_exit)
		# Explicitly hook right-click handling
		if not card_button.gui_input.is_connected(_on_card_gui_input):
			card_button.gui_input.connect(_on_card_gui_input)

	if sell_button and not sell_button.pressed.is_connected(_on_sellbutton_pressed):
		sell_button.pressed.connect(_on_sellbutton_pressed)
func set_card_data(data: Dictionary, player_color: String = ""):
	card_name = data.get("name", "")
	move_value = data.get("move_value", 0)
	shop_cost = data.get("shop_cost", 0)
	effect_description = data.get("effect_description", "")
	card_type = data.get("card_type", "consumable")
	card_mode = data.get("card_mode", "hand")

	# NEW LINE — store ownership
	owner_color = player_color
	data["owner_color"] = player_color  # for the emitted signal too

func set_turn_state(player_turn: bool, rolled: bool) -> void:
	is_player_turn = player_turn
	has_rolled_dice = rolled
	_update_enabled_state()


func set_card_mode(mode: String, callback: Callable = Callable()) -> void:
	card_mode = mode
	buy_callback = callback
	_update_enabled_state()
	# Sell button never shows by default, only toggled on right-click
	if sell_button:
		sell_button.visible = false
func update_card_art() -> void:
	# Ensure art_texture is present
	if art_texture == null:
		push_warning("No art_texture node found on card instance.")
		return

	var tex: Texture2D = null
	# Try to load the art path if provided
	if art_path != "":
		# load can be used directly; handle failures
		tex = null
		var r = ResourceLoader.load(art_path)
		if r:
			tex = r
	# fallback to default
	if tex == null:
		tex = load("res://assets/pixil-frame-0(1)_scaled_2x_pngcrushed.png")
	# Apply texture
	art_texture.texture = tex
	art_texture.visible = true


func _safe_setup_appearance() -> void:
	custom_minimum_size = Vector2(card_width, card_height)
	size = Vector2(card_width, card_height)
	if card_button:
		card_button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		card_button.position = Vector2.ZERO
		card_button.size = Vector2(card_width, card_height)


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

	if sell_button:
		sell_button.text = "Sell +$" + str(sell_value)
func _update_enabled_state() -> void:
	# Safely get root scene
	var tree = get_tree()
	if not tree or not tree.current_scene:
		return  # Scene not ready yet

	var root = tree.current_scene
	var current_color = root.get_current_player() if root and root.has_method("get_current_player") else ""

	var enabled = (
		is_player_turn
		and not has_rolled_dice
		and card_mode != "shop"
		and owner_color == current_color
	)

	if card_button:
		card_button.disabled = not enabled
		modulate = Color(1, 1, 1, 1) if enabled else Color(0.6, 0.6, 0.6, 1)

func _on_card_pressed() -> void:
	# --- SHOP CARDS ---
	if card_mode == "shop":
		if buy_callback.is_valid():
			buy_callback.call(get_card_data())
		else:
			print("⚠️ Shop card pressed but no buy_callback set.")
		return

	# --- HAND CARDS ---
	var scene = get_tree().get_current_scene()
	if not scene.has_method("is_player_turn"):
		return

	if owner_color == "":
		if scene.has_method("get_current_player_color"):
			owner_color = scene.get_current_player_color()

	if not scene.is_player_turn(owner_color):
		print("Not your turn — card ignored.")
		return

	if has_rolled_dice:
		print("You already rolled the dice — can't play cards now.")
		return

	if card_mode != "hand":
		print("Card mode not hand — ignoring press.")
		return

	print("✅ Card pressed:", card_name, "owned by:", owner_color)
	emit_signal("card_played", move_value, get_card_data())

func get_card_data() -> Dictionary:
	return {
		"name": card_name,
		"move_value": move_value,
		"shop_cost": shop_cost,
		"effect_description": effect_description,
		"card_type": card_type,
		"owner_color": owner_color
	}

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


# -------------------------
# Right-click toggle sell
# -------------------------
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		print_debug("RC detected on root for:", card_name, " mode:", card_mode)
		if card_mode in ["hand", "permanent"] and sell_button:
			sell_button.visible = not sell_button.visible
			print_debug(" → Sell visible:", sell_button.visible)
			accept_event()


# Card button (catches clicks directly on the button)
func _on_card_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if card_mode in ["hand", "permanent"] and sell_button:
			sell_button.visible = not sell_button.visible
			print_debug("RC on (button)", card_name, "→ Sell visible:", sell_button.visible)
			accept_event()

func play_sell_animation() -> void:
	var tween = create_tween()
	tween.parallel().tween_property(self, "scale", Vector2.ZERO, 0.25)
	tween.parallel().tween_property(self, "modulate", Color(1, 0.3, 0.3, 0), 0.25)
	await tween.finished
	queue_free()

# -------------------------
# Sell logic
# -------------------------
func _on_sellbutton_pressed() -> void:
	if card_mode not in ["hand", "permanent"]:
		print_debug("Cannot sell card:", card_name, "— not owned (mode:", card_mode, ")")
		return

	var root = get_tree().current_scene
	if root and root.has_method("sell_card"):
		print_debug("Selling card via button:", card_name)
		root.sell_card(get_card_data(), self)
		play_sell_animation()
	else:
		print_debug("Sell failed — scene has no sell_card() method")'''
