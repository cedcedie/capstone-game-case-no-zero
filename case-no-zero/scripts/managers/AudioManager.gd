extends Node

# AudioManager - Combined BGM and Ambient Audio Manager
# Manages both background music and ambient audio across scenes

signal bgm_changed(new_bgm: String)
signal bgm_restored()
signal ambient_changed(new_ambient: String)

# BGM Audio settings
var current_bgm: String = ""
var scene_bgm: String = ""  # The BGM that should play for the current scene
var bgm_player: AudioStreamPlayer = null

# Ambient Audio settings
var current_ambient: String = ""
var ambient_player: AudioStreamPlayer = null
var ambient_is_playing: bool = false

# Global audio tracker - tracks position across scene transitions
var global_audio_tracker: Dictionary = {
	"current_track": "",
	"playback_position": 0.0,
	"is_exterior_scene": false,
	"was_playing": false
}

# Playlist tracking
var current_track_index: int = 0
var playlist_tracker: Dictionary = {
	"current_track_index": 0,
	"playback_position": 0.0,
	"was_playing": false
}

# Playlist system - cycles through multiple ambient tracks
var ambient_playlist: Array[String] = [
	"res://assets/audio/deltaruneAud/Toby Fox - Deltarune - 37 A Town Called Hometown.ogg",  # Peaceful town start
	"res://assets/audio/music/toby fox - UNDERTALE Soundtrack - 12 Home.mp3",  # Cozy home feeling
	"res://assets/audio/deltaruneAud/Toby Fox - Deltarune - 13 Field Of Hopes and Dreams.ogg",  # Open field exploration
	"res://assets/audio/deltaruneAud/A CYBER'S WORLD？.ogg",  # Modern/electronic atmosphere
	"res://assets/audio/deltaruneAud/Toby Fox - Deltarune - 3 School.ogg",  # Urban/structured areas
	"res://assets/audio/deltaruneAud/Toby Fox - Deltarune - 9 Lancer.ogg",  # Quirky and fun
	"res://assets/audio/music/toby fox - UNDERTALE Soundtrack - 51 Another Medium.mp3",  # Mysterious atmosphere
	"res://assets/audio/16-Bit Starter Pack/Towns/Returning Home.ogg"  # Nostalgic ending
]

# Exterior scene ambient mapping - All use playlist system
var exterior_ambient_map: Dictionary = {
	"apartment_morgue": "playlist",
	"camp": "playlist", 
	"police_station": "playlist",
	"hotel_hospital": "playlist",
	"terminal_market": "playlist",
	"baranggay_court": "playlist"
}

# Additional ambient layers (optional - for layered audio)
var ambient_layers: Array[AudioStreamPlayer] = []
var max_layers: int = 3

