extends Node

# --- Node references ---
var dialogue_ui: CanvasLayer = null  # Will reference global DialogueUI autoload
var dialog_chooser: CanvasLayer = null  # Will reference DialogChooser autoload
var player: CharacterBody2D = null
var celine: CharacterBody2D = null
var kapitana: CharacterBody2D = null
var barangay_npc: CharacterBody2D = null
var camera: Camera2D = null

# --- Task Manager reference ---
var task_manager: Node = null
var checkpoint_manager: Node = null

# --- Dialogue data ---
var dialogue_lines: Array = []
var miguel_choices: Array = []
var current_line: int = 0
var waiting_for_next: bool = false

# --- Choice system ---
var current_choice_data: Dictionary = {}
var waiting_for_choice: bool = false
var choice_completed: bool = false

# --- Scene state ---
var cutscene_played: bool = false
var evidence_collection_phase: bool = false

# --- Movement and transition tuning ---
@export var walk_speed: float = 200.0
@export var fade_duration: float = 1.2
@export var text_fade_duration: float = 0.8
@export var transition_pause: float = 0.3
@export var camera_zoom_duration: float = 1.5
var current_tween: Tween

# --------------------------
# DIALOGUE LOADING
# --------------------------
func load_dialogue() -> void:
	var file: FileAccess = FileAccess.open("res://data/dialogues/barangay_hall_investigation_dialogue.json", FileAccess.READ)
	if file == null:
		push_error("Cannot open barangay_hall_investigation_dialogue.json")
		return

	var text: String = file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Failed to parse barangay_hall_investigation_dialogue.json")
		return

	dialogue_lines = parsed["barangay_hall_investigation"]["dialogue_lines"]
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
	choice_completed = false
	
	# Show the choice UI
	dialog_chooser.show_choices(choice_data["choices"])
	
	print("🎯 Showing Miguel choice:", choice_data["choices"])

func _on_choice_selected(choice_index: int):
	"""Handle when player selects a choice"""
	if not waiting_for_choice:
		return
	
	waiting_for_choice = false
	choice_completed = true
	
	# Get the response for the selected choice
	var response = current_choice_data["responses"][choice_index]
	
	# Show Miguel's choice as dialogue
	dialogue_ui.show_dialogue_line("Miguel", current_choice_data["choices"][choice_index])
	await get_tree().create_timer(1.0).timeout
	
	# Show the response
	dialogue_ui.show_dialogue_line("Kapitana Lourdes", response)
	waiting_for_next = true
	
	print("✅ Choice selected:", choice_index, "Response:", response)

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
		print("❌ Character not found for animation:", animation)
		return
		
	var anim_sprite = character.get_node_or_null("AnimatedSprite2D")
	if anim_sprite:
		print("🎭 Playing animation:", animation, "on character:", character.name)
		anim_sprite.play(animation)
		# Remove await to prevent timing conflicts when multiple characters animate
		# await get_tree().create_timer(duration).timeout
	else:
		print("❌ AnimatedSprite2D not found on character:", character.name)

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

func tween_camera_zoom(target_zoom: float) -> void:
	"""Tween camera zoom to target value"""
	if not camera:
		return
	
	var zoom_tween = create_tween()
	zoom_tween.set_ease(Tween.EASE_IN_OUT)
	zoom_tween.set_trans(Tween.TRANS_CUBIC)
	zoom_tween.tween_property(camera, "zoom", Vector2(target_zoom, target_zoom), camera_zoom_duration)

func show_evidence_collected() -> void:
	"""Show evidence collected using TaskManager"""
	print("📋 Showing evidence collected via TaskManager")
	
	# Show evidence collection in task display
	if task_manager and task_manager.task_display:
		task_manager.task_display.show_task("2 Evidence Items Collected!\nHandwriting Sample\nLogbook")
		print("📋 Evidence collection shown in task display (2 items)")
	else:
		print("⚠️ TaskManager or TaskDisplay not available")

func _input(event):
	"""Handle evidence inventory input during cutscene"""
	if event.is_action_pressed("evidence_inventory"):
		# Only handle during evidence collection phase (line 12 exception)
		if evidence_collection_phase:
			# Allow inventory access during evidence collection phase
			if has_node("/root/EvidenceInventorySettings"):
				var evidence_ui = get_node("/root/EvidenceInventorySettings")
				
				if evidence_ui.is_visible:
					# Close evidence inventory and wait for animation to complete
					await evidence_ui.hide_evidence_inventory()
					print("📋 Evidence inventory closed")
					
					# Show dialogue after inventory is completely closed
					if dialogue_ui:
						dialogue_ui.show()
						print("📋 Dialogue shown after inventory closed")
					
					# End evidence collection phase
					evidence_collection_phase = false
					print("📋 Evidence collection phase ended")
				else:
					# Hide dialogue when showing inventory
					if dialogue_ui:
						dialogue_ui.hide()
						print("📋 Dialogue hidden for inventory")
					
					# Hide task display
					if task_manager and task_manager.task_display:
						task_manager.task_display.hide_task()
						print("📋 Task display hidden")
					
					# Show evidence inventory
					evidence_ui.show_evidence_inventory()
					print("📋 Evidence inventory shown")
			
			# Consume the input so it doesn't trigger the global handler
			get_viewport().set_input_as_handled()

