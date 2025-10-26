extends Node2D

# --- Scene state ---
var is_cinematic_active: bool = false
var is_in_cutscene: bool = false

# --- Dialogue data ---
var dialogue_lines: Array = []
var current_line: int = 0

func _ready():
	"""Initialize the morgue cutscene"""
	await get_tree().process_frame
	
	# Load dialogue data
	var dialogue_data = load_morgue_dialogue()
	dialogue_lines = dialogue_data.get("dialogue_lines", [])
	print("📝 Morgue cutscene dialogue loaded:", dialogue_lines.size(), "lines")
	
	# Audio will be handled by the scene's AudioManager automatically
	print("🎵 Audio will be handled by scene's AudioManager")
	
	# Check if morgue cutscene should play (only if HEAD_POLICE_COMPLETED)
	if CheckpointManager and CheckpointManager.has_checkpoint(CheckpointManager.CheckpointType.HEAD_POLICE_COMPLETED):
		print("📋 Head police completed - morgue cutscene will play")
	else:
		print("⚠️ Head police not completed - morgue cutscene blocked")
		return
	
	print("📋 Starting morgue cutscene sequence")
	
	# TODO: Uncomment this when ready for production
	# # Check if HEAD_POLICE_ROOM is completed before playing morgue cutscene
	# if CheckpointManager:
	# 	if CheckpointManager.has_checkpoint(CheckpointManager.CheckpointType.HEAD_POLICE_ROOM_COMPLETED):
	# 		print("📋 HEAD_POLICE_ROOM completed - morgue cutscene can play")
	# 	else:
	# 		print("⚠️ HEAD_POLICE_ROOM not completed - morgue cutscene will not play")
	# 		return
	# else:
	# 	print("⚠️ CheckpointManager not available - morgue cutscene will not play")
	# 	return
	
	# Disable player movement during cutscene
	disable_player_movement()
	print("🚫 Player movement disabled during cutscene")
	
	# Additional safeguard - disable input processing on the scene
	set_process_input(false)
	set_process_unhandled_input(false)
	print("🚫 Cutscene script input processing disabled")
	
	# Set DialogueUI to cutscene mode for input handling
	if DialogueUI:
		DialogueUI.set_cutscene_mode(true)
		print("💬 DialogueUI set to cutscene mode for input handling")
	
	# Start the AnimationPlayer (dialogue will be controlled by AnimationPlayer Method Call tracks)
	play_morgue_animation()
	print("🎬 AnimationPlayer started - dialogue controlled by Method Call tracks")
	
	# FALLBACK: If animation doesn't exist, start dialogue manually
	await get_tree().create_timer(1.0).timeout
	if not $AnimationPlayer.is_playing():
		print("⚠️ Animation not playing - starting dialogue manually")
		# Start with line 0 and let user control progression
		await show_line_0()
	
	# Add manual trigger for testing (F12 key)
	print("🧪 Press F12 to manually start morgue animation for testing")

# --------------------------
# PLAYER MOVEMENT CONTROL
# --------------------------

func disable_player_movement():
	"""Disable player movement during cutscene"""
	print("🔍 Searching for player node...")
	
	# Try multiple ways to find the player
	var player = null
	
	# Method 1: Try "player" group
	player = get_tree().get_first_node_in_group("player")
	if player:
		print("✅ Found player in 'player' group:", player.name)
	else:
		print("❌ No player found in 'player' group")
	
	# Method 2: Try "Player" group
	if not player:
		player = get_tree().get_first_node_in_group("Player")
		if player:
			print("✅ Found player in 'Player' group:", player.name)
		else:
			print("❌ No player found in 'Player' group")
	
	# Method 3: Try to find by name patterns
	if not player:
		var possible_names = ["Player", "player", "MainCharacter", "Miguel"]
		for name in possible_names:
			player = get_node_or_null("/root/" + name)
			if player:
				print("✅ Found player by name:", name)
				break
			player = get_node_or_null("../" + name)
			if player:
				print("✅ Found player by relative path:", name)
				break
	
	# Method 4: Search all nodes for player-like scripts
	if not player:
		print("🔍 Searching all nodes for player...")
		player = find_player_node(get_tree().current_scene)
	
	if player:
		print("🎯 Player found:", player.name, "Type:", player.get_class())
		
		# Disable player input processing
		player.set_process_input(false)
		player.set_process_unhandled_input(false)
		print("🚫 set_process_input(false) and set_process_unhandled_input(false) applied")
		
		# Try various movement disable methods
		if player.has_method("set_movement_enabled"):
			player.set_movement_enabled(false)
			print("🚫 set_movement_enabled(false) applied")
		
		if player.has_method("set_can_move"):
			player.set_can_move(false)
			print("🚫 set_can_move(false) applied")
		
		if player.has_method("disable_movement"):
			player.disable_movement()
			print("🚫 disable_movement() applied")
		
		# Try to set a custom property
		player.set("can_move", false)
		print("🚫 can_move property set to false")
		
		print("🚫 Player movement disabled with multiple methods")
	else:
		print("❌ No player node found with any method!")
		print("🔍 Available groups:", get_tree().get_nodes_in_group("player"))
		print("🔍 Available groups:", get_tree().get_nodes_in_group("Player"))

