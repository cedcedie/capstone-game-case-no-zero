extends Area2D

@export var transition_duration: float = 0.3
@export var fade_color: Color = Color.BLACK

var is_transitioning: bool = false

func _ready():
	# Connect the body_entered signal to handle player entering the area
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	# Check if the body is the player and we're not already transitioning
	if body.name == "PlayerM" and not is_transitioning:
		# Find which collision shape the player entered
		var target_scene = _get_target_scene_from_position(body.global_position)
		if target_scene:
			_start_transition(target_scene)

func _get_target_scene_from_position(player_pos: Vector2) -> String:
	# Check each collision shape to see which one the player is in
	for child in get_children():
		if child is CollisionShape2D:
			var collision_shape = child as CollisionShape2D
			var area_pos = global_position + collision_shape.position
			var shape = collision_shape.shape as RectangleShape2D
			
			if shape:
				var rect = Rect2(area_pos - shape.size / 2, shape.size)
				if rect.has_point(player_pos):
					return _get_scene_path_from_collision_name(collision_shape.name)
	return ""

func _get_scene_path_from_collision_name(collision_name: String) -> String:
	# Map collision shape names to their corresponding scene paths
	match collision_name:
		"police_lobby":
			return "res://scenes/maps/Police Station/police_lobby.tscn"
		"lower_level_station":
			return "res://scenes/maps/Police Station/lower_level_station.tscn"
		"head_police_room":
			return "res://scenes/maps/Police Station/head_police_room.tscn"
		"security_server":
			return "res://scenes/maps/Police Station/security_server.tscn"
		_:
			print("Unknown collision shape name: ", collision_name)
			return ""

func _start_transition(target_scene: String):
	is_transitioning = true
	
	# Create a ColorRect for the fade effect
	var fade_rect = ColorRect.new()
	fade_rect.color = fade_color
	fade_rect.color.a = 0.0
	fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_tree().current_scene.add_child(fade_rect)
	
	# Simple fade in
	var tween = create_tween()
	tween.tween_property(fade_rect, "color:a", 1.0, transition_duration)
	
	# Wait for fade in to complete, then change scene
	await tween.finished
	
	# Change to the target scene
	var result = get_tree().change_scene_to_file(target_scene)
	if result != OK:
		print("Failed to change scene to: ", target_scene)
		# If scene change failed, fade out and reset
		_fade_out_and_cleanup(fade_rect)
	else:
		# Scene change successful, the new scene will handle its own fade-in
		fade_rect.queue_free()

func _fade_out_and_cleanup(fade_rect: ColorRect):
	# Fade out and clean up
	var tween = create_tween()
	tween.tween_property(fade_rect, "color:a", 0.0, transition_duration)
	await tween.finished
	fade_rect.queue_free()
	is_transitioning = false