func find_character_references():
	"""Find character references from the scene root"""
	var scene_root = get_tree().current_scene
	
	# Find PlayerM
	player = scene_root.get_node_or_null("PlayerM")
	if not player:
		player = scene_root.get_node_or_null("Player")
	
	# Find Celine
	celine = scene_root.get_node_or_null("celine")
	if not celine:
		celine = scene_root.get_node_or_null("Celine")
	
	# Find Kapitana
	kapitana = scene_root.get_node_or_null("KapitanaPalma")
	if not kapitana:
		kapitana = scene_root.get_node_or_null("kapitanaPalma")
	
	# Find Barangay NPC
	barangay_npc = scene_root.get_node_or_null("barangay_npc")
	
	# Find Camera
	if player:
		camera = player.get_node_or_null("Camera2D")
	
	print("🔍 Character references found:")
	print("  - player:", player != null, "name:", player.name if player else "null")
	print("  - celine:", celine != null, "name:", celine.name if celine else "null")
	print("  - kapitana:", kapitana != null, "name:", kapitana.name if kapitana else "null")
	print("  - barangay_npc:", barangay_npc != null, "name:", barangay_npc.name if barangay_npc else "null")
	print("  - camera:", camera != null)

func _ready():
	print("🏛️ Barangay Hall Manager: _ready() called")
	
	# Get managers
	task_manager = get_node("/root/TaskManager")
	checkpoint_manager = get_node("/root/CheckpointManager")
	
	# Find character references from scene root
	find_character_references()
	
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
	
	# ============================================================
	# DEBUG MODE: Comment/uncomment these lines to control debugging
	# ============================================================
	
	# Option 1: Clear ALL checkpoints to test from bedroom scene start
	# Uncomment this to test the full game flow: bedroom → lower level → police lobby → barangay hall
	checkpoint_manager.checkpoints.clear()
	print("🔄 DEBUG MODE: ALL CHECKPOINTS CLEARED - Starting from beginning")
	print("🔄 DEBUG: Test flow: bedroom → lower level → police lobby → barangay hall")
	
	# Option 2: Auto-complete prerequisites to test barangay hall scene only
	# Uncomment these lines to jump directly to barangay hall cutscene
	# checkpoint_manager.set_checkpoint(CheckpointManager.CheckpointType.POLICE_LOBBY_CUTSCENE_COMPLETED)
	# checkpoint_manager.set_checkpoint(CheckpointManager.CheckpointType.BARANGAY_HALL_ACCESS_GRANTED)
	# checkpoint_manager.clear_checkpoint(CheckpointManager.CheckpointType.BARANGAY_HALL_CUTSCENE_COMPLETED)
	# print("🔄 DEBUG MODE: Barangay hall checkpoint cleared for replay")
	
	print("🔄 DEBUG: Current checkpoints:", checkpoint_manager.checkpoints)
	
	# Check if cutscene already played
	var cutscene_already_played = checkpoint_manager.has_checkpoint(CheckpointManager.CheckpointType.BARANGAY_HALL_CUTSCENE_COMPLETED)
	
	print("🔍 Barangay Hall Manager Debug:")
	print("  - cutscene_already_played:", cutscene_already_played)
	print("  - police_lobby_completed:", checkpoint_manager.has_checkpoint(CheckpointManager.CheckpointType.POLICE_LOBBY_CUTSCENE_COMPLETED))
	print("  - barangay_access_granted:", checkpoint_manager.has_checkpoint(CheckpointManager.CheckpointType.BARANGAY_HALL_ACCESS_GRANTED))
	
	# Complete the "Go to Barangay Hall" task if it's active and fade task display
	if task_manager and task_manager.is_task_active():
		var current_task = task_manager.get_current_task()
		if current_task.get("id") == "go_to_barangay_hall":
			task_manager.complete_current_task()
			print("✅ Task completed: Go to Barangay Hall")
			
			# Fade task display like bedroom to police transition
			await get_tree().create_timer(2.0).timeout
			if task_manager.has_method("fade_task_display"):
				task_manager.fade_task_display()
				print("📋 Task display faded")
	
	# Play cutscene if not already played
	if not cutscene_already_played:
		print("🎬 Starting barangay hall investigation cutscene")
		print("🎬 About to call play_barangay_hall_cutscene()")
		# Wait for scene to fully load
		await get_tree().create_timer(0.5).timeout
		play_barangay_hall_cutscene()
	else:
		print("🔍 Barangay hall cutscene already played - skipping")

