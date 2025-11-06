extends Node2D

var display_duration: float = 10.0  # 10 seconds display time
var fade_duration: float = 1.0  # 1 second fade in/out
var parent_control: Control
var skip_requested: bool = false

func _ready():
	print("🎮 Control Guide: Starting control guide display")
	
	# Get reference to parent Control node
	parent_control = get_parent() as Control
	if not parent_control:
		print("❌ Control Guide: Parent Control not found!")
		return
	
	# Start with alpha 0 (invisible)
	parent_control.modulate.a = 0.0
	
	# Fade in
	await fade_in()
	
	# Wait for display duration (only if not skipped)
	if not skip_requested:
		print("🎮 Control Guide: Displaying for ", display_duration, " seconds")
		await get_tree().create_timer(display_duration).timeout
		
		# Only proceed if not skipped
		if not skip_requested:
			# Fade out
			print("🎮 Control Guide: Fading out")
			await fade_out()
			
			# Small delay to ensure fade is completely finished
			await get_tree().create_timer(0.1).timeout
			
			# Transition to intro
			print("🎬 Control Guide: Transitioning to intro story")
			get_tree().change_scene_to_file("res://scenes/cutscenes/intro_story.tscn")

func fade_in():
	"""Fade in the control guide"""
	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(parent_control, "modulate:a", 1.0, fade_duration)
	await tween.finished
	print("🎮 Control Guide: Fade in completed")

func fade_out():
	"""Fade out the control guide"""
	if not parent_control:
		print("❌ Control Guide: Parent control not found for fade out")
		return
	
	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(parent_control, "modulate:a", 0.0, fade_duration)
	await tween.finished
	print("🎮 Control Guide: Fade out completed")
	
	# Ensure fade is completely finished
	parent_control.modulate.a = 0.0

func _input(event: InputEvent) -> void:
	"""Allow player to skip the control guide by pressing any key"""
	if event is InputEventKey and event.pressed and not event.echo and not skip_requested:
		print("🎮 Control Guide: Player pressed key - skipping control guide")
		skip_requested = true
		
		# Stop current tween if any
		var tweens = get_tree().get_processed_tweens()
		for tween in tweens:
			if tween.is_valid():
				tween.kill()
		
		# Fade out immediately and go to intro
		_skip_to_intro()

func _skip_to_intro():
	"""Skip to intro story"""
	# Fade out immediately and go to intro
	await fade_out()
	
	# Small delay to ensure fade is completely finished
	await get_tree().create_timer(0.1).timeout
	
	get_tree().change_scene_to_file("res://scenes/cutscenes/intro_story.tscn")
