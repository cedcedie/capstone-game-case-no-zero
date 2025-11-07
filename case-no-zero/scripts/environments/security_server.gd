extends Node2D

var anim_player: AnimationPlayer = null
var player_node: Node = null
var dialogue_lines: Array[Dictionary] = []
var fade_layer: CanvasLayer
var fade_rect: ColorRect
var resume_on_next: bool = false
var cutscene_active: bool = false

func _ready() -> void:
	print("🎬 Security server: _ready() started")
	# Prepare cutscene: disable player, load dialogue, and optionally auto-start animation
	_setup_fade()
	print("🎬 Fade setup complete")
	player_node = _find_player()
	print("🎬 Player found: ", player_node != null, " - Node: ", player_node)
	if player_node != null:
		print("🎬 Player has disable_movement method: ", player_node.has_method("disable_movement"))
	_set_player_active(false)
	# Load dialogue will be determined based on which cutscene plays
	print("🎬 Dialogue loaded: ", dialogue_lines.size(), " lines")
	# Connect DialogueUI next_pressed signal to resume animation
	var dui: Node = get_node_or_null("/root/DialogueUI")
	if dui and dui.has_signal("next_pressed") and not dui.next_pressed.is_connected(_on_dialogue_next):
		dui.next_pressed.connect(_on_dialogue_next)
	
	# Find AnimationPlayer (could be child or sibling)
	var root_scene := get_tree().current_scene
	if root_scene != null:
		anim_player = root_scene.get_node_or_null("AnimationPlayer")
		if anim_player == null:
			# Try as child of this node
			anim_player = get_node_or_null("AnimationPlayer")
		if anim_player == null:
			# Try recursive search
			var found := root_scene.find_child("AnimationPlayer", true, false)
			if found is AnimationPlayer:
				anim_player = found
	
	# Check if alley cutscene is completed - play security_server_cutscene_2
	if CheckpointManager.has_checkpoint(CheckpointManager.CheckpointType.ALLEY_CUTSCENE_COMPLETED):
		print("🎬 Alley cutscene completed - playing security_server_cutscene_2")
		# Load dialogue for security_server_cutscene_2
		_load_dialogue_if_available("security_server_cutscene_2")
		print("🎬 Dialogue loaded for security_server_cutscene_2: ", dialogue_lines.size(), " lines")
		cutscene_active = true
		show_environment_and_characters()
		await fade_in()
		if anim_player:
			if anim_player.has_animation("security_server_cutscene_2"):
				print("🎬 Playing 'security_server_cutscene_2' animation")
				anim_player.play("security_server_cutscene_2")
			else:
				print("⚠️ Animation 'security_server_cutscene_2' not found")
		return
	
	# DEBUG MODE: Set to true to play cutscene regardless of checkpoint
	var DEBUG_MODE: bool = false
	
	# Check if HEAD_POLICE_COMPLETED checkpoint is set (or DEBUG_MODE)
	if DEBUG_MODE or CheckpointManager.has_checkpoint(CheckpointManager.CheckpointType.HEAD_POLICE_COMPLETED):
		if DEBUG_MODE:
			print("🎬 DEBUG MODE: Playing cutscene regardless of checkpoint")
		else:
			print("🎬 HEAD_POLICE_COMPLETED checkpoint found - playing security_server_cutscene")
		
		# Hide task display when cutscene plays
		_hide_task_display()
		
		# Load dialogue for security_server_cutscene
		_load_dialogue_if_available("security_server_cutscene")
		print("🎬 Dialogue loaded for security_server_cutscene: ", dialogue_lines.size(), " lines")
		
		# Start cutscene for first time
		print("🎬 Starting fade in...")
		cutscene_active = true
		show_environment_and_characters()
		await fade_in()
		print("🎬 Fade in complete, checking animation...")
		if anim_player:
			print("🎬 AnimationPlayer found, available animations: ", anim_player.get_animation_list())
			# Try to play security_server_cutscene first, then fallback to first available
			if anim_player.has_animation("security_server_cutscene"):
				print("🎬 Playing 'security_server_cutscene' animation")
				anim_player.play("security_server_cutscene")
			elif anim_player.get_animation_list().size() > 0:
				var first_anim = anim_player.get_animation_list()[0]
				print("🎬 Playing first available animation: ", first_anim)
				anim_player.play(first_anim)
			else:
				print("⚠️ No animations found in AnimationPlayer")
		else:
			print("⚠️ AnimationPlayer node not found!")
		return
	
	# If no checkpoint, don't play cutscene
	print("⚠️ HEAD_POLICE_COMPLETED checkpoint not set. Cutscene will not play.")
	print("   Set DEBUG_MODE = true in _ready() to test the cutscene.")

