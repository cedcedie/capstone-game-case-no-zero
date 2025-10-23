extends Node

# AudioManager - Autoload for managing BGM across scenes and cutscenes

signal bgm_changed(new_bgm: String)
signal bgm_restored()

# Audio settings
var current_bgm: String = ""
var scene_bgm: String = ""  # The BGM that should play for the current scene
var bgm_player: AudioStreamPlayer = null

# Scene BGM mapping
var scene_bgm_map: Dictionary = {
	"lower_level_station": "res://assets/audio/deltaruneAud/Toby Fox - Deltarune - 19 Scarlet Forest.ogg",
	"head_police": "res://assets/audio/deltaruneAud/Toby Fox - Deltarune - 19 Scarlet Forest.ogg", 
	"security_server": "res://assets/audio/deltaruneAud/Toby Fox - Deltarune - 19 Scarlet Forest.ogg",
	"police_lobby": "res://assets/audio/deltaruneAud/Toby Fox - Deltarune - 19 Scarlet Forest.ogg",
	"bedroom": "res://assets/audio/deltaruneAud/You Can Always Come Home.ogg",
	"bedroomScene": "res://assets/audio/deltaruneAud/You Can Always Come Home.ogg",
	"intro_story": "res://assets/audio/music/toby fox - UNDERTALE Soundtrack - 28 Premonition.mp3",
	"barangay_hall": "res://assets/audio/music/toby fox - UNDERTALE Soundtrack - 31 Waterfall.mp3",
	"barangay_hall_second_floor": "res://assets/audio/music/toby fox - UNDERTALE Soundtrack - 31 Waterfall.mp3"
}

# Cutscene BGM mapping removed - scenes handle their own cutscene audio

func _ready():
	print("🎵 AudioManager: Ready")
	# Create BGM player
	bgm_player = AudioStreamPlayer.new()
	bgm_player.name = "BGMAudioPlayer"
	add_child(bgm_player)
	print("🎵 AudioManager: BGM player created")
	
	# Auto-detect scene and set BGM
	call_deferred("_on_scene_changed")
	
	# Also try to set BGM immediately if scene is already loaded
	await get_tree().process_frame
	if get_tree().current_scene:
		print("🎵 AudioManager: Scene already loaded, setting BGM immediately")
		_on_scene_changed()

func set_scene_bgm(scene_name: String):
	"""Set the BGM for a specific scene with smooth transitions"""
	print("🎵 AudioManager: set_scene_bgm called for:", scene_name)
	var bgm_path = scene_bgm_map.get(scene_name, "")
	print("🎵 AudioManager: BGM path found:", bgm_path)
	if bgm_path == "":
		print("⚠️ AudioManager: No BGM defined for scene:", scene_name)
		return
	
	# Check if we're switching between related station scenes
	var is_station_scene = scene_name in ["lower_level_station", "head_police", "security_server", "police_lobby"]
	var current_is_station = current_bgm.contains("Scarlet Forest")
	
	# Check if we're switching between barangay hall scenes
	var is_barangay_scene = scene_name in ["barangay_hall", "barangay_hall_second_floor"]
	var current_is_barangay = current_bgm.contains("Waterfall")
	
	# Check if we're switching from intro story to bedroom
	var is_intro_to_bedroom = current_bgm.contains("Premonition") and scene_name in ["bedroom", "bedroomScene"]
	
	# If switching between station scenes, don't restart the audio
	if is_station_scene and current_is_station and bgm_player and bgm_player.playing:
		print("🎵 AudioManager: Continuing Scarlet Forest BGM for", scene_name, "- no restart needed")
		scene_bgm = bgm_path
		return
	
	# If switching between barangay hall scenes, don't restart the audio
	if is_barangay_scene and current_is_barangay and bgm_player and bgm_player.playing:
		print("🎵 AudioManager: Continuing Waterfall BGM for", scene_name, "- no restart needed")
		scene_bgm = bgm_path
		return
	
	# If switching from intro story to bedroom, use smooth transition
	if is_intro_to_bedroom:
		print("🎵 AudioManager: Smooth transition from intro story to bedroom")
		# Brief pause for smooth transition
		await get_tree().create_timer(0.3).timeout
	
	# If switching between different scene groups, fade out current BGM first
	if bgm_player and bgm_player.playing:
		print("🎵 AudioManager: Fading out current BGM before switching to", scene_name)
		await fade_out_bgm(1.5)  # 1.5-second fade out for smoother transition
	
	scene_bgm = bgm_path
	play_bgm(bgm_path)
	print("🎵 AudioManager: Scene BGM set for", scene_name, ":", bgm_path)

# play_cutscene_bgm function removed - scenes handle their own cutscene audio

func restore_scene_bgm():
	"""Restore the scene BGM after cutscene ends"""
	if scene_bgm != "":
		play_bgm(scene_bgm)
		print("🎵 AudioManager: Scene BGM restored:", scene_bgm)
		bgm_restored.emit()
	else:
		print("⚠️ AudioManager: No scene BGM to restore")

func play_bgm(bgm_path: String):
	"""Play a BGM file with fade-in"""
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
		bgm_player.volume_db = -10  # Set to -10 dB as requested
		bgm_player.play()
		current_bgm = bgm_path
		bgm_changed.emit(bgm_path)
		print("🎵 AudioManager: Playing BGM:", bgm_path, "at -10 dB")
		print("🎵 AudioManager: BGM playing:", bgm_player.playing)
		
		# Fade in the new BGM
		await fade_in_bgm(0.3)
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

func fade_out_bgm(duration: float = 0.3):
	"""Fade out the current BGM smoothly"""
	if not bgm_player or not bgm_player.playing:
		return
	
	var original_volume = bgm_player.volume_db
	var fade_tween = create_tween()
	fade_tween.set_ease(Tween.EASE_IN_OUT)
	fade_tween.set_trans(Tween.TRANS_CUBIC)
	fade_tween.tween_property(bgm_player, "volume_db", -80.0, duration)
	await fade_tween.finished
	bgm_player.stop()
	bgm_player.volume_db = original_volume
	print("🎵 AudioManager: BGM faded out")

func fade_in_bgm(duration: float = 0.3):
	"""Fade in the current BGM smoothly"""
	if not bgm_player or not bgm_player.playing:
		return
	
	var target_volume = bgm_player.volume_db
	bgm_player.volume_db = -80.0
	var fade_tween = create_tween()
	fade_tween.set_ease(Tween.EASE_IN_OUT)
	fade_tween.set_trans(Tween.TRANS_CUBIC)
	fade_tween.tween_property(bgm_player, "volume_db", target_volume, duration)
	print("🎵 AudioManager: BGM faded in")

# Scene change detection
func _on_scene_changed():
	"""Called when scene changes - set appropriate BGM"""
	await get_tree().process_frame
	var scene_name = get_tree().current_scene.scene_file_path.get_file().get_basename()
	print("🎵 AudioManager: Auto-detecting scene:", scene_name)
	print("🎵 AudioManager: Scene file path:", get_tree().current_scene.scene_file_path)
	set_scene_bgm(scene_name)

# Debug controls
func _input(event):
	if event is InputEventKey and event.pressed:
		match event.physical_keycode:
			KEY_F3:
				# F3 - Test current BGM (cutscene BGM removed)
				print("🎵 AudioManager: Current BGM:", current_bgm)
			KEY_F2:
				# F2 - Restore scene BGM
				restore_scene_bgm()
			KEY_F1:
				# F1 - Stop BGM
				stop_bgm()
