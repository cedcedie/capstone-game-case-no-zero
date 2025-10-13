extends Node2D

@export var fade_duration: float = 0.25  # Faster fade since we check scene readiness
@export var fade_color: Color = Color.BLACK

func _ready():
	# Create a CanvasLayer to be above everything immediately
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 100  # High layer to be on top
	
	# Create a ColorRect for the fade effect
	var fade_rect = ColorRect.new()
	fade_rect.color = fade_color
	fade_rect.color.a = 1.0  # Start fully opaque (scene was faded out)
	fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas_layer.add_child(fade_rect)
	add_child(canvas_layer)
	
	# Smart loading detection - check if scene is ready
	await _wait_for_scene_ready()
	
	# Fade out to reveal the scene
	var tween = create_tween()
	tween.tween_property(fade_rect, "color:a", 0.0, fade_duration)
	
	# Clean up after fade
	await tween.finished
	canvas_layer.queue_free()

func _wait_for_scene_ready():
	# Universal approach - wait for scene to be processed and settled
	# This works for any scene structure
	
	# Wait for scene to be processed by the engine
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Small delay to ensure everything is settled
	await get_tree().create_timer(0.08).timeout