func end_cutscene() -> void:
	# Dramatic fade out before scene transition
	print("🎬 Cutscene ending - dramatic fade out...")
	await dramatic_fade_out(2.0)
	
	# Hide dialogue UI during fade
	_hide_dialogue_ui()
	
	# Set checkpoint before transitioning
	cutscene_active = false
	CheckpointManager.set_checkpoint(CheckpointManager.CheckpointType.SECURITY_SERVER_COMPLETED)
	print("🎬 Security server cutscene completed - checkpoint set.")
	
	# Transition to alley scene and play alley_cutscene animation
	# Skip fade since we already did dramatic_fade_out above
	await transition_to_scene("res://scenes/environments/alley/alley.tscn", "alley_cutscene", true)

func end_cutscene_2() -> void:
	"""End security_server_cutscene_2 - set checkpoint and re-enable player"""
	# Hide dialogue UI
	_hide_dialogue_ui()
	
	# Set checkpoint after cutscene completes
	cutscene_active = false
	CheckpointManager.set_checkpoint(CheckpointManager.CheckpointType.SECURITY_SERVER_CUTSCENE_2_COMPLETED)
	print("🎬 Security server cutscene 2 completed - checkpoint set.")
	
	# Re-enable player control
	_set_player_active(true)
	print("🎬 Security server cutscene 2 ended - returning to normal gameplay.")

# Transition to another scene and optionally play an animation
func transition_to_scene(target_scene_path: String, animation_name: String = "", skip_fade: bool = false) -> void:
	"""Transition to another scene and optionally play an animation there"""
	print("🎬 Transitioning to scene: ", target_scene_path)
	
	# Dramatic fade out current scene before transition (unless already faded)
	if not skip_fade:
		await dramatic_fade_out(2.0)
	
	# Hide dialogue UI
	_hide_dialogue_ui()
	
	# Change scene
	var tree := get_tree()
	if tree == null:
		print("⚠️ Cannot transition - tree is null")
		return
	
	var result: Error
	if ScenePreloader and ScenePreloader.is_scene_preloaded(target_scene_path):
		print("🚀 Using preloaded scene: ", target_scene_path.get_file())
		var preloaded_scene = ScenePreloader.get_preloaded_scene(target_scene_path)
		result = tree.change_scene_to_packed(preloaded_scene)
	else:
		print("📁 Loading scene from file: ", target_scene_path.get_file())
		result = tree.change_scene_to_file(target_scene_path)
	
	if result != OK:
		print("❌ Failed to change scene to: ", target_scene_path)
		return
	
	# Wait for scene to be ready
	await tree.process_frame
	await tree.process_frame
	
	# If animation name is provided, play it in the new scene
	if animation_name != "":
		var new_scene := tree.current_scene
		if new_scene:
			# Find AnimationPlayer in new scene
			var new_anim_player: AnimationPlayer = new_scene.get_node_or_null("AnimationPlayer")
			if new_anim_player == null:
				new_anim_player = new_scene.find_child("AnimationPlayer", true, false) as AnimationPlayer
			
			if new_anim_player and new_anim_player.has_animation(animation_name):
				print("🎬 Playing animation '", animation_name, "' in new scene")
				new_anim_player.play(animation_name)
			else:
				print("⚠️ AnimationPlayer not found or animation '", animation_name, "' not available in new scene")
	
	# Note: SceneFadeIn autoload handles fade-in automatically, no need to fade here

var _player_movement_disabled: bool = false  # Track if movement is already disabled

func _process(_delta: float) -> void:
	# Only disable movement once during cutscene (performance optimization)
	if cutscene_active and player_node != null:
		if not _player_movement_disabled:
			if "control_enabled" in player_node:
				player_node.control_enabled = false
			if "velocity" in player_node:
				player_node.velocity = Vector2.ZERO
			_player_movement_disabled = true
	elif not cutscene_active:
		# Reset flag when cutscene ends
		_player_movement_disabled = false

# ---- Environment visibility helpers ----
func hide_environment_and_characters(duration: float = 0.5) -> void:
	var root_scene := get_tree().current_scene
	if root_scene == null:
		return

	var elements_to_fade: Array[CanvasItem] = []
	
	for tilemap in root_scene.find_children("*", "TileMapLayer", true, false):
		if tilemap is TileMapLayer and (tilemap as TileMapLayer).visible:
			elements_to_fade.append(tilemap as CanvasItem)
	
	if player_node == null:
		player_node = _find_player()
	if player_node != null and player_node is CanvasItem and (player_node as CanvasItem).visible:
		elements_to_fade.append(player_node as CanvasItem)
	
	for child in root_scene.get_children():
		if child is Node2D and (String(child.name).to_lower().find("player") != -1):
			if child is CanvasItem and (child as CanvasItem).visible:
				elements_to_fade.append(child as CanvasItem)
	
	if elements_to_fade.is_empty():
		return

	print("🎬 Fading out ", elements_to_fade.size(), " environment elements")
	
	for element in elements_to_fade:
		element.modulate.a = 1.0
		element.visible = true
	
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	
	for element in elements_to_fade:
		tween.tween_property(element, "modulate:a", 0.0, duration)
	
	await tween.finished
	
	for element in elements_to_fade:
		element.visible = false
		element.modulate.a = 1.0
	
	print("🎬 Environment fade out complete")

