extends Control

var display_duration: float = 10.0  # 10 seconds display time
var fade_duration: float = 1.0  # 1 second fade in/out

func _ready():
	print("🎮 Control Guide: Starting control guide display")
	
	# Start with alpha 0 (invisible)
	modulate.a = 0.0
	
	# Fade in
	await fade_in()
	
	# Wait for display duration
	print("🎮 Control Guide: Displaying for ", display_duration, " seconds")
	await get_tree().create_timer(display_duration).timeout
	
	# Fade out
	print("🎮 Control Guide: Fading out")
	await fade_out()
	
	# Transition to intro
	print("🎬 Control Guide: Transitioning to intro story")
	get_tree().change_scene_to_file("res://intro_story.tscn")

func fade_in():
	"""Fade in the control guide"""
	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "modulate:a", 1.0, fade_duration)
	await tween.finished
	print("🎮 Control Guide: Fade in completed")

func fade_out():
	"""Fade out the control guide"""
	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "modulate:a", 0.0, fade_duration)
	await tween.finished
	print("🎮 Control Guide: Fade out completed")

func _input(event: InputEvent) -> void:
	"""Allow player to skip the control guide by pressing any key"""
	if event is InputEventKey and event.pressed and not event.echo:
		print("🎮 Control Guide: Player pressed key - skipping control guide")
		# Stop current tween if any
		var tweens = get_tree().get_processed_tweens()
		for tween in tweens:
			if tween.is_valid():
				tween.kill()
		
		# Fade out immediately and go to intro
		await fade_out()
		get_tree().change_scene_to_file("res://intro_story.tscn")
