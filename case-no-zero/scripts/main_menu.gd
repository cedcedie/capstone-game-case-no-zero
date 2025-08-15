extends Control

func _ready():
	AudioPlayer.play_music_level()

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/caseOption.tscn")

func _on_settings_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/settings.tscn")

func _on_exit_pressed() -> void:
	get_tree().quit()
