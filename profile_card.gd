extends Button

@onready var name_label = $NameLabel
@onready var save_label = $SaveLabel

var profile_id := -1
func _ready():
	print("PROFILE CARD READY")
	print(self)
	print($NameLabel)
	print($SaveLabel)
func setup(profile):

	profile_id = profile["id"]

	name_label.text = profile["name"]
	save_label.text = "Profile %d" % profile["id"]
