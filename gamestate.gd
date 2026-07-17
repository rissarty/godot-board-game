extends Node

enum StartupMode {
	NEW_GAME,
	LOAD_GAME
}

var startup_mode: StartupMode = StartupMode.NEW_GAME

var save_file: String = "user://debug_save.json"

func start_new_game() -> void:
	startup_mode = StartupMode.NEW_GAME

func load_game() -> void:
	startup_mode = StartupMode.LOAD_GAME

func is_loading() -> bool:
	return startup_mode == StartupMode.LOAD_GAME

func is_new_game() -> bool:
	return startup_mode == StartupMode.NEW_GAME
