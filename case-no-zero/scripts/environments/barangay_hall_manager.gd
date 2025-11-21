extends Node

var anim_player: AnimationPlayer = null
var player_node: Node = null
var dialogue_lines: Array[Dictionary] = []
var fade_layer: CanvasLayer
var fade_rect: ColorRect
var resume_on_next: bool = false
var cutscene_active: bool = false
var evidence_added: bool = false  # Prevent duplicate evidence addition

func _ready() -> void:
	print("🎬 Barangay hall cutscene: _ready() started")
	
	# Find AnimationPlayer (sibling node in scene root)
	var root_scene := get_tree().current_scene
	if root_scene != null:
		anim_player = root_scene.get_node_or_null("AnimationPlayer")
		if anim_player == null:
			# Try recursive search
			var found := root_scene.find_child("AnimationPlayer", true, false)
			if found is AnimationPlayer:
				anim_player = found
	
	# Find player
	player_node = _find_player()
	
	# Load dialogue
	_load_dialogue_if_available()
	
	# Connect DialogueUI next_pressed signal (use autoload directly)
	if DialogueUI and DialogueUI.has_signal("next_pressed") and not DialogueUI.next_pressed.is_connected(_on_dialogue_next):
		DialogueUI.next_pressed.connect(_on_dialogue_next)
	
	# Check if CELINE_CALL_COMPLETED - play barangay hall cutscene (only once)
	if CheckpointManager.has_checkpoint(CheckpointManager.CheckpointType.CELINE_CALL_COMPLETED):
		if not CheckpointManager.has_checkpoint(CheckpointManager.CheckpointType.BARANGAY_HALL_CUTSCENE_COMPLETED):
			print("🎬 CELINE_CALL_COMPLETED - playing barangay hall cutscene")
			# Hide task display when entering barangay hall
			_hide_task_display()
			# Start cutscene
			cutscene_active = true
			
			# Disable player movement during cutscene
			_set_player_active(false)
			
			# Wait for scene fade-in to complete
			await get_tree().process_frame
			await get_tree().process_frame
			await get_tree().process_frame
			
			var scene_root := get_tree().current_scene
			var fade_in_node := scene_root.get_node_or_null("SceneFadeIn") if scene_root != null else null
			if fade_in_node != null:
				await get_tree().create_timer(0.3).timeout
			else:
				await get_tree().create_timer(0.2).timeout
			
			# Play barangay hall cutscene animation
			if anim_player != null:
				if anim_player.has_animation("baranggay_hall_cutscene"):
					print("🎬 Playing baranggay_hall_cutscene animation")
					anim_player.play("baranggay_hall_cutscene")
					# Wait for animation to finish
					# Note: _set_barangay_hall_completed() should be called from AnimationPlayer method call track
					await anim_player.animation_finished
					# Fallback: if not called from animation, call it here
					if not CheckpointManager.has_checkpoint(CheckpointManager.CheckpointType.BARANGAY_HALL_CUTSCENE_COMPLETED):
						_set_barangay_hall_completed()
				else:
					print("⚠️ No 'baranggay_hall_cutscene' animation found. Available animations: ", anim_player.get_animation_list())
					_set_player_active(true)
			else:
				print("⚠️ AnimationPlayer not found!")
				_set_player_active(true)
		else:
			# Barangay hall cutscene already completed - enable player
			print("🎬 Barangay hall cutscene already completed")
			_set_player_active(true)
	else:
		# Celine call not completed yet - enable player
		print("🎬 CELINE_CALL_COMPLETED not set yet - enabling player")
		_set_player_active(true)

# ---- Player helpers ----
func _find_player() -> Node:
	var root_scene := get_tree().current_scene
	if root_scene == null:
		return null
	
	# Try direct child first
	var direct := root_scene.get_node_or_null("PlayerM")
	if direct != null:
		return direct
	
	# Try recursive search
	var candidates := root_scene.find_children("*", "", true, false)
	for n in candidates:
		if String(n.name).to_lower().contains("playerm") or String(n.name).to_lower().contains("player"):
			return n
	
	return null