# --------------------------
# CUTSCENE START
# --------------------------
func play_barangay_hall_cutscene():
	"""Play the barangay hall investigation cutscene"""
	print("🎬 Playing barangay hall investigation cutscene")
	load_dialogue()

	# Disable player control
	if player:
		if "control_enabled" in player:
			player.control_enabled = false
			print("🎮 Player movement disabled")
		else:
			print("❌ Player doesn't have control_enabled property")
	else:
		print("❌ Player not found")

	# Setup initial character positions during scene fade-in
	setup_initial_positions()
	
	# Wait for scene fade in to complete (characters are now positioned and ready)
	await get_tree().create_timer(1.0).timeout
	
	# Start dialogue sequence (animations will be handled in match case)
	show_next_line()

func setup_initial_positions() -> void:
	print("🎭 Setting up initial character positions...")
	
	# Debug character references
	print("🔍 Character references:")
	print("  - player:", player != null, "name:", player.name if player else "null")
	print("  - celine:", celine != null, "name:", celine.name if celine else "null")
	print("  - kapitana:", kapitana != null, "name:", kapitana.name if kapitana else "null")
	
	# Celine - idle_back at 480.0, 560.0 (already invisible in editor)
	if celine:
		celine.global_position = Vector2(480.0, 560.0)
		var celine_anim = celine.get_node_or_null("AnimatedSprite2D")
		if celine_anim:
			celine_anim.play("idle_back")
			print("✅ Celine positioned and animated")
		else:
			print("❌ Celine AnimatedSprite2D not found")
	else:
		print("❌ Celine not found")
	
	# PlayerM - idle_back at 528.0, 560.0 (already invisible in editor)
	if player:
		player.global_position = Vector2(528.0, 560.0)
		var player_anim = player.get_node_or_null("AnimatedSprite2D")
		if player_anim:
			player_anim.play("idle_back")
			print("✅ Player positioned and animated - Position:", player.global_position, "Animation: idle_back")
		else:
			print("❌ Player AnimatedSprite2D not found")
	else:
		print("❌ Player not found")
	
	# Kapitana - idle_back at 504.0, 416.0 (already invisible in editor)
	if kapitana:
		kapitana.global_position = Vector2(504.0, 416.0)
		var kapitana_anim = kapitana.get_node_or_null("AnimatedSprite2D")
		if kapitana_anim:
			kapitana_anim.play("idle_back")
			print("✅ Kapitana positioned and animated")
		else:
			print("❌ Kapitana AnimatedSprite2D not found")
	else:
		print("❌ Kapitana not found")
	
	# Don't modify camera - let it follow player naturally
	print("✅ Camera left to follow player naturally")


