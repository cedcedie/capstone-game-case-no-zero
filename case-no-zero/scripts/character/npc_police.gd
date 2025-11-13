extends CharacterBody2D

# Node references
@onready var interaction_label: Label = $Label
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var interaction_area: Area2D = $Area2D

# Dialogue system
var dialogue_lines: Array = []
var dialogue_data: Dictionary = {}
var has_interacted: bool = false
var story_has_interacted: bool = false  # Track if story dialogue was used
var recollection_has_interacted: bool = false  # Track if recollection dialogue was used
var is_player_nearby: bool = false
var player_reference: Node2D = null
var is_in_dialogue: bool = false  # Prevent E key spam during dialogue

# Animation settings
var label_fade_duration: float = 0.3
var label_slide_offset: float = 10.0
var label_show_position: float = -72.0  # Position above the NPC's head

func _ready():
	# Hide label initially
	interaction_label.modulate = Color(1.0, 1.0, 0.0, 0.0)  # Yellow color, transparent initially
	interaction_label.position.y = label_show_position + label_slide_offset  # Start slightly lower
	interaction_label.text = "Press E to interact"
	
	# Connect Area2D signals
	if interaction_area:
		interaction_area.connect("body_entered", Callable(self, "_on_body_entered"))
		interaction_area.connect("body_exited", Callable(self, "_on_body_exited"))
	else:
	
	# Load dialogue
	load_dialogue()
	
	# Play idle animation
	if animated_sprite:
		animated_sprite.play("idle_front")

func _process(_delta):
	# Check for interaction input when player is nearby and not in dialogue
	if is_player_nearby and Input.is_action_just_pressed("interact") and not is_in_dialogue:
		interact()

func load_dialogue():
	var file: FileAccess = FileAccess.open("res://data/dialogues/npc_police_dialogue.json", FileAccess.READ)
	if file == null:
		push_error("Cannot open npc_police_dialogue.json")
		return
	
	var text: String = file.get_as_text()
	file.close()
	
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("npc_police"):
		push_error("Failed to parse npc_police_dialogue.json")
		return
	
	dialogue_data = parsed["npc_police"]

func _on_body_entered(body):
	if body.name == "PlayerM":
		is_player_nearby = true
		player_reference = body
		face_player(body.global_position)
		show_interaction_label()

func _on_body_exited(body):
	if body == player_reference:
		is_player_nearby = false
		player_reference = null
		restore_original_animation()  # Return to original pose when player leaves
		hide_interaction_label()

func show_interaction_label():
	# Slide up and fade in animation
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	
	tween.tween_property(interaction_label, "modulate", Color(1.0, 1.0, 0.0, 1.0), label_fade_duration)  # Yellow color, fully visible
	tween.tween_property(interaction_label, "position:y", label_show_position, label_fade_duration)

func hide_interaction_label():
	# Slide down and fade out animation
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_CUBIC)
	
	tween.tween_property(interaction_label, "modulate", Color(1.0, 1.0, 0.0, 0.0), label_fade_duration)  # Yellow color, transparent
	tween.tween_property(interaction_label, "position:y", label_show_position + label_slide_offset, label_fade_duration)

func face_player(player_position: Vector2):
	"""Make NPC face the player"""
	var direction = player_position - global_position
	
	if abs(direction.x) > abs(direction.y):
		# Player is more to the left or right
		if direction.x > 0:
			animated_sprite.play("idle_right")
		else:
			animated_sprite.play("idle_left")
	else:
		# Player is more above or below
		if direction.y > 0:
			animated_sprite.play("idle_front")
		else:
			animated_sprite.play("idle_back")

func restore_original_animation():
	"""Restore the NPC's original idle animation after dialogue"""
	animated_sprite.play("idle_front")

func interact():
	is_in_dialogue = true  # Prevent E key spam
	hide_interaction_label()
	
	# Disable player movement during dialogue
	if player_reference and player_reference.has_method("disable_movement"):
		player_reference.disable_movement()
	
	# Choose dialogue based on checkpoint state and interaction history
	var has_recollection: bool = CheckpointManager.has_checkpoint(CheckpointManager.CheckpointType.RECOLLECTION_COMPLETED)
	var has_office: bool = CheckpointManager.has_checkpoint(CheckpointManager.CheckpointType.OFFICE_CUTSCENE_COMPLETED)
	
	if has_recollection:
		# Recollection completed - use recollection dialogue
		if not recollection_has_interacted:
			# Hide station lobby nodes during or after first conversation (only after RECOLLECTION_COMPLETED)
			if CheckpointManager.has_checkpoint(CheckpointManager.CheckpointType.RECOLLECTION_COMPLETED):
				_hide_station_lobby_nodes()
			dialogue_lines = dialogue_data.get("recollection_completed", [])
			recollection_has_interacted = true
		else:
			dialogue_lines = dialogue_data.get("recollection_repeated", [])
	elif has_office and not has_recollection:
		# Only office completed - use story dialogue
		if not story_has_interacted:
			dialogue_lines = dialogue_data.get("story_first_interaction", [])
			story_has_interacted = true
		else:
			dialogue_lines = dialogue_data.get("story_repeated_interaction", [])
	else:
		# Default/modern dialogue
		if not has_interacted:
			dialogue_lines = dialogue_data.get("modern_first_interaction", [])
			has_interacted = true
		else:
			dialogue_lines = dialogue_data.get("modern_repeated_interaction", [])

	# Start showing dialogue
	if dialogue_lines.size() > 0:
		show_dialogue()
	else:
		is_in_dialogue = false  # Reset if no dialogue
		# Re-enable player movement if no dialogue - fully restore all processing
		if player_reference:
			# Re-enable processing mode first
			if "process_mode" in player_reference:
				player_reference.process_mode = Node.PROCESS_MODE_INHERIT
			else:
				if player_reference.has_method("set_process_mode"):
					player_reference.set_process_mode(Node.PROCESS_MODE_INHERIT)
			
			# Enable input/physics processing
			if player_reference.has_method("set_process_input"):
				player_reference.set_process_input(true)
			if player_reference.has_method("set_physics_process"):
				player_reference.set_physics_process(true)
			
			# Enable movement control
			if player_reference.has_method("enable_movement"):
				player_reference.enable_movement()
			
			# Enable control_enabled property
			if "control_enabled" in player_reference:
				player_reference.control_enabled = true
			
		else:

func show_dialogue():
	# Use the global DialogueUI autoload
	if not DialogueUI:
		return
	
	for line in dialogue_lines:
		var speaker = line.get("speaker", "")
		var text = line.get("text", "")
	
	# Show each dialogue line using the global DialogueUI
	for line in dialogue_lines:
		var speaker = line.get("speaker", "")
		var text = line.get("text", "")
		DialogueUI.show_dialogue_line(speaker, text)
		
		# Wait for player to press next
		await DialogueUI.next_pressed
	
	# Hide dialogue after all lines shown
	DialogueUI.hide_ui()
	
	# Reset cutscene mode in DialogueUI to allow normal input
	if DialogueUI and DialogueUI.has_method("set_cutscene_mode"):
		DialogueUI.set_cutscene_mode(false)
	
	# Reset dialogue state
	is_in_dialogue = false
	
	# Restore original animation after dialogue
	restore_original_animation()
	
	# Hide "Tanungin ang pulis" task display after talking to NPC police
	var has_recollection: bool = CheckpointManager.has_checkpoint(CheckpointManager.CheckpointType.RECOLLECTION_COMPLETED)
	if has_recollection and recollection_has_interacted:
		var task_display: Node = get_node_or_null("/root/TaskDisplay")
		if task_display == null:
			var tree := get_tree()
			if tree:
				var found := tree.get_first_node_in_group("task_display")
				if found:
					task_display = found
		if task_display != null and task_display.has_method("hide_task"):
			task_display.hide_task()
	
	# Reset cutscene mode in DialogueUI FIRST to allow normal input
	if DialogueUI and DialogueUI.has_method("set_cutscene_mode"):
		DialogueUI.set_cutscene_mode(false)
	
	# Re-enable player movement after dialogue - fully restore all processing
	# Try to get player reference if it's null
	if not player_reference:
		# Try to find player in scene
		var root_scene = get_tree().current_scene
		if root_scene:
			player_reference = root_scene.get_node_or_null("PlayerM")
			if not player_reference:
				# Try to find by name
				var found = root_scene.find_child("PlayerM", true, false)
				if found:
					player_reference = found
	
	if player_reference:
		
		# Force enable processing mode - ensure it's not INHERIT if parent is disabled
		if "process_mode" in player_reference:
			var current_mode = player_reference.process_mode
			# Use PROCESS_MODE_PAUSABLE or PROCESS_MODE_ALWAYS to ensure it works
			player_reference.process_mode = Node.PROCESS_MODE_INHERIT
		
		# Enable input/physics processing - CRITICAL
		if player_reference.has_method("set_process_input"):
			player_reference.set_process_input(true)
		if player_reference.has_method("set_physics_process"):
			player_reference.set_physics_process(true)
		
		# Enable movement control - call enable_movement() which sets control_enabled
		if player_reference.has_method("enable_movement"):
			player_reference.enable_movement()
		
		# Force set control_enabled to true - make absolutely sure
		if "control_enabled" in player_reference:
			player_reference.control_enabled = true
		
		# Wait a frame to ensure everything is applied
		await get_tree().process_frame
		
		# Final check
		var final_control = player_reference.get("control_enabled") if "control_enabled" in player_reference else "N/A"
		var final_mode = player_reference.get("process_mode") if "process_mode" in player_reference else "N/A"
		var final_process_input = player_reference.get_process_input() if player_reference.has_method("get_process_input") else "N/A"
		var final_physics = player_reference.get_physics_process() if player_reference.has_method("get_physics_process") else "N/A"
	else:
	
	# Show the label again if player is still nearby
	if is_player_nearby:
		show_interaction_label()

func _hide_station_lobby_nodes() -> void:
	# Hide station_lobby and StationLobby2 and disable their collision
	# These are direct children of the scene root
	var root_scene := get_tree().current_scene
	if root_scene == null:
		return
	
	# Hide station_lobby and disable collision
	var station_lobby := root_scene.get_node_or_null("station_lobby")
	if station_lobby != null:
		if station_lobby is CanvasItem:
			(station_lobby as CanvasItem).visible = false
		_set_node_collision_enabled(station_lobby, false)
	else:
	
	# Hide StationLobby2 and disable collision
	var station_lobby2 := root_scene.get_node_or_null("StationLobby2")
	if station_lobby2 != null:
		if station_lobby2 is CanvasItem:
			(station_lobby2 as CanvasItem).visible = false
		_set_node_collision_enabled(station_lobby2, false)
	else:

func _set_node_collision_enabled(node: Node, enabled: bool) -> void:
	# Recursively disable/enable all CollisionShape2D nodes within the given node
	if node == null:
		return
	var stack: Array = [node]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		for child in n.get_children():
			stack.push_back(child)
			if child is CollisionShape2D:
				(child as CollisionShape2D).disabled = not enabled
