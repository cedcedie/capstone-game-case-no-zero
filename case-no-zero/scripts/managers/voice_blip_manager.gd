extends Node

var voice_blip_player: AudioStreamPlayer
var bleep_cache: Dictionary = {}  # path -> AudioStream cached once

func _ready():
	# Create the voice blip player
	voice_blip_player = AudioStreamPlayer.new()
	voice_blip_player.name = "VoiceBlipPlayer"
	
	# Add to this autoload node so it can play audio
	add_child(voice_blip_player)
	
	# No default sound; per-character bleeps will be loaded on demand

func play_voice_blip(speaker: String):
	"""Play character-specific voice blip sounds like in Undertale"""
	
	if not voice_blip_player:
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
			else:
				pass  # Failed to load stream; ignore
		else:
			pass  # File missing; ignore

	if stream:
		voice_blip_player.stream = stream
		voice_blip_player.volume_db = -10
		voice_blip_player.pitch_scale = get_pitch_for_speaker(speaker)
		voice_blip_player.play()
	else:
		pass  # No stream available; skip

func get_beep_for_speaker(speaker: String) -> String:
	"""Get specific beep file for each character"""
	match speaker.to_lower():
		"miguel", "erwin":
			return "res://assets/audio/sfx/bleep001.ogg"  # Miguel gets bleep001
		"celine":
			return "res://assets/audio/sfx/bleep002.ogg"  # Celine gets bleep002
		"narrator", "system":
			return "res://assets/audio/sfx/bleep003.ogg"  # Narrator gets bleep003
		_:
			return "res://assets/audio/sfx/bleep004.ogg"  # Default gets bleep004

func get_pitch_for_speaker(speaker: String) -> float:
	"""Get pitch scale for different speakers"""
	match speaker.to_lower():
		"miguel", "erwin":
			return 0.8  # Lower pitch
		"celine":
			return 1.2  # Higher pitch
		"narrator", "system":
			return 1.0  # Normal pitch
		_:
			return 1.0  # Default pitch

func play_simple_tone(speaker: String):
	"""Play a simple tone using the system beep"""
	print("🎵 Playing simple tone for: " + speaker)
	# Just play a short beep with character-specific pitch
	voice_blip_player.volume_db = -15
	voice_blip_player.pitch_scale = get_pitch_for_speaker(speaker)
	voice_blip_player.play()

func play_synthesized_voice(freq: float, duration: float, volume: float):
	"""Generate a simple voice blip sound - Godot 4.4 compatible"""
	if not voice_blip_player:
		return
	
	print("🎵 Generating voice blip: freq=" + str(freq) + ", duration=" + str(duration))
	
	# Create a simple generator for voice blips
	var gen = AudioStreamGenerator.new()
	gen.mix_rate = 22050  # Lower sample rate for voice blips
	gen.buffer_length = 0.1  # Small buffer for immediate playback
	voice_blip_player.stream = gen
	voice_blip_player.volume_db = linear_to_db(volume) - 5  # Louder volume
	
	# Start playing first
	voice_blip_player.play()
	print("🎵 Voice blip player started")
	
	# Get playback after starting
	await get_tree().process_frame  # Wait one frame for playback to be available
	var playback = voice_blip_player.get_stream_playback()
	if not playback:
		print("⚠️ No playback available after waiting!")
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
	
	print("🎵 Voice blip generation complete")
	
	# Stop after duration
	await get_tree().create_timer(duration).timeout
	voice_blip_player.stop()
	print("🎵 Voice blip finished")