# Scene BGM mapping
var scene_bgm_map: Dictionary = {
	"main_menu": "res://assets/audio/deltaruneAud/From Now On (Battle 2).ogg",
	"chapter_menu": "res://assets/audio/deltaruneAud/From Now On (Battle 2).ogg",  # Same as main menu for continuity
	"lower_level_station": "res://assets/audio/deltaruneAud/Toby Fox - Deltarune - 19 Scarlet Forest.ogg",
	"head_police_room": "res://assets/audio/deltaruneAud/Toby Fox - Deltarune - 19 Scarlet Forest.ogg", 
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
	
	# Create ambient player
	ambient_player = AudioStreamPlayer.new()
	ambient_player.name = "AmbientAudioPlayer"
	ambient_player.volume_db = -10  # Set to -10 dB
	add_child(ambient_player)
	
	# Connect to track finished signal for playlist progression
	ambient_player.finished.connect(_on_ambient_finished)
	
	# Start position tracking timer
	start_position_tracking()
	
	# Create additional layer players for complex ambient
	for i in range(max_layers):
		var layer_player = AudioStreamPlayer.new()
		layer_player.name = "AmbientLayer" + str(i)
		layer_player.volume_db = -25
		add_child(layer_player)
		ambient_layers.append(layer_player)
	
	print("🎵 AudioManager: Ambient players created")
	
	# Connect to scene change detection
	get_tree().node_added.connect(_on_node_added)
	
	# Auto-detect scene and set audio
	call_deferred("_on_scene_changed")
	
	# Also try to set audio immediately if scene is already loaded
	await get_tree().process_frame
	if get_tree().current_scene:
		print("🎵 AudioManager: Scene already loaded, setting audio immediately")
		_on_scene_changed()

func set_scene_bgm(scene_name: String):
	"""Set the BGM for a specific scene with smooth transitions"""
	print("🎵 AudioManager: set_scene_bgm called for:", scene_name)
	print("🎵 AudioManager: Available BGM scenes:", scene_bgm_map.keys())
	var bgm_path = scene_bgm_map.get(scene_name, "")
	print("🎵 AudioManager: BGM path found:", bgm_path)
	
	# Check if this is an exterior scene (no BGM, only ambient)
	if bgm_path == "":
		print("⚠️ AudioManager: No BGM defined for scene:", scene_name)
		# If we're transitioning to an exterior scene, stop current BGM
		if bgm_player and bgm_player.playing:
			print("🎵 AudioManager: Stopping BGM for exterior scene transition")
			await fade_out_bgm(1.0)  # Fade out BGM for exterior scenes
			stop_bgm()
		return
	
	# Check if we're switching between related station scenes
	var is_station_scene = scene_name in ["lower_level_station", "head_police_room", "security_server", "police_lobby"]
	var current_is_station = current_bgm.contains("Scarlet Forest")
	print("🎵 AudioManager: Station scene check - scene:", scene_name, "is_station:", is_station_scene, "current_is_station:", current_is_station)
	
	# Check if we're switching between barangay hall scenes
	var is_barangay_scene = scene_name in ["barangay_hall", "barangay_hall_second_floor"]
	var current_is_barangay = current_bgm.contains("Waterfall")
	
	# Check if we're switching between main menu and chapter menu (same audio)
	var is_menu_scene = scene_name in ["main_menu", "chapter_menu"]
	var current_is_menu = current_bgm.contains("From Now On")
	
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
	
	# If switching between menu scenes, don't restart the audio
	if is_menu_scene and current_is_menu and bgm_player and bgm_player.playing:
		print("🎵 AudioManager: Continuing menu BGM for", scene_name, "- no restart needed")
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
	var is_station_scene = scene_name in ["lower_level_station", "head_police_room", "security_server", "police_lobby"]
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
func _on_node_added(node: Node):
	"""Called when a node is added to the scene tree"""
	# Only respond to scene root nodes
	if node == get_tree().current_scene:
		call_deferred("_on_scene_changed")

func _on_scene_changed():
	"""Called when scene changes - set appropriate BGM and ambient"""
	await get_tree().process_frame
	if get_tree().current_scene:
		var scene_name = get_tree().current_scene.scene_file_path.get_file().get_basename()
		print("🎵 AudioManager: Auto-detecting scene:", scene_name)
		print("🎵 AudioManager: Scene file path:", get_tree().current_scene.scene_file_path)
		
		# Set BGM for the scene
		set_scene_bgm(scene_name)

		# Set ambient for exterior scenes
		set_exterior_ambient(scene_name)
	else:
		print("⚠️ AudioManager: No current scene found")

# ===========================================
# AMBIENT AUDIO FUNCTIONS
# ===========================================

func set_exterior_ambient(scene_name: String):
	"""Set ambient audio for exterior scenes and interior scenes without BGM"""
	print("🌍 AudioManager: Setting ambient for:", scene_name)
	
	# Check if this is an exterior scene OR an interior scene without BGM
	var has_bgm = scene_bgm_map.has(scene_name) and scene_bgm_map[scene_name] != ""
	var is_exterior = exterior_ambient_map.has(scene_name)
	
	if not is_exterior and has_bgm:
		print("🌍 AudioManager: Interior scene with BGM, pausing ambient")
		pause_ambient_tracked()
		global_audio_tracker["is_exterior_scene"] = false
		return
	
	# If it's an exterior scene OR interior scene without BGM, play ambient
	if is_exterior or not has_bgm:
		print("🌍 AudioManager: Playing ambient for scene (exterior or interior without BGM)")
		global_audio_tracker["is_exterior_scene"] = true
	
	# If already playing ambient, just continue - no restart
	if ambient_is_playing and ambient_player and ambient_player.playing:
		print("🌍 AudioManager: Ambient already playing, continuing seamlessly")
		return
	
	# If ambient was paused, resume from where it left off
	if global_audio_tracker["was_playing"]:
		print("🌍 AudioManager: Resuming ambient from paused position")
		resume_ambient_tracked()
	else:
		# Start fresh only if never played before
		print("🌍 AudioManager: Starting fresh ambient")
		start_fresh_ambient()

func pause_ambient_tracked():
	"""Pause ambient and save current position - only when leaving exterior scenes"""
	if ambient_player and ambient_player.playing:
		# Save current position before pausing
		global_audio_tracker["playback_position"] = ambient_player.get_playback_position()
		global_audio_tracker["was_playing"] = true
		ambient_player.stream_paused = true
		ambient_is_playing = false
		print("🌍 AudioManager: Ambient paused at position:", global_audio_tracker["playback_position"])
	elif ambient_player and not ambient_player.playing and global_audio_tracker["was_playing"]:
		# Already paused, just update the flag
		global_audio_tracker["was_playing"] = true
		ambient_is_playing = false
		print("🌍 AudioManager: Ambient already paused, position tracked")

func resume_ambient_tracked():
	"""Resume ambient from tracked position"""
	if global_audio_tracker["was_playing"]:
		# Resume from where we left off
		if not ambient_player.stream:
			# Load the ambient track from playlist if not loaded
			var ambient_path = ambient_playlist[current_track_index]
			var ambient_stream = load(ambient_path)
			if ambient_stream:
				ambient_player.stream = ambient_stream
				global_audio_tracker["current_track"] = ambient_path
				print("🌍 AudioManager: Loaded ambient track from playlist:", ambient_path)
		
		ambient_player.stream_paused = false
		# Set playback position to where we left off
		ambient_player.seek(global_audio_tracker["playback_position"])
		
		ambient_is_playing = true
		print("🌍 AudioManager: Ambient resumed seamlessly from position:", global_audio_tracker["playback_position"])
	else:
		# Start fresh if never played before
		start_fresh_ambient()

func start_fresh_ambient():
	"""Start ambient from beginning of playlist with smooth fade in"""
	var ambient_path = ambient_playlist[0]
	print("🌍 AudioManager: Starting fresh ambient playlist:", ambient_path)
	var ambient_stream = load(ambient_path)
	if ambient_stream:
		ambient_player.stream = ambient_stream
		ambient_player.volume_db = -80.0  # Start silent
		ambient_player.play()
		
		# Smooth fade in
		var fade_in_tween = create_tween()
		fade_in_tween.set_ease(Tween.EASE_IN_OUT)
		fade_in_tween.set_trans(Tween.TRANS_CUBIC)
		fade_in_tween.tween_property(ambient_player, "volume_db", -10.0, 0.8)  # 0.8-second fade in (faster!)
		
		global_audio_tracker["current_track"] = ambient_path
		global_audio_tracker["playback_position"] = 0.0
		global_audio_tracker["was_playing"] = true
		playlist_tracker["current_track_index"] = 0
		playlist_tracker["playback_position"] = 0.0
		playlist_tracker["was_playing"] = true
		current_track_index = 0
		ambient_is_playing = true
		current_ambient = ambient_path
		ambient_changed.emit(ambient_path)
		print("🌍 AudioManager: Started fresh ambient with smooth fade in:", ambient_path)
	else:
		print("⚠️ AudioManager: Failed to load ambient:", ambient_path)

func _on_ambient_finished():
	"""Called when current track finishes - advance to next track"""
	print("🌍 AudioManager: Track finished, advancing playlist")
	advance_to_next_track()

func advance_to_next_track():
	"""Move to next track in playlist with smooth transition"""
	current_track_index = (current_track_index + 1) % ambient_playlist.size()
	var next_track = ambient_playlist[current_track_index]
	print("🌍 AudioManager: Advancing to track", current_track_index + 1, ":", next_track)
	
	# Smooth crossfade transition
	await crossfade_to_next_track(next_track)

func crossfade_to_next_track(next_track: String):
	"""Smooth crossfade transition to next track"""
	var ambient_stream = load(next_track)
	if not ambient_stream:
		print("⚠️ AudioManager: Failed to load next track:", next_track)
		return
	
	# Start crossfade: fade out current, fade in new
	var original_volume = ambient_player.volume_db
	var fade_duration = 0.5  # 0.5-second crossfade (much faster!)
	
	# Create fade out tween for current track
	var fade_out_tween = create_tween()
	fade_out_tween.set_ease(Tween.EASE_IN_OUT)
	fade_out_tween.set_trans(Tween.TRANS_CUBIC)
	fade_out_tween.tween_property(ambient_player, "volume_db", -80.0, fade_duration)
	
	# Wait for fade out to complete
	await fade_out_tween.finished
	
	# Switch to new track
	ambient_player.stream = ambient_stream
	ambient_player.volume_db = -80.0  # Start silent
	ambient_player.play()
	
	# Fade in new track
	var fade_in_tween = create_tween()
	fade_in_tween.set_ease(Tween.EASE_IN_OUT)
	fade_in_tween.set_trans(Tween.TRANS_CUBIC)
	fade_in_tween.tween_property(ambient_player, "volume_db", original_volume, fade_duration)
	
	# Update tracking
	global_audio_tracker["current_track"] = next_track
	global_audio_tracker["playback_position"] = 0.0
	playlist_tracker["current_track_index"] = current_track_index
	playlist_tracker["playback_position"] = 0.0
	current_ambient = next_track
	ambient_changed.emit(next_track)
	print("🌍 AudioManager: Smoothly transitioned to:", next_track)

func stop_ambient():
	"""Stop ambient audio completely"""
	if ambient_player:
		ambient_player.stop()
		ambient_is_playing = false
		global_audio_tracker["was_playing"] = false
		global_audio_tracker["playback_position"] = 0.0
		playlist_tracker["was_playing"] = false
		playlist_tracker["playback_position"] = 0.0
		print("🌍 AudioManager: Ambient stopped completely")

func pause_ambient():
	"""Pause ambient audio (for cutscenes) - uses tracking system"""
	pause_ambient_tracked()

func resume_ambient():
	"""Resume ambient audio - uses tracking system"""
	if global_audio_tracker["is_exterior_scene"]:
		resume_ambient_tracked()
	else:
		print("🌍 AudioManager: Not in exterior scene, ambient stays paused")

func add_ambient_layer(layer_path: String, volume_db: float = -25):
	"""Add an additional ambient layer (for complex audio)"""
	for layer in ambient_layers:
		if not layer.playing:
			var layer_stream = load(layer_path)
			if layer_stream:
				layer.stream = layer_stream
				layer.volume_db = volume_db
				layer.play()
				print("🌍 AudioManager: Added ambient layer:", layer_path)
				return
	print("⚠️ AudioManager: No available ambient layer slots")

func remove_ambient_layers():
	"""Remove all ambient layers"""
	for layer in ambient_layers:
		layer.stop()
	print("🌍 AudioManager: All ambient layers removed")

func set_ambient_volume(volume_db: float):
	"""Set main ambient volume"""
	if ambient_player:
		ambient_player.volume_db = volume_db
		print("🌍 AudioManager: Ambient volume set to", volume_db, "dB")

func is_ambient_playing() -> bool:
	"""Check if ambient is currently playing"""
	return ambient_is_playing and ambient_player and ambient_player.playing

func get_current_ambient() -> String:
	"""Get current ambient file path"""
	return current_ambient

func start_position_tracking():
	"""Start continuous position tracking for ambient audio"""
	var timer = Timer.new()
	timer.wait_time = 0.1  # Update every 0.1 seconds
	timer.timeout.connect(_update_ambient_position)
	timer.autostart = true
	add_child(timer)
	print("🌍 AudioManager: Position tracking started")

func _update_ambient_position():
	"""Update ambient position continuously while playing"""
	if ambient_player and ambient_player.playing and ambient_is_playing:
		global_audio_tracker["playback_position"] = ambient_player.get_playback_position()
		playlist_tracker["playback_position"] = ambient_player.get_playback_position()

# ===========================================
# DEBUG CONTROLS
# ===========================================

func _input(event):
	if event is InputEventKey and event.pressed:
		match event.physical_keycode:
			KEY_F1:
				# F1 - Stop BGM
				stop_bgm()
			KEY_F2:
				# F2 - Restore scene BGM
				restore_scene_bgm()
			KEY_F3:
				# F3 - Test current BGM
				print("🎵 AudioManager: Current BGM:", current_bgm)
			KEY_F6:
				# F6 - Test ambient and tracking info
				print("🌍 AudioManager: Current ambient:", current_ambient)
				print("🌍 AudioManager: Is playing:", ambient_is_playing)
				print("🌍 AudioManager: Tracked position:", global_audio_tracker["playback_position"])
				print("🌍 AudioManager: Was playing:", global_audio_tracker["was_playing"])
				print("🌍 AudioManager: Is exterior scene:", global_audio_tracker["is_exterior_scene"])
				print("🌍 AudioManager: Current track index:", current_track_index + 1, "/", ambient_playlist.size())
				print("🌍 AudioManager: Playlist tracker position:", playlist_tracker["playback_position"])
			KEY_F7:
				# F7 - Stop ambient
				stop_ambient()
			KEY_F8:
				# F8 - Resume ambient
				resume_ambient()
			KEY_F9:
				# F9 - Force pause and track position
				pause_ambient_tracked()
			KEY_F10:
				# F10 - Force resume from tracked position
				resume_ambient_tracked()
