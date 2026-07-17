extends Node

const MAX_PROFILES := 3

var current_profile := -1
var profiles:Array = []

func _ready():
	load_profiles()

func get_profiles_file()->String:
	return "user://profiles.json"

func get_save_file(id:int)->String:
	return "user://profile_%d_save.json" % id

func load_profiles():

	if !FileAccess.file_exists(get_profiles_file()):
		profiles.clear()
		save_profiles()
	else:
		var file = FileAccess.open(get_profiles_file(), FileAccess.READ)
		var json = JSON.parse_string(file.get_as_text())

		if typeof(json) != TYPE_DICTIONARY:
			profiles.clear()
			current_profile = -1
		else:
			profiles = json.get("profiles", [])
			current_profile = json.get("current_profile", -1)

			if current_profile != -1:
				for profile in profiles:
					if profile["id"] == current_profile:
						Gamestate.save_file = profile["save_file"]
						break

	# -------------------------
	# Create default profile
	# -------------------------
	if profiles.is_empty():
		create_profile("Player 1")
		select_profile(1)
		save_profiles()

func save_profiles():
	var file = FileAccess.open(get_profiles_file(), FileAccess.WRITE)

	file.store_string(JSON.stringify({
		"current_profile": current_profile,
		"profiles": profiles
	}))

func create_profile(player_name:String)->bool:
	if profiles.size() >= MAX_PROFILES:
		return false

	var id := 1
	while true:
		var used := false
		for p in profiles:
			if p["id"] == id:
				used = true
				break
		if !used:
			break
		id += 1

	var save_path := get_save_file(id)

	profiles.append({
		"id":id,
		"name":player_name,
		"save_file":save_path,
		"created":Time.get_datetime_string_from_system(),
		"last_played":Time.get_datetime_string_from_system()
	})

	save_profiles()
	select_profile(id)

	return true

func delete_profile(id:int):
	for i in range(profiles.size()):
		if profiles[i]["id"] == id:
			var save_path:String = profiles[i]["save_file"]

			if FileAccess.file_exists(save_path):
				DirAccess.remove_absolute(save_path)

			profiles.remove_at(i)

			if current_profile == id:
				current_profile = -1
				Gamestate.save_file = "user://debug_save.json"

			break

	save_profiles()

func select_profile(id:int):
	current_profile = id

	for profile in profiles:
		if profile["id"] == id:
			Gamestate.save_file = profile["save_file"]
			break

	save_profiles()
func has_save(id:int=-1)->bool:
	if id == -1:
		id = current_profile

	if id == -1:
		return false

	for p in profiles:
		if p["id"] == id:
			return FileAccess.file_exists(p["save_file"])

	return false



func get_current_save_file()->String:
	if current_profile == -1:
		return ""
	return get_current_profile().get("save_file","")
func has_selected_profile() -> bool:
	return current_profile != -1

func get_current_profile() -> Dictionary:
	for profile in profiles:
		if profile["id"] == current_profile:
			return profile
	return {}

func current_save_exists() -> bool:
	if !has_selected_profile():
		return false

	if !FileAccess.file_exists(Gamestate.save_file):
		return false

	var file = FileAccess.open(Gamestate.save_file, FileAccess.READ)
	if file == null:
		return false

	var text = file.get_as_text().strip_edges()
	file.close()

	return text != "" and text != "{}"