func find_player_node(node: Node) -> Node:
	"""Recursively search for player node"""
	if node.has_method("_physics_process") or node.has_method("_process"):
		# Check if this looks like a player node
		if "player" in node.name.to_lower() or "character" in node.name.to_lower():
			return node
	
	for child in node.get_children():
		var result = find_player_node(child)
		if result:
			return result
	
	return null

func enable_player_movement():
	"""Re-enable player movement after cutscene"""
	print("🔍 Re-enabling player movement...")
	
	# Try multiple ways to find the player (same as disable)
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		player = get_tree().get_first_node_in_group("Player")
	if not player:
		player = find_player_node(get_tree().current_scene)
	
	if player:
		print("🎯 Player found for re-enabling:", player.name)
		
		# Re-enable player input processing
		player.set_process_input(true)
		player.set_process_unhandled_input(true)
		print("✅ set_process_input(true) and set_process_unhandled_input(true) applied")
		
		# Try various movement enable methods
		if player.has_method("set_movement_enabled"):
			player.set_movement_enabled(true)
			print("✅ set_movement_enabled(true) applied")
		
		if player.has_method("set_can_move"):
			player.set_can_move(true)
			print("✅ set_can_move(true) applied")
		
		if player.has_method("enable_movement"):
			player.enable_movement()
			print("✅ enable_movement() applied")
		
		# Try to set a custom property
		player.set("can_move", true)
		print("✅ can_move property set to true")
		
		print("✅ Player movement enabled with multiple methods")
	else:
		print("❌ No player node found for re-enabling!")

# --------------------------
# ANIMATION METHODS
# --------------------------

func play_morgue_animation():
	"""Play the 'morgue_cutscene' from AnimationPlayer"""
	if has_node("AnimationPlayer"):
		$AnimationPlayer.play("morgue_cutscene")
		print("🎬 Playing morgue cutscene animation")
	else:
		print("⚠️ AnimationPlayer not found")

func stop_morgue_animation():
	"""Stop the morgue animation"""
	if has_node("AnimationPlayer"):
		$AnimationPlayer.stop()
		print("🎬 Stopped morgue animation")

func pause_morgue_animation():
	"""Pause the morgue animation"""
	if has_node("AnimationPlayer"):
		$AnimationPlayer.pause()
		print("🎬 Paused morgue animation")

func resume_morgue_animation():
	"""Resume the morgue animation"""
	if has_node("AnimationPlayer"):
		$AnimationPlayer.play()
		print("🎬 Resumed morgue animation")

# --------------------------
# DIALOGUE LOADING AND DISPLAY
# --------------------------

func load_morgue_dialogue() -> Dictionary:
	"""Load morgue cutscene dialogue from JSON"""
	var file: FileAccess = FileAccess.open("res://data/dialogues/morgue_autopsy_dialogue.json", FileAccess.READ)
	if file == null:
		push_error("Cannot open morgue_autopsy_dialogue.json")
		return {}

	var text: String = file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("morgue_autopsy"):
		push_error("Failed to parse morgue_autopsy_dialogue.json correctly")
		return {}

	dialogue_lines = parsed["morgue_autopsy"]["dialogue_lines"]
	print("📝 Morgue cutscene dialogue loaded:", dialogue_lines.size(), "lines")
	return parsed["morgue_autopsy"]

# Individual character line functions for AnimationPlayer Method Call tracks
func show_line_0(): 
	"""Show line 0 - Miguel's introduction"""
	print("🎬 Showing line 0 - Miguel's introduction")
	# Don't fade in characters yet - let the animation handle positioning
	await play_dialogue_line(0)
func show_line_1(): 
	"""Show line 1 - Dr. Leticia Salvador's response"""
	print("🎬 Showing line 1 - Dr. Leticia Salvador's response")
	# Don't fade in characters - let AnimationPlayer handle positioning
	await play_dialogue_line(1)
func show_line_2(): await play_dialogue_line(2)
func show_line_3(): await play_dialogue_line(3)
func show_line_4(): await play_dialogue_line(4)
func show_line_5(): await play_dialogue_line(5)
func show_line_6(): await play_dialogue_line(6)
func show_line_7(): await play_dialogue_line(7)
func show_line_8(): await play_dialogue_line(8)
func show_line_9(): 
	await play_dialogue_line(9)
	# Show 5th evidence (autopsy report) after line 9
	show_evidence_inventory_5th()
func show_line_10(): await play_dialogue_line(10)
func show_line_11(): await play_dialogue_line(11)
func show_line_12(): await play_dialogue_line(12)
func show_line_13(): await play_dialogue_line(13)
func show_line_14(): await play_dialogue_line(14)
func show_line_15(): await play_dialogue_line(15)
func show_line_16(): await play_dialogue_line(16)
func show_line_17(): await play_dialogue_line(17)
func show_line_18(): await play_dialogue_line(18)
func show_line_19(): await play_dialogue_line(19)
func show_line_20(): 
	await play_dialogue_line(20)
	# Show 6th evidence (Leo's notebook) after line 20
	show_evidence_inventory_6th()
