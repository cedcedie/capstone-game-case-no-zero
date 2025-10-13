extends Node

# --- Node references ---
var dialogue_ui: CanvasLayer = null  # Will reference global DialogueUI autoload
var dialog_chooser: CanvasLayer = null  # Will reference DialogChooser autoload
@onready var player: CharacterBody2D = $PlayerM
@onready var celine: CharacterBody2D = $celine
@onready var boy_trip: CharacterBody2D = $erwin
@onready var guard: CharacterBody2D = $station_guard
@onready var guard_2: CharacterBody2D = $station_guard_2
@onready var guard_3: CharacterBody2D = $station_guard_3
@onready var police_lobby_trigger: Area2D = $Area2D_police_lobby

# --- Task Manager reference ---
var task_manager: Node = null

# --- Dialogue data ---
var dialogue_lines: Array = []
var miguel_choices: Array = []
var current_line: int = 0
var waiting_for_next: bool = false

# --- Choice system ---
var current_choice_data: Dictionary = {}
var waiting_for_choice: bool = false

# --- Scene state ---
var cutscene_played: bool = false
# --- Movement and transition tuning ---
@export var walk_speed: float = 200.0
@export var fade_duration: float = 1.2
@export var text_fade_duration: float = 0.8
@export var transition_pause: float = 0.3
var current_tween: Tween
var is_first_visit: bool = true

# --------------------------
# DIALOGUE LOADING
# --------------------------
func load_dialogue() -> void:
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

# --------------------------
# CHOICE SYSTEM
# --------------------------
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


# --------------------------
# CUTSCENE START
# --------------------------
func start_detention_scene() -> void:
	print("🎬 Detention cell scene starting...")
	load_dialogue()

	# Disable player control
	if player and "control_enabled" in player:
		player.control_enabled = false

	# Setup initial character positions
	setup_initial_positions()
	
	# Start dialogue sequence
	show_next_line()

func setup_initial_positions() -> void:
	print("🎭 Setting up initial character positions...")
	
	# Station guard 3 - idle_right (same position as placed)
	if guard_3 and guard_3.get_node_or_null("AnimatedSprite2D"):
		guard_3.get_node("AnimatedSprite2D").play("idle_right")
	
	# PlayerM - idle_right at 1112.0, 368.0
	if player:
		player.global_position = Vector2(1112.0, 368.0)
		if player.get_node_or_null("AnimatedSprite2D"):
			player.get_node("AnimatedSprite2D").play("idle_right")
	
	# Celine - idle_left at 1112.0, 400.0
	if celine:
		celine.global_position = Vector2(1112.0, 400.0)
		if celine.get_node_or_null("AnimatedSprite2D"):
			celine.get_node("AnimatedSprite2D").play("idle_left")

# --------------------------
# HELPER FUNCTIONS
# --------------------------
func smooth_fade_in(node: CanvasItem, duration: float = fade_duration) -> void:
	if current_tween:
		current_tween.kill()
	current_tween = create_tween()
	current_tween.set_ease(Tween.EASE_IN_OUT)
	current_tween.set_trans(Tween.TRANS_CUBIC)
	node.modulate.a = 0.0
	node.visible = true
	current_tween.tween_property(node, "modulate:a", 1.0, duration)

func smooth_fade_out(node: CanvasItem, duration: float = fade_duration) -> void:
	if current_tween:
		current_tween.kill()
	current_tween = create_tween()
	current_tween.set_ease(Tween.EASE_IN_OUT)
	current_tween.set_trans(Tween.TRANS_CUBIC)
	current_tween.tween_property(node, "modulate:a", 0.0, duration)
	await current_tween.finished
	node.visible = false

func play_character_animation(character: CharacterBody2D, animation: String, duration: float = transition_pause) -> void:
	if not character:
		return
		
	if character.get_node_or_null("AnimatedSprite2D"):
		character.get_node("AnimatedSprite2D").play(animation)
		await get_tree().create_timer(duration).timeout