# --------------------------
# DIALOGUE SEQUENCE
# --------------------------
func show_next_line() -> void:
	if current_line >= dialogue_lines.size():
		end_cutscene()
		return

	var line: Dictionary = dialogue_lines[current_line]
	var speaker: String = String(line.get("speaker", ""))
	var text: String = String(line.get("text", ""))

	print("🗨️ Showing line", current_line, "Speaker:", speaker)

	# Organized by scene beats for better readability
	match current_line:
		# Miguel's line 0 - Miguel's shy personality animation sequence
		0:
			print("🎭 Miguel: Playing shy personality sequence")
			# Hide dialogue during animation
			if dialogue_ui:
				dialogue_ui.hide()
			# Start with idle_back
			await play_character_animation(player, "idle_back", 2.0)
			# Loop: idle_left -> idle_back -> idle_left (getting progressively faster)
			await play_character_animation(player, "idle_left", 0.8)
			await play_character_animation(player, "idle_back", 0.6)
			await play_character_animation(player, "idle_left", 0.4)
			await play_character_animation(player, "idle_back", 0.3)
			await play_character_animation(player, "idle_left", 0.2)
			# Show dialogue after animation
			show_dialogue_with_transition(speaker, text)
		
		# Celine's line 1 - Celine animation
		1:
			print("🎭 Celine: Playing idle_right")
			# Hide dialogue during animation
			if dialogue_ui:
				dialogue_ui.hide()
			await play_character_animation(celine, "idle_right", 0.5)
			# Show dialogue after animation
			show_dialogue_with_transition(speaker, text)
		
		# Kapitana's line 2 - All three characters animate in sync
		2:
			print("🎭 Line 2: All three characters animate in sync")
			# Hide dialogue during animation
			if dialogue_ui:
				dialogue_ui.hide()
			
			# Set all characters to animate simultaneously (no await)
			if player:
				play_character_animation(player, "idle_back", 0.3)
			if celine:
				play_character_animation(celine, "idle_back", 0.3)
			if kapitana:
				play_character_animation(kapitana, "idle_back", 0.5)
			
			# Wait for initial animations to complete
			await get_tree().create_timer(0.5).timeout
			
			# Kapitana turns to face them
			if kapitana:
				play_character_animation(kapitana, "idle_front", 0.5)
			
			# Wait for final animation
			await get_tree().create_timer(0.5).timeout
			
			# Show dialogue after animation
			show_dialogue_with_transition(speaker, text)
		
		# Miguel's introduction - both characters walk to new positions
		3:
			print("🎭 Line 3: Miguel and Celine walking to new positions")
			# Hide dialogue during movement
			if dialogue_ui:
				dialogue_ui.hide()
			
			# Move both characters simultaneously
			var player_target = Vector2(528.0, 464.0)
			var celine_target = Vector2(480.0, 464.0)
			
			print("🎭 Current positions - Player:", player.position if player else "null", "Celine:", celine.position if celine else "null")
			print("🎭 Target positions - Player:", player_target, "Celine:", celine_target)
			
			# Start walking animations and movement (no await - both animate simultaneously)
			if player:
				move_character_smoothly(player, player_target, "walk_back", "idle_back")
			if celine:
				move_character_smoothly(celine, celine_target, "walk_back", "idle_back")
			
			# Wait for movement to complete
			await get_tree().create_timer(2.0).timeout
			
			print("🎭 Movement completed - Player:", player.position if player else "null", "Celine:", celine.position if celine else "null")
			
			# Show dialogue after movement
			show_dialogue_with_transition(speaker, text)
		
		# Kapitana's response
		4:
			show_dialogue_with_transition(speaker, text)
		
		# Miguel's questions - choice line
		5:
			# Reset choice completed flag for this new choice
			choice_completed = false
			# Show Miguel's dialogue first
			show_dialogue_with_transition(speaker, text)
			# The choice will be shown in _on_next_pressed() after this dialogue
		
		# Normal dialogue lines 6-7
		6, 7:
			show_dialogue_with_transition(speaker, text)
		
		# Barangay NPC line 8 - NPC walks to position
		8:
			print("🎭 Line 8: Barangay NPC walking to position")
			# Hide dialogue during movement
			if dialogue_ui:
				dialogue_ui.hide()
			
			# Use the Barangay NPC reference
			if barangay_npc:
				print("🎭 Barangay NPC found, starting movement")
				print("🎭 Current position:", barangay_npc.position)
				
				# Step 1: Walk down to 680.0, 504.0 (walk_down) - wait for completion
				var intermediate_pos = Vector2(680.0, 504.0)
				move_character_smoothly(barangay_npc, intermediate_pos, "walk_down", "idle_down")
				# Calculate wait time based on distance
				var distance1 = barangay_npc.position.distance_to(intermediate_pos)
				var wait_time1 = distance1 / walk_speed
				await get_tree().create_timer(wait_time1).timeout
				print("🎭 Step 1 completed - NPC at intermediate position")
				
				# Step 2: Walk left to 504.0, 504.0 (walk_left) - wait for completion
				var final_pos = Vector2(504.0, 504.0)
				move_character_smoothly(barangay_npc, final_pos, "walk_left", "idle_back")
				# Calculate wait time based on distance
				var distance2 = intermediate_pos.distance_to(final_pos)
				var wait_time2 = distance2 / walk_speed
				await get_tree().create_timer(wait_time2).timeout
				print("🎭 Step 2 completed - NPC at final position")
				
				print("🎭 Final position:", barangay_npc.position)
				
				# Set Miguel and Celine to idle_front only when NPC reaches final destination
				if player:
					var player_anim = player.get_node_or_null("AnimatedSprite2D")
					if player_anim:
						player_anim.play("idle_down")
						print("✅ Player set to idle_front")
				
				if celine:
					var celine_anim = celine.get_node_or_null("AnimatedSprite2D")
					if celine_anim:
						celine_anim.play("idle_front")
						print("✅ Celine set to idle_front")
			else:
				print("❌ Barangay NPC not found")
			
			# Show dialogue after movement
			show_dialogue_with_transition(speaker, text)
		
		# Line 9 - Miguel and Celine back to idle_back
		9:
			print("🎭 Line 9: Miguel and Celine back to idle_back")
			# Hide dialogue during animation
			if dialogue_ui:
				dialogue_ui.hide()
			
			# Set Miguel and Celine to idle_back
			if player:
				var player_anim = player.get_node_or_null("AnimatedSprite2D")
				if player_anim:
					player_anim.play("idle_back")
					print("✅ Player set to idle_back")
			
			if celine:
				var celine_anim = celine.get_node_or_null("AnimatedSprite2D")
				if celine_anim:
					celine_anim.play("idle_back")
					print("✅ Celine set to idle_back")
			
			# Show dialogue after animation
			show_dialogue_with_transition(speaker, text)
		
		# Normal dialogue line 10
		10:
			show_dialogue_with_transition(speaker, text)
		
		# Line 11 - Complex simultaneous character movements
		11:
			print("🎭 Line 11: Complex simultaneous character movements")
			# Hide dialogue during movement
			if dialogue_ui:
				dialogue_ui.hide()
			
			# Celine: walk_left to 456.0x then walk_back to 424y
			if celine:
				print("🎭 Celine: Starting complex movement")
				# Step 1: walk_left to 456.0x
				var celine_intermediate = Vector2(456.0, celine.position.y)
				move_character_smoothly(celine, celine_intermediate, "walk_left", "idle_left")
				var celine_distance1 = celine.position.distance_to(celine_intermediate)
				var celine_wait1 = celine_distance1 / walk_speed
				await get_tree().create_timer(celine_wait1).timeout
				print("🎭 Celine: Step 1 completed")
				
				# Step 2: walk_back to 424y
				var celine_final = Vector2(456.0, 424.0)
				move_character_smoothly(celine, celine_final, "walk_back", "idle_right")
				var celine_distance2 = celine_intermediate.distance_to(celine_final)
				var celine_wait2 = celine_distance2 / walk_speed
				await get_tree().create_timer(celine_wait2).timeout
				print("🎭 Celine: Movement completed - idle_right")
			
			# PlayerM: walk_left to 456.0x (after Celine completes)
			if player:
				print("🎭 PlayerM: Starting walk_left to 456.0x")
				var player_target = Vector2(456.0, player.position.y)
				move_character_smoothly(player, player_target, "walk_left", "idle_right")
				var player_distance = player.position.distance_to(player_target)
				var player_wait = player_distance / walk_speed
				await get_tree().create_timer(player_wait).timeout
				print("🎭 PlayerM: Movement completed")
			
			# Now start NPC and Kapitana movements (only after Miguel reaches destination)
			print("🎭 Starting NPC and Kapitana movements...")
			
			# Barangay NPC and Kapitana: Move together after Miguel finishes
			if barangay_npc and kapitana:
				print("🎭 NPC and Kapitana: Starting simultaneous return movement")
				
				# NPC: walk_right to 680x then walk_back to 112y then fade out
				# Step 1: walk_right to 680x
				var npc_intermediate = Vector2(680.0, barangay_npc.position.y)
				move_character_smoothly(barangay_npc, npc_intermediate, "walk_right", "idle_back")
				var npc_distance1 = barangay_npc.position.distance_to(npc_intermediate)
				var npc_wait1 = npc_distance1 / walk_speed
				await get_tree().create_timer(npc_wait1).timeout
				print("🎭 Barangay NPC: Step 1 completed")
				
				# Kapitana: walk_down to 504,504 (simultaneous with NPC step 1)
				var kapitana_intermediate = Vector2(504.0, 504.0)
				move_character_smoothly(kapitana, kapitana_intermediate, "walk_down", "idle_back")
				var kapitana_distance1 = kapitana.position.distance_to(kapitana_intermediate)
				var kapitana_wait1 = kapitana_distance1 / walk_speed
				await get_tree().create_timer(kapitana_wait1).timeout
				print("🎭 Kapitana: Step 1 completed")
				
				# Both move to final destinations simultaneously
				# NPC: walk_back to 112y
				var npc_final = Vector2(680.0, 112.0)
				move_character_smoothly(barangay_npc, npc_final, "walk_back", "idle_back")
				
				# Kapitana: walk_right to 680x then walk_back to 112y (same as NPC)
				var kapitana_step2 = Vector2(680.0, 504.0)
				move_character_smoothly(kapitana, kapitana_step2, "walk_right", "idle_back")
				var kapitana_distance2 = kapitana_intermediate.distance_to(kapitana_step2)
				var kapitana_wait2 = kapitana_distance2 / walk_speed
				await get_tree().create_timer(kapitana_wait2).timeout
				
				# Kapitana: walk_back to 112y (same as NPC)
				var kapitana_final = Vector2(680.0, 112.0)
				move_character_smoothly(kapitana, kapitana_final, "walk_back", "idle_back")
				
				# Wait for both to reach final destinations
				var npc_distance2 = npc_intermediate.distance_to(npc_final)
				var npc_wait2 = npc_distance2 / walk_speed
				var kapitana_distance3 = kapitana_step2.distance_to(kapitana_final)
				var kapitana_wait3 = kapitana_distance3 / walk_speed
				var max_wait = max(npc_wait2, kapitana_wait3)
				await get_tree().create_timer(max_wait).timeout
				print("🎭 Both NPC and Kapitana reached final destinations")
				
				# Fade out both NPC and Kapitana
				var npc_tween = create_tween()
				npc_tween.tween_property(barangay_npc, "modulate:a", 0.0, 1.0)
				
				var kapitana_tween = create_tween()
				kapitana_tween.tween_property(kapitana, "modulate:a", 0.0, 1.0)
				
				await npc_tween.finished
				await kapitana_tween.finished
				print("🎭 Both Barangay NPC and Kapitana: Faded out")
			
			# PlayerM additional movements after fade out
			if player:
				print("🎭 PlayerM: Starting additional movements after fade out")
				
				# Step 1: walk_right to 552.0x
				var player_step1 = Vector2(552.0, player.position.y)
				await move_character_smoothly(player, player_step1, "walk_right", "idle_right")
				print("🎭 PlayerM: Step 1 completed - walk_right to 552.0x")
				
				# Step 2: walk_back to 384.0y
				var player_step2 = Vector2(552.0, 384.0)
				await move_character_smoothly(player, player_step2, "walk_back", "idle_back")
				print("🎭 PlayerM: Step 2 completed - walk_back to 384.0y")
			
			# Show evidence collected notification
			show_evidence_collected()
			
			# Wait for "Evidence collected" to show and animate
			await get_tree().create_timer(2.0).timeout
			
			# Hide "Evidence collected" message
			if task_manager and task_manager.task_display:
				task_manager.task_display.hide_task()
				print("📋 Evidence collected message hidden")
			
			# Wait for hide animation to complete
			await get_tree().create_timer(0.8).timeout
			
			# Start evidence collection phase - TAB input will now show evidence inventory
			evidence_collection_phase = true
			print("📋 Evidence collection phase started - TAB input enabled")
			
			# Show evidence inventory automatically and wait for it to be closed
			if has_node("/root/EvidenceInventorySettings"):
				var evidence_ui = get_node("/root/EvidenceInventorySettings")
				
				# Hide dialogue when showing inventory
				if dialogue_ui:
					dialogue_ui.hide()
					print("📋 Dialogue hidden for inventory")
				
				# Show evidence inventory
				evidence_ui.show_evidence_inventory()
				print("📋 Evidence inventory shown")
				
				# Add both evidence items - handwriting sample and logbook
				evidence_ui.add_evidence("handwriting_sample")
				evidence_ui.add_evidence("logbook")
				print("📋 Added 2 evidence items: handwriting_sample and logbook")
				
				# Mark task as completed
				if task_manager:
					task_manager.complete_current_task()
					print("📋 Task marked as completed after evidence collection")
				
				# Show "Tab to close inventory" message
				if task_manager and task_manager.task_display:
					task_manager.task_display.show_task("Tab to close inventory")
					print("📋 Task display: Tab to close inventory")
				
				# Wait for inventory to be closed (evidence_collection_phase will be set to false when closed)
				while evidence_collection_phase:
					await get_tree().process_frame
				
				# Hide task manager display only after inventory is closed
				if task_manager and task_manager.task_display:
					task_manager.task_display.hide_task()
					print("📋 Task display hidden after inventory closed")
				
				print("📋 Evidence inventory closed, now showing dialogue")
			
			# Show dialogue after inventory is closed
			show_dialogue_with_transition(speaker, text)
		
		# Line 12 - PlayerM additional movements
		12:
			print("🎭 Line 12: PlayerM additional movements")
			# Hide dialogue during movement
			if dialogue_ui:
				dialogue_ui.hide()
			
			# PlayerM: walk_down to 424.0y then walk_right to 488.0x
			if player:
				print("🎭 PlayerM: Starting additional movements for line 12")
				
				# Step 1: walk_down to 424.0y
				var player_step1 = Vector2(player.position.x, 424.0)
				await move_character_smoothly(player, player_step1, "walk_down", "idle_down")
				print("🎭 PlayerM: Step 1 completed - walk_down to 424.0y")
				
				# Step 2: walk_right to 488.0x
				var player_step2 = Vector2(488.0, 424.0)
				await move_character_smoothly(player, player_step2, "walk_left", "idle_left")
				print("🎭 PlayerM: Step 2 completed - walk_left to 488.0x")
			
			# Show dialogue after movement
			show_dialogue_with_transition(speaker, text)
		
		# Normal dialogue lines 13-15
		13, 14, 15:
			show_dialogue_with_transition(speaker, text)
		
		# Line 16 - Kapitana movement with PlayerM and Celine animations
		16:
			print("🎭 Line 16: Kapitana movement with character animations")
			# Hide dialogue during animation
			if dialogue_ui:
				dialogue_ui.hide()
			
			# Fade in Kapitana before walking (she was faded out in line 11)
			if kapitana:
				smooth_fade_in(kapitana, fade_duration)
				await get_tree().create_timer(fade_duration).timeout
				print("✅ Kapitana faded in")
			
			# Set PlayerM to idle_right immediately
			if player:
				var player_anim = player.get_node_or_null("AnimatedSprite2D")
				if player_anim:
					player_anim.play("idle_right")
					print("✅ PlayerM set to idle_right")
			
			# Kapitana: walk_down to (680, 472)
			if kapitana:
				print("🎭 Kapitana: Starting walk_down to (680, 472)")
				var kapitana_step1 = Vector2(680.0, 472.0)
				await move_character_smoothly(kapitana, kapitana_step1, "walk_down", "idle_down")
				print("🎭 Kapitana: Reached (680, 472) - idle_down")
				
				# Set Celine and PlayerM to idle_front and idle_down while Kapitana is at this position
				if celine:
					var celine_anim = celine.get_node_or_null("AnimatedSprite2D")
					if celine_anim:
						celine_anim.play("idle_front")
						print("✅ Celine set to idle_front")
				
				if player:
					var player_anim2 = player.get_node_or_null("AnimatedSprite2D")
					if player_anim2:
						player_anim2.play("idle_down")
						print("✅ PlayerM set to idle_down")
				
			# Kapitana: walk_left to (472, 472)
			print("🎭 Kapitana: Starting walk_left to (472, 472)")
			var kapitana_step2 = Vector2(472.0, 472.0)
			await move_character_smoothly(kapitana, kapitana_step2, "walk_left", "idle_back")
			print("🎭 Kapitana: Reached (472, 472) - idle_back")
			
			# Show dialogue after all animations complete
			show_dialogue_with_transition(speaker, text)
		
		# Normal dialogue lines 17-18
		17, 18:
			show_dialogue_with_transition(speaker, text)
		
		# Miguel's confrontation - choice line
		19:
			# Reset choice completed flag for this new choice
			choice_completed = false
			# Show Miguel's dialogue first
			show_dialogue_with_transition(speaker, text)
			# The choice will be shown in _on_next_pressed() after this dialogue
		
		# Normal dialogue line 20
		20:
			show_dialogue_with_transition(speaker, text)
		
		# Line 21 - Kapitana walks and fades out, then character animations
		21:
			print("🎭 Line 21: Kapitana walks and fades out")
			# Hide dialogue during movement
			if dialogue_ui:
				dialogue_ui.hide()
			
			# Kapitana: walk_right to (504, 472)
			if kapitana:
				print("🎭 Kapitana: Starting walk_right to (504, 472)")
				var kapitana_step1 = Vector2(504.0, 472.0)
				await move_character_smoothly(kapitana, kapitana_step1, "walk_right", "idle_down")
				print("🎭 Kapitana: Reached (504, 472)")
				
				# Kapitana: walk_down to (504, 600)
				print("🎭 Kapitana: Starting walk_down to (504, 600)")
				var kapitana_step2 = Vector2(504.0, 600.0)
				await move_character_smoothly(kapitana, kapitana_step2, "walk_down", "idle_down")
				print("🎭 Kapitana: Reached (504, 600)")
				
				# Fade out Kapitana
				var kapitana_tween = create_tween()
				kapitana_tween.tween_property(kapitana, "modulate:a", 0.0, 1.0)
				await kapitana_tween.finished
				print("🎭 Kapitana: Faded out")
			
			# Set Celine to idle_right
			if celine:
				var celine_anim = celine.get_node_or_null("AnimatedSprite2D")
				if celine_anim:
					celine_anim.play("idle_right")
					print("✅ Celine set to idle_right")
			
			# Set PlayerM to idle_left
			if player:
				var player_anim = player.get_node_or_null("AnimatedSprite2D")
				if player_anim:
					player_anim.play("idle_left")
					print("✅ PlayerM set to idle_left")
			
			# Show dialogue after animations
			show_dialogue_with_transition(speaker, text)
		
		# Final dialogue line 22 (last line)
		22:
			show_dialogue_with_transition(speaker, text)
		
		# Default: Regular dialogue for other lines
		_:
			show_dialogue_with_transition(speaker, text)

