extends Node2D

@onready var leo_sprite := $leo_mendoza
@onready var label := $RichTextLabel

var timeline : Array = []
var index : int = 0
var input_locked : bool = false  

# Fade durations
var text_fade_duration := 0.5
var sprite_fade_duration := 0.5

func _ready():
	leo_sprite.visible = false
	leo_sprite.modulate.a = 0.0

	var file = FileAccess.open("res://json/intro_timeline.json", FileAccess.READ)
	if not file:
		push_error("Cannot open res://json/intro_timeline.json")
		return

	var data = file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(data)
	if typeof(parsed) != TYPE_ARRAY:
		push_error("Timeline JSON is not an array")
		return

	timeline = parsed
	set_process_input(true)
	play_next_event()


func play_next_event():
	if index >= timeline.size():
		return  

	input_locked = true 
	var entry = timeline[index]
	index += 1

	match entry.type:
		"narration":
			await fade_text_out()
			label.text = entry.text
			await fade_text_in()
			input_locked = false
			await wait_for_input()
			play_next_event()

		"show_sprite":
			var node = get_node(entry.target)
			if node:
				fade_in(node, sprite_fade_duration)
			input_locked = false
			play_next_event()

		"hide_sprite":
			var node = get_node(entry.target)
			if node:
				fade_out(node, sprite_fade_duration)
			input_locked = false
			play_next_event()

func fade_text_in():
	label.visible = true
	label.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(label, "modulate:a", 1.0, text_fade_duration)
	await tween.finished

func fade_text_out():
	var tween = create_tween()
	tween.tween_property(label, "modulate:a", 0.0, text_fade_duration)
	await tween.finished

func wait_for_input() -> void:
	while true:
		await get_tree().process_frame
		if input_locked:
			continue  
		if Input.is_action_just_pressed("ui_accept") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			break


func _input(event):
	if input_locked:
		return  # prevent double-click
	if event is InputEventKey or event is InputEventMouseButton:
		pass  # player click advances after fade completes


# Fade-in for sprite
func fade_in(node: Node2D, duration: float = 0.5):
	node.visible = true
	node.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(node, "modulate:a", 1.0, duration)


# Fade-out for sprite
func fade_out(node: Node2D, duration: float = 0.5):
	var tween = create_tween()
	tween.tween_property(node, "modulate:a", 0.0, duration)
	tween.finished.connect(func(): node.visible = false)
