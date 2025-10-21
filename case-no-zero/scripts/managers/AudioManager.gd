extends Node

# AudioManager - Autoload for managing BGM across scenes and cutscenes

signal bgm_changed(new_bgm: String)
signal bgm_restored()

# Audio settings
var current_bgm: String = ""
var scene_bgm: String = ""  # The BGM that should play for the current scene
var cutscene_bgm: String = ""  # The BGM that plays during cutscenes
var bgm_player: AudioStreamPlayer = null

# Scene BGM mapping
var scene_bgm_map: Dictionary = {
	"lower_level_station": "res://assets/audio/deltaruneAud/Toby Fox - Deltarune - 19 Scarlet Forest.ogg",
	"head_police": "res://assets/audio/deltaruneAud/Toby Fox - Deltarune - 19 Scarlet Forest.ogg", 
	"security_server": "res://assets/audio/deltaruneAud/Toby Fox - Deltarune - 19 Scarlet Forest.ogg",
	"police_lobby": "res://assets/audio/deltaruneAud/Toby Fox - Deltarune - 19 Scarlet Forest.ogg",
	"bedroom": "res://assets/audio/music/bedroom_bgm.mp3",
	"barangay_hall": "res://assets/audio/music/barangay_bgm.mp3"
}

# Cutscene BGM mapping
var cutscene_bgm_map: Dictionary = {
	"lower_level_cutscene": "res://assets/audio/music/detention_cutscene.mp3",
	"bedroom_cutscene": "res://assets/audio/music/bedroom_cutscene.mp3",
	"barangay_cutscene": "res://assets/audio/music/barangay_cutscene.mp3"
}

func _ready():
	print("🎵 AudioManager: Ready")
	# Create BGM player
	bgm_player = AudioStreamPlayer.new()
	bgm_player.name = "BGMAudioPlayer"
	add_child(bgm_player)
	print("🎵 AudioManager: BGM player created")
	
	# Auto-detect scene and set BGM
	call_deferred("_on_scene_changed")

func set_scene_bgm(scene_name: String):
	"""Set the BGM for a specific scene"""
	print("🎵 AudioManager: set_scene_bgm called for:", scene_name)
	var bgm_path = scene_bgm_map.get(scene_name, "")
	print("🎵 AudioManager: BGM path found:", bgm_path)
	if bgm_path == "":
		print("⚠️ AudioManager: No BGM defined for scene:", scene_name)
		return
	
	# Check if we're switching between related station scenes
	var is_station_scene = scene_name in ["lower_level_station", "head_police", "security_server", "police_lobby"]
	var current_is_station = current_bgm.contains("Scarlet Forest")
	
	# If switching between station scenes, don't restart the audio
	if is_station_scene and current_is_station and bgm_player and bgm_player.playing:
		print("🎵 AudioManager: Continuing Scarlet Forest BGM for", scene_name, "- no restart needed")
		scene_bgm = bgm_path
		return
	
	scene_bgm = bgm_path
	play_bgm(bgm_path)
	print("🎵 AudioManager: Scene BGM set for", scene_name, ":", bgm_path)

func play_cutscene_bgm(cutscene_name: String):
	"""Play BGM for a specific cutscene"""
	var bgm_path = cutscene_bgm_map.get(cutscene_name, "")
	if bgm_path == "":
		print("⚠️ AudioManager: No cutscene BGM defined for:", cutscene_name)
		return
	
	cutscene_bgm = bgm_path
	play_bgm(bgm_path)
	print("🎵 AudioManager: Cutscene BGM set for", cutscene_name, ":", bgm_path)

func restore_scene_bgm():
	"""Restore the scene BGM after cutscene ends"""
	if scene_bgm != "":
		play_bgm(scene_bgm)
		print("🎵 AudioManager: Scene BGM restored:", scene_bgm)
		bgm_restored.emit()
	else:
		print("⚠️ AudioManager: No scene BGM to restore")

func play_bgm(bgm_path: String):
	"""Play a BGM file"""
	print("🎵 AudioManager: play_bgm called with:", bgm_path)
	if not bgm_player:
		print("⚠️ AudioManager: BGM player not available")
		return
	
	# Load and play the BGM
	print("🎵 AudioManager: Loading BGM file:", bgm_path)
	var bgm_stream = load(bgm_path)
	if bgm_stream:
		print("🎵 AudioManager: BGM loaded successfully")
		bgm_player.stream = bgm_stream
		bgm_player.volume_db = -15  # Set to -15 dB as requested
		bgm_player.play()
		current_bgm = bgm_path
		bgm_changed.emit(bgm_path)
		print("🎵 AudioManager: Playing BGM:", bgm_path, "at -15 dB")
		print("🎵 AudioManager: BGM playing:", bgm_player.playing)
	else:
		print("⚠️ AudioManager: Failed to load BGM:", bgm_path)

func stop_bgm():
	"""Stop the current BGM"""
	if bgm_player:
		bgm_player.stop()
		print("🎵 AudioManager: BGM stopped")

func set_volume(volume_db: float):
	"""Set BGM volume"""
	if bgm_player:
		bgm_player.volume_db = volume_db
		print("🎵 AudioManager: Volume set to", volume_db, "dB")

func is_playing() -> bool:
	"""Check if BGM is currently playing"""
	return bgm_player and bgm_player.playing

func get_current_bgm() -> String:
	"""Get the current BGM file path"""
	return current_bgm

func should_continue_bgm(scene_name: String) -> bool:
	"""Check if we should continue the current BGM without restarting"""
	var is_station_scene = scene_name in ["lower_level_station", "head_police", "security_server", "police_lobby"]
	var current_is_station = current_bgm.contains("Scarlet Forest")
	
	return is_station_scene and current_is_station and bgm_player and bgm_player.playing

# Scene change detection
func _on_scene_changed():
	"""Called when scene changes - set appropriate BGM"""
	await get_tree().process_frame
	var scene_name = get_tree().current_scene.scene_file_path.get_file().get_basename()
	print("🎵 AudioManager: Auto-detecting scene:", scene_name)
	set_scene_bgm(scene_name)

# Debug controls
func _input(event):
	if event is InputEventKey and event.pressed:
		match event.physical_keycode:
			KEY_F3:
				# F3 - Test lower level cutscene BGM
				play_cutscene_bgm("lower_level_cutscene")
			KEY_F2:
				# F2 - Restore scene BGM
				restore_scene_bgm()
			KEY_F1:
				# F1 - Stop BGM
				stop_bgm()