func _set_player_active(active: bool) -> void:
	if player_node == null:
		player_node = _find_player()
	if player_node == null:
		print("⚠️ Cannot set player active - player not found")
		return
	
	if not active:
		if "control_enabled" in player_node:
			player_node.control_enabled = false
		if "velocity" in player_node:
			player_node.velocity = Vector2.ZERO
		if player_node.has_method("set_process_input"):
			player_node.set_process_input(false)
		if player_node.has_method("set_physics_process"):
			player_node.set_physics_process(false)
		print("🎬 Player movement disabled")
	else:
		if player_node.has_method("enable_movement"):
			player_node.enable_movement()
		if player_node.has_method("set_process_input"):
			player_node.set_process_input(true)
		if player_node.has_method("set_physics_process"):
			player_node.set_physics_process(true)
		if "control_enabled" in player_node:
			player_node.control_enabled = true
		print("🎬 Player movement enabled")

# ---- Dialogue helpers ----
func show_line(index: int, auto_advance: bool = false) -> void:
	if index < 0 or index >= dialogue_lines.size():
		push_warning("Dialogue index out of range: " + str(index))
		return
	var line: Dictionary = dialogue_lines[index]
	var speaker: String = String(line.get("speaker", ""))
	var text: String = String(line.get("text", ""))
	if DialogueUI == null:
		print("⚠️ DialogueUI autoload not found.")
		return
	if DialogueUI.has_method("set_cutscene_mode"):
		DialogueUI.set_cutscene_mode(true)
	if DialogueUI.has_method("show_dialogue_line"):
		# Invert auto_advance: when user sets auto_advance=true, we want to wait (not auto-advance)
		# So pass the opposite to DialogueUI
		DialogueUI.show_dialogue_line(speaker, text, not auto_advance)
		if auto_advance:
			# When auto_advance is true, show next button and wait for user to press it
			resume_on_next = false
			await wait_for_next()
		return
	print("⚠️ DialogueUI missing show_dialogue_line().")

func show_line_auto_advance(index: int, delay_after: float = 2.0) -> void:
	"""Show a line with auto-advance: wait for typing to finish + delay, then auto-advance"""
	if index < 0 or index >= dialogue_lines.size():
		push_warning("Dialogue index out of range: " + str(index))
		return
	var line: Dictionary = dialogue_lines[index]
	var _speaker: String = String(line.get("speaker", ""))
	var text: String = String(line.get("text", ""))
	
	# Show the line (typing will start) - pass false to actually auto-advance
	show_line(index, false)  # false = auto-advance mode (hides button)
	
	# Calculate typing duration: text_length * typing_speed (0.01 seconds per character)
	var typing_speed: float = 0.01  # From DialogueUI
	var text_length: int = text.length()
	var typing_duration: float = float(text_length) * typing_speed
	
	# Wait for typing to complete
	await get_tree().create_timer(typing_duration).timeout
	
	# Wait additional delay after typing finishes
	await get_tree().create_timer(delay_after).timeout
	
	# Auto-advance by emitting next_pressed signal (use autoload directly)
	if DialogueUI and DialogueUI.has_signal("next_pressed"):
		DialogueUI.emit_signal("next_pressed")

func wait_for_next() -> void:
	_set_player_active(false)
	resume_on_next = true
	if anim_player:
		anim_player.pause()
		print("🎬 Animation paused, waiting for next_pressed")

func show_line_wait(index: int) -> void:
	if index < 0 or index >= dialogue_lines.size():
		push_warning("Dialogue index out of range: " + str(index))
		return
	show_line(index, false)
	wait_for_next()

