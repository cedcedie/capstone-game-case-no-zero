extends CanvasLayer  

@onready var label: Label = $NinePatchRect/Label
@onready var container: NinePatchRect = $NinePatchRect

# Animation settings
var slide_duration: float = 0.6
var hidden_offset: float = -280.0  # Slide from left (off-screen)
var visible_position: Vector2 = Vector2(0, 0)

func _ready():
	# Start hidden off-screen to the left
	container.position.x = hidden_offset
	hide()

func show_task(task_name: String):
	print("🎯 TaskDisplay: Showing task -", task_name)
	label.text = task_name
	
	# Dynamic font sizing based on text length
	_adjust_font_size_for_text(task_name)
	
	show()
	
	# Slide in animation from left to right
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(container, "position:x", visible_position.x, slide_duration)

func _adjust_font_size_for_text(text: String):
	"""Dynamically adjust font size based on text length to prevent overflow"""
	var base_font_size = 16  # Default font size
	var max_width = 250.0    # Maximum width for the label
	
	# Count lines in text (including \n characters)
	var line_count = text.count("\n") + 1
	var char_count = text.length()
	
	# Calculate font size based on text complexity
	var font_size = base_font_size
	
	# Reduce font size for longer text
	if char_count > 50:
		font_size = base_font_size - 2
	if char_count > 100:
		font_size = base_font_size - 4
	if line_count > 2:
		font_size = base_font_size - 2
	if line_count > 3:
		font_size = base_font_size - 4
	
	# Ensure minimum font size
	font_size = max(font_size, 10)
	
	# Apply font size to label
	if label.label_settings:
		label.label_settings.font_size = font_size
		print("🎯 TaskDisplay: Adjusted font size to ", font_size, " for text length: ", char_count, " chars, ", line_count, " lines")
	else:
		print("⚠️ TaskDisplay: No label_settings found for font adjustment")

func hide_task():
	print("👋 TaskDisplay: Hiding task")
	
	# Slide out animation from right to left
	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(container, "position:x", hidden_offset, slide_duration * 0.8)
	await tween.finished
	hide()