func show_line_21(): await play_dialogue_line(21)
func show_line_22(): await play_dialogue_line(22)
func show_line_23(): await play_dialogue_line(23)
func show_line_24(): await play_dialogue_line(24)
func show_line_25(): await play_dialogue_line(25)

func show_line_26(): 
	await play_dialogue_line(26)
	# Wait for user input to finish line 26
	# End morgue dialogue but keep background for recollection
	end_morgue_dialogue_only()

func show_line_27(): 
	"""Show line 27 - Miguel's recollection (cinematic text)"""
	print("🎬 Showing line 27 - Miguel's recollection")
	show_cinematic_text_from_json(27)

func show_line_28(): 
	"""Show line 28 - Miguel's recollection (cinematic text)"""
	print("🎬 Showing line 28 - Miguel's recollection")
	show_cinematic_text_from_json(28)

func show_line_29(): 
	"""Show line 29 - Miguel's recollection (cinematic text)"""
	print("🎬 Showing line 29 - Miguel's recollection")
	show_cinematic_text_from_json(29)

func show_line_30(): 
	"""Show line 30 - Miguel's recollection (cinematic text)"""
	print("🎬 Showing line 30 - Miguel's recollection")
	show_cinematic_text_from_json(30)

func show_line_31(): 
	"""Show line 31 - Miguel's recollection (cinematic text)"""
	print("🎬 Showing line 31 - Miguel's recollection")
	show_cinematic_text_from_json(31)

func show_line_32(): 
	"""Show line 32 - Miguel's recollection (cinematic text)"""
	print("🎬 Showing line 32 - Miguel's recollection")
	show_cinematic_text_from_json(32)

func show_line_33(): 
	"""Show line 33 - Miguel's recollection (cinematic text)"""
	print("🎬 Showing line 33 - Miguel's recollection")
	show_cinematic_text_from_json(33)

func show_line_34(): 
	"""Show line 34 - Miguel's recollection (cinematic text)"""
	print("🎬 Showing line 34 - Miguel's recollection")
	show_cinematic_text_from_json(34)

func show_line_35(): 
	"""Show line 35 - Miguel's recollection (cinematic text)"""
	print("🎬 Showing line 35 - Miguel's recollection")
	show_cinematic_text_from_json(35)

func show_cinematic_text_from_json(line_index: int):
	"""Show cinematic text from JSON dialogue file"""
	print("🎬 Loading cinematic text from JSON for line:", line_index)
	
	# Load dialogue from JSON
	var dialogue_data = load_morgue_dialogue()
	if not dialogue_data or dialogue_data.is_empty():
		print("❌ Failed to load morgue dialogue")
		return
	
	print("🎬 DEBUG: dialogue_data keys:", dialogue_data.keys())
	
	# Find the recollection line
	var recollection_lines = dialogue_data.get("recollection_lines", [])
	print("🎬 DEBUG: recollection_lines size:", recollection_lines.size())
	
	var target_line = null
	
	for line in recollection_lines:
		print("🎬 DEBUG: Checking line with index:", line.get("line_index"), "against target:", line_index)
		if line.get("line_index") == line_index:
			target_line = line
			break
	
	if target_line:
		var text = target_line.get("text", "")
		print("🎬 Found recollection text:", text)
		await show_cinematic_text(text, 1.0, 5.9)
	else:
		print("❌ Recollection line not found for index:", line_index)
		print("🎬 DEBUG: Available line indices:")
		for line in recollection_lines:
			print("  - Index:", line.get("line_index"), "Text:", line.get("text", "").substr(0, 50) + "...")

func show_cinematic_text(text: String, fade_in_duration: float, hold_duration: float):
	"""Show cinematic text with fade effects (like bedroom scene)"""
	print("🎬 Showing cinematic text:", text)
	
	# Find cinematic text label
	var cinematic_text = get_node_or_null("CinematicText")
	print("🎬 DEBUG: CinematicText node found:", cinematic_text != null)
	if cinematic_text:
		print("🎬 DEBUG: CinematicText node name:", cinematic_text.name)
		print("🎬 DEBUG: CinematicText node path:", cinematic_text.get_path())
	else:
		print("🎬 DEBUG: CinematicText node not found - checking scene structure")
		print("🎬 DEBUG: Scene root:", get_tree().current_scene.name)
		print("🎬 DEBUG: Available nodes in scene:")
		_print_node_tree(get_tree().current_scene, 0)
	
	if cinematic_text:
		print("🎬 Cinematic text found:", cinematic_text.name)
		cinematic_text.text = text
		cinematic_text.visible = true
		cinematic_text.modulate.a = 0.0
		
		# Ensure proper z-index and layer
		if cinematic_text.get_parent():
			cinematic_text.get_parent().move_child(cinematic_text, -1)  # Move to front
		cinematic_text.z_index = 100  # High z-index
		cinematic_text.z_as_relative = false  # Use absolute z-index
		
		print("🎬 Cinematic text set up with z-index 100 - starting fade in")
		
		# Fade in
		var fade_in_tween = create_tween()
		fade_in_tween.tween_property(cinematic_text, "modulate:a", 1.0, fade_in_duration)
		await fade_in_tween.finished
		print("🎬 Cinematic text faded in - holding for", hold_duration, "seconds")
		
		# Hold the text
		await get_tree().create_timer(hold_duration).timeout
		print("🎬 Hold complete - starting fade out")
		
		# Fade out
		var fade_out_tween = create_tween()
		fade_out_tween.tween_property(cinematic_text, "modulate:a", 0.0, fade_in_duration)
		await fade_out_tween.finished
		
		cinematic_text.visible = false
		print("🎬 Cinematic text completed:", text)
	else:
		print("❌ CinematicText node not found - using fallback dialogue")
		# Fallback: Use regular dialogue UI
		if DialogueUI:
			DialogueUI.show_dialogue_line("Miguel", text)
			await get_tree().create_timer(hold_duration).timeout
			DialogueUI.hide_ui()

