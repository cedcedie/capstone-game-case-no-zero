extends Node

# --- Node references ---
var dialogue_ui: CanvasLayer = null  # Will reference global DialogueUI autoload
@onready var animation_player: AnimationPlayer = $AnimationPlayer

# --- Task Manager reference ---
var task_manager: Node = null

# --- Dialogue data ---
var dialogue_lines: Array = []

# --- Scene state ---
var cutscene_played: bool = false

# --------------------------
# INITIALIZATION
# --------------------------
func _ready():
	print("🔍 Alley Manager: _ready() called")
	
	# Get references to autoloads
	dialogue_ui = get_node_or_null("/root/DialogueUI")
	task_manager = get_node_or_null("/root/TaskManager")
	
	if not dialogue_ui:
		print("⚠️ Alley Manager: DialogueUI autoload not found")
	if not task_manager:
		print("⚠️ Alley Manager: TaskManager autoload not found")
	
	# No need to connect to dialogue UI signals since we use timed dialogue
	
	# Connect to AnimationPlayer signals
	if animation_player:
		animation_player.connect("animation_finished", Callable(self, "_on_animation_finished"))
		print("✅ Alley Manager: Connected to AnimationPlayer signals")
	
	# Check if cutscene should play
	_check_cutscene_conditions()

# --------------------------
# CUTSCENE CONDITIONS
# --------------------------
func _check_cutscene_conditions():
	"""Check if the alley cutscene should play"""
	# Add your conditions here - for example:
	# - Check if player has completed certain tasks
	# - Check if this is the first time entering the alley
	# - Check checkpoint states
	
	# For now, let's assume it should play if not already played
	if not cutscene_played:
		# Add a small delay to ensure everything is loaded
		await get_tree().create_timer(0.5).timeout
		start_alley_cutscene()

# --------------------------
# CUTSCENE START
# --------------------------
func start_alley_cutscene() -> void:
	print("🎬 Alley cutscene starting...")
	cutscene_played = true
	load_dialogue()

	# Enable cutscene mode for DialogueUI (hide Next)
	if dialogue_ui and dialogue_ui.has_method("set_cutscene_mode"):
		dialogue_ui.set_cutscene_mode(true)

	# Start the single animation - dialogue will be triggered by Method Call tracks
	if animation_player and animation_player.has_animation("alley_cutscene"):
		animation_player.play("alley_cutscene")
		print("🎬 Started alley_cutscene animation")
	else:
		print("⚠️ No alley_cutscene animation found")
		# Fallback: show first dialogue directly
		show_dialogue_for_line(0)

# Removed setup_initial_positions() since there are no characters in the scene

# --------------------------
# DIALOGUE LOADING
# --------------------------
func load_dialogue():
	"""Load dialogue from JSON file"""
	var file: FileAccess = FileAccess.open("res://data/dialogues/alley_dialogue.json", FileAccess.READ)
	if not file:
		push_error("Cannot open res://data/dialogues/alley_dialogue.json")
		return

	var data = file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(data)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Alley dialogue JSON is not a dictionary")
		return

	# Extract dialogue lines
	var dialogue_data = parsed.get("alley_investigation", {})
	dialogue_lines = dialogue_data.get("dialogue_lines", [])
	
	print("✅ Alley Manager: Loaded", dialogue_lines.size(), "dialogue lines")

# --------------------------
# DIALOGUE SEQUENCE (Simplified for single animation)
# --------------------------
# This function is no longer needed since we use Method Call tracks
# func show_next_line() -> void:

# --------------------------
# ANIMATION HELPERS (Simplified)
# --------------------------
# Animation helpers removed since we use single animation with Method Call tracks

# --------------------------
# DIALOGUE DISPLAY
# --------------------------
func show_dialogue_with_transition(speaker: String, text: String) -> void:
	"""Show dialogue with smooth transition"""
	if not dialogue_ui:
		print("⚠️ Alley Manager: DialogueUI not available")
		return
	
	# Show dialogue
	dialogue_ui.show_dialogue_line(speaker, text)
	print("🗨️ Alley: Showing dialogue -", speaker, ":", text)