func show_environment_and_characters(duration: float = 0.5) -> void:
	var root_scene := get_tree().current_scene
	if root_scene == null:
		return
	
	var elements_to_fade: Array[CanvasItem] = []
	
	for tilemap in root_scene.find_children("*", "TileMapLayer", true, false):
		if tilemap is TileMapLayer:
			elements_to_fade.append(tilemap as CanvasItem)
	
	if player_node == null:
		player_node = _find_player()
	if player_node != null and player_node is CanvasItem:
		elements_to_fade.append(player_node as CanvasItem)
	
	for child in root_scene.get_children():
		if child is Node2D and (String(child.name).to_lower().find("player") != -1):
			if child is CanvasItem:
				elements_to_fade.append(child as CanvasItem)
	
	if elements_to_fade.is_empty():
		return

	for element in elements_to_fade:
		element.visible = true
		element.modulate.a = 0.0
	
	print("🎬 Fading in ", elements_to_fade.size(), " environment elements")
	
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	for element in elements_to_fade:
		tween.tween_property(element, "modulate:a", 1.0, duration)
	
	await tween.finished
	print("🎬 Environment fade in complete")

# ---- Fade helpers ----
func _setup_fade() -> void:
	if fade_layer:
		return
	fade_layer = CanvasLayer.new()
	fade_layer.layer = 100
	add_child(fade_layer)
	fade_rect = ColorRect.new()
	fade_rect.color = Color.BLACK
	fade_rect.visible = true
	fade_rect.modulate.a = 1.0
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_rect.offset_left = 0
	fade_rect.offset_top = 0
	fade_rect.offset_right = 0
	fade_rect.offset_bottom = 0
	fade_layer.add_child(fade_rect)
	print("🎬 Fade layer created with alpha: ", fade_rect.modulate.a)

func fade_in(duration: float = 0.5) -> void:
	if not fade_rect:
		_setup_fade()
	fade_rect.visible = true
	fade_rect.modulate.a = 1.0
	print("🎬 Fade in starting from alpha: ", fade_rect.modulate.a)
	var t := create_tween()
	t.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(fade_rect, "modulate:a", 0.0, duration)
	await t.finished
	print("🎬 Fade in complete, alpha: ", fade_rect.modulate.a)
	fade_rect.visible = false

func fade_out(duration: float = 0.5) -> void:
	if not fade_rect:
		_setup_fade()
	fade_rect.visible = true
	fade_rect.modulate.a = 0.0
	var t := create_tween()
	t.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(fade_rect, "modulate:a", 1.0, duration)
	await t.finished

func dramatic_fade_out(duration: float = 2.0) -> void:
	"""Dramatic fade out with longer duration and smooth easing"""
	if not fade_rect:
		_setup_fade()
	fade_rect.visible = true
	fade_rect.modulate.a = 0.0
	var t := create_tween()
	# Use QUART transition for more dramatic effect
	t.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	t.tween_property(fade_rect, "modulate:a", 1.0, duration)
	await t.finished
	print("🎬 Dramatic fade out complete")

# ---- Dialogue helpers ----
func show_line(index: int, auto_advance: bool = false) -> void:
	if index < 0 or index >= dialogue_lines.size():
		push_warning("Dialogue index out of range: " + str(index))
		return
	var line: Dictionary = dialogue_lines[index]
	var speaker: String = String(line.get("speaker", ""))
	var text: String = String(line.get("text", ""))
	var dui: Node = get_node_or_null("/root/DialogueUI")
	if dui == null:
		print("⚠️ DialogueUI autoload not found.")
		return
	if dui.has_method("show_dialogue_line"):
		dui.show_dialogue_line(speaker, text, auto_advance)
		return
	print("⚠️ DialogueUI missing show_dialogue_line().")

func wait_for_next() -> void:
	_set_player_active(false)
	if player_node != null:
		if "control_enabled" in player_node:
			player_node.control_enabled = false
		if "velocity" in player_node:
			player_node.velocity = Vector2.ZERO
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

