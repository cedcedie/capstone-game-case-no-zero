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
	show()
	
	# Slide in animation from left to right
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(container, "position:x", visible_position.x, slide_duration)

func hide_task():
	print("👋 TaskDisplay: Hiding task")
	
	# Slide out animation from right to left
	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(container, "position:x", hidden_offset, slide_duration * 0.8)
	await tween.finished
	hide()
