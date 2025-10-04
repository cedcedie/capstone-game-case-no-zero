extends Control
class_name DialogueUI  # unique class_name for type hints

@onready var name_label = $Name
@onready var dialogue_label = $Dialogue
@onready var next_button = $Button

signal next_pressed
var waiting_for_next: bool = false

func _ready():
	hide()
	next_button.hide()
	next_button.pressed.connect(_on_next_pressed)

func show_dialogue_line(speaker: String, text: String):
	show()
	next_button.show()
	name_label.text = speaker
	dialogue_label.text = text
	waiting_for_next = true
	print("DEBUG: Showing line:", speaker, text)

func hide_dialogue():
	hide()
	next_button.hide()
	waiting_for_next = false

func _on_next_pressed():
	if waiting_for_next:
		waiting_for_next = false
		emit_signal("next_pressed")
