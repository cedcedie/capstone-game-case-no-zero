extends CharacterBody2D

# ============================================
# REUSABLE NPC INTERACTION SCRIPT
# ============================================
# 
# CONFIGURATION - CHANGE THESE FOR EACH NPC:
# - dialogue_file_path: Path to your dialogue JSON file
# - dialogue_key: The key in the JSON file
# - default_idle_animation: The default idle animation to restore (e.g., "idle_front", "idle_back", etc.)
#
# ============================================

# ============================================
# CONFIGURATION - CHANGE THESE FOR EACH NPC
# ============================================
@export var dialogue_file_path: String = "res://data/npc/npc_em7_dialogue.json"
@export var dialogue_key: String = "npc_em7"
@export var default_idle_animation: String = "idle_left"  # Animation to restore when player leaves

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
	print("🔍 NPC Interaction: _ready() called for ", dialogue_key)
	# Hide label initially
	interaction_label.modulate = Color(1.0, 1.0, 0.0, 0.0)  # Yellow color, transparent initially
	interaction_label.position.y = label_show_position + label_slide_offset  # Start slightly lower
	interaction_label.text = "Press E to interact"
	
	# Connect Area2D signals
	if interaction_area:
		# Make sure Area2D doesn't detect itself (the NPC's CharacterBody2D)
		# Set collision layers/masks appropriately
		interaction_area.monitoring = true
		interaction_area.monitorable = false  # Don't let other areas detect this
		
		# Verify Area2D has its own CollisionShape2D (not the body's collision)
		var area_collision = interaction_area.get_node_or_null("CollisionShape2D")
		if area_collision == null:
			print("⚠️ NPC Interaction: Area2D has no CollisionShape2D child! Add one in the scene.")
		else:
			print("🔍 NPC Interaction: Area2D CollisionShape2D found")
		
		# IMPORTANT: Make sure the Area2D's collision mask doesn't include the NPC's own layer
		# The Area2D should only detect the player's collision layer
		# In the scene, set:
		# - Area2D Collision Mask: Only the player's layer (e.g., layer 1)
		# - CharacterBody2D Collision Layer: Different layer (e.g., layer 2)
		# This prevents the Area2D from detecting the NPC's own CharacterBody2D collision
		
		# Connect signals
		interaction_area.connect("body_entered", Callable(self, "_on_body_entered"))
		interaction_area.connect("body_exited", Callable(self, "_on_body_exited"))
		print("🔍 NPC Interaction: Area2D signals connected (monitoring: ", interaction_area.monitoring, ")")
	else:
		print("⚠️ NPC Interaction: No Area2D found!")
	
	# Load dialogue
	load_dialogue()
	
	# Play default idle animation
	if animated_sprite:
		animated_sprite.play(default_idle_animation)
		print("🔍 NPC Interaction: Animation started with ", default_idle_animation)

func _process(_delta):
	# Check for interaction input when player is nearby and not in dialogue
	if is_player_nearby and Input.is_action_just_pressed("interact") and not is_in_dialogue:
		interact()

func load_dialogue():
	var file: FileAccess = FileAccess.open(dialogue_file_path, FileAccess.READ)
	if file == null:
		push_error("Cannot open dialogue file: " + dialogue_file_path)
		return
	
	var text: String = file.get_as_text()
	file.close()
	
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has(dialogue_key):
		push_error("Failed to parse dialogue file or missing key: " + dialogue_key)
		return
	
	dialogue_data = parsed[dialogue_key]
	print("✅ Loaded dialogue for ", dialogue_key)

func _on_body_entered(body):
	print("🔍 NPC Interaction: Body entered - ", body.name)
	if body.name == "PlayerM" and body is CharacterBody2D and body != self:
		is_player_nearby = true
		player_reference = body
		show_interaction_label()
		print("👮 Player near NPC: ", dialogue_key)

func _on_body_exited(body):
	if body == player_reference:
		is_player_nearby = false
		player_reference = null
		restore_original_animation()  # Return to original pose when player leaves
		hide_interaction_label()
		print("👮 Player left NPC: ", dialogue_key)

func show_interaction_label():
	print("🔍 NPC Interaction: Showing interaction label")
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
	if not animated_sprite:
		return
	
	# Try using sprite center positions instead of node origins
	# NPC position (accounting for sprite offset)
	var npc_sprite_pos = global_position
	if animated_sprite:
		npc_sprite_pos += animated_sprite.position
	
	# Player position (try to get sprite center if possible)
	var player_pos = player_position
	if player_reference and player_reference.has_node("AnimatedSprite2D"):
		var player_sprite = player_reference.get_node("AnimatedSprite2D")
		if player_sprite:
			player_pos = player_reference.global_position + player_sprite.position
	
	var direction = player_pos - npc_sprite_pos
	
	# Check if sprite_frames exists
	if not animated_sprite.sprite_frames:
		return
	
	var target_anim = ""
	if abs(direction.x) > abs(direction.y):
		# Player is more to the left or right
		if direction.x > 0:
			target_anim = "idle_right"
		else:
			target_anim = "idle_left"
	else:
		# Player is more above or below
		if direction.y > 0:
			target_anim = "idle_front"
		else:
			target_anim = "idle_back"
	
	# Check if animation exists before playing
	if animated_sprite.sprite_frames.has_animation(target_anim):
		animated_sprite.play(target_anim)
		animated_sprite.frame = 0

func restore_original_animation():
	"""Restore the NPC's original idle animation after dialogue"""
	animated_sprite.play(default_idle_animation)

func interact():
	print("💬 Interacting with NPC: ", dialogue_key)
	is_in_dialogue = true  # Prevent E key spam
	hide_interaction_label()
	
	# Face the player when they press E (based on their position at that moment)
	if player_reference:
		face_player(player_reference.global_position)
	else:
		# Try to find player manually using the same method as other scripts
		var player = null
		var root_scene = get_tree().current_scene
		if root_scene:
			player = root_scene.get_node_or_null("PlayerM")
		if player == null:
			player = get_tree().get_first_node_in_group("player")
		if player == null and root_scene:
			var candidates = root_scene.find_children("*", "", true, false)
			for n in candidates:
				if String(n.name).to_lower().contains("playerm") or String(n.name).to_lower().contains("player"):
					player = n
					break
		if player:
			player_reference = player  # Store it for future use
			face_player(player.global_position)
	
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
	print("📋 NPC DIALOGUE (", dialogue_key, "):")
	for line in dialogue_lines:
		var speaker = line.get("speaker", "")
		var text = line.get("text", "")
		print(speaker + ": " + text)
	print("==================================================")
	
	# Show each dialogue line using the global DialogueUI
	for line in dialogue_lines:
		var speaker = line.get("speaker", "")
		var text = line.get("text", "")
		DialogueUI.show_dialogue_line(speaker, text, false, dialogue_key)
		
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
