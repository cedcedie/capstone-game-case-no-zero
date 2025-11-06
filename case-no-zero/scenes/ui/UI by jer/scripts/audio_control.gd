extends HSlider


@export var audio_bus_name: String 
var audio_bus_id
var _is_syncing := false

func _ready():
	audio_bus_id = AudioServer.get_bus_index(audio_bus_name)

	# Try to sync with AudioManager first to avoid overwriting saved value
	var audio_manager = get_node_or_null("/root/AudioManager")
	if audio_manager == null:
		var mgr_script: Script = preload("res://scripts/managers/AudioManager.gd")
		audio_manager = mgr_script.new()
		audio_manager.name = "AudioManager"
		get_tree().root.add_child(audio_manager)
		await get_tree().process_frame
	if audio_manager:
		if audio_bus_name == "Music" and audio_manager.has_signal("music_volume_changed"):
			_is_syncing = true
			value = audio_manager.music_volume
			_is_syncing = false
			audio_manager.music_volume_changed.connect(_on_music_volume_changed)
			return
		elif audio_bus_name == "SFX" and audio_manager.has_signal("sfx_volume_changed"):
			_is_syncing = true
			value = audio_manager.sfx_volume
			_is_syncing = false
			audio_manager.sfx_volume_changed.connect(_on_sfx_volume_changed)
			return

	# Fallback: apply current slider value at startup
	_on_value_changed(value)

func _on_value_changed(value: float) -> void:
	if _is_syncing:
		return
	# Refresh bus id if not found yet (e.g., bus created at runtime)
	if audio_bus_id == -1:
		audio_bus_id = AudioServer.get_bus_index(audio_bus_name)
	var audio_manager = get_node_or_null("/root/AudioManager")
	if audio_manager:
		if audio_bus_name == "Music" and audio_manager.has_method("set_music_volume"):
			audio_manager.set_music_volume(value)
			return
		elif audio_bus_name == "SFX" and audio_manager.has_method("set_sfx_volume"):
			audio_manager.set_sfx_volume(value)
			return
	if audio_bus_id == -1:
		return
	var db = linear_to_db(value)
	AudioServer.set_bus_volume_db(audio_bus_id, db)

func _on_music_volume_changed(new_value: float) -> void:
	_is_syncing = true
	value = new_value
	_is_syncing = false

func _on_sfx_volume_changed(new_value: float) -> void:
	_is_syncing = true
	value = new_value
	_is_syncing = false