func show_dialogue_line_wait(speaker: String, text: String) -> void:
	var dui: Node = get_node_or_null("/root/DialogueUI")
	if dui == null:
		print("⚠️ DialogueUI autoload not found.")
		return
	if dui.has_method("set_cutscene_mode"):
		dui.set_cutscene_mode(true)
	if dui.has_method("show_dialogue_line"):
		dui.show_dialogue_line(speaker, text, false)
		wait_for_next()
	else:
		print("⚠️ DialogueUI missing show_dialogue_line().")

func _on_dialogue_next() -> void:
	if player_node != null:
		if "control_enabled" in player_node:
			player_node.control_enabled = false
		if "velocity" in player_node:
			player_node.velocity = Vector2.ZERO
	if resume_on_next and anim_player:
		resume_on_next = false
		print("🎬 Resuming animation after next_pressed")
		anim_player.play()

func show_lines_sequence(lines: Array[Dictionary]) -> void:
	for line in lines:
		var speaker: String = String(line.get("speaker", ""))
		var text: String = String(line.get("text", ""))
		await show_dialogue_line_wait(speaker, text)

func hide_ui() -> void:
	_hide_dialogue_ui()

func _hide_dialogue_ui() -> void:
	var dui: Node = get_node_or_null("/root/DialogueUI")
	if dui and dui.has_method("hide_ui"):
		dui.hide_ui()

func _load_dialogue_if_available(dialogue_key: String = "security_server_cutscene") -> void:
	var path := "res://data/dialogues/security_server_cutscene.json"
	if not ResourceLoader.exists(path):
		print("⚠️ Dialogue file not found: ", path)
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		print("⚠️ Cannot open dialogue file: ", path)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		print("⚠️ Invalid dialogue JSON format")
		return
	var section: Variant = (parsed as Dictionary).get(dialogue_key, {})
	if typeof(section) != TYPE_DICTIONARY:
		print("⚠️ Missing '", dialogue_key, "' section in dialogue file")
		return
	var arr: Variant = (section as Dictionary).get("dialogue_lines", [])
	if typeof(arr) == TYPE_ARRAY:
		for item in (arr as Array):
			if typeof(item) == TYPE_DICTIONARY:
				dialogue_lines.append(item as Dictionary)

# ---- Camera helpers ----
func shake_camera(intensity: float = 6.0, duration: float = 0.3) -> void:
	var cam: Camera2D = _get_camera_2d()
	if cam == null:
		print("⚠️ No Camera2D found to shake.")
		return
	var original_offset: Vector2 = cam.offset
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var steps := 10
	var step_duration: float = duration / float(steps)
	
	for i in range(steps):
		var fade_factor: float = 1.0 - (float(i) / float(steps))
		var current_intensity: float = intensity * fade_factor
		var rand_offset := Vector2(randf_range(-current_intensity, current_intensity), randf_range(-current_intensity, current_intensity))
		tween.tween_property(cam, "offset", original_offset + rand_offset, step_duration)
	
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(cam, "offset", original_offset, 0.12)
	await tween.finished

func _unlock_radio_log() -> void:
	"""Unlock radio log evidence and add it to inventory"""
	var eis: Node = get_node_or_null("/root/EvidenceInventorySettings")
	if eis == null:
		print("⚠️ EvidenceInventorySettings node not found at /root/EvidenceInventorySettings")
		return
	
	# Use add_evidence method with evidence ID string
	if eis.has_method("add_evidence"):
		eis.add_evidence("radio_log")
		print("🔎 Radio log evidence added via add_evidence(\"radio_log\")")
		return
	
	# Fallback methods if add_evidence doesn't exist
	if eis.has_method("unlock_evidence"):
		# radio_log is Evidence2 in the mapping (index 1)
		eis.unlock_evidence(2)
		print("🔎 Evidence unlocked via unlock_evidence(2)")
		return
	
	print("⚠️ Could not find a method to add radio log evidence on EvidenceInventorySettings")

func add_radio_log_evidence() -> void:
	"""Add radio log evidence and briefly show inventory (3 seconds) - call from AnimationPlayer"""
	_unlock_radio_log()
	await _show_inventory_brief(3.0)

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

func _get_camera_2d() -> Camera2D:
	var cam := get_viewport().get_camera_2d()
	if cam:
		return cam
	if has_node("Camera2D"):
		var c := get_node("Camera2D")
		if c is Camera2D:
			return c
	for child in get_tree().get_nodes_in_group("cameras"):
		if child is Camera2D:
			return child
	return null

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

# ---- Player helpers ----
func _find_player() -> Node:
	var root_scene := get_tree().current_scene
	if root_scene == null:
		return null
	
	var direct := root_scene.get_node_or_null("PlayerM")
	if direct != null:
		return direct
	
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