func play_dialogue_line(line_index: int):
	"""Play a specific dialogue line using DialogueUI and pause AnimationPlayer"""
	print("🎬 play_dialogue_line called with index:", line_index)
	
	# Pause AnimationPlayer during dialogue
	pause_morgue_animation()
	print("⏸️ AnimationPlayer paused for dialogue")
	
	if line_index >= 0 and line_index < dialogue_lines.size():
		var line = dialogue_lines[line_index]
		var speaker = line.get("speaker", "")
		var text = line.get("text", "")
		
		print("💬 Playing dialogue line:", speaker, ":", text)
		
		# Wait for any existing dialogue to finish
		if DialogueUI and DialogueUI.is_typing:
			print("⏳ Waiting for existing dialogue to finish...")
			await get_tree().create_timer(0.1).timeout
			# Keep waiting until typing is done
			while DialogueUI.is_typing:
				await get_tree().create_timer(0.1).timeout
		
		if DialogueUI:
			print("💬 Calling DialogueUI.show_dialogue_line")
			DialogueUI.show_dialogue_line(speaker, text)
			print("💬 Dialogue line shown - waiting for user input")
			# Wait for user input to continue (next button press)
			await DialogueUI.next_pressed
			print("▶️ User input received, continuing...")
		else:
			print("⚠️ DialogueUI not found in play_dialogue_line!")
	else:
		print("⚠️ Invalid line index:", line_index, "dialogue_lines.size():", dialogue_lines.size())
	
	# Resume AnimationPlayer after dialogue
	resume_morgue_animation()
	print("▶️ AnimationPlayer resumed")

# --------------------------
# EVIDENCE INVENTORY DISPLAY
# --------------------------

func show_evidence_inventory():
	"""Show evidence inventory after line 20, similar to barangay hall cutscene"""
	print("📋 Showing evidence inventory after line 20")
	
	# Wait 3 seconds before showing evidence (like barangay hall)
	await get_tree().create_timer(3.0).timeout
	
	# Hide dialogue when showing inventory
	if DialogueUI:
		DialogueUI.hide_ui()
		print("📋 Dialogue hidden for inventory")
	
	# Show evidence inventory
	if has_node("/root/EvidenceInventorySettings"):
		var evidence_ui = get_node("/root/EvidenceInventorySettings")
		
		# Show evidence inventory
		evidence_ui.show_evidence_inventory()
		print("📋 Evidence inventory shown")
		
		# Add both evidences simultaneously to show 6 total evidence pieces
		evidence_ui.add_evidence("autopsy_report")
		evidence_ui.add_evidence("leos_notebook")
		print("📋 Added autopsy_report (5th) and leos_notebook (6th) evidence - Total: 6 evidence pieces")
		
		# Flash inventory for 3 seconds then auto-close (like a cutscene)
		print("📋 Flashing evidence inventory for 3 seconds")
		await get_tree().create_timer(3.0).timeout
		
		# Auto-close inventory after 3 seconds
		if evidence_ui:
			await evidence_ui.hide_evidence_inventory()
			print("📋 Evidence inventory auto-closed after 3 seconds")
		
		print("📋 Evidence inventory closed, continuing dialogue")
	else:
		print("⚠️ EvidenceInventorySettings not found")

func show_evidence_inventory_5th():
	"""Show 5th evidence (autopsy report) after line 9"""
	print("📋 Showing 5th evidence (autopsy report) after line 9")
	
	# Wait 3 seconds before showing evidence
	await get_tree().create_timer(3.0).timeout
	
	# Don't hide dialogue - keep it visible for user interaction
	print("📋 Showing 5th evidence while keeping dialogue visible")
	
	# Show evidence inventory
	if has_node("/root/EvidenceInventorySettings"):
		var evidence_ui = get_node("/root/EvidenceInventorySettings")
		
		# Show evidence inventory
		evidence_ui.show_evidence_inventory()
		print("📋 Evidence inventory shown")
		
		# Add 5th evidence (autopsy report)
		evidence_ui.add_evidence("autopsy_report")
		print("📋 Added autopsy_report (5th evidence)")
		
		# Flash inventory for 3 seconds then auto-close
		print("📋 Flashing 5th evidence for 3 seconds")
		await get_tree().create_timer(3.0).timeout
		
		# Auto-close evidence inventory
		await evidence_ui.hide_evidence_inventory()
		print("📋 5th evidence inventory auto-closed")
		
		print("📋 5th evidence closed, continuing dialogue")
	else:
		print("⚠️ EvidenceInventorySettings not found")

