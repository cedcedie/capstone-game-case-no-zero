extends Control

@onready var mainbuttons: HBoxContainer = $mainbuttons
@onready var options: Panel = $Options

# Audio players for UI sounds
var confirm_player: AudioStreamPlayer = null
var close_player: AudioStreamPlayer = null

func _ready():
	mainbuttons.visible = true
	options.visible = false
	
	# Setup audio players for UI sounds
	confirm_player = AudioStreamPlayer.new()
	confirm_player.stream = load("res://assets/audio/sfx/SoupTonic UI1 SFX Pack 1 - ogg/SFX_UI_Confirm.ogg")
	confirm_player.bus = "SFX"
	add_child(confirm_player)
	
	close_player = AudioStreamPlayer.new()
	close_player.stream = load("res://assets/audio/sfx/SoupTonic UI1 SFX Pack 1 - ogg/SFX_UI_CloseMenu.ogg")
	close_player.bus = "SFX"
	add_child(close_player)

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
				# Skip past head police checkpoint and go to security server
				if CheckpointManager:
					CheckpointManager.debug_set_phase("head_police")
					print("🐛 Debug: Skipped past head police - going to security server room")
					get_tree().change_scene_to_file("res://scenes/environments/police_station/security_server.tscn")
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
				# Reserved (bedroom phase removed - no checkpoint)
				print("🐛 Debug: F10 reserved - bedroom phase removed")
			KEY_F11:
				
				print("🐛 Debug: Going to lower level station")
				get_tree().change_scene_to_file("res://scenes/environments/police_station/security_server.tscn")
				CheckpointManager.set_checkpoint(CheckpointManager.CheckpointType.ALLEY_CUTSCENE_COMPLETED)
				
			KEY_F12:
				# Debug: Reserved (no-op under fresh checkpoint system)
				print("🐛 Debug: F12 reserved - no action in fresh start")

func _on_start_pressed() -> void:
	if confirm_player:
		confirm_player.play()
	await get_tree().create_timer(0.1).timeout  # Small delay for sound
	get_tree().change_scene_to_file("res://scenes/ui/UI by jer/design/chapter_menu.tscn")


func _on_option_pressed() -> void:
	if confirm_player:
		confirm_player.play()
	mainbuttons.visible = false
	options.visible = true
	


func _on_exit_pressed() -> void:
	if close_player:
		close_player.play()
	await get_tree().create_timer(0.1).timeout  # Small delay for sound
	get_tree().quit()


func _on_back_options_pressed() -> void:
	if close_player:
		close_player.play()
	_ready()
