extends Node

var anim_player: AnimationPlayer = null
var player_node: Node = null
var dialogue_lines: Array[Dictionary] = []
var fade_layer: CanvasLayer
var fade_rect: ColorRect
var resume_on_next: bool = false
var cutscene_active: bool = false
var evidence_added: bool = false

func _ready() -> void:
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
			_hide_task_display()
			cutscene_active = true
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
					anim_player.play("baranggay_hall_cutscene")
					await anim_player.animation_finished
					if not CheckpointManager.has_checkpoint(CheckpointManager.CheckpointType.BARANGAY_HALL_CUTSCENE_COMPLETED):
						_set_barangay_hall_completed()
				else:
					push_warning("No 'baranggay_hall_cutscene' animation found. Available animations: " + str(anim_player.get_animation_list()))
					_set_player_active(true)
			else:
				push_warning("AnimationPlayer not found!")
				_set_player_active(true)
		else:
			_set_player_active(true)
	else:
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
	else:
		if player_node.has_method("enable_movement"):
			player_node.enable_movement()
		if player_node.has_method("set_process_input"):
			player_node.set_process_input(true)
		if player_node.has_method("set_physics_process"):
			player_node.set_physics_process(true)
		if "control_enabled" in player_node:
			player_node.control_enabled = true

# ---- Dialogue helpers ----
func show_line(index: int, auto_advance: bool = false) -> void:
	if index < 0 or index >= dialogue_lines.size():
		push_warning("Dialogue index out of range: " + str(index))
		return
	var line: Dictionary = dialogue_lines[index]
	var speaker: String = String(line.get("speaker", ""))
	var text: String = String(line.get("text", ""))
	if DialogueUI == null:
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

func show_line_wait(index: int) -> void:
	if index < 0 or index >= dialogue_lines.size():
		push_warning("Dialogue index out of range: " + str(index))
		return
	show_line(index, false)
	wait_for_next()

func _on_dialogue_next() -> void:
	if player_node != null:
		if "control_enabled" in player_node:
			player_node.control_enabled = false
		if "velocity" in player_node:
			player_node.velocity = Vector2.ZERO
	if resume_on_next and anim_player:
		resume_on_next = false
		anim_player.play()

func _hide_dialogue_ui() -> void:
	if DialogueUI and DialogueUI.has_method("hide_ui"):
		DialogueUI.hide_ui()

func _load_dialogue_if_available() -> void:
	var path := "res://data/dialogues/barangay_hall_investigation_dialogue.json"
	if not ResourceLoader.exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var section: Variant = (parsed as Dictionary).get("barangay_hall_investigation", {})
	if typeof(section) != TYPE_DICTIONARY:
		return
	var arr: Variant = (section as Dictionary).get("dialogue_lines", [])
	if typeof(arr) == TYPE_ARRAY:
		dialogue_lines.clear()
		for item in (arr as Array):
			if typeof(item) == TYPE_DICTIONARY:
				dialogue_lines.append(item as Dictionary)

func _set_barangay_hall_completed() -> void:
	if CheckpointManager.has_checkpoint(CheckpointManager.CheckpointType.BARANGAY_HALL_CUTSCENE_COMPLETED):
		return
	
	_hide_dialogue_ui()
	CheckpointManager.set_checkpoint(CheckpointManager.CheckpointType.BARANGAY_HALL_CUTSCENE_COMPLETED)
	_show_task_display("Pumunta sa morgue")
	
	if DialogueUI and DialogueUI.has_method("set_cutscene_mode"):
		DialogueUI.set_cutscene_mode(false)
	
	cutscene_active = false
	
	if player_node == null:
		player_node = _find_player()
	
	if player_node != null:
		if player_node.has_method("set_process_input"):
			player_node.set_process_input(true)
		if player_node.has_method("set_physics_process"):
			player_node.set_physics_process(true)
		
		if player_node.has_method("enable_movement"):
			player_node.enable_movement()
		
		if "control_enabled" in player_node:
			player_node.control_enabled = true
		
		await get_tree().process_frame
	else:
		_set_player_active(true)

func show_dialogue_line_0() -> void:
	if dialogue_lines.size() > 0:
		show_line_wait(0)

func show_dialogue_line_1() -> void:
	if dialogue_lines.size() > 1:
		show_line_wait(1)

func show_dialogue_line_2() -> void:
	if dialogue_lines.size() > 2:
		show_line_wait(2)

func show_dialogue_line_3() -> void:
	if dialogue_lines.size() > 3:
		show_line_wait(3)

func show_dialogue_line_4() -> void:
	if dialogue_lines.size() > 4:
		show_line_wait(4)

func show_dialogue_line_5() -> void:
	if dialogue_lines.size() > 5:
		show_line_wait(5)

func show_dialogue_line_6() -> void:
	if dialogue_lines.size() > 6:
		show_line_wait(6)

func show_dialogue_line_7() -> void:
	if dialogue_lines.size() > 7:
		show_line_wait(7)

func show_dialogue_line_8() -> void:
	if dialogue_lines.size() > 8:
		show_line_wait(8)

func show_dialogue_line_9() -> void:
	if dialogue_lines.size() > 9:
		show_line_wait(9)

func show_dialogue_line_10() -> void:
	if dialogue_lines.size() > 10:
		show_line_wait(10)

func show_dialogue_line_11() -> void:
	if dialogue_lines.size() > 11:
		show_line_wait(11)

func add_logbook_evidence() -> void:
	var eis: Node = get_node_or_null("/root/EvidenceInventorySettings")
	if eis == null:
		return
	
	if not eis.has_method("add_evidence"):
		return
	
	eis.add_evidence("logbook")
	
	# Wait a brief moment to ensure evidence is processed, then show inventory
	await get_tree().create_timer(0.2).timeout
	_show_inventory_brief(3.0)

func add_handwriting_sample_evidence() -> void:
	var eis: Node = get_node_or_null("/root/EvidenceInventorySettings")
	if eis == null:
		return
	
	if not eis.has_method("add_evidence"):
		return
	
	eis.add_evidence("handwriting_sample")
	
	# Wait a brief moment to ensure evidence is processed, then show inventory
	await get_tree().create_timer(0.2).timeout
	_show_inventory_brief(3.0)

func _show_inventory_brief(seconds: float = 3.0) -> void:
	var inv: Node = get_node_or_null("/root/EvidenceInventorySettings")
	if inv == null:
		return
	
	if inv.has_method("show_evidence_inventory"):
		inv.show_evidence_inventory()
		await get_tree().create_timer(max(0.1, seconds)).timeout
		if inv.has_method("hide_evidence_inventory"):
			inv.hide_evidence_inventory()
		return
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

func _hide_task_display() -> void:
	var task_display: Node = get_node_or_null("/root/TaskDisplay")
	if task_display == null:
		var tree := get_tree()
		if tree:
			var found := tree.get_first_node_in_group("task_display")
			if found:
				task_display = found
	if task_display != null and task_display.has_method("hide_task"):
		task_display.hide_task()

func _show_task_display(task_text: String) -> void:
	var task_display: Node = get_node_or_null("/root/TaskDisplay")
	if task_display == null:
		var tree := get_tree()
		if tree:
			var found := tree.get_first_node_in_group("task_display")
			if found:
				task_display = found
	if task_display != null and task_display.has_method("show_task"):
		task_display.show_task(task_text)

func end_cutscene() -> void:
	_set_barangay_hall_completed()