func show_evidence_inventory_6th():
	"""Show 6th evidence (Leo's notebook) after line 20"""
	print("📋 Showing 6th evidence (Leo's notebook) after line 20")
	
	# Wait 3 seconds before showing evidence
	await get_tree().create_timer(3.0).timeout
	
	# Don't hide dialogue - keep it visible for user interaction
	print("📋 Showing 6th evidence while keeping dialogue visible")
	
	# Show evidence inventory
	if has_node("/root/EvidenceInventorySettings"):
		var evidence_ui = get_node("/root/EvidenceInventorySettings")
		
		# Show evidence inventory
		evidence_ui.show_evidence_inventory()
		print("📋 Evidence inventory shown")
		
		# Add 6th evidence (Leo's notebook)
		evidence_ui.add_evidence("leos_notebook")
		print("📋 Added leos_notebook (6th evidence)")
		
		# Flash inventory for 3 seconds then auto-close
		print("📋 Flashing 6th evidence for 3 seconds")
		await get_tree().create_timer(3.0).timeout
		
		# Auto-close evidence inventory
		await evidence_ui.hide_evidence_inventory()
		print("📋 6th evidence inventory auto-closed")
		
		print("📋 6th evidence closed, continuing dialogue")
	else:
		print("⚠️ EvidenceInventorySettings not found")

# --------------------------
# CHARACTER FADE METHODS
# --------------------------

func fade_out_character(character_name: String, duration: float = 1.0):
	"""Fade out a character by name"""
	var character = get_node_or_null(character_name)
	if character:
		var tween = create_tween()
		tween.tween_property(character, "modulate:a", 0.0, duration)
		await tween.finished
		character.visible = false
		print("✨ Faded out character:", character_name)
	else:
		print("⚠️ Character not found:", character_name)

func fade_in_character(character_name: String, duration: float = 1.0):
	"""Fade in a character by name"""
	var character = get_node_or_null(character_name)
	if character:
		character.visible = true
		character.modulate.a = 0.0
		var tween = create_tween()
		tween.tween_property(character, "modulate:a", 1.0, duration)
		await tween.finished
		print("✨ Faded in character:", character_name)
	else:
		print("⚠️ Character not found:", character_name)

# Specific character fade methods for AnimationPlayer
func fade_in_miguel():
	"""Fade in Miguel character"""
	await fade_in_character("Miguel")

func fade_out_miguel():
	"""Fade out Miguel character"""
	await fade_out_character("Miguel")

func fade_in_celine():
	"""Fade in Celine character"""
	await fade_in_character("celine")

func fade_out_celine():
	"""Fade out Celine character"""
	await fade_out_character("celine")

func fade_in_dr_leticia_salvador():
	"""Fade in Dr. Leticia Salvador character"""
	await fade_in_character("LeticiaSalvador")

func fade_out_dr_leticia_salvador():
	"""Fade out Dr. Leticia Salvador character"""
	await fade_out_character("LeticiaSalvador")

func fade_in_leticia_salvador():
	"""Fade in Dr. Leticia Salvador character"""
	await fade_in_character("LeticiaSalvador")

func fade_out_leticia_salvador():
	"""Fade out Dr. Leticia Salvador character"""
	await fade_out_character("LeticiaSalvador")

func fade_in_celine_morgue():
	"""Fade in Celine character for morgue scene"""
	await fade_in_character("celine")

func fade_out_celine_morgue():
	"""Fade out Celine character for morgue scene"""
	await fade_out_character("celine")


# --------------------------
# CUTSCENE END METHODS
# --------------------------

func end_cutscene_simple():
	"""End cutscene simply - hide dialogue, fade characters, enable movement, show task"""
	print("🎬 Ending morgue cutscene")
	
	# Hide dialogue UI
	if DialogueUI:
		DialogueUI.hide_ui()
		print("💬 Dialogue UI hidden")
	
	# Fade out Celine and Dr. Leticia Salvador
	await fade_out_celine_and_dr_leticia_salvador()
	print("🎬 Celine and Dr. Leticia Salvador faded out")
	
	# Re-enable player movement
	enable_player_movement()
	print("✅ Player movement re-enabled")
	
	# Re-enable input processing on the scene
	set_process_input(true)
	set_process_unhandled_input(true)
	print("✅ Cutscene script input processing re-enabled")
	
	# Set checkpoint as completed
	if CheckpointManager:
		CheckpointManager.set_checkpoint(CheckpointManager.CheckpointType.MORGUE_COMPLETED)
		print("📋 Morgue cutscene marked as completed")
	
	# Complete current task and set new task
	if TaskManager:
		TaskManager.complete_current_task()
		print("📋 Morgue task completed")
		# Set next task if available
		if TaskManager.has_next_task():
			TaskManager.start_next_task()
	
	print("🎬 Morgue cutscene ended - player can now move and task is displayed")

