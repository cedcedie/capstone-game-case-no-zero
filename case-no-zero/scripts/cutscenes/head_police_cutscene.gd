extends Node2D

# --- Scene state ---
var is_cinematic_active: bool = false
var is_in_cutscene: bool = false

# --- Dialogue data ---
var dialogue_lines: Array = []
var current_line: int = 0

func _ready():
	"""Initialize the head police cutscene"""
	await get_tree().process_frame
	
	# Load dialogue data
	dialogue_lines = load_head_police_dialogue()
	print("📝 Head police cutscene dialogue loaded:", dialogue_lines.size(), "lines")
	
	# Audio will be handled by the scene's AudioManager automatically
	print("🎵 Audio will be handled by scene's AudioManager")
	
	# Check if head police cutscene should play (only if BARANGAY_HALL_CUTSCENE_COMPLETED)
	if CheckpointManager and CheckpointManager.has_checkpoint(CheckpointManager.CheckpointType.BARANGAY_HALL_CUTSCENE_COMPLETED):
		print("📋 Barangay hall completed - head police cutscene will play")
	else:
		print("⚠️ Barangay hall not completed - head police cutscene blocked")
		return
	
	print("📋 Starting head police cutscene sequence")
	
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
	play_head_police_animation()
	print("🎬 AnimationPlayer started - dialogue controlled by Method Call tracks")

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

func play_head_police_animation():
	"""Play the 'head_police' animation from AnimationPlayer"""
	if has_node("AnimationPlayer"):
		$AnimationPlayer.play("head_police")
		print("🎬 Playing head police cutscene animation")
	else:
		print("⚠️ AnimationPlayer not found")


func stop_head_police_animation():
	"""Stop the head police animation"""
	if has_node("AnimationPlayer"):
		$AnimationPlayer.stop()
		print("🎬 Stopped head police animation")

func pause_head_police_animation():
	"""Pause the head police animation"""
	if has_node("AnimationPlayer"):
		$AnimationPlayer.pause()
		print("🎬 Paused head police animation")

func resume_head_police_animation():
	"""Resume the head police animation"""
	if has_node("AnimationPlayer"):
		$AnimationPlayer.play()
		print("🎬 Resumed head police animation")

# --------------------------
# DIALOGUE LOADING AND DISPLAY
# --------------------------

func load_head_police_dialogue() -> Array:
	"""Load head police cutscene dialogue from JSON"""
	var file: FileAccess = FileAccess.open("res://data/dialogues/head_police_cutscene_dialogue.json", FileAccess.READ)
	if file == null:
		push_error("Cannot open head_police_cutscene_dialogue.json")
		return []

	var text: String = file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("head_police_cutscene"):
		push_error("Failed to parse head_police_cutscene_dialogue.json correctly")
		return []

	dialogue_lines = parsed["head_police_cutscene"]["dialogue_lines"]
	print("📝 Head police cutscene dialogue loaded:", dialogue_lines.size(), "lines")
	return dialogue_lines

func play_dialogue():
	"""Play the head police cutscene dialogue using DialogueUI"""
	print("💬 Starting head police cutscene dialogue")
	
	if not DialogueUI:
		print("⚠️ DialogueUI autoload not found")
		return
	
	# Load dialogue from JSON file
	var dialogue_lines = load_head_police_dialogue()
	if dialogue_lines.is_empty():
		print("⚠️ Failed to load dialogue from JSON")
		return
	
	# Show each dialogue line (auto-advance for cutscene)
	for line in dialogue_lines:
		var speaker = line.get("speaker", "")
		var text = line.get("text", "")
		DialogueUI.show_dialogue_line(speaker, text)
		
		# Text loads for 1.5 seconds, then 1.5 seconds reading time
		var typing_time = 1.5  # Fixed 1.5s for text to load
		var reading_time = 1.5  # Fixed 1.5s reading time
		var total_wait = typing_time + reading_time
		
		print("💬 Auto-advancing dialogue: ", text.length(), " chars, waiting ", total_wait, "s")
		await get_tree().create_timer(total_wait).timeout
	
	# Hide dialogue after all lines shown
	DialogueUI.hide_ui()
	print("💬 Head police cutscene dialogue completed")