func _on_dialogue_next() -> void:
	# Ignore DialogueUI next presses when the cutscene is no longer active.
	# Without this guard, every normal conversation in the game would call
	# this handler (signal stays connected) and permanently disable player input.
	if not cutscene_active:
		return
	
	if player_node != null:
		if "control_enabled" in player_node:
			player_node.control_enabled = false
		if "velocity" in player_node:
			player_node.velocity = Vector2.ZERO
	if resume_on_next and anim_player:
		resume_on_next = false
		print("🎬 Resuming animation after next_pressed")
		anim_player.play()

func _hide_dialogue_ui() -> void:
	if DialogueUI and DialogueUI.has_method("hide_ui"):
		DialogueUI.hide_ui()

func _load_dialogue_if_available() -> void:
	var path := "res://data/dialogues/barangay_hall_investigation_dialogue.json"
	if not ResourceLoader.exists(path):
		print("⚠️ Barangay hall dialogue file not found: ", path)
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		print("⚠️ Cannot open barangay hall dialogue file: ", path)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		print("⚠️ Invalid barangay hall dialogue JSON format")
		return
	var section: Variant = (parsed as Dictionary).get("barangay_hall_investigation", {})
	if typeof(section) != TYPE_DICTIONARY:
		print("⚠️ Missing 'barangay_hall_investigation' section in dialogue file")
		return
	var arr: Variant = (section as Dictionary).get("dialogue_lines", [])
	if typeof(arr) == TYPE_ARRAY:
		dialogue_lines.clear()
		for item in (arr as Array):
			if typeof(item) == TYPE_DICTIONARY:
				dialogue_lines.append(item as Dictionary)
		print("📝 Loaded ", dialogue_lines.size(), " dialogue lines from barangay_hall_investigation_dialogue.json")

# ---- Cutscene completion (callable from AnimationPlayer) ----
func _set_barangay_hall_completed() -> void:
	"""Set the BARANGAY_HALL_CUTSCENE_COMPLETED checkpoint after animation completes - callable from AnimationPlayer"""
	# Prevent duplicate checkpoint setting
	if CheckpointManager.has_checkpoint(CheckpointManager.CheckpointType.BARANGAY_HALL_CUTSCENE_COMPLETED):
		print("🎬 BARANGAY_HALL_CUTSCENE_COMPLETED already set, skipping")
		return
	
	# Hide dialogue UI first
	_hide_dialogue_ui()
	
	# Set checkpoint
	CheckpointManager.set_checkpoint(CheckpointManager.CheckpointType.BARANGAY_HALL_CUTSCENE_COMPLETED)
	print("🎬 Barangay hall cutscene completed, checkpoint set.")
	
	# Update task display to "Pumunta sa morgue"
	_show_task_display("Pumunta sa morgue")
	
	# Reset DialogueUI cutscene mode FIRST
	if DialogueUI and DialogueUI.has_method("set_cutscene_mode"):
		DialogueUI.set_cutscene_mode(false)
		print("🎬 Reset DialogueUI cutscene_mode to false")
	
	# Mark cutscene as inactive FIRST - this stops _process() from disabling movement
	cutscene_active = false
	print("🎬 cutscene_active set to FALSE")
	
	# Re-enable player movement - fully restore all processing
	if player_node == null:
		player_node = _find_player()
	
	if player_node != null:
		print("🔧 Barangay Hall: Restoring player movement...")
		# Re-enable input/physics processing FIRST
		if player_node.has_method("set_process_input"):
			player_node.set_process_input(true)
			print("   ✅ Enabled set_process_input(true)")
		if player_node.has_method("set_physics_process"):
			player_node.set_physics_process(true)
			print("   ✅ Enabled set_physics_process(true)")
		
		# Re-enable movement control - call enable_movement() which sets control_enabled
		if player_node.has_method("enable_movement"):
			player_node.enable_movement()
			print("   ✅ Called enable_movement()")
		
		# Force set control_enabled to true - make absolutely sure
		if "control_enabled" in player_node:
			player_node.control_enabled = true
			print("   ✅ Force set control_enabled = true")
		
		# Wait a frame to ensure everything is applied
		await get_tree().process_frame
		
		print("🎬 Barangay Hall: Player movement fully restored!")
	else:
		print("⚠️ Barangay Hall: player_node is null! Cannot restore movement!")
		_set_player_active(true)  # Fallback

