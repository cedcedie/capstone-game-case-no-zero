extends Node2D

@export var fade_duration: float = 0.3
@export var fade_color: Color = Color.BLACK

func _ready():
	# Create a ColorRect for the fade effect
	var fade_rect = ColorRect.new()
	fade_rect.color = fade_color
	fade_rect.color.a = 1.0  # Start fully opaque
	fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fade_rect)
	
	# Fade out to reveal the scene
	var tween = create_tween()
	tween.tween_property(fade_rect, "color:a", 0.0, fade_duration)
	
	# Clean up after fade
	await tween.finished
	fade_rect.queue_free()
