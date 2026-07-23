class_name SpriteCardScene
extends Control

signal card_clicked(card_data)
signal card_sell_clicked(card_data)
signal card_hovered(card_data)
signal card_selected(card)
signal card_dragged(card, position)
signal card_drag_finished(card, drop_position)
var mouse_dragging := false
var card_data: Dictionary = {}
var card_mode: String = "hand"  # "hand", "permanent", "shop"
var card_name: String = ""
var mobile_selected := false
var mobile_drag_started := false
var mobile_touch_start_position := Vector2.ZERO
const TOUCH_DRAG_THRESHOLD := 12.0
var last_screen_touch_event_ms := -1000

func _ready():
	custom_minimum_size = Vector2(120, 160)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_FILL
	mouse_filter = Control.MOUSE_FILTER_STOP

	connect("gui_input", _on_gui_input)
	connect("mouse_entered", _on_hover_enter)
	connect("mouse_exited", _on_hover_exit)

func set_card_data(data: Dictionary) -> void:
	card_data = data

	var sprite: Sprite2D = $Sprite2D
	var label: Label = $Label
	var sell_button: Button = $Sellbutton
	var cost_label: Label = $CostLabel

	if label:
		label.text = String(card_data.get("name", "?"))

	if cost_label:
		var cost := int(card_data.get("shop_cost", 0))
		cost_label.text = "$" + str(cost)

	if sprite:
		var art_path: String = card_data.get("art", "")
		var tex: Texture2D = null

		if art_path != "":
			tex = load(art_path) as Texture2D

		if tex:
			sprite.texture = tex
		else:
			sprite.texture = preload("res://assets/Ladder_straight.png")

		var dim_input: String = card_data.get("dims", "120x160")
		var tex_size: Vector2 = sprite.texture.get_size() if sprite.texture else Vector2(120, 160)
		var scale_factor: float = 1.0

		if dim_input.contains("x"):
			var parts = dim_input.split("x")
			var target_w: float = float(parts[0])
			var target_h: float = float(parts[1])
			scale_factor = min(target_w / tex_size.x, target_h / tex_size.y)
		else:
			scale_factor = float(dim_input)

		sprite.scale = Vector2(scale_factor, scale_factor)
		custom_minimum_size = tex_size * sprite.scale

	if sell_button:
		var value: int = 0
		var tree := get_tree()

		if tree != null:
			var root = tree.current_scene

			if root != null and root.has_method("get_sell_value"):
				value = int(root.get_sell_value(card_data))
			else:
				var cost := int(card_data.get("shop_cost", 0))
				value = int(round(cost * 0.75))
		else:
			var cost := int(card_data.get("shop_cost", 0))
			value = int(round(cost * 0.75))

		sell_button.text = "Sell $" + str(value)
		sell_button.visible = false

func _on_gui_input(event: InputEvent) -> void:

	# =========================================================
	# MOBILE TOUCH
	# =========================================================
	if event is InputEventScreenTouch:
		last_screen_touch_event_ms = Time.get_ticks_msec()

		if card_mode not in ["hand", "permanent"]:
			return

		if event.pressed:

			mobile_selected = true
			mobile_drag_started = false
			mobile_touch_start_position = event.position

			emit_signal("card_selected", self)

		else:

			if mobile_selected:

				mobile_selected = false
				mobile_drag_started = false

				emit_signal(
					"card_drag_finished",
					self,
					event.position
				)

		accept_event()
		return


	# =========================================================
	# MOBILE DRAG
	# =========================================================
	if event is InputEventScreenDrag:
		last_screen_touch_event_ms = Time.get_ticks_msec()

		if card_mode in ["hand", "permanent"] and mobile_selected:
			if not mobile_drag_started:
				mobile_drag_started = event.position.distance_to(mobile_touch_start_position) >= TOUCH_DRAG_THRESHOLD
			if not mobile_drag_started:
				accept_event()
				return

			emit_signal(
				"card_dragged",
				self,
				event.position
			)

			accept_event()

		return

	# =========================================================
	# PC MOUSE BUTTON
	# =========================================================
	if event is InputEventMouseButton:
		# Ignore the synthetic mouse event that follows a real screen-touch event.
		# Some mobile web views only send mouse events; those continue through the
		# drag path below rather than falling into desktop click mode.
		if card_mode in ["hand", "permanent"] and Time.get_ticks_msec() - last_screen_touch_event_ms < 750:
			accept_event()
			return

		# -------------------------
		# LEFT CLICK
		# -------------------------
		if event.button_index == MOUSE_BUTTON_LEFT:

			if card_mode in ["hand", "permanent"]:
				if not _uses_drag_for_mouse_input():
					if event.pressed and card_mode == "hand":
						emit_signal("card_clicked", card_data)
					accept_event()
					return

				if event.pressed:

					mouse_dragging = true

					emit_signal(
						"card_selected",
						self
					)

				else:

					if mouse_dragging:

						mouse_dragging = false

						emit_signal(
						"card_drag_finished",
						self,
						get_global_mouse_position()
					)

				accept_event()

			else:

				# Shop cards retain normal click behavior
				if event.pressed:

					emit_signal(
						"card_clicked",
						card_data
					)

			return


		# -------------------------
		# RIGHT CLICK = TOGGLE THE SELL BUTTON (click mode only)
		# -------------------------
		if (
			event.button_index == MOUSE_BUTTON_RIGHT
			and event.pressed
		):

			if card_mode in ["hand", "permanent"] and not _uses_drag_for_mouse_input():
				var sell_button: Button = $Sellbutton
				if sell_button:
					sell_button.visible = not sell_button.visible
				accept_event()

			return


	# =========================================================
	# PC MOUSE MOVEMENT
	# =========================================================
	if event is InputEventMouseMotion:

		if mouse_dragging and card_mode in ["hand", "permanent"]:

			emit_signal(
				"card_dragged",
				self,
				get_global_mouse_position()
			)

			accept_event()

		return

func _uses_desktop_drag_mode() -> bool:
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return false
	var root := tree.current_scene
	return root.has_method("is_desktop_drag_mode") and root.is_desktop_drag_mode()

func _uses_drag_for_mouse_input() -> bool:
	return _uses_desktop_drag_mode() or _is_mobile_platform()

func _is_mobile_platform() -> bool:
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return false
	var root := tree.current_scene
	return root.has_method("_is_mobile_platform") and root._is_mobile_platform()
func get_sell_value(card: Dictionary) -> int:
	var cost: int = int(card.get("shop_cost", 0))
	return int(round(cost * 0.75))

func play_sell_animation() -> void:
	var tween = create_tween()

	tween.parallel().tween_property(
		self,
		"scale",
		Vector2.ZERO,
		0.25
	)

	tween.parallel().tween_property(
		self,
		"modulate",
		Color(1, 0.3, 0.3, 0),
		0.25
	)

	await tween.finished
	queue_free()

func _on_SellButton_pressed() -> void:
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
	create_tween().tween_property(
		self,
		"scale",
		Vector2(1.05, 1.05),
		0.1
	)

	emit_signal("card_hovered", card_data)

func _on_hover_exit() -> void:
	create_tween().tween_property(
		self,
		"scale",
		Vector2(1, 1),
		0.1
	)
