extends Node

var voice_blip_player: AudioStreamPlayer
var bleep_cache: Dictionary = {}  # path -> AudioStream cached once

func _ready():
	# Create the voice blip player
	voice_blip_player = AudioStreamPlayer.new()
	voice_blip_player.name = "VoiceBlipPlayer"
	voice_blip_player.bus = "SFX"
	
	# Add to this autoload node so it can play audio
	add_child(voice_blip_player)
	
	# No default sound; per-character bleeps will be loaded on demand

func play_voice_blip(speaker: String):
	"""Play character-specific voice blip sounds like in Undertale"""
	
	if not voice_blip_player:
		print("⚠️ VoiceBlipManager: voice_blip_player not available")
		return
	
	# Stop any currently playing sound to allow rapid typing
	if voice_blip_player.playing:
		voice_blip_player.stop()
	
	# Load per-character bleep and cache
	var path := get_beep_for_speaker(speaker)
	var stream: Resource = null
	if bleep_cache.has(path):
		stream = bleep_cache[path]
	else:
		if FileAccess.file_exists(path):
			stream = load(path)
			if stream:
				bleep_cache[path] = stream
				print("🔊 VoiceBlipManager: Loaded audio for speaker '", speaker, "' from ", path)
			else:
				print("⚠️ VoiceBlipManager: Failed to load stream from ", path, " for speaker '", speaker, "'")
		else:
			print("⚠️ VoiceBlipManager: File not found: ", path, " for speaker '", speaker, "'")

	if stream:
		voice_blip_player.stream = stream
		voice_blip_player.volume_db = 5.0  # Increased from 0 dB to 5 dB for better audibility
		voice_blip_player.pitch_scale = get_pitch_for_speaker(speaker)
		voice_blip_player.play()
		print("🔊 VoiceBlipManager: Playing beep for '", speaker, "' at ", voice_blip_player.volume_db, " dB")
	else:
		print("⚠️ VoiceBlipManager: No stream available for speaker '", speaker, "' (path: ", path, ")")

func get_beep_for_speaker(speaker: String) -> String:
	"""Get specific beep file for each character"""
	match speaker.to_lower():
		"miguel":
			return "res://assets/audio/sfx/bleep001.ogg"  # Miguel gets bleep001
		"erwin", "boy trip":
			return "res://assets/audio/sfx/bleep003.ogg"  # Erwin/Boy Trip gets bleep003
		"celine":
			return "res://assets/audio/sfx/bleep002.ogg"  # Celine gets bleep002
		"kapitana", "kapitana lourdes":
			return "res://assets/audio/sfx/bleep006.ogg"  # Kapitana gets bleep006
		"po1 darwin", "po1_darwin":
			return "res://assets/audio/sfx/bleep007.ogg"  # PO1 Darwin gets bleep007
		"dr. leticia salvador", "dr leticia salvador", "leticia salvador", "dr_leticia_salvador":
			return "res://assets/audio/sfx/bleep008.ogg"  # Dr. Leticia Salvador gets bleep008
		"narrator", "system":
			return "res://assets/audio/sfx/bleep004.ogg"  # Narrator gets bleep004
		_:
			return "res://assets/audio/sfx/bleep005.ogg"  # Default gets bleep005

func get_pitch_for_speaker(speaker: String) -> float:
	"""Get pitch scale for different speakers"""
	match speaker.to_lower():
		"miguel":
			return 0.8  # Lower pitch
		"erwin", "boy trip":
			return 0.9  # Slightly higher than Miguel
		"celine":
			return 1.2  # Higher pitch
		"kapitana", "kapitana lourdes":
			return 0.7  # Lower pitch for authority figure
		"po1 darwin", "po1_darwin":
			return 0.9  # Medium pitch for police officer
		"dr. leticia salvador", "dr leticia salvador", "leticia salvador", "dr_leticia_salvador":
			return 0.8  # Lower pitch for medical professional
		"narrator", "system":
			return 1.0  # Normal pitch
		_:
			return 1.0  # Default pitch