# --------------------------
# INPUT HANDLING
# --------------------------
func _on_next_pressed() -> void:
	if waiting_for_next:
		waiting_for_next = false
		
		# Check if we're trying to proceed from line 12 and evidence inventory is still open
		if current_line == 12 and evidence_collection_phase:
			if has_node("/root/EvidenceInventorySettings"):
				var evidence_ui = get_node("/root/EvidenceInventorySettings")
				if evidence_ui.is_visible:
					print("⚠️ Cannot proceed to next line - evidence inventory is still open")
					print("📋 Please close evidence inventory with TAB before continuing")
					waiting_for_next = true  # Reset waiting state
					return
		
		# Check if we just finished a choice line and need to show choices
		# Only show choices if we haven't already completed them
		if (current_line == 5 or current_line == 19) and not choice_completed:
			print("🔍 Checking choice for line:", current_line, "choice_completed:", choice_completed)
			var choice_data = get_choice_for_line(current_line)
			print("🔍 Choice data for line", current_line, ":", choice_data)
			if choice_data:
				# Add a small delay to ensure dialogue is fully displayed
				await get_tree().create_timer(0.1).timeout
				show_miguel_choice(choice_data)
				return
			else:
				print("⚠️ No choice data found for line", current_line)
		
		current_line += 1
		show_next_line()

