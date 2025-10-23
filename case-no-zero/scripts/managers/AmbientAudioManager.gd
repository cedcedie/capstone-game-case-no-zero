extends Node

# AmbientAudioManager - Global ambient audio for exterior scenes
# Plays continuously across all exterior scenes without restarting

signal ambient_changed(new_ambient: String)

# Ambient audio settings
var current_ambient: String = ""
var ambient_player: AudioStreamPlayer = null
var is_playing: bool = false

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
	"res://assets/audio/deltaruneAud/Toby Fox - Deltarune - 37 A Town Called Hometown.ogg",
	"res://assets/audio/music/toby fox - UNDERTALE Soundtrack - 12 Home.mp3",
	"res://assets/audio/deltaruneAud/Toby Fox - Deltarune - 13 Field Of Hopes and Dreams.ogg",
	"res://assets/audio/deltaruneAud/Toby Fox - Deltarune - 3 School.ogg",
	"res://assets/audio/music/toby fox - UNDERTALE Soundtrack - 51 Another Medium.mp3",
	"res://assets/audio/16-Bit Starter Pack/Towns/Returning Home.ogg"
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

func _ready():
	print("🌍 AmbientAudioManager: Ready")
	# Create main ambient player
	ambient_player = AudioStreamPlayer.new()
	ambient_player.name = "AmbientAudioPlayer"
	ambient_player.volume_db = -10  # Set to -10 dB
	add_child(ambient_player)
	
	# Connect to track finished signal for playlist progression
	ambient_player.finished.connect(_on_ambient_finished)
	
	# Connect to scene change signal
	get_tree().current_scene_changed.connect(_on_scene_changed)
	
	# Create additional layer players for complex ambient
	for i in range(max_layers):
		var layer_player = AudioStreamPlayer.new()
		layer_player.name = "AmbientLayer" + str(i)
		layer_player.volume_db = -25
		add_child(layer_player)
		ambient_layers.append(layer_player)
	
	print("🌍 AmbientAudioManager: Ambient players created")
	
	# Auto-detect scene and set ambient
	call_deferred("_on_scene_changed")

func set_exterior_ambient(scene_name: String):
	"""Set ambient audio for exterior scenes - continues from tracked position"""
	print("🌍 AmbientAudioManager: Setting ambient for:", scene_name)
	
	# Check if this is an exterior scene
	if not exterior_ambient_map.has(scene_name):
		print("🌍 AmbientAudioManager: Not an exterior scene, pausing ambient")
		pause_ambient_tracked()
		global_audio_tracker["is_exterior_scene"] = false
		return
	
	# Mark as exterior scene
	global_audio_tracker["is_exterior_scene"] = true
	
	# Resume from tracked position
	resume_ambient_tracked()

func pause_ambient_tracked():
	"""Pause ambient and save current position"""
	if ambient_player and ambient_player.playing:
		global_audio_tracker["playback_position"] = ambient_player.get_playback_position()
		global_audio_tracker["was_playing"] = true
		ambient_player.stream_paused = true
		print("🌍 AmbientAudioManager: Ambient paused at position:", global_audio_tracker["playback_position"])
	elif ambient_player and not ambient_player.playing and global_audio_tracker["was_playing"]:
		# Already paused, just update the flag
		global_audio_tracker["was_playing"] = true
		print("🌍 AmbientAudioManager: Ambient already paused, position tracked")

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
				print("🌍 AmbientAudioManager: Loaded ambient track from playlist:", ambient_path)
		
		ambient_player.stream_paused = false
		# Set playback position to where we left off
		ambient_player.seek(global_audio_tracker["playback_position"])
		is_playing = true
		print("🌍 AmbientAudioManager: Ambient resumed from position:", global_audio_tracker["playback_position"])
	else:
		# Start fresh if never played before
		start_fresh_ambient()

func start_fresh_ambient():
	"""Start ambient from beginning of playlist"""
	var ambient_path = ambient_playlist[0]
	print("🌍 AmbientAudioManager: Starting fresh ambient playlist:", ambient_path)
	var ambient_stream = load(ambient_path)
	if ambient_stream:
		ambient_player.stream = ambient_stream
		ambient_player.play()
		global_audio_tracker["current_track"] = ambient_path
		global_audio_tracker["playback_position"] = 0.0
		global_audio_tracker["was_playing"] = true
		playlist_tracker["current_track_index"] = 0
		playlist_tracker["playback_position"] = 0.0
		playlist_tracker["was_playing"] = true
		current_track_index = 0
		is_playing = true
		current_ambient = ambient_path
		ambient_changed.emit(ambient_path)
		print("🌍 AmbientAudioManager: Started fresh ambient:", ambient_path)
	else:
		print("⚠️ AmbientAudioManager: Failed to load ambient:", ambient_path)