# Individual character line functions for AnimationPlayer Method Call tracks
func show_line_0(): await play_dialogue_line(0)
func show_line_1(): await play_dialogue_line(1)
func show_line_2(): await play_dialogue_line(2)
func show_line_3(): await play_dialogue_line(3)
func show_line_4(): await play_dialogue_line(4)
func show_line_5(): await play_dialogue_line(5)
func show_line_6(): await play_dialogue_line(6)
func show_line_7(): await play_dialogue_line(7)
func show_line_8(): await play_dialogue_line(8)
func show_line_9(): await play_dialogue_line(9)
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
func show_line_20(): await play_dialogue_line(20)
func show_line_21(): await play_dialogue_line(21)
func show_line_22(): await play_dialogue_line(22)
func show_line_23(): await play_dialogue_line(23)
func show_line_24(): await play_dialogue_line(24)
func show_line_25(): await play_dialogue_line(25)
func show_line_26(): await play_dialogue_line(26)
func show_line_27(): await play_dialogue_line(27)
func show_line_28(): await play_dialogue_line(28)
func show_line_29(): await play_dialogue_line(29)
func show_line_30(): 
	await play_dialogue_line(30)
	# Wait for user input to finish line 30
	# End cutscene without fading characters
	end_cutscene_simple()


func play_dialogue_line(line_index: int):
	"""Play a specific dialogue line using DialogueUI and pause AnimationPlayer"""
	print("🎬 play_dialogue_line called with index:", line_index)
	
	# Pause AnimationPlayer during dialogue
	pause_head_police_animation()
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
			
			# Wait for user input to continue (next button press)
			print("⏳ Waiting for user input to continue...")
			# Wait for the next input signal
			await DialogueUI.next_pressed
			print("▶️ User input received, continuing...")
		else:
			print("⚠️ DialogueUI not found in play_dialogue_line!")
	else:
		print("⚠️ Invalid line index:", line_index, "dialogue_lines.size():", dialogue_lines.size())
	
	# Resume AnimationPlayer after dialogue
	resume_head_police_animation()
	print("▶️ AnimationPlayer resumed")

# --------------------------
# EVIDENCE INVENTORY DISPLAY
# --------------------------

func show_evidence_inventory():
	"""Show evidence inventory after line 16, similar to barangay hall cutscene"""
	print("📋 Showing evidence inventory after line 16")
	
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
		
		# Add radio log evidence (4th evidence in new order)
		evidence_ui.add_evidence("radio_log")
		print("📋 Added radio_log evidence (4th evidence)")
		
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

func fade_out_and_transition():
	"""Fade out all characters and tileset, then transition to police_lobby"""
	print("🎬 Fading out all characters and tileset")
	
	# Fade out all characters
	await fade_out_character("Miguel", 2.0)
	await fade_out_character("Celine", 2.0)
	await fade_out_character("PO1_Darwin", 2.0)
	await fade_out_character("Police", 2.0)
	
	# Fade out tileset/background
	fade_out_tileset()
	
	# Wait a moment before transition
	await get_tree().create_timer(1.0).timeout
	
	# Transition to police_lobby scene
	print("🎬 Transitioning to police_lobby scene")
	get_tree().change_scene_to_file("res://scenes/environments/police_lobby.tscn")

func end_cutscene_simple():
	"""End cutscene simply - hide dialogue, fade characters, enable movement, show task"""
	print("🎬 Ending cutscene simply")
	
	# Hide dialogue UI
	if DialogueUI:
		DialogueUI.hide_ui()
		print("💬 Dialogue UI hidden")
	
	# Fade out Celine and PO1 Darwin
	await fade_out_celine_and_po1()
	print("🎬 Celine and PO1 Darwin faded out")
	
	# Re-enable player movement
	enable_player_movement()
	print("✅ Player movement re-enabled")
	
	# Re-enable input processing on the scene
	set_process_input(true)
	set_process_unhandled_input(true)
	print("✅ Cutscene script input processing re-enabled")
	
	# Set checkpoint as completed
	if CheckpointManager:
		CheckpointManager.set_checkpoint(CheckpointManager.CheckpointType.HEAD_POLICE_COMPLETED)
		print("📋 Head police cutscene marked as completed")
	
	# Complete current barangay hall task and set new task to go to morgue
	if TaskManager:
		TaskManager.complete_current_task()
		print("📋 Barangay hall task completed")
		TaskManager.set_current_task("go_to_morgue")
		print("📋 Task set to: go_to_morgue")
	else:
		print("⚠️ TaskManager not found - task not set")
	
	print("🎬 Cutscene ended - player can now move and task is displayed")

