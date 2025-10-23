extends Control


func _on_back_to_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/UI by jer/design/main_menu.tscn")


func _on_chapter_1_pressed() -> void:
	get_tree().change_scene_to_file("res://intro_story.tscn")
