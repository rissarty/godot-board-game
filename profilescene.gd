extends Control

@onready var profile_container = $CanvasLayer/ScrollContainer/HBoxContainer

var profile_card_scene = preload("res://profile_card.tscn")


@onready var add_popup = $AddProfilePopup
@onready var player_name_edit = $AddProfilePopup/VBoxContainer/PlayerNameEdit

@onready var delete_popup = $DeleteProfilePopup
@onready var profile_select = $DeleteProfilePopup/VBoxContainer/ProfileSelect



func _ready():

	ProfileManager.load_profiles()
	

	refresh_profiles()

	if ProfileManager.current_profile != -1:
		var profile = ProfileManager.get_current_profile()
		if profile:
			$CanvasLayer/CurrentProfileLabel.text = "Current: " + profile["name"]
		else:
			$CanvasLayer/CurrentProfileLabel.text = "Current: None"
	else:
		$CanvasLayer/CurrentProfileLabel.text = "Current: None"

func refresh_profiles():

	for child in profile_container.get_children():
		child.queue_free()

	for profile in ProfileManager.profiles:

		var card = profile_card_scene.instantiate()

		profile_container.add_child(card)   # <-- FIRST

		card.setup(profile)                 # <-- SECOND

		card.pressed.connect(
			func():
				ProfileManager.select_profile(profile["id"])
				$CanvasLayer/CurrentProfileLabel.text = "Current: " + profile["name"]
		)
func _on_profile_selected(profile_id:int):

	print("Selected Profile ", profile_id)
func _on_create_button_pressed():

	var name = player_name_edit.text.strip_edges()

	if name == "":
		return

	if ProfileManager.create_profile(name):

		add_popup.hide()

		refresh_profiles()

		player_name_edit.clear()
func _on_delete_button_pressed():
	if profile_select.item_count == 0:
		return

	var id = profile_select.get_selected_id()

	ProfileManager.delete_profile(id)

	delete_popup.hide()

	refresh_profiles()

	var profile = ProfileManager.get_current_profile()

	if profile:
		$CanvasLayer/CurrentProfileLabel.text = "Current: " + profile["name"]
	else:
		$CanvasLayer/CurrentProfileLabel.text = "Current: None"
func _on_addprofilebutton_pressed():

	player_name_edit.clear()

	add_popup.popup_centered()
func _on_backtomenubutton_pressed():

	get_tree().change_scene_to_file("res://scenes/menuscene.tscn")
func _on_deleteprofilebutton_pressed():
	profile_select.clear()

	for profile in ProfileManager.profiles:
		profile_select.add_item(
			"%d - %s" % [profile["id"], profile["name"]],
			profile["id"]
		)
	delete_popup.popup_centered()
func _on_cancel_button_pressed():
	delete_popup.hide()