func end_cutscene_and_spawn():
	"""End cutscene and spawn player in police_lobby at coordinates 768.0, 312.0"""
	print("🎬 Ending cutscene and spawning in police_lobby")
	
	# Fade out characters and tileset
	await fade_out_all_characters()
	print("🎬 All characters faded out")
	
	# Re-enable player movement
	enable_player_movement()
	print("✅ Player movement re-enabled")
	
	# Re-enable input processing on the scene
	set_process_input(true)
	set_process_unhandled_input(true)
	print("✅ Cutscene script input processing re-enabled")
	
	# Set checkpoint as completed
	if CheckpointManager:
		CheckpointManager.set_checkpoint(CheckpointManager.CheckpointType.HEAD_POLICE_COMPLETED)
		print("📋 Head police cutscene marked as completed")
	
	# SpawnManager removed - player will spawn at default position
	print("📍 SpawnManager logic removed - using default spawn position")
	
	# Set task to go to morgue
	if TaskManager:
		TaskManager.set_current_task("Go to morgue to check autopsy report")
		print("📋 Task set to: Go to morgue to check autopsy report")
	else:
		print("⚠️ TaskManager not found - task not set")
	
	# Small delay to ensure SpawnManager data is set
	await get_tree().create_timer(0.1).timeout
	
	# Transition to police_lobby
	print("🎬 Transitioning to police_lobby")
	get_tree().change_scene_to_file("res://scenes/environments/police_lobby.tscn")

# --------------------------
# CHARACTER FADE METHODS
# --------------------------

func fade_out_celine_and_po1():
	"""Fade out Celine and PO1 Darwin specifically"""
	print("🎬 Fading out Celine and PO1 Darwin")
	
	# Find and fade out Celine - try multiple search methods
	var celine = null
	
	# Method 1: Direct node search
	celine = get_node_or_null("Celine")
	if not celine:
		# Method 2: Search in parent scene
		var parent_scene = get_parent()
		if parent_scene:
			celine = parent_scene.get_node_or_null("Celine")
	if not celine:
		# Method 3: Search for any node with "celine" in the name
		celine = find_node_with_name_containing("celine")
	if not celine:
		# Method 4: Search all nodes recursively
		celine = find_character_node("Celine")
	
	if celine:
		print("🎬 Found Celine:", celine.name, "at path:", celine.get_path())
		var tween = create_tween()
		tween.tween_property(celine, "modulate:a", 0.0, 1.0)
		print("🎬 Fading out Celine")
		await tween.finished
		celine.visible = false
		celine.modulate.a = 1.0  # Reset for next time
	else:
		print("⚠️ Celine not found with any method")
	
	# Find and fade out PO1 Darwin (actual node name: NpcPlPo1Darwin)
	var po1_darwin = get_node_or_null("NpcPlPo1Darwin")
	if not po1_darwin:
		# Try alternative search methods
		var parent_scene = get_parent()
		if parent_scene:
			po1_darwin = parent_scene.get_node_or_null("NpcPlPo1Darwin")
	if not po1_darwin:
		po1_darwin = find_character_node("NpcPlPo1Darwin")
	
	if po1_darwin:
		print("🎬 Found PO1 Darwin:", po1_darwin.name, "at path:", po1_darwin.get_path())
		var tween = create_tween()
		tween.tween_property(po1_darwin, "modulate:a", 0.0, 1.0)
		print("🎬 Fading out PO1 Darwin")
		await tween.finished
		po1_darwin.visible = false
		po1_darwin.modulate.a = 1.0  # Reset for next time
	else:
		print("⚠️ NpcPlPo1Darwin not found with any method")
	
	print("🎬 Celine and PO1 Darwin fade out completed")

func find_character_node(character_name: String) -> Node:
	"""Recursively search for a character node"""
	var current_scene = get_tree().current_scene
	if current_scene:
		return find_character_recursive(current_scene, character_name)
	return null