func end_morgue_dialogue_only():
	"""End morgue dialogue and create cinematic black screen for recollection"""
	print("🎬 Ending morgue dialogue - creating cinematic black screen")
	
	# Hide dialogue UI
	if DialogueUI:
		DialogueUI.hide_ui()
		print("💬 Dialogue UI hidden")
	
	# Fade out all characters and background for cinematic effect
	await fade_out_all_characters()
	await fade_out_tileset()
	print("🎬 All characters and background faded out - cinematic black screen")
	
	# Disable collision for cinematic mode
	disable_collision_for_cinematic()
	print("🎬 Collision disabled for cinematic mode")
	
	# Brief pause before starting recollection
	await get_tree().create_timer(1.0).timeout
	
	# Start recollection animation
	start_recollection_animation()

func start_recollection_animation():
	"""Start the recollection animation with cinematic black screen"""
	print("🎬 Starting recollection animation")
	
	# Everything should already be hidden from end_morgue_dialogue_only()
	print("🎬 Tileset and characters already hidden from previous fade out")
	
	# Disable input during recollection
	disable_input_for_cinematic()
	print("🎬 Input disabled for cinematic mode")
	
	# Brief pause before starting animation
	await get_tree().create_timer(0.5).timeout
	
	# Play recollection animation
	if has_node("AnimationPlayer"):
		$AnimationPlayer.play("recollection_animation")
		print("🎬 Recollection animation started")
	else:
		print("⚠️ AnimationPlayer not found for recollection")
	
	# FALLBACK: If recollection_animation doesn't exist, start cinematic text manually
	await get_tree().create_timer(1.0).timeout
	if not $AnimationPlayer.is_playing():
		print("⚠️ Recollection animation not playing - starting cinematic text manually")
		# Start the recollection cinematic text manually
		await show_line_27()
		await get_tree().create_timer(2.5).timeout
		await show_line_28()
		await get_tree().create_timer(2.5).timeout
		await show_line_29()
		await get_tree().create_timer(2.5).timeout
		await show_line_30()
		await get_tree().create_timer(2.5).timeout
		await show_line_31()
		await get_tree().create_timer(2.5).timeout
		await show_line_32()
		await get_tree().create_timer(2.5).timeout
		await show_line_33()
		await get_tree().create_timer(2.5).timeout
		await show_line_34()
		await get_tree().create_timer(2.5).timeout
		await show_line_35()
		await get_tree().create_timer(2.5).timeout
		# End the recollection
		end_recollection_cutscene()

func hide_all_tileset_and_characters():
	"""Hide all tileset and characters for cinematic mode"""
	print("🎬 Hiding all tileset and characters for cinematic mode")
	
	# Hide all tileset nodes
	var tileset_nodes = get_tree().get_nodes_in_group("tileset")
	for node in tileset_nodes:
		if node.has_method("set_modulate"):
			node.set_modulate(Color(1, 1, 1, 0))  # Set opacity to 0
		elif node.has_method("set_visible"):
			node.set_visible(false)
	
	# Hide all character nodes
	var character_nodes = get_tree().get_nodes_in_group("character")
	for node in character_nodes:
		if node.has_method("set_modulate"):
			node.set_modulate(Color(1, 1, 1, 0))  # Set opacity to 0
		elif node.has_method("set_visible"):
			node.set_visible(false)
	
	# Hide all background nodes
	var background_nodes = get_tree().get_nodes_in_group("background")
	for node in background_nodes:
		if node.has_method("set_modulate"):
			node.set_modulate(Color(1, 1, 1, 0))  # Set opacity to 0
		elif node.has_method("set_visible"):
			node.set_visible(false)
	
	# Hide playerM initially for cinematic fade-in effect
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.set_modulate(Color(1, 1, 1, 0))  # Hide player initially
		print("🎬 PlayerM hidden initially for cinematic fade-in")
	
	print("🎬 All tileset and characters hidden - cinematic black screen ready")

func fade_out_all_characters():
	"""Fade out all characters for cinematic effect"""
	print("🎬 Fading out all characters")
	
	# Fade out specific characters by name
	var characters_to_fade = ["LeticiaSalvador", "celine", "PlayerM", "Player"]
	
	for char_name in characters_to_fade:
		var character = get_node_or_null(char_name)
		if character:
			print("🎬 Fading out character:", char_name)
			var tween = create_tween()
			tween.tween_property(character, "modulate:a", 0.0, 0.3)  # Faster fade - 0.3 seconds
			await tween.finished
			character.visible = false
			character.modulate.a = 1.0  # Reset for next time
		else:
			print("⚠️ Character not found:", char_name)
	
	# Also try to find player by group
	var player = get_tree().get_first_node_in_group("player")
	if player and player.visible:
		print("🎬 Fading out player from group")
		var tween = create_tween()
		tween.tween_property(player, "modulate:a", 0.0, 1.0)
		await tween.finished
		player.visible = false
		player.modulate.a = 1.0  # Reset for next time
	
	print("🎬 All characters faded out")

