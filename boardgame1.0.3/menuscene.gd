extends Control #menuscene

@onready var Menupanel = $Panel
@onready var playbutton = $Playbutton
@onready var panel2 = $Panel2
@onready var Aibutton = $Panel2/VBoxContainer/vsAIbutton
@onready var passbutton = $Panel2/VBoxContainer/Passandplaybutton
@onready var gamescene = preload("res://boardgameplayscene.tscn").instantiate()
# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


func _on_playbutton_pressed():
	panel2.visible = !panel2.visible


func _on_vs_a_ibutton_pressed():
	var game_scene = preload("res://boardgameplayscene.tscn").instantiate()
	game_scene.is_singleplayer = true
	get_tree().root.add_child(game_scene)
	get_tree().current_scene.queue_free()
	get_tree().current_scene = game_scene