func find_node_with_name_containing(search_name: String) -> Node:
	"""Find any node that contains the search name in its name"""
	var current_scene = get_tree().current_scene
	if current_scene:
		return find_node_with_name_containing_recursive(current_scene, search_name)
	return null

func find_node_with_name_containing_recursive(node: Node, search_name: String) -> Node:
	"""Recursively search for a node containing the search name"""
	# Check if this node's name contains the search term
	if search_name.to_lower() in node.name.to_lower():
		return node
	
	# Check children
	for child in node.get_children():
		var result = find_node_with_name_containing_recursive(child, search_name)
		if result:
			return result
	
	return null

func find_character_recursive(node: Node, character_name: String) -> Node:
	"""Recursively search for a character node"""
	# Check if this node matches the character name
	if node.name == character_name:
		return node
	
	# Check if this node has a script that might be the character
	if node.has_method("_ready") and (character_name == "Celine" and "celine" in node.name.to_lower()):
		return node
	
	# Check if this node has a child that matches
	for child in node.get_children():
		var result = find_character_recursive(child, character_name)
		if result:
			return result
	
	return null

func fade_out_all_characters():
	"""Fade out all characters and tileset"""
	print("🎬 Starting fade out of all characters")
	
	# Find all character nodes and fade them out
	var characters = []
	
	# Look for common character node names
	var possible_character_names = ["PlayerM", "Celine", "PO1_Darwin", "Police", "Miguel"]
	
	for name in possible_character_names:
		var character = get_node_or_null(name)
		if character:
			characters.append(character)
			print("🎬 Found character:", name)
	
	# Also look for characters in groups
	var player_group = get_tree().get_nodes_in_group("player")
	var npc_group = get_tree().get_nodes_in_group("npc")
	var character_group = get_tree().get_nodes_in_group("character")
	
	characters.append_array(player_group)
	characters.append_array(npc_group)
	characters.append_array(character_group)
	
	# Remove duplicates
	var unique_characters = []
	for char in characters:
		if char and not char in unique_characters:
			unique_characters.append(char)
	
	print("🎬 Fading out", unique_characters.size(), "characters")
	
	# Fade out all characters simultaneously
	var fade_tweens = []
	for character in unique_characters:
		if character and character.has_method("modulate"):
			var tween = create_tween()
			tween.tween_property(character, "modulate:a", 0.0, 1.0)
			fade_tweens.append(tween)
		elif character and character.has_method("set_modulate"):
			var tween = create_tween()
			tween.tween_property(character, "modulate:a", 0.0, 1.0)
			fade_tweens.append(tween)
	
	# Wait for all fades to complete
	if fade_tweens.size() > 0:
		await get_tree().create_timer(1.0).timeout
		print("🎬 All characters faded out")
	else:
		print("⚠️ No characters found to fade out")
	
	# Also try to fade out tileset/background
	fade_out_tileset()
	
	print("🎬 Fade out sequence completed")

func fade_out_tileset():
	"""Fade out the tileset/background"""
	print("🎬 Fading out tileset")
	
	# Look for common tileset/background nodes
	var tileset_nodes = []
	
	# Try to find tileset by name
	var possible_tileset_names = ["TileMap", "Background", "Tileset", "Environment"]
	
	for name in possible_tileset_names:
		var node = get_node_or_null(name)
		if node:
			tileset_nodes.append(node)
			print("🎬 Found tileset node:", name)
	
	# Also look for nodes in groups
	var tilemap_group = get_tree().get_nodes_in_group("tilemap")
	var background_group = get_tree().get_nodes_in_group("background")
	
	tileset_nodes.append_array(tilemap_group)
	tileset_nodes.append_array(background_group)
	
	# Fade out tileset nodes
	for node in tileset_nodes:
		if node and node.has_method("modulate"):
			var tween = create_tween()
			tween.tween_property(node, "modulate:a", 0.0, 1.0)
			print("🎬 Fading out tileset node:", node.name)
	
	print("🎬 Tileset fade out initiated")

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

# Specific character fade methods for AnimationPlayer
func fade_in_miguel():
	"""Fade in Miguel character"""
	await fade_in_character("Miguel")

func fade_out_miguel():
	"""Fade out Miguel character"""
	await fade_out_character("Miguel")