# --------------------------
# CUTSCENE END
# --------------------------
func end_cutscene():
	print("🏁 Barangay hall investigation cutscene ended")
	
	# Mark cutscene as played
	cutscene_played = true
	
	# End evidence collection phase if still active
	if evidence_collection_phase:
		evidence_collection_phase = false
		print("📋 Evidence collection phase ended with cutscene")
	
	# Hide dialogue UI
	if dialogue_ui:
		dialogue_ui.hide()
	
	# Wait a moment before fading
	await get_tree().create_timer(0.5).timeout
	
	# Fade out transition
	await fade_out_scene()
	
	# Reposition Miguel to spawn point
	reposition_after_cutscene()
	
	# Fade in transition
	await fade_in_scene()
	
	# Enable player control
	if player and "control_enabled" in player:
		player.control_enabled = true
		print("🎮 Player control enabled")
	
	# Set the checkpoint to prevent replay
	checkpoint_manager.set_checkpoint(CheckpointManager.CheckpointType.BARANGAY_HALL_CUTSCENE_COMPLETED)
	print("🎯 Global checkpoint set: BARANGAY_HALL_CUTSCENE_COMPLETED")
	print("🎬 Barangay hall cutscene completed")

func fade_out_scene() -> void:
	"""Fade out all characters and scene elements"""
	print("🎭 Fading out scene...")
	
	var scene_root = get_tree().current_scene
	var fade_tween = create_tween()
	fade_tween.set_parallel(true)
	
	# Fade out all characters
	if player:
		fade_tween.tween_property(player, "modulate:a", 0.0, fade_duration)
	if celine:
		fade_tween.tween_property(celine, "modulate:a", 0.0, fade_duration)
	if kapitana:
		fade_tween.tween_property(kapitana, "modulate:a", 0.0, fade_duration)
	if barangay_npc:
		fade_tween.tween_property(barangay_npc, "modulate:a", 0.0, fade_duration)
	
	# Fade out tilemap/tileset (get all TileMap nodes)
	for child in scene_root.get_children():
		if child is TileMap:
			fade_tween.tween_property(child, "modulate:a", 0.0, fade_duration)
	
	await fade_tween.finished
	print("✅ Scene faded out")

