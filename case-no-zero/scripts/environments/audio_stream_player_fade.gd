extends AudioStreamPlayer

## AudioStreamPlayer with fade-out stop functionality
## Attach this script to AudioStreamPlayer nodes to enable fade-out when stop() is called

var fade_duration: float = 0.5  # Default fade duration in seconds

func stop(fade_duration_override: float = -1.0) -> void:
	"""Override stop() to fade out instead of stopping immediately"""
	var duration: float = fade_duration_override if fade_duration_override >= 0.0 else fade_duration
	
	if not playing:
		print("🎵 AudioStreamPlayer (", name, ") is not playing")
		return
	
	print("🎵 Fading out AudioStreamPlayer (", name, ")...")
	var original_volume: float = volume_db
	var fade_tween := create_tween()
	fade_tween.set_ease(Tween.EASE_IN_OUT)
	fade_tween.set_trans(Tween.TRANS_CUBIC)
	fade_tween.tween_property(self, "volume_db", -80.0, duration)
	await fade_tween.finished
	super.stop()  # Call the original stop() method
	volume_db = original_volume
	print("🎵 AudioStreamPlayer (", name, ") stopped with fade out")