func move_character_smoothly(character: CharacterBody2D, target_pos: Vector2, walk_animation: String = "walk_down", idle_animation: String = "idle_right") -> void:
	if not character:
		return
		
	var start_pos: Vector2 = character.position
	var distance: float = start_pos.distance_to(target_pos)
	var duration: float = distance / walk_speed
	
	# Play walk animation
	play_character_animation(character, walk_animation)
	
	# Move character
	var t: Tween = create_tween()
	t.set_ease(Tween.EASE_IN_OUT)
	t.tween_property(character, "position", target_pos, duration)
	await t.finished
	
	# Play idle animation
	play_character_animation(character, idle_animation)

func show_dialogue_with_transition(speaker: String, text: String, hide_first: bool = false) -> void:
	if hide_first:
		await dialogue_ui.hide_ui()
		await get_tree().create_timer(transition_pause).timeout
	
	if dialogue_ui:
		dialogue_ui.show_dialogue_line(speaker, text)
		waiting_for_next = true

# --------------------------
# DIALOGUE SEQUENCE
# --------------------------
func show_next_line() -> void:
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

	# Organized by scene beats for better readability
	match current_line:
		# Opening lines - characters in initial positions
		0, 1:
			await play_character_animation(player, "idle_right", transition_pause)
			show_dialogue_with_transition(speaker, text)

		# Character movement sequence
		2:
			# Hide dialogue during movement
			if dialogue_ui:
				dialogue_ui.hide()
			
			# Miguel's movement sequence
			# Miguel: walk_down to 1112.0, 496.0
			await move_character_smoothly(player, Vector2(1112.0, 496.0), "walk_down", "idle_back")
			# Miguel: walk_left to 520.0, 496.0
			await move_character_smoothly(player, Vector2(520.0, 496.0), "walk_left", "idle_back")
			
			# Celine's movement with 0.3s delay
			await get_tree().create_timer(0.3).timeout
			# Celine: walk_down to 1112.0, 496.0
			await move_character_smoothly(celine, Vector2(1112.0, 496.0), "walk_down", "idle_back")
			# Celine: walk_left to 560.0, 496.0
			await move_character_smoothly(celine, Vector2(560.0, 496.0), "walk_left", "idle_back")
			
			show_dialogue_with_transition(speaker, text, true)

		# Default: Regular dialogue for other lines
		_:
			show_dialogue_with_transition(speaker, text)

# --------------------------
# INPUT HANDLING
# --------------------------
func _on_next_pressed() -> void:
	if waiting_for_next:
		waiting_for_next = false
		current_line += 1
		show_next_line()

# --------------------------
# SCENE END
# --------------------------
func end_scene():
	print("🏁 Detention cell scene ended")
	# Transition to next scene or enable player control
	if player and "control_enabled" in player:
		player.control_enabled = true


# --------------------------
# INITIALIZATION
# --------------------------
func _ready() -> void:
	await get_tree().process_frame
	
	# Debug: Print all children to see what's available
	print("🔍 Scene children:")
	for child in get_children():
		print("  - ", child.name, " (", child.get_class(), ")")
	
	print("🔍 Found nodes - Player:", player != null, "Celine:", celine != null, "BoyTrip:", boy_trip != null, "Guard:", guard != null, "Guard2:", guard_2 != null, "Guard3:", guard_3 != null, "PoliceLobbyTrigger:", police_lobby_trigger != null)
	
	# Get TaskManager autoload
	if has_node("/root/TaskManager"):
		task_manager = get_node("/root/TaskManager")
		print("✅ TaskManager connected")
	else:
		print("⚠️ TaskManager autoload not found - task system disabled")
	
	# Get autoload references
	if has_node("/root/DialogueUI"):
		dialogue_ui = get_node("/root/DialogueUI")
		print("✅ DialogueUI connected")
	else:
		print("⚠️ DialogueUI autoload not found - dialogue system disabled")
	
	# Get DialogChooser autoload
	if has_node("/root/DialogChooser"):
		dialog_chooser = get_node("/root/DialogChooser")
		print("✅ DialogChooser connected")
		# Connect choice signal
		dialog_chooser.choice_selected.connect(_on_choice_selected)
	else:
		print("⚠️ DialogChooser autoload not found - choice system disabled")
	
	# Connect dialogue UI signals
	if dialogue_ui:
		var cb: Callable = Callable(self, "_on_next_pressed")
		if not dialogue_ui.is_connected("next_pressed", cb):
			dialogue_ui.connect("next_pressed", cb)
	
	print("🟢 Scene ready — starting cutscene...")
	start_detention_scene()