# ---- AnimationPlayer callable functions ----
# These functions can be called from AnimationPlayer method call tracks

func show_dialogue_line_0() -> void:
	"""Show first line of dialogue - callable from AnimationPlayer"""
	if dialogue_lines.size() > 0:
		show_line_wait(0)
	else:
		print("⚠️ Dialogue not loaded")

func show_dialogue_line_1() -> void:
	"""Show second line of dialogue - callable from AnimationPlayer"""
	if dialogue_lines.size() > 1:
		show_line_wait(1)
	else:
		print("⚠️ Dialogue line 1 not available")

func show_dialogue_line_2() -> void:
	"""Show third line of dialogue - callable from AnimationPlayer"""
	if dialogue_lines.size() > 2:
		show_line_wait(2)
	else:
		print("⚠️ Dialogue line 2 not available")

func show_dialogue_line_3() -> void:
	"""Show fourth line of dialogue - callable from AnimationPlayer"""
	if dialogue_lines.size() > 3:
		show_line_wait(3)
	else:
		print("⚠️ Dialogue line 3 not available")

func show_dialogue_line_4() -> void:
	"""Show fifth line of dialogue - callable from AnimationPlayer"""
	if dialogue_lines.size() > 4:
		show_line_wait(4)
	else:
		print("⚠️ Dialogue line 4 not available")

func show_dialogue_line_5() -> void:
	"""Show sixth line of dialogue - callable from AnimationPlayer"""
	if dialogue_lines.size() > 5:
		show_line_wait(5)
	else:
		print("⚠️ Dialogue line 5 not available")

func show_dialogue_line_6() -> void:
	"""Show seventh line of dialogue - callable from AnimationPlayer"""
	if dialogue_lines.size() > 6:
		show_line_wait(6)
	else:
		print("⚠️ Dialogue line 6 not available")

func show_dialogue_line_7() -> void:
	"""Show eighth line of dialogue - callable from AnimationPlayer"""
	if dialogue_lines.size() > 7:
		show_line_wait(7)
	else:
		print("⚠️ Dialogue line 7 not available")

func show_dialogue_line_8() -> void:
	"""Show ninth line of dialogue - callable from AnimationPlayer"""
	if dialogue_lines.size() > 8:
		show_line_wait(8)
	else:
		print("⚠️ Dialogue line 8 not available")

func show_dialogue_line_9() -> void:
	"""Show tenth line of dialogue - callable from AnimationPlayer"""
	if dialogue_lines.size() > 9:
		show_line_wait(9)
	else:
		print("⚠️ Dialogue line 9 not available")

func show_dialogue_line_10() -> void:
	"""Show eleventh line of dialogue - callable from AnimationPlayer"""
	if dialogue_lines.size() > 10:
		show_line_wait(10)
	else:
		print("⚠️ Dialogue line 10 not available")

func show_dialogue_line_11() -> void:
	"""Show twelfth line of dialogue - callable from AnimationPlayer"""
	if dialogue_lines.size() > 11:
		show_line_wait(11)
	else:
		print("⚠️ Dialogue line 11 not available")

func add_logbook_evidence() -> void:
	"""Add logbook evidence and show inventory - callable from AnimationPlayer"""
	var eis: Node = get_node_or_null("/root/EvidenceInventorySettings")
	if eis == null:
		print("⚠️ EvidenceInventorySettings node not found at /root/EvidenceInventorySettings")
		return
	
	if not eis.has_method("add_evidence"):
		print("⚠️ EvidenceInventorySettings missing add_evidence method")
		return
	
	eis.add_evidence("logbook")
	print("🔎 Logbook evidence added")
	
	# Wait a brief moment to ensure evidence is processed, then show inventory
	await get_tree().create_timer(0.2).timeout
	_show_inventory_brief(3.0)