func show_dialogue_with_timer(line_index: int, duration: float) -> void:
	"""Show dialogue for a specific duration, then auto-hide"""
	if line_index >= dialogue_lines.size():
		end_cutscene()
		return
	
	var line: Dictionary = dialogue_lines[line_index]
	var speaker: String = String(line.get("speaker", ""))
	var text: String = String(line.get("text", ""))
	
	print("🗨️ Alley: Showing timed dialogue -", speaker, ":", text)
	
	# Show dialogue
	dialogue_ui.show_dialogue_line(speaker, text)
	
	# Auto-hide after duration
	await get_tree().create_timer(duration).timeout
	dialogue_ui.hide_ui()
	print("🗨️ Alley: Dialogue auto-hidden after", duration, "seconds")

# --------------------------
# ANIMATION PLAYER SIGNALS
# --------------------------
func _on_animation_finished(animation_name: String) -> void:
	"""Handle when AnimationPlayer animation finishes"""
	print("🎬 Animation finished:", animation_name)
	
	# When the main cutscene animation finishes, end the cutscene
	if animation_name == "alley_cutscene":
		end_cutscene()

# --------------------------
# ANIMATION PLAYER CALLBACKS (for direct calls from AnimationPlayer)
# --------------------------
func show_dialogue_line_0() -> void:
	"""Called directly from AnimationPlayer track"""
	show_dialogue_with_timer(0, 3.0)

func show_dialogue_line_1() -> void:
	"""Called directly from AnimationPlayer track"""
	show_dialogue_with_timer(1, 3.0)

func show_dialogue_line_2() -> void:
	"""Called directly from AnimationPlayer track"""
	show_dialogue_with_timer(2, 3.0)

func show_dialogue_line_3() -> void:
	"""Called directly from AnimationPlayer track"""
	show_dialogue_with_timer(3, 3.0)

func show_dialogue_line_4() -> void:
	"""Called directly from AnimationPlayer track"""
	show_dialogue_with_timer(4, 3.0)

func show_dialogue_line_5() -> void:
	"""Called directly from AnimationPlayer track"""
	show_dialogue_with_timer(5, 3.0)

func show_dialogue_line_6() -> void:
	"""Called directly from AnimationPlayer track"""
	show_dialogue_with_timer(6, 3.0)

func show_dialogue_line_7() -> void:
	"""Called directly from AnimationPlayer track"""
	show_dialogue_with_timer(7, 3.0)

func show_dialogue_line_8() -> void:
	"""Called directly from AnimationPlayer track"""
	show_dialogue_with_timer(8, 3.0)

func show_dialogue_line_9() -> void:
	"""Called directly from AnimationPlayer track"""
	show_dialogue_with_timer(9, 3.0)

func show_dialogue_line_10() -> void:
	"""Called directly from AnimationPlayer track"""
	show_dialogue_with_timer(10, 3.0)

# --------------------------
# CUTSCENE END
# --------------------------
func end_cutscene() -> void:
	"""End the alley cutscene"""
	print("🎬 Alley cutscene ending...")
	
	# Hide dialogue UI
	if dialogue_ui:
		dialogue_ui.hide_ui()
		if dialogue_ui.has_method("set_cutscene_mode"):
			dialogue_ui.set_cutscene_mode(false)
	
	# Mark task as completed if needed
	if task_manager:
		# Uncomment if you want to complete a task after this cutscene
		# task_manager.complete_current_task()
		pass
	
	print("✅ Alley cutscene completed")

# --------------------------
# INPUT HANDLING (for manual cutscene trigger)
# --------------------------
func _input(event):
	"""Handle input for manual cutscene triggering (for testing)"""
	# Press 'T' to manually trigger the cutscene (for testing)
	if event.is_action_pressed("ui_accept") and Input.is_key_pressed(KEY_T):
		if not cutscene_played:
			start_alley_cutscene()