func play_simple_tone(speaker: String):
	"""Play a simple tone using the system beep"""
	# Just play a short beep with character-specific pitch
	voice_blip_player.volume_db = 0
	voice_blip_player.pitch_scale = get_pitch_for_speaker(speaker)
	voice_blip_player.play()

func play_synthesized_voice(freq: float, duration: float, volume: float):
	"""Generate a simple voice blip sound - Godot 4.4 compatible"""
	if not voice_blip_player:
		return
	
	
	# Create a simple generator for voice blips
	var gen = AudioStreamGenerator.new()
	gen.mix_rate = 22050  # Lower sample rate for voice blips
	gen.buffer_length = 0.1  # Small buffer for immediate playback
	voice_blip_player.stream = gen
	voice_blip_player.volume_db = 0  # Set to -5 dB
	
	# Start playing first
	voice_blip_player.play()
	
	# Get playback after starting
	await get_tree().process_frame  # Wait one frame for playback to be available
	var playback = voice_blip_player.get_stream_playback()
	if not playback:
		voice_blip_player.stop()
		return
	
	# Generate a short voice blip
	var sample_rate = 22050.0
	var samples = int(duration * sample_rate)
	
	for i in range(samples):
		var t = i / sample_rate
		# Create a more voice-like sound with multiple harmonics
		var wave = 0.0
		wave += sin(2.0 * PI * freq * t) * 0.4
		wave += sin(2.0 * PI * freq * 2.0 * t) * 0.2
		wave += sin(2.0 * PI * freq * 3.0 * t) * 0.1
		
		# Add some randomness for character
		wave += sin(2.0 * PI * (freq + randf_range(-20, 20)) * t) * 0.1
		
		# Apply envelope
		var envelope = 1.0 - (t / duration)
		wave *= envelope
		
		# Clamp the wave to prevent distortion
		wave = clamp(wave, -1.0, 1.0)
		
		playback.push_frame(Vector2(wave, wave))
	
	
	# Stop after duration
	await get_tree().create_timer(duration).timeout
	voice_blip_player.stop()

func play_ringtone(ring_count: int = 3, ring_duration: float = 0.2, pause_duration: float = 0.3) -> float:
	"""Play bleep009 in a ringtone pattern (ring-pause-ring-pause-ring)
	
	Args:
		ring_count: Number of rings (default: 3)
		ring_duration: How long each ring plays (default: 0.2 seconds)
		pause_duration: Pause between rings (default: 0.3 seconds)
	
	Returns:
		Total duration of the ringtone sequence
	"""
	if not voice_blip_player:
		return 0.0
	
	var ringtone_path := "res://assets/audio/sfx/bleep009.ogg"
	
	# Load and cache the ringtone sound
	var stream: Resource = null
	if bleep_cache.has(ringtone_path):
		stream = bleep_cache[ringtone_path]
	else:
		if FileAccess.file_exists(ringtone_path):
			stream = load(ringtone_path)
			if stream:
				bleep_cache[ringtone_path] = stream
				# Get actual duration of the sound file
				if stream is AudioStream:
					var actual_duration = (stream as AudioStream).get_length()
	
	if not stream:
		return 0.0
	
	# Calculate total duration
	var total_duration: float = 0.0
	for i in range(ring_count):
		# Play the ring
		voice_blip_player.stream = stream
		voice_blip_player.volume_db = 5.0  # Increased from 0 dB to 5 dB for better audibility
		voice_blip_player.pitch_scale = 1.0  # Normal pitch for ringtone
		voice_blip_player.play()
		
		# Wait for ring duration (or actual sound length, whichever is shorter)
		var actual_duration = (stream as AudioStream).get_length() if stream is AudioStream else ring_duration
		var play_duration = min(ring_duration, actual_duration)
		await get_tree().create_timer(play_duration).timeout
		voice_blip_player.stop()
		
		total_duration += play_duration
		
		# Pause between rings (except after last ring)
		if i < ring_count - 1:
			await get_tree().create_timer(pause_duration).timeout
			total_duration += pause_duration
	
	return total_duration
