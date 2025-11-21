extends Control

const DEBUG_CHECKPOINTS := [
	{"label": "Intro Completed", "type": CheckpointManager.CheckpointType.INTRO_COMPLETED},
	{"label": "Office Cutscene Completed", "type": CheckpointManager.CheckpointType.OFFICE_CUTSCENE_COMPLETED},
	{"label": "Lower Level Cutscene Completed", "type": CheckpointManager.CheckpointType.LOWER_LEVEL_CUTSCENE_COMPLETED},
	{"label": "Recollection Completed", "type": CheckpointManager.CheckpointType.RECOLLECTION_COMPLETED},
	{"label": "Head Police Completed", "type": CheckpointManager.CheckpointType.HEAD_POLICE_COMPLETED},
	{"label": "Follow Darwin Completed", "type": CheckpointManager.CheckpointType.FOLLOW_DARWIN_COMPLETED},
	{"label": "Security Server Completed", "type": CheckpointManager.CheckpointType.SECURITY_SERVER_COMPLETED},
	{"label": "Alley Cutscene Completed", "type": CheckpointManager.CheckpointType.ALLEY_CUTSCENE_COMPLETED},
	{"label": "Security Server Cutscene 2", "type": CheckpointManager.CheckpointType.SECURITY_SERVER_CUTSCENE_2_COMPLETED},
	{"label": "Celine Call Completed", "type": CheckpointManager.CheckpointType.CELINE_CALL_COMPLETED},
	{"label": "Barangay Hall Cutscene Completed", "type": CheckpointManager.CheckpointType.BARANGAY_HALL_CUTSCENE_COMPLETED},
	{"label": "Morgue Cutscene Completed", "type": CheckpointManager.CheckpointType.MORGUE_CUTSCENE_COMPLETED},
	{"label": "Cinematic Text Cutscene Completed", "type": CheckpointManager.CheckpointType.CINEMATIC_TEXT_CUTSCENE_COMPLETED}
]

const BARANGAY_COURT_SCENE := "res://scenes/environments/exterior/baranggay_court.tscn"
const MORGUE_SCENE := "res://scenes/environments/morgue/morgue.tscn"

@onready var mainbuttons: HBoxContainer = $mainbuttons
@onready var options: Panel = $Options
@onready var debugger_panel: Panel = $DebuggerPanel
@onready var checkpoint_list: VBoxContainer = $DebuggerPanel/VBoxContainer/ScrollContainer/CheckpointList

# Audio players for UI sounds
var confirm_player: AudioStreamPlayer = null
var close_player: AudioStreamPlayer = null

var checkpoint_toggle_map: Dictionary = {}

func _ready():
	mainbuttons.visible = true
	options.visible = false
	debugger_panel.visible = false
	
	# Setup audio players for UI sounds
	confirm_player = AudioStreamPlayer.new()
	confirm_player.stream = load("res://assets/audio/sfx/SoupTonic UI1 SFX Pack 1 - ogg/SFX_UI_Confirm.ogg")
	confirm_player.bus = "SFX"
	add_child(confirm_player)
	
	close_player = AudioStreamPlayer.new()
	close_player.stream = load("res://assets/audio/sfx/SoupTonic UI1 SFX Pack 1 - ogg/SFX_UI_CloseMenu.ogg")
	close_player.bus = "SFX"
	add_child(close_player)
	
	_initialize_debugger_ui()

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

func _initialize_debugger_ui() -> void:
	if checkpoint_list == null:
		return
	for child in checkpoint_list.get_children():
		child.queue_free()
	checkpoint_toggle_map.clear()
	
	for entry in DEBUG_CHECKPOINTS:
		var toggle := CheckButton.new()
		toggle.text = entry.label
		toggle.button_pressed = CheckpointManager != null and CheckpointManager.has_checkpoint(entry.type)
		checkpoint_list.add_child(toggle)
		checkpoint_toggle_map[entry.type] = toggle

func _sync_debugger_toggles() -> void:
	if CheckpointManager == null:
		return
	for checkpoint_type in checkpoint_toggle_map.keys():
		var toggle: CheckButton = checkpoint_toggle_map[checkpoint_type]
		if toggle:
			toggle.button_pressed = CheckpointManager.has_checkpoint(checkpoint_type)

func _apply_selected_checkpoints() -> void:
	if CheckpointManager == null:
		return
	CheckpointManager.clear_all_checkpoints()
	for checkpoint_type in checkpoint_toggle_map.keys():
		var toggle: CheckButton = checkpoint_toggle_map[checkpoint_type]
		if toggle and toggle.button_pressed:
			CheckpointManager.set_checkpoint(checkpoint_type)
	print("🐛 Debug: checkpoints applied -> ", CheckpointManager.get_debug_info())

func _on_debugger_toggle_pressed() -> void:
	debugger_panel.visible = not debugger_panel.visible
	if debugger_panel.visible:
		_sync_debugger_toggles()

func _on_debug_close_pressed() -> void:
	debugger_panel.visible = false

func _on_debug_apply_pressed() -> void:
	_apply_selected_checkpoints()
	_sync_debugger_toggles()

func _on_debug_jump_barangay_pressed() -> void:
	_apply_selected_checkpoints()
	if CheckpointManager:
		# Only enforce the absolute minimum needed to enter barangay hall.
		# Respect whatever the user toggled for the cutscene completion flag.
		if not CheckpointManager.has_checkpoint(CheckpointManager.CheckpointType.CELINE_CALL_COMPLETED):
			CheckpointManager.set_checkpoint(CheckpointManager.CheckpointType.CELINE_CALL_COMPLETED)
			print("🐛 Debug: Auto-set CELINE_CALL_COMPLETED to allow barangay access.")
		print("🐛 Debug: Jumping to barangay court with checkpoints -> ", CheckpointManager.get_debug_info())
	if SpawnManager:
		SpawnManager.set_entry_point("debug_main_menu", "default")
	debugger_panel.visible = false
	get_tree().change_scene_to_file(BARANGAY_COURT_SCENE)

func _on_debug_jump_morgue_pressed() -> void:
	_apply_selected_checkpoints()
	if CheckpointManager:
		var required := [
			CheckpointManager.CheckpointType.CELINE_CALL_COMPLETED,
			CheckpointManager.CheckpointType.BARANGAY_HALL_CUTSCENE_COMPLETED
		]
		for checkpoint in required:
			if not CheckpointManager.has_checkpoint(checkpoint):
				CheckpointManager.set_checkpoint(checkpoint)
		print("🐛 Debug: Jumping to morgue with checkpoints -> ", CheckpointManager.get_debug_info())
	if SpawnManager:
		SpawnManager.set_entry_point("debug_main_menu", "default")
	debugger_panel.visible = false
	get_tree().change_scene_to_file(MORGUE_SCENE)