func reposition_after_cutscene() -> void:
	"""Reposition characters after cutscene"""
	print("🎭 Repositioning characters for normal gameplay...")
	
	# Reposition Miguel to spawn point
	if player:
		player.global_position = Vector2(504.0, 560.0)
		var player_anim = player.get_node_or_null("AnimatedSprite2D")
		if player_anim:
			player_anim.play("idle_front")
		print("✅ Miguel repositioned to (504, 560)")
	
	# Hide cutscene-only characters
	if celine:
		celine.visible = false
		print("✅ Celine hidden")
	
	if kapitana:
		kapitana.visible = false
		print("✅ Kapitana hidden")
	
	if barangay_npc:
		barangay_npc.visible = false
		print("✅ Barangay NPC hidden")
	
	# TODO: Spawn other NPCs here later
	print("🎭 Repositioning complete")

func fade_in_scene() -> void:
	"""Fade in scene for normal gameplay"""
	print("🎭 Fading in scene...")
	
	var scene_root = get_tree().current_scene
	var fade_tween = create_tween()
	fade_tween.set_parallel(true)
	
	# Fade in player
	if player:
		player.modulate.a = 0.0
		fade_tween.tween_property(player, "modulate:a", 1.0, fade_duration)
	
	# Fade in tilemap/tileset
	for child in scene_root.get_children():
		if child is TileMap:
			child.modulate.a = 0.0
			fade_tween.tween_property(child, "modulate:a", 1.0, fade_duration)
	
	await fade_tween.finished
	print("✅ Scene faded in - normal gameplay ready")
