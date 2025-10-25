extends Control

@onready var mainbuttons: HBoxContainer = $mainbuttons
@onready var options: Panel = $Options

func _ready():
	mainbuttons.visible = true
	options.visible = false

func _input(event: InputEvent) -> void:
	# Debug controls
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_F1:
				# Show game flow status
				if CheckpointManager:
					print(CheckpointManager.get_game_flow_status())
			KEY_F2:
				# Reset to start
				if CheckpointManager:
					CheckpointManager.debug_set_phase("start")
			KEY_F3:
				# Set to bedroom completed
				if CheckpointManager:
					CheckpointManager.debug_set_phase("bedroom")
			KEY_F4:
				# Set to lower level completed
				if CheckpointManager:
					CheckpointManager.debug_set_phase("lower_level")
			KEY_F5:
				# Set to police lobby completed
				if CheckpointManager:
					CheckpointManager.debug_set_phase("police_lobby")
			KEY_F6:
				# Set to barangay hall access
				if CheckpointManager:
					CheckpointManager.debug_set_phase("barangay_hall")
			KEY_F7:
				# Set to barangay hall completed
				if CheckpointManager:
					CheckpointManager.debug_set_phase("barangay_completed")
			KEY_F8:
				# Show debug info
				if CheckpointManager:
					print(CheckpointManager.get_debug_info())
			KEY_F9:
				# Clear checkpoint file completely
				if CheckpointManager:
					CheckpointManager.debug_clear_file()
			KEY_F10:
				# Skip to bedroom completed and go to apartment_morgue
				if CheckpointManager:
					CheckpointManager.debug_skip_to_apartment_morgue()
			KEY_F11:
				# Debug: Go directly to lower level station
				print("🐛 Debug: Going to lower level station")
				get_tree().change_scene_to_file("res://scenes/environments/Police Station/lower_level_station.tscn")
			KEY_F12:
				# Debug: Set checkpoints for lower level cutscene and go there
				print("🐛 Debug: Setting checkpoints for lower level cutscene")
				if CheckpointManager:
					# Make sure LOWER_LEVEL_COMPLETED is NOT set (cutscene plays when this is false)
					CheckpointManager.clear_checkpoint(CheckpointManager.CheckpointType.LOWER_LEVEL_COMPLETED)
					# Set the required checkpoints for lower level cutscene to play
					CheckpointManager.set_checkpoint(CheckpointManager.CheckpointType.BEDROOM_COMPLETED)
					CheckpointManager.set_checkpoint(CheckpointManager.CheckpointType.BEDROOM_CUTSCENE_COMPLETED)
					print("✅ Checkpoints set for lower level cutscene")
					print("🎬 Lower level cutscene should play when you arrive (LOWER_LEVEL_COMPLETED is false)")
				get_tree().change_scene_to_file("res://scenes/environments/Police Station/lower_level_station.tscn")

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/UI by jer/design/chapter_menu.tscn")


func _on_option_pressed() -> void:
	mainbuttons.visible = false
	options.visible = true
	


func _on_exit_pressed() -> void:
	get_tree().quit()


func _on_back_options_pressed() -> void:
	_ready()
