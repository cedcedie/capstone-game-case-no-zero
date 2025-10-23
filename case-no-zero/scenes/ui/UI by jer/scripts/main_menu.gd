extends Control

@onready var mainbuttons: HBoxContainer = $mainbuttons
@onready var options: Panel = $Options

func _ready():
	mainbuttons.visible = true
	options.visible = false

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/UI by jer/design/chapter_menu.tscn")


func _on_option_pressed() -> void:
	mainbuttons.visible = false
	options.visible = true
	


func _on_exit_pressed() -> void:
	get_tree().quit()


func _on_back_options_pressed() -> void:
	_ready()
