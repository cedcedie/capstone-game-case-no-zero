extends Node

# --- Node references ---
@onready var dialogue_ui: CanvasLayer = null  # Will reference global DialogueUI autoload
@onready var dialog_chooser: CanvasLayer = null  # Will reference DialogChooser autoload
@onready var player: CharacterBody2D = $PlayerM
@onready var celine: CharacterBody2D = $Celine
@onready var boy_trip: CharacterBody2D = $BoyTrip
@onready var guard: CharacterBody2D = $Guard

# --- Dialogue data ---
var dialogue_lines: Array = []
var miguel_choices: Array = []
var current_line: int = 0
var waiting_for_next: bool = false

# --- Choice system ---
var current_choice_data: Dictionary = {}
var waiting_for_choice: bool = false

func _ready():
	# Get autoload references
	dialogue_ui = get_node("/root/DialogueUI")
	dialog_chooser = get_node("/root/DialogChooser")
	
	# Connect choice signal
	dialog_chooser.choice_selected.connect(_on_choice_selected)
	
	# Load dialogue
	load_dialogue()
	
	# Start the scene
	start_detention_scene()

func load_dialogue():
	var file: FileAccess = FileAccess.open("res://data/dialogues/DetentionCell.json", FileAccess.READ)
	if file == null:
		push_error("Cannot open DetentionCell.json")
		return

	var text: String = file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Failed to parse DetentionCell.json")
		return

	dialogue_lines = parsed["DetentionCell"]
	miguel_choices = parsed["MiguelChoices"]
	current_line = 0
	print("✅ Loaded dialogue lines:", dialogue_lines.size())
	print("✅ Loaded Miguel choices:", miguel_choices.size())

func start_detention_scene():
	# Disable player control
	if "control_enabled" in player:
		player.control_enabled = false
	
	# Setup initial states
	player.anim_sprite.play("idle_front")
	celine.anim_sprite.play("idle_front")
	boy_trip.anim_sprite.play("idle_front")
	guard.anim_sprite.play("idle_front")
	
	await get_tree().create_timer(1.0).timeout
	show_next_line()

func show_next_line():
	if current_line >= dialogue_lines.size():
		end_scene()
		return

	var line: Dictionary = dialogue_lines[current_line]
	var speaker: String = String(line.get("speaker", ""))
	var text: String = String(line.get("text", ""))

	print("🗨️ Showing line", current_line, "Speaker:", speaker)

	# Check if this line has a choice for Miguel
	var choice_data = get_choice_for_line(current_line)
	if choice_data and speaker == "Miguel":
		# Show choice instead of regular dialogue
		show_miguel_choice(choice_data)
		return

	# Show regular dialogue
	dialogue_ui.show_dialogue_line(speaker, text)
	waiting_for_next = true

func get_choice_for_line(line_index: int) -> Dictionary:
	"""Check if there's a choice for this line index"""
	for choice in miguel_choices:
		if choice.get("line_index", -1) == line_index:
			return choice
	return {}

func show_miguel_choice(choice_data: Dictionary):
	"""Show Miguel's choice options"""
	current_choice_data = choice_data
	waiting_for_choice = true
	
	# Show the choice UI
	dialog_chooser.show_choices(choice_data["choices"])
	
	print("🎯 Showing Miguel choice:", choice_data["choices"])

func _on_choice_selected(choice_index: int):
	"""Handle when player selects a choice"""
	if not waiting_for_choice:
		return
	
	waiting_for_choice = false
	
	# Get the response for the selected choice
	var response = current_choice_data["responses"][choice_index]
	
	# Show Miguel's choice as dialogue
	dialogue_ui.show_dialogue_line("Miguel", current_choice_data["choices"][choice_index])
	await get_tree().create_timer(1.0).timeout
	
	# Show the response
	dialogue_ui.show_dialogue_line("Boy Trip", response)
	waiting_for_next = true
	
	print("✅ Choice selected:", choice_index, "Response:", response)

func _on_next_pressed():
	if waiting_for_next:
		waiting_for_next = false
		current_line += 1
		show_next_line()

func end_scene():
	print("🏁 Detention cell scene ended")
	# Transition to next scene or enable player control
	if "control_enabled" in player:
		player.control_enabled = true