func add_handwriting_sample_evidence() -> void:
	"""Add handwriting sample evidence and show inventory - callable from AnimationPlayer"""
	var eis: Node = get_node_or_null("/root/EvidenceInventorySettings")
	if eis == null:
		print("⚠️ EvidenceInventorySettings node not found at /root/EvidenceInventorySettings")
		return
	
	if not eis.has_method("add_evidence"):
		print("⚠️ EvidenceInventorySettings missing add_evidence method")
		return
	
	eis.add_evidence("handwriting_sample")
	print("🔎 Handwriting sample evidence added")
	
	# Wait a brief moment to ensure evidence is processed, then show inventory
	await get_tree().create_timer(0.2).timeout
	_show_inventory_brief(3.0)

func _show_inventory_brief(seconds: float = 3.0) -> void:
	"""Briefly show the evidence inventory for a few seconds"""
	var inv: Node = get_node_or_null("/root/EvidenceInventorySettings")
	if inv == null:
		print("⚠️ EvidenceInventorySettings not found for brief show")
		return
	
	# Use the proper API method to show the inventory
	if inv.has_method("show_evidence_inventory"):
		inv.show_evidence_inventory()
		# Wait for the specified duration
		await get_tree().create_timer(max(0.1, seconds)).timeout
		# Hide the inventory
		if inv.has_method("hide_evidence_inventory"):
			inv.hide_evidence_inventory()
		print("🔎 Evidence inventory shown briefly for ", seconds, " seconds")
		return
	
	# Fallback: try to access ui_container directly
	if inv.has("ui_container"):
		var ui_container = inv.ui_container
		if ui_container is CanvasItem:
			var ci := ui_container as CanvasItem
			ci.visible = true
			# Prepare initial state
			ci.modulate.a = 0.0
			if ui_container is Node2D or ui_container is Control:
				ui_container.scale = Vector2(0.9, 0.9)
			# Tween in
			var tin := create_tween()
			tin.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tin.tween_property(ci, "modulate:a", 1.0, 0.25)
			if ui_container is Node2D or ui_container is Control:
				tin.tween_property(ui_container, "scale", Vector2(1.0, 1.0), 0.25)
			await tin.finished
			# Hold
			await get_tree().create_timer(max(0.1, seconds)).timeout
			# Tween out
			var tout := create_tween()
			tout.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
			tout.tween_property(ci, "modulate:a", 0.0, 0.25)
			await tout.finished
			ci.visible = false
			print("🔎 Evidence inventory shown briefly for ", seconds, " seconds (fallback method)")

func _hide_task_display() -> void:
	"""Hide the task display"""
	var task_display: Node = get_node_or_null("/root/TaskDisplay")
	if task_display == null:
		# Try to find it in scene tree
		var tree := get_tree()
		if tree:
			var found := tree.get_first_node_in_group("task_display")
			if found:
				task_display = found
	if task_display != null and task_display.has_method("hide_task"):
		task_display.hide_task()
		print("📝 Task display hidden")
	else:
		print("⚠️ TaskDisplay not found or missing hide_task() method")

func _show_task_display(task_text: String) -> void:
	"""Show the task display with the given text"""
	var task_display: Node = get_node_or_null("/root/TaskDisplay")
	if task_display == null:
		# Try to find it in scene tree
		var tree := get_tree()
		if tree:
			var found := tree.get_first_node_in_group("task_display")
			if found:
				task_display = found
	if task_display != null and task_display.has_method("show_task"):
		task_display.show_task(task_text)
		print("📝 Task display updated: ", task_text)
	else:
		print("⚠️ TaskDisplay not found or missing show_task() method")

func end_cutscene() -> void:
	"""End the cutscene - callable from AnimationPlayer"""
	_set_barangay_hall_completed()
