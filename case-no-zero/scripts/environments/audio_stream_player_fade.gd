extends AudioStreamPlayer

var fade_duration: float = 0.5

func stop(fade_duration_override: float = -1.0) -> void:
	var duration: float = fade_duration_override if fade_duration_override >= 0.0 else fade_duration
	
	if not playing:
		return
	
	var original_volume: float = volume_db
	var fade_tween := create_tween()
	fade_tween.set_ease(Tween.EASE_IN_OUT)
	fade_tween.set_trans(Tween.TRANS_CUBIC)
	fade_tween.tween_property(self, "volume_db", -80.0, duration)
	await fade_tween.finished
	super.stop()
	volume_db = original_volume
