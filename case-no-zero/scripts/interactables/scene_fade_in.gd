extends Node

# Global Scene Fade In Manager
# Automatically handles fade-in effects for all scene transitions
# No need to reference fade nodes in individual scenes

@export var fade_duration: float = 0.25  # Faster fade since we check scene readiness
@export var fade_color: Color = Color.BLACK

var current_fade_overlay: CanvasLayer
var is_fading: bool = false

func _ready():
	# Connect to scene change signals
	get_tree().node_added.connect(_on_node_added)
	
	# Start with a fade-in for the initial scene
	call_deferred("_fade_in_initial_scene")

func _on_node_added(node: Node):
	"""Called when a node is added to the scene tree"""
	# Only respond to scene root nodes
	if node == get_tree().current_scene:
		call_deferred("_on_scene_changed")

func _on_scene_changed():
	"""Called when scene changes - automatically fade in the new scene"""
	await get_tree().process_frame
	if get_tree().current_scene and not is_fading:
		print("🎬 SceneFadeIn: Auto-fading in scene:", get_tree().current_scene.scene_file_path.get_file())
		await _fade_in_scene()

func _fade_in_initial_scene():
	"""Fade in the very first scene when the game starts"""
	if get_tree().current_scene:
		await _fade_in_scene()

func _fade_in_scene():
	"""Create and execute fade-in effect for current scene"""
	if is_fading:
		return
	
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
		print("⚠️ SceneFadeIn: current_scene is null, cannot add fade overlay")
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
	
	is_fading = false
	print("🎬 SceneFadeIn: Scene fade-in completed")

func _wait_for_scene_ready():
	"""Universal approach - wait for scene to be processed and settled"""
	# Wait for scene to be processed by the engine
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Small delay to ensure everything is settled
	await get_tree().create_timer(0.08).timeout
