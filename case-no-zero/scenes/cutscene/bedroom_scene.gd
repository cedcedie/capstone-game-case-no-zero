extends Node

# --- Node references ---
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var player: Node = $PlayerM
@onready var dialogue_ui: DialogueUI = $CanvasLayer/DialogueUiTest
@onready var character_sprite: AnimatedSprite2D = $PlayerM/AnimatedSprite2D

# --- Dialogue data ---
var dialogue_lines: Array = []
var current_line: int = 0
var waiting_for_next: bool = false

# --- Player control helpers ---
func disable_control():
	if player:
		player.control_enabled = false

func enable_control():
	if player:
		player.control_enabled = true

# --- Start cutscene ---
func start_cutscene():
	# Load JSON
	var file = FileAccess.open("res://dialogue/mainStory/Intro.json", FileAccess.READ)
	if not file:
		push_error("Cannot open Intro.json")
		return

	var json_text = file.get_as_text()
	file.close()

	var parse_result = JSON.parse_string(json_text)  # returns Dictionary in Godot 4.4

	# Correct bracket syntax for JSON keys
	if parse_result["error"] != OK:
		push_error("Failed to parse JSON: %s" % parse_result["error_string"])
		return

	var json_data = parse_result["result"]
	if not json_data.has("Intro"):
		push_error("JSON missing 'Intro' key")
		return

	dialogue_lines = json_data["Intro"]
	current_line = 0

	disable_control()
	show_next_line()

	# Optional: play cosmetic cutscene animation
	if anim_player.has_animation("IntroCutscene"):
		anim_player.play("IntroCutscene")
	else:
		push_warning("AnimationPlayer missing 'IntroCutscene' animation!")

# --- Show next dialogue line ---
func show_next_line():
	if current_line < dialogue_lines.size():
		var line = dialogue_lines[current_line]
		dialogue_ui.show_dialogue_line(line["speaker"], line["text"])
		waiting_for_next = true

		# Switch character animation while speaking
		match line["speaker"]:
			"Miguel", "Celine":
				character_sprite.animation = "talk"
			_:
				character_sprite.animation = "idle"
	else:
		end_cutscene()

# --- Called when Next button pressed ---
func _on_next_pressed():
	if waiting_for_next:
		waiting_for_next = false
		current_line += 1
		show_next_line()

# --- End cutscene ---
func end_cutscene():
	dialogue_ui.hide_dialogue()
	enable_control()
	character_sprite.animation = "idle"
	anim_player.stop()  # optional outro animation

# --- Ready setup ---
func _ready():
	# Connect Next signal safely
	var cb = Callable(self, "_on_next_pressed")
	if not dialogue_ui.is_connected("next_pressed", cb):
		dialogue_ui.connect("next_pressed", cb)

	# Start cutscene automatically for testing
	start_cutscene()