func fade_out_tileset():
	"""Fade out all tileset for cinematic effect"""
	print("🎬 Fading out all tileset")
	
	# Find and fade out tileset nodes by common names
	var tileset_names = ["ground wall layer 1", "TileMapLayer0", "TileMapLayer", "TileMapLayer2", "TileMapLayer3"]
	
	for tileset_name in tileset_names:
		var tileset = get_node_or_null(tileset_name)
		if tileset:
			print("🎬 Fading out tileset:", tileset_name)
			var tween = create_tween()
			tween.tween_property(tileset, "modulate:a", 0.0, 0.3)  # Faster fade - 0.3 seconds
			await tween.finished
			tileset.visible = false
			tileset.modulate.a = 1.0  # Reset for next time
		else:
			print("⚠️ Tileset not found:", tileset_name)
	
	# Also try to find by groups
	var tileset_nodes = get_tree().get_nodes_in_group("tileset")
	for node in tileset_nodes:
		if node.visible:
			print("🎬 Fading out tileset from group:", node.name)
			var tween = create_tween()
			tween.tween_property(node, "modulate:a", 0.0, 1.0)
			await tween.finished
			node.visible = false
			node.modulate.a = 1.0  # Reset for next time
	
	print("🎬 All tileset faded out")

func disable_input_for_cinematic():
	"""Disable input during cinematic mode"""
	print("🎬 Disabling input for cinematic mode")
	
	# Disable player input
	var player = get_tree().get_first_node_in_group("player")
	if player:
		if player.has_method("set_process_input"):
			player.set_process_input(false)
		if player.has_method("set_movement_enabled"):
			player.set_movement_enabled(false)
		print("🎬 Player input disabled")
	
	# Disable global input handling
	print("🎬 Global input disabled for cinematic mode")

func fade_in_playerM():
	"""Fade in playerM for cinematic effect"""
	print("🎬 Fading in playerM for cinematic effect")
	
	# Debug: List all nodes to find player
	print("🔍 Available nodes in scene:")
	for child in get_children():
		print("  -", child.name, "(", child.get_class(), ")")
	
	# Try to find PlayerM by name first
	var player = get_node_or_null("PlayerM")
	if not player:
		print("⚠️ PlayerM node not found, trying alternative names...")
		# Try other possible names
		var alt_names = ["Player", "player", "Miguel", "miguel", "PlayerM", "playerM"]
		for name in alt_names:
			player = get_node_or_null(name)
			if player:
				print("✅ Found alternative node:", name)
				break
	
	if not player:
		# Fallback to player group
		player = get_tree().get_first_node_in_group("player")
		if player:
			print("✅ Found player from group")
	
	if player:
		print("🎬 Player found:", player.name, "(", player.get_class(), ")")
		# Make sure player is visible and start transparent
		player.visible = true
		player.set_modulate(Color(1, 1, 1, 0))  # Start transparent
		print("🎬 Player set to visible and transparent")
		
		# Fade in playerM smoothly
		var fade_tween = create_tween()
		fade_tween.set_ease(Tween.EASE_IN_OUT)
		fade_tween.set_trans(Tween.TRANS_CUBIC)
		fade_tween.tween_property(player, "modulate:a", 1.0, 1.0)  # 1-second fade in
		await fade_tween.finished
		print("🎬 PlayerM faded in successfully")
	else:
		print("❌ PlayerM not found for fade in - no player nodes available")

func end_recollection_cutscene():
	"""End the recollection cutscene and transition to next scene"""
	print("🎬 Ending recollection cutscene")
	
	# Hide dialogue UI
	if DialogueUI:
		DialogueUI.hide_ui()
		print("💬 Dialogue UI hidden")
	
	# Fade out audio (BGM and ambient)
	if AudioManager:
		AudioManager.fade_out_bgm(2.0)  # 2-second fade out
		# AudioManager.fade_out_ambient(2.0)  # Function doesn't exist, removed
		print("🔊 Audio fading out")
	
	# Fade out playerM for smooth transition
	# Try to find PlayerM by name first
	var player = get_node_or_null("PlayerM")
	if not player:
		# Fallback to player group
		player = get_tree().get_first_node_in_group("player")
	
	if player:
		var fade_tween = create_tween()
		fade_tween.set_ease(Tween.EASE_IN_OUT)
		fade_tween.set_trans(Tween.TRANS_CUBIC)
		fade_tween.tween_property(player, "modulate:a", 0.0, 1.0)  # 1-second fade out
		await fade_tween.finished
		print("🎬 PlayerM faded out")
	
	# Wait for audio to finish fading
	await get_tree().create_timer(2.5).timeout
	
	# Set morgue checkpoint as completed
	if CheckpointManager:
		CheckpointManager.set_checkpoint(CheckpointManager.CheckpointType.MORGUE_COMPLETED)
		print("✅ Morgue checkpoint completed")
	
	# Set next task
	if TaskManager:
		TaskManager.set_current_task("courtroom_preparation")
		print("📋 Next task: courtroom_preparation")
	
	# Transition to courtroom scene
	print("🏛️ Transitioning to courtroom scene")
	get_tree().change_scene_to_file("res://scenes/environments/Courtroom/courtroom.tscn")

