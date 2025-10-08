extends Control
class_name DialogueUI

@onready var name_label = $Name
@onready var dialogue_label = $Dialogue
@onready var next_button = $Button

signal next_pressed
var waiting_for_next: bool = false

func _ready():
	hide()
	modulate.a = 0.0
	next_button.pressed.connect(_on_next_pressed)

# Smooth fade-in
func show_ui():
	show()
	var t = create_tween()
	t.tween_property(self, "modulate:a", 1.0, 0.4)

# Smooth fade-out
func hide_ui():
	var t = create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.4)
	await t.finished
	hide()

func show_dialogue_line(speaker: String, text: String):
	show_ui()
	name_label.text = speaker
	dialogue_label.text = text
	waiting_for_next = true

func _on_next_pressed():
	if waiting_for_next:
		waiting_for_next = false
		emit_signal("next_pressed")
