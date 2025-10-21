extends CharacterBody2D

# Node references
@onready var interaction_label: Label = $Label
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var interaction_area: Area2D = $Area2D

# Dialogue system
var dialogue_lines: Array = []
var dialogue_data: Dictionary = {}
var has_interacted: bool = false
var is_player_nearby: bool = false
var player_reference: Node2D = null
var is_in_dialogue: bool = false  # Prevent E key spam during dialogue

# Animation settings
var label_fade_duration: float = 0.3
var label_slide_offset: float = 10.0
var label_show_position: float = -72.0  # Position above the NPC's head

func _ready():
	print("🔍 station_guard_3: _ready() called")
	# Hide label initially
	interaction_label.modulate = Color(1.0, 1.0, 0.0, 0.0)  # Yellow color, transparent initially
	interaction_label.position.y = label_show_position + label_slide_offset  # Start slightly lower
	interaction_label.text = "Press E to interact"
	
	# Connect Area2D signals
	if interaction_area:
		interaction_area.connect("body_entered", Callable(self, "_on_body_entered"))
		interaction_area.connect("body_exited", Callable(self, "_on_body_exited"))
		print("🔍 station_guard_3: Area2D signals connected")
	else:
		print("⚠️ station_guard_3: No Area2D found!")
	
	# Load dialogue
	load_dialogue()
	
	# Play idle animation
	if animated_sprite:
		animated_sprite.play("idle_right")
		print("🔍 station_guard_3: Animation started")

func _process(_delta):
	# Check for interaction input when player is nearby and not in dialogue
	if is_player_nearby and Input.is_action_just_pressed("interact") and not is_in_dialogue:
		interact()

func load_dialogue():
	var file: FileAccess = FileAccess.open("res://data/dialogues/station_guard_3_dialogue.json", FileAccess.READ)
	if file == null:
		push_error("Cannot open station_guard_3_dialogue.json")
		return
	
	var text: String = file.get_as_text()
	file.close()
	
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("station_guard_3"):
		push_error("Failed to parse station_guard_3 dialogue")
		return
	
	dialogue_data = parsed["station_guard_3"]
	print("✅ Loaded Station Guard 3 dialogue")

func _on_body_entered(body):
	print("🔍 station_guard_3: Body entered - ", body.name)
	if body.name == "PlayerM":
		is_player_nearby = true
		player_reference = body
		face_player(body.global_position)
		show_interaction_label()
		print("👮 Player near station guard 3")

func _on_body_exited(body):
	if body == player_reference:
		is_player_nearby = false
		player_reference = null
		restore_original_animation()  # Return to original pose when player leaves
		hide_interaction_label()
		print("👮 Player left station guard 3")

func show_interaction_label():
	print("🔍 station_guard_3: Showing interaction label")
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
	animated_sprite.play("idle_right")

func interact():
	print("💬 Interacting with station guard 3")
	is_in_dialogue = true  # Prevent E key spam
	hide_interaction_label()
	
	# Disable player movement during dialogue
	if player_reference and player_reference.has_method("disable_movement"):
		player_reference.disable_movement()
	
	# Choose dialogue based on interaction history
	if not has_interacted:
		dialogue_lines = dialogue_data.get("first_interaction", [])
		has_interacted = true
	else:
		dialogue_lines = dialogue_data.get("repeated_interaction", [])
	
	# Start showing dialogue
	if dialogue_lines.size() > 0:
		show_dialogue()
	else:
		print("⚠️ No dialogue lines loaded")
		is_in_dialogue = false  # Reset if no dialogue
		# Re-enable player movement if no dialogue
		if player_reference and player_reference.has_method("enable_movement"):
			player_reference.enable_movement()

func show_dialogue():
	if not DialogueUI:
		print("⚠️ DialogueUI autoload not found")
		return
	
	print("==================================================")
	print("📋 STATION GUARD 3 DIALOGUE:")
	for line in dialogue_lines:
		var speaker = line.get("speaker", "")
		var text = line.get("text", "")
		print(speaker + ": " + text)
	print("==================================================")
	
	# Show each dialogue line using the global DialogueUI
	for line in dialogue_lines:
		var speaker = line.get("speaker", "")
		var text = line.get("text", "")
		DialogueUI.show_dialogue_line(speaker, text)
		
		# Wait for player to press next
		await DialogueUI.next_pressed
	
	# Hide dialogue after all lines shown
	DialogueUI.hide_ui()
	
	# Reset dialogue state
	is_in_dialogue = false
	
	# Restore original animation after dialogue
	restore_original_animation()
	
	# Re-enable player movement after dialogue
	if player_reference and player_reference.has_method("enable_movement"):
		player_reference.enable_movement()
	
	# Show the label again if player is still nearby
	if is_player_nearby:
		show_interaction_label()