func fade_in_celine():
	"""Fade in Celine character"""
	await fade_in_character("Celine")

func fade_out_celine():
	"""Fade out Celine character"""
	await fade_out_character("Celine")

func fade_in_po1_darwin():
	"""Fade in PO1 Darwin character"""
	await fade_in_character("PO1_Darwin")

func fade_out_po1_darwin():
	"""Fade out PO1 Darwin character"""
	await fade_out_character("PO1_Darwin")

func fade_in_random_police():
	"""Fade in Random Police character"""
	await fade_in_character("Random_Police")

func fade_out_random_police():
	"""Fade out Random Police character"""
	await fade_out_character("Random_Police")


# --------------------------
# AUDIO FADE METHODS
# --------------------------

func fade_out_police_bgm(duration: float = 2.0):
	"""Fade out the police station BGM"""
	if AudioManager:
		await AudioManager.fade_out_bgm(duration)
		print("🎵 Police station BGM faded out")
	else:
		print("⚠️ AudioManager not found")

func start_police_bgm():
	"""Start the police station BGM for head police cutscene"""
	if AudioManager:
		AudioManager.set_scene_bgm("police_station")
		print("🎵 Police station BGM started for head police cutscene")
	else:
		print("⚠️ AudioManager not found")

func stop_police_bgm():
	"""Stop the police station BGM immediately"""
	if AudioManager:
		AudioManager.stop_bgm()
		print("🎵 Police station BGM stopped")
	else:
		print("⚠️ AudioManager not found")

# --------------------------
# CHARACTER COLOR METHODS
# --------------------------

func make_character_white(character_name: String):
	"""Make a character completely white"""
	var character = get_node_or_null(character_name)
	if character:
		character.modulate = Color.WHITE
		print("⚪ Character made white:", character_name)
	else:
		print("⚠️ Character not found:", character_name)

func make_character_red(character_name: String):
	"""Make a character red"""
	var character = get_node_or_null(character_name)
	if character:
		character.modulate = Color.RED
		print("🔴 Character made red:", character_name)
	else:
		print("⚠️ Character not found:", character_name)

func make_character_black(character_name: String):
	"""Make a character black"""
	var character = get_node_or_null(character_name)
	if character:
		character.modulate = Color.BLACK
		print("⚫ Character made black:", character_name)
	else:
		print("⚠️ Character not found:", character_name)

func make_character_normal(character_name: String):
	"""Reset character to normal color"""
	var character = get_node_or_null(character_name)
	if character:
		character.modulate = Color.WHITE
		print("🎨 Character reset to normal:", character_name)
	else:
		print("⚠️ Character not found:", character_name)

# Specific character color methods for AnimationPlayer
func make_miguel_white(): make_character_white("Miguel")
func make_miguel_red(): make_character_red("Miguel")
func make_miguel_black(): make_character_black("Miguel")
func make_miguel_normal(): make_character_normal("Miguel")

func make_celine_white(): make_character_white("Celine")
func make_celine_red(): make_character_red("Celine")
func make_celine_black(): make_character_black("Celine")
func make_celine_normal(): make_character_normal("Celine")

func make_po1_darwin_white(): make_character_white("PO1_Darwin")
func make_po1_darwin_red(): make_character_red("PO1_Darwin")
func make_po1_darwin_black(): make_character_black("PO1_Darwin")
func make_po1_darwin_normal(): make_character_normal("PO1_Darwin")

# --------------------------
# CUTSCENE END METHODS
# --------------------------

func end_head_police_cutscene():
	"""End the head police cutscene and transition to next scene"""
	print("🎬 Ending head police cutscene...")
	
	# Disable cutscene mode for DialogueUI
	if DialogueUI and DialogueUI.has_method("set_cutscene_mode"):
		DialogueUI.set_cutscene_mode(false)
		print("🎬 DialogueUI cutscene mode disabled")
	
	# Hide all characters
	fade_out_miguel()
	fade_out_celine()
	fade_out_po1_darwin()
	fade_out_random_police()
	
	# Set checkpoint to mark head police cutscene as completed
	var checkpoint_manager = get_node("/root/CheckpointManager")
	checkpoint_manager.set_checkpoint(CheckpointManager.CheckpointType.HEAD_POLICE_COMPLETED)
	print("📋 Head police cutscene checkpoint set")
	
	# Smooth audio transition - fade out police BGM
	print("🎵 Fading out police BGM...")
	await fade_out_police_bgm(2.0)  # 2-second fade out
	
	# Brief pause for smooth transition
	await get_tree().create_timer(0.5).timeout
	
	print("✅ Head police cutscene completed - returning to normal gameplay")

