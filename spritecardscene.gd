class_name SpriteCardScene
extends Control
signal card_clicked(card_data)
signal card_right_clicked(card_data)
signal card_hovered(card_data)

# Remove @onready for sprite/label
var card_data: Dictionary = {}
var card_mode: String = "hand"  # "hand", "permanent", "shop"
var card_name: String = ""

func _ready():
	custom_minimum_size = Vector2(120, 160)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical   = Control.SIZE_FILL
	mouse_filter = Control.MOUSE_FILTER_STOP

	connect("gui_input", _on_gui_input)
	connect("mouse_entered", _on_hover_enter)
	connect("mouse_exited", _on_hover_exit)

func set_card_data(data: Dictionary) -> void:
	card_data = data

	# Always resolve nodes fresh (avoids hot‑reload issues)
	var sprite: Sprite2D = $Sprite2D
	var label: Label     = $Label
	var sell_button: Button = $Sellbutton
	var cost_label: Label = $CostLabel

	# 1) Label text: works for power + permanent
	if label:
		label.text = String(card_data.get("name", "?"))
	# Cost text
	if cost_label:
		var cost := int(card_data.get("shop_cost", 0))
		cost_label.text = "$" + str(cost)

	# 2) Texture: use art if present, fallback otherwise
	if sprite:
		var art_path: String = card_data.get("art", "")
		var tex: Texture2D = null
		if art_path != "":
			tex = load(art_path) as Texture2D
		if tex:
			sprite.texture = tex
		else:
			# Generic fallback for cards without art (e.g. permanents)
			sprite.texture = preload("res://assets/Ladder_straight.png")
	# Ask root for sell value (so logic stays in board script)
	if sell_button:
		var value: int = 0
		var tree := get_tree()
		if tree != null:
			var root = tree.current_scene
			if root != null and root.has_method("get_sell_value"):
				value = int(root.get_sell_value(card_data))
			else:
				# fallback if method missing
				var cost := int(card_data.get("shop_cost", 0))
				value = int(round(cost * 0.75))
		else:
			# fallback if no tree yet
			var cost := int(card_data.get("shop_cost", 0))
			value = int(round(cost * 0.75))

		sell_button.text = "Sell $" + str(value)
		sell_button.visible = false

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			emit_signal("card_clicked", card_data)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if card_mode in ["hand", "permanent"]:
				var sell_button: Button = $Sellbutton
				print_debug("RC root; mode=%s name=%s" % [card_mode, card_name])
				if sell_button:
					sell_button.visible = not sell_button.visible
					print_debug(" → Sell visible: %s" % sell_button.visible)
					accept_event()

func get_sell_value(card: Dictionary) -> int:
	var cost: int = int(card.get("shop_cost", 0))
	return int(round(cost * 0.75))

func play_sell_animation() -> void:
	var tween = create_tween()
	tween.parallel().tween_property(self, "scale", Vector2.ZERO, 0.25)
	tween.parallel().tween_property(self, "modulate", Color(1, 0.3, 0.3, 0), 0.25)
	await tween.finished
	queue_free()

func _on_SellButton_pressed() -> void:
	# Extra safety: only owned cards can be sold
	if card_mode not in ["hand", "permanent"]:
		print_debug("Cannot sell card in mode:", card_mode)
		return
	var tree := get_tree()
	if tree == null:
		return
	var root = tree.current_scene
	if root and root.has_method("sell_card"):
		root.sell_card(card_data, self)

func _on_hover_enter() -> void:
	create_tween().tween_property(self, "scale", Vector2(1.05, 1.05), 0.1)
	emit_signal("card_hovered", card_data)

func _on_hover_exit() -> void:
	create_tween().tween_property(self, "scale", Vector2(1, 1), 0.1)
