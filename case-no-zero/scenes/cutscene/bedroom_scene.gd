extends Node

# --- Node references ---
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var player: Node = $PlayerM
@onready var dialogue_ui: Control = $CanvasLayer/DialogueUiTest
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

# --- Load dialogue JSON ---
func load_dialogue():
	var file = FileAccess.open("res://dialogue/mainStory/Intro.json", FileAccess.READ)
	if not file:
		push_error("Cannot open Intro.json")
		return

	var text = file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(text)  # returns Dictionary in Godot 4.4

	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Failed to parse JSON, not a Dictionary")
		return

	if not parsed.has("Intro"):
		push_error("JSON missing 'Intro' key")
		return

	dialogue_lines = parsed["Intro"]
	current_line = 0

	print("DEBUG: Loaded %d dialogue lines" % dialogue_lines.size())

# --- Start cutscene ---
func start_cutscene():
	load_dialogue()
	disable_control()
	show_next_line()

	# Optional cosmetic cutscene animation
	if anim_player.has_animation("IntroCutscene"):
		anim_player.play("IntroCutscene")
	else:
		push_warning("AnimationPlayer missing 'IntroCutscene' animation!")

# --- Show next line ---
func show_next_line():
	if current_line < dialogue_lines.size():
		var line = dialogue_lines[current_line]
		dialogue_ui.show_dialogue_line(line["speaker"], line["text"])
		waiting_for_next = true

		# Switch character animation
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
	dialogue_ui.hide()
	enable_control()
	character_sprite.animation = "idle"
	anim_player.stop()  # optional outro animation

# --- Ready ---
func _ready():
	# Connect DialogueUI next_pressed signal
	var cb = Callable(self, "_on_next_pressed")
	if not dialogue_ui.is_connected("next_pressed", cb):
		dialogue_ui.connect("next_pressed", cb)

	start_cutscene()