func hide_all_characters():
	"""Hide all characters in the scene"""
	fade_out_miguel()
	fade_out_celine()
	fade_out_po1_darwin()
	fade_out_random_police()
	print("👻 All characters hidden")

# --------------------------
# DEBUG CONTROLS AND LINEAR FLOW
# --------------------------

func skip_to_next_scene():
	"""Skip head police cutscene and go directly to morgue scene"""
	print("🚀 DEBUG: Skipping head police cutscene, going to morgue scene")
	
	# Disable cutscene mode for DialogueUI
	if DialogueUI and DialogueUI.has_method("set_cutscene_mode"):
		DialogueUI.set_cutscene_mode(false)
		print("🎬 DialogueUI cutscene mode disabled")
	
	# Set checkpoint
	var checkpoint_manager = get_node("/root/CheckpointManager")
	checkpoint_manager.set_checkpoint(CheckpointManager.CheckpointType.HEAD_POLICE_COMPLETED)
	print("📋 Head police cutscene checkpoint set")
	
	# Brief pause for smooth transition
	await get_tree().create_timer(0.5).timeout
	print("✅ Head police cutscene skipped - returning to normal gameplay")

func debug_complete_head_police():
	"""Debug function to complete head police cutscene instantly"""
	print("🚀 DEBUG: Completing head police cutscene instantly")
	
	# Stop any running animations
	if $AnimationPlayer:
		$AnimationPlayer.stop()
		print("📋 AnimationPlayer stopped")
	
	# Set checkpoint
	var checkpoint_manager = get_node("/root/CheckpointManager")
	checkpoint_manager.set_checkpoint(CheckpointManager.CheckpointType.HEAD_POLICE_COMPLETED)
	print("📋 Head police cutscene checkpoint set")
	
	# Transition to next scene
	await get_tree().create_timer(0.5).timeout
	skip_to_next_scene()

func debug_restart_head_police():
	"""Debug function to restart head police cutscene from beginning"""
	print("🔄 DEBUG: Restarting head police cutscene from beginning")
	
	# Restart the head police sequence
	start_head_police_cutscene()

func _unhandled_input(event: InputEvent) -> void:
	"""Handle debug input controls"""
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_F10:
				# F10 - Complete head police cutscene instantly and go to next scene (DEBUG ONLY)
				var debug_mode = false  # Set to true only for development
				if debug_mode:
					debug_complete_head_police()
					print("🚀 DEBUG: Head police cutscene skipped")
				else:
					print("⚠️ Debug skip disabled - complete cutscene normally")
			KEY_F7:
				# F7 - Restart head police cutscene from beginning
				debug_restart_head_police()
			KEY_F1:
				# F1 - Skip to next scene
				skip_to_next_scene()
			KEY_F2:
				# F2 - Start police BGM
				start_police_bgm()
			KEY_F3:
				# F3 - Stop police BGM
				stop_police_bgm()
			KEY_F4:
				# F4 - Fade out police BGM
				fade_out_police_bgm()

# --------------------------
# SCENE INITIALIZATION
# --------------------------

func start_head_police_cutscene() -> void:
	"""Start the head police cutscene sequence"""
	is_in_cutscene = true
	
	# Enable cutscene mode for DialogueUI (hide Next button)
	if DialogueUI and DialogueUI.has_method("set_cutscene_mode"):
		DialogueUI.set_cutscene_mode(true)
		print("🎬 DialogueUI set to cutscene mode")
	
	# Smooth audio transition - start police BGM with fade in
	print("🎵 Starting police BGM with smooth fade in...")
	start_police_bgm()
	
	# Auto-play the head police animation when scene starts
	play_head_police_animation()
	
	# Start the dialogue after a brief delay
	await get_tree().create_timer(1.0).timeout
	await play_dialogue()
	
	# End the cutscene
	end_head_police_cutscene()
