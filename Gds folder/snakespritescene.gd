extends Node2D

@onready var segments_root          := $Segments
@onready var head_straight_t        := $Segments/Snakeheadstraight
@onready var body_straight1_t       := $Segments/Snakebodystraight1
@onready var body_straight2_t       := $Segments/Snakebodystraight2
@onready var tail_straight_t        := $Segments/Snaketail
@onready var head_diag_t            := $Segments/snakeheaddiagonal
@onready var neck_diag_top_t        := $Segments/diagonalnecktop
@onready var neck_diag_down_t       := $Segments/diagonalneckdown
@onready var body_diag_t            := $Segments/Diagonalbody
@onready var tail_diag_t            := $Segments/Diagtail


func _ready() -> void:
	print(head_straight_t, body_straight1_t, body_straight2_t, tail_straight_t)
	head_straight_t.visible = false
	body_straight1_t.visible = false
	body_straight2_t.visible = false
	tail_straight_t.visible = false


func build_from_world_points(points: Array[Vector2]) -> void:
	for c in segments_root.get_children():
		if c != head_straight_t and c != body_straight1_t \
		and c != body_straight2_t and c != tail_straight_t:
			c.queue_free()

	if points.size() < 2:
		return

	for i in range(points.size()):
		var pos: Vector2 = points[i]
		var delta: Vector2 = Vector2.ZERO
		if i < points.size() - 1:
			delta = points[i + 1] - points[i]
		elif i > 0:
			delta = points[i] - points[i - 1]

		var piece: Sprite2D
		if i == 0:
			piece = head_straight_t.duplicate()
		elif i == points.size() - 1:
			piece = tail_straight_t.duplicate()
		elif i == 1:
			piece = body_straight1_t.duplicate()
		else:
			piece = body_straight2_t.duplicate()

		piece.global_position = pos
		piece.visible = true

		if delta != Vector2.ZERO:
			var dir := delta.normalized()
			piece.rotation = atan2(dir.y, dir.x)

		segments_root.add_child(piece)
		print("ADD PIECE", i, "AT", piece.position)
