extends Area2D

var is_transitioning: bool = false
var fade_duration: float = 0.25  # Faster fade since we check scene readiness
var player_reference: Node = null

func _ready():
	# Connect the body_entered signal to handle player entering the area
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	# Check if the body is the player and we're not already transitioning
	if body.name == "PlayerM" and not is_transitioning:
		var target_scene_path = _get_target_scene_path_from_area_name()
		if target_scene_path != "":
			# Store player reference and disable movement during transition
			player_reference = body
			if body.has_method("disable_movement"):
				body.disable_movement()
			_start_transition(target_scene_path)

func _get_target_scene_path_from_area_name() -> String:
	# Get the scene path based on the Area2D's name
	var area_name = name
	match area_name:
		"Area2D_lower_level":
			return "res://scenes/maps/Police Station/lower_level_station.tscn"
		"Area2D_head_police":
			return "res://scenes/maps/Police Station/head_police_room.tscn"
		"Area2D_security_server":
			return "res://scenes/maps/Police Station/security_server.tscn"
		"Area2D_police_lobby":
			return "res://scenes/maps/Police Station/police_lobby.tscn"
		_:
			return ""

func _start_transition(target_scene_path: String):
	is_transitioning = true
	
	# Create full-screen fade overlay on the CanvasLayer to be above everything
	var canvas_layer = CanvasLayer.new()
	var fade_rect = ColorRect.new()
	fade_rect.color = Color.BLACK
	fade_rect.color.a = 0.0
	fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas_layer.add_child(fade_rect)
	get_tree().current_scene.add_child(canvas_layer)
	
	# Move canvas layer to be on top of everything
	canvas_layer.layer = 100
	
	# Smooth fade in to cover entire scene
	var tween = create_tween()
	tween.tween_property(fade_rect, "color:a", 1.0, fade_duration)
	
	# Wait for fade in, then change scene
	await tween.finished
	
	# Small delay to ensure fade is complete before scene change
	await get_tree().create_timer(0.05).timeout
	
	# Change scene
	var result = get_tree().change_scene_to_file(target_scene_path)
	if result != OK:
		print("Failed to change scene to: ", target_scene_path)
		is_transitioning = false
		# If scene change failed, fade out
		_fade_out_and_cleanup(canvas_layer)
	else:
		# Scene change successful, canvas layer will be destroyed with old scene
		pass

func _fade_out_and_cleanup(canvas_layer: CanvasLayer):
	# Fade out and clean up if scene change failed
	var fade_rect = canvas_layer.get_child(0) as ColorRect
	var tween = create_tween()
	tween.tween_property(fade_rect, "color:a", 0.0, fade_duration)
	await tween.finished
	canvas_layer.queue_free()
	is_transitioning = false
	
	# Re-enable player movement if scene change failed
	if player_reference and player_reference.has_method("enable_movement"):
		player_reference.enable_movement()
	player_reference = null