func _on_ambient_finished():
	"""Called when current track finishes - advance to next track"""
	print("🌍 AmbientAudioManager: Track finished, advancing playlist")
	advance_to_next_track()

func advance_to_next_track():
	"""Move to next track in playlist"""
	current_track_index = (current_track_index + 1) % ambient_playlist.size()
	var next_track = ambient_playlist[current_track_index]
	print("🌍 AmbientAudioManager: Advancing to track", current_track_index + 1, ":", next_track)
	
	var ambient_stream = load(next_track)
	if ambient_stream:
		ambient_player.stream = ambient_stream
		ambient_player.play()
		global_audio_tracker["current_track"] = next_track
		global_audio_tracker["playback_position"] = 0.0
		playlist_tracker["current_track_index"] = current_track_index
		playlist_tracker["playback_position"] = 0.0
		current_ambient = next_track
		ambient_changed.emit(next_track)
		print("🌍 AmbientAudioManager: Now playing:", next_track)
	else:
		print("⚠️ AmbientAudioManager: Failed to load next track:", next_track)

func stop_ambient():
	"""Stop ambient audio completely"""
	if ambient_player:
		ambient_player.stop()
		is_playing = false
		global_audio_tracker["was_playing"] = false
		global_audio_tracker["playback_position"] = 0.0
		playlist_tracker["was_playing"] = false
		playlist_tracker["playback_position"] = 0.0
		print("🌍 AmbientAudioManager: Ambient stopped completely")

func pause_ambient():
	"""Pause ambient audio (for cutscenes) - uses tracking system"""
	pause_ambient_tracked()

func resume_ambient():
	"""Resume ambient audio - uses tracking system"""
	if global_audio_tracker["is_exterior_scene"]:
		resume_ambient_tracked()
	else:
		print("🌍 AmbientAudioManager: Not in exterior scene, ambient stays paused")

func add_ambient_layer(layer_path: String, volume_db: float = -25):
	"""Add an additional ambient layer (for complex audio)"""
	for layer in ambient_layers:
		if not layer.playing:
			var layer_stream = load(layer_path)
			if layer_stream:
				layer.stream = layer_stream
				layer.volume_db = volume_db
				layer.play()
				print("🌍 AmbientAudioManager: Added ambient layer:", layer_path)
				return
	print("⚠️ AmbientAudioManager: No available ambient layer slots")

func remove_ambient_layers():
	"""Remove all ambient layers"""
	for layer in ambient_layers:
		layer.stop()
	print("🌍 AmbientAudioManager: All ambient layers removed")

func set_ambient_volume(volume_db: float):
	"""Set main ambient volume"""
	if ambient_player:
		ambient_player.volume_db = volume_db
		print("🌍 AmbientAudioManager: Ambient volume set to", volume_db, "dB")

func is_ambient_playing() -> bool:
	"""Check if ambient is currently playing"""
	return is_playing and ambient_player and ambient_player.playing

func get_current_ambient() -> String:
	"""Get current ambient file path"""
	return current_ambient

# Scene change detection
func _on_scene_changed():
	"""Called when scene changes - set appropriate ambient"""
	await get_tree().process_frame
	if get_tree().current_scene:
		var scene_name = get_tree().current_scene.scene_file_path.get_file().get_basename()
		print("🌍 AmbientAudioManager: Auto-detecting scene:", scene_name)
		set_exterior_ambient(scene_name)

# Debug controls
func _input(event):
	if event is InputEventKey and event.pressed:
		match event.physical_keycode:
			KEY_F6:
				# F6 - Test ambient and tracking info
				print("🌍 AmbientAudioManager: Current ambient:", current_ambient)
				print("🌍 AmbientAudioManager: Is playing:", is_playing)
				print("🌍 AmbientAudioManager: Tracked position:", global_audio_tracker["playback_position"])
				print("🌍 AmbientAudioManager: Was playing:", global_audio_tracker["was_playing"])
				print("🌍 AmbientAudioManager: Is exterior scene:", global_audio_tracker["is_exterior_scene"])
				print("🌍 AmbientAudioManager: Current track index:", current_track_index + 1, "/", ambient_playlist.size())
				print("🌍 AmbientAudioManager: Playlist tracker position:", playlist_tracker["playback_position"])
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