func disable_collision_for_cinematic():
	"""Disable collision for cinematic mode"""
	print("🎬 Disabling collision for cinematic mode")
	
	# Find and disable all collision areas
	var collision_areas = get_tree().get_nodes_in_group("collision")
	for area in collision_areas:
		if area.has_method("set_disabled"):
			area.set_disabled(true)
		elif area.has_method("set_monitoring"):
			area.set_monitoring(false)
	
	# Disable player collision
	var player = get_tree().get_first_node_in_group("player")
	if player:
		var player_collision = player.get_node_or_null("CollisionShape2D")
		if player_collision:
			player_collision.disabled = true
			print("🎬 Player collision disabled")
	
	print("🎬 All collision disabled for cinematic mode")

func fade_out_celine_and_dr_leticia_salvador():
	"""Fade out Celine and Dr. Leticia Salvador specifically"""
	print("🎬 Fading out Celine and Dr. Leticia Salvador")
	
	# Find and fade out Celine
	var celine = get_node_or_null("Celine")
	if not celine:
		celine = get_node_or_null("celine")
	if not celine:
		var parent_scene = get_parent()
		if parent_scene:
			celine = parent_scene.get_node_or_null("Celine")
	
	if celine:
		print("🎬 Found Celine:", celine.name)
		var tween = create_tween()
		tween.tween_property(celine, "modulate:a", 0.0, 1.0)
		await tween.finished
		celine.visible = false
		celine.modulate.a = 1.0  # Reset for next time
	else:
		print("⚠️ Celine not found")
	
	# Find and fade out Dr. Leticia Salvador
	var dr_leticia_salvador = get_node_or_null("Dr_Leticia_Salvador")
	if not dr_leticia_salvador:
		dr_leticia_salvador = get_node_or_null("DrLeticiaSalvador")
	if not dr_leticia_salvador:
		dr_leticia_salvador = get_node_or_null("dr_leticia_salvador")
	
	if dr_leticia_salvador:
		print("🎬 Found Dr. Leticia Salvador:", dr_leticia_salvador.name)
		var tween = create_tween()
		tween.tween_property(dr_leticia_salvador, "modulate:a", 0.0, 1.0)
		await tween.finished
		dr_leticia_salvador.visible = false
		dr_leticia_salvador.modulate.a = 1.0  # Reset for next time
	else:
		print("⚠️ Dr. Leticia Salvador not found")
	
	print("🎬 Celine and Dr. Leticia Salvador fade out completed")

# --------------------------
# DEBUG CONTROLS
# --------------------------

func _unhandled_input(event: InputEvent) -> void:
	"""Handle debug input controls"""
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_F10:
				# F10 - Complete morgue cutscene instantly (DEBUG ONLY)
				var debug_mode = false  # Set to true only for development
				if debug_mode:
					debug_complete_morgue()
					print("🚀 DEBUG: Morgue cutscene skipped")
				else:
					print("⚠️ Debug skip disabled - complete cutscene normally")
			KEY_F7:
				# F7 - Restart morgue cutscene from beginning
				debug_restart_morgue()

func debug_complete_morgue():
	"""Debug function to complete morgue cutscene instantly"""
	print("🚀 DEBUG: Completing morgue cutscene instantly")
	
	# Stop any running animations
	if has_node("AnimationPlayer"):
		$AnimationPlayer.stop()
		print("📋 AnimationPlayer stopped")
	
	# Set checkpoint
	if CheckpointManager:
		CheckpointManager.set_checkpoint(CheckpointManager.CheckpointType.MORGUE_COMPLETED)
		print("📋 Morgue cutscene checkpoint set")
	
	# Add autopsy report evidence
	if has_node("/root/EvidenceInventorySettings"):
		var evidence_ui = get_node("/root/EvidenceInventorySettings")
		evidence_ui.add_evidence("autopsy_report")
		print("📋 Added autopsy report evidence")
	
	# End cutscene
	end_cutscene_simple()

func play_morgue_animation_manually():
	"""Manually play morgue animation for testing"""
	print("🎬 Manually playing morgue animation")
	
	# Disable player movement
	disable_player_movement()
	
	# Set DialogueUI to cutscene mode
	if DialogueUI:
		DialogueUI.set_cutscene_mode(true)
	
	# Start the animation
	play_morgue_animation()

func _print_node_tree(node: Node, depth: int):
	"""Helper function to print node tree structure"""
	var indent = "  ".repeat(depth)
	print(indent + "- " + node.name + " (" + node.get_class() + ")")
	for child in node.get_children():
		_print_node_tree(child, depth + 1)

func debug_restart_morgue():
	"""Debug function to restart morgue cutscene from beginning"""
	print("🔄 DEBUG: Restarting morgue cutscene from beginning")
	
	# Restart the morgue sequence
	_ready()



func _input(event):
	"""Handle input for testing"""
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F12:
			print("🧪 F12 pressed - manually starting morgue animation")
			play_morgue_animation_manually()
