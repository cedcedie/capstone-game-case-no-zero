extends Node

# Global Scene Fade In Manager
# Automatically handles fade-in effects for all scene transitions
# No need to reference fade nodes in individual scenes

@export var fade_duration: float = 0.25  # Faster fade since we check scene readiness
@export var fade_color: Color = Color.BLACK

var current_fade_overlay: CanvasLayer
var is_fading: bool = false
var current_scene_path: String = ""
var has_faded_scene: bool = false

func _ready():
	# Start with a fade-in for the initial scene
	call_deferred("_fade_in_initial_scene")
	
	# Connect to scene change signals - only once
	if not get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.connect(_on_node_added)

func _on_node_added(node: Node):
	"""Called when a node is added to the scene tree"""
	# Only respond to scene root nodes and only if it's a new scene
	if node == get_tree().current_scene:
		var scene_path = ""
		if get_tree().current_scene and get_tree().current_scene.scene_file_path:
			scene_path = get_tree().current_scene.scene_file_path
		
		# Only trigger if this is a different scene than we've already handled
		if scene_path != current_scene_path:
			current_scene_path = scene_path
			has_faded_scene = false
			call_deferred("_on_scene_changed")

func _on_scene_changed():
	"""Called when scene changes - automatically fade in the new scene"""
	# Prevent multiple simultaneous fades for the same scene
	if has_faded_scene or is_fading:
		return
	
	await get_tree().process_frame
	
	# Double-check after waiting
	if has_faded_scene or is_fading:
		return
		
	if get_tree().current_scene and not is_fading:
		# Mark as fading immediately to prevent double fade from _fade_in_initial_scene
		is_fading = true
		has_faded_scene = true
		await _fade_in_scene()

func _fade_in_initial_scene():
	"""Fade in the very first scene when the game starts"""
	await get_tree().process_frame  # Wait a frame to ensure scene is fully loaded
	
	if get_tree().current_scene and not has_faded_scene and not is_fading:
		var scene_path = ""
		if get_tree().current_scene.scene_file_path:
			scene_path = get_tree().current_scene.scene_file_path
		
		# Mark as fading immediately to prevent double fade
		is_fading = true
		current_scene_path = scene_path
		has_faded_scene = true
		
		await _fade_in_scene()

func _fade_in_scene():
	"""Create and execute fade-in effect for current scene"""
	# Double-check: if already fading, return immediately (safety check)
	if is_fading:
		return
	
	# Check if there's already a fade overlay active
	if current_fade_overlay != null and is_instance_valid(current_fade_overlay):
		return
	
	# Mark as fading immediately to prevent any other calls
	is_fading = true
	
	# Create a CanvasLayer to be above everything
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 100  # High layer to be on top
	
	# Create a ColorRect for the fade effect
	var fade_rect = ColorRect.new()
	fade_rect.color = fade_color
	fade_rect.color.a = 1.0  # Start fully opaque (scene was faded out)
	fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas_layer.add_child(fade_rect)
	
	# Add to current scene
	var current_scene = get_tree().current_scene
	if current_scene:
		current_scene.add_child(canvas_layer)
		current_fade_overlay = canvas_layer
	else:
		is_fading = false
		return
	
	# Smart loading detection - check if scene is ready
	await _wait_for_scene_ready()
	
	# Fade out to reveal the scene
	var tween = create_tween()
	tween.tween_property(fade_rect, "color:a", 0.0, fade_duration)
	
	# Clean up after fade
	await tween.finished
	if canvas_layer and is_instance_valid(canvas_layer):
		canvas_layer.queue_free()
	
	# Clear the overlay reference before resetting the flag
	if current_fade_overlay == canvas_layer:
		current_fade_overlay = null
	
	is_fading = false

func _wait_for_scene_ready():
	"""Universal approach - wait for scene to be processed and settled"""
	# Wait for scene to be processed by the engine
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Small delay to ensure everything is settled
	await get_tree().create_timer(0.08).timeout
