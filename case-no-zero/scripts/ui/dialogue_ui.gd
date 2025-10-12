extends CanvasLayer

@onready var container = $Container
@onready var name_label = $Container/Name
@onready var dialogue_label = $Container/Dialogue
@onready var next_button = $Container/Button
@onready var typing_sound = $Container/TypingSound 

signal next_pressed
var waiting_for_next: bool = false
var is_typing: bool = false
var typing_speed := 0.01

func _ready():
	hide()
	container.modulate.a = 0.0
	next_button.hide()
	next_button.pressed.connect(_on_next_pressed)

# Smooth fade-in
func show_ui():
	show()
	var t = create_tween()
	t.tween_property(container, "modulate:a", 1.0, 0.4)

# Smooth fade-out
func hide_ui():
	var t = create_tween()
	t.tween_property(container, "modulate:a", 0.0, 0.4)
	await t.finished
	hide()

# Typing animation with sound
func show_dialogue_line(speaker: String, text: String) -> void:
	show_ui()
	name_label.text = speaker
	next_button.hide()
	dialogue_label.text = ""
	waiting_for_next = false
	is_typing = true

	for i in text.length():
		dialogue_label.text = text.substr(0, i + 1)
		if not typing_sound.playing:
			typing_sound.play() # Play the typing sound each step (short "tick" or "blip" sound works best)
		await get_tree().create_timer(typing_speed).timeout

	is_typing = false
	waiting_for_next = true
	next_button.show() # Show the next button only after typing finishes

func _on_next_pressed():
	if waiting_for_next and not is_typing:
		waiting_for_next = false
		next_button.hide()
		emit_signal("next_pressed")
