extends Node

@onready var anim_player: AnimationPlayer = $AnimationPlayer if has_node("AnimationPlayer") else null
var player_node: Node = null
var dialogue_lines: Array[Dictionary] = []
var fade_layer: CanvasLayer
var fade_rect: ColorRect
var original_camera_offset: Vector2 = Vector2.ZERO
var resume_on_next: bool = false
var cutscene_active: bool = false

func _ready() -> void:
	# Prepare cutscene: disable player, load dialogue, and optionally auto-start animation
	_setup_fade()
	player_node = _find_player()
	if player_node != null:
	_set_player_active(false)
	_load_dialogue_if_available()
	# Connect DialogueUI next_pressed signal to resume animation
	var dui: Node = get_node_or_null("/root/DialogueUI")
	if dui and dui.has_signal("next_pressed") and not dui.next_pressed.is_connected(_on_dialogue_next):
		dui.next_pressed.connect(_on_dialogue_next)
	# Capture original camera offset for camera swipe functions
	var cam := _get_camera_2d()
	if cam != null:
		original_camera_offset = cam.offset
	
	# Check if cutscene already played
	if CheckpointManager.has_checkpoint(CheckpointManager.CheckpointType.LOWER_LEVEL_CUTSCENE_COMPLETED):
		# Set positions for post-cutscene state
		_set_post_cutscene_positions()
		await fade_in()
		show_environment_and_characters()
		_set_player_active(true)
		return

	# Start cutscene for first time
	# Hide task display when cutscene plays for the first time
	_hide_task_display()
	cutscene_active = true
	show_environment_and_characters()
	await fade_in()
	if anim_player:
		if anim_player.has_animation("jail_cutscene"):
			anim_player.play("jail_cutscene")
		else:
	else:

func end_cutscene() -> void:
	# Fade out to black for scene transition
	await fade_out(0.5)
	
	# Hide dialogue UI during fade
	_hide_dialogue_ui()
	
	# Set checkpoint
	cutscene_active = false
	CheckpointManager.set_checkpoint(CheckpointManager.CheckpointType.LOWER_LEVEL_CUTSCENE_COMPLETED)
	
	# Set characters to post-cutscene positions (including player - only after cutscene ends)
	_set_post_cutscene_positions()
	
	# Position player after cutscene completes (not on scene load)
	if player_node == null:
		player_node = _find_player()
	if player_node != null and player_node is Node2D:
		if player_node is CanvasItem:
			(player_node as CanvasItem).visible = true
		(player_node as Node2D).global_position = Vector2(872.0, 472.0)
	
	# Set everything visible first (with new positions)
	var root_scene := get_tree().current_scene
	if root_scene:
		# Make sure all environment elements are visible (they have new positions)
		for tilemap in root_scene.find_children("*", "TileMapLayer", true, false):
			if tilemap is TileMapLayer:
				(tilemap as TileMapLayer).visible = true
		if player_node:
			if player_node is CanvasItem:
				(player_node as CanvasItem).visible = true
	
	# Fade in the screen overlay to return to normal gameplay (remove black overlay from fade_out)
	await fade_in(0.5)
	
	# Re-enable player control
	_set_player_active(true)

var _player_movement_disabled: bool = false  # Track if movement is already disabled

func _process(_delta: float) -> void:
	# Only disable movement once during cutscene (performance optimization)
	# But don't reset animation - let AnimationPlayer control it
	if cutscene_active and player_node != null:
		if not _player_movement_disabled:
			# Only disable control_enabled, don't call disable_movement() which resets animation
			if "control_enabled" in player_node:
				player_node.control_enabled = false
			# Also stop velocity if player has it
			if "velocity" in player_node:
				player_node.velocity = Vector2.ZERO
			_player_movement_disabled = true
	elif not cutscene_active:
		# Reset flag when cutscene ends
		_player_movement_disabled = false

# ---- Environment visibility helpers ----
func hide_environment_and_characters(duration: float = 0.5) -> void:
	# Smoothly fade out environment and characters
	# Use longer duration for smoother fade
	var root_scene := get_tree().current_scene
	if root_scene == null:
		return

	# Collect all elements to fade out
	var elements_to_fade: Array[CanvasItem] = []
	
	# Find all TileMapLayers recursively
	for tilemap in root_scene.find_children("*", "TileMapLayer", true, false):
		if tilemap is TileMapLayer and (tilemap as TileMapLayer).visible:
			elements_to_fade.append(tilemap as CanvasItem)
	
	# Find PlayerM
	if player_node == null:
		player_node = _find_player()
	if player_node != null and player_node is CanvasItem and (player_node as CanvasItem).visible:
		elements_to_fade.append(player_node as CanvasItem)
	
	# Find other character nodes
	for child in root_scene.get_children():
		if child is Node2D and (String(child.name).to_lower().find("player") != -1):
			if child is CanvasItem and (child as CanvasItem).visible:
				elements_to_fade.append(child as CanvasItem)
	
	if elements_to_fade.is_empty():
		return

	
	# Ensure all elements start at full alpha and are visible
	for element in elements_to_fade:
		element.modulate.a = 1.0
		element.visible = true
	
	# Smoothly fade out with tween - use slower easing for smoother fade
	var tween := create_tween()
	tween.set_parallel(true)  # Animate all elements simultaneously
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)  # EASE_IN for smoother fade out
	
	for element in elements_to_fade:
		tween.tween_property(element, "modulate:a", 0.0, duration)
	
	await tween.finished
	
	# Set visibility to false after fade completes
	for element in elements_to_fade:
		element.visible = false
		element.modulate.a = 1.0  # Reset for next time
	

func show_environment_and_characters(duration: float = 0.5) -> void:
	# Smoothly fade in environment and characters
	# Note: Elements should already be in their NEW positions from AnimationPlayer
	var root_scene := get_tree().current_scene
	if root_scene == null:
		return
	
	# Collect all elements to fade in
	var elements_to_fade: Array[CanvasItem] = []
	
	# Find all TileMapLayers recursively (they should already be repositioned)
	for tilemap in root_scene.find_children("*", "TileMapLayer", true, false):
		if tilemap is TileMapLayer:
			elements_to_fade.append(tilemap as CanvasItem)
	
	# Find PlayerM (should already be in new position)
	if player_node == null:
		player_node = _find_player()
	if player_node != null and player_node is CanvasItem:
		elements_to_fade.append(player_node as CanvasItem)
	
	# Find other character nodes
	for child in root_scene.get_children():
		if child is Node2D and (String(child.name).to_lower().find("player") != -1):
			if child is CanvasItem:
				elements_to_fade.append(child as CanvasItem)
	
	if elements_to_fade.is_empty():
		return

	# First set visible and alpha to 0 (they're already in new positions from AnimationPlayer)
	for element in elements_to_fade:
		element.visible = true
		element.modulate.a = 0.0
	
	
	# Then fade in with smooth tween - use slower easing for smoother fade
	var tween := create_tween()
	tween.set_parallel(true)  # Animate all elements simultaneously
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)  # EASE_OUT for smoother fade in
	
	for element in elements_to_fade:
		tween.tween_property(element, "modulate:a", 1.0, duration)
	
	await tween.finished

# ---- Fade helpers ----
func _setup_fade() -> void:
	if fade_layer:
		return
	fade_layer = CanvasLayer.new()
	fade_layer.layer = 100  # High layer to ensure it's on top
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

func fade_in(duration: float = 0.5) -> void:
	if not fade_rect:
		_setup_fade()
	fade_rect.visible = true
	fade_rect.modulate.a = 1.0
	var t := create_tween()
	t.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(fade_rect, "modulate:a", 0.0, duration)
	await t.finished
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
		return
	if dui.has_method("show_dialogue_line"):
		dui.show_dialogue_line(speaker, text, auto_advance)
		return

func wait_for_next() -> void:
	# Pause animation and wait for next_pressed signal
	# Ensure player movement stays disabled during dialogue
	# Don't call disable_movement() - it resets animation. Just disable control.
	_set_player_active(false)
	# Force disable control without resetting animation
	if player_node != null:
		if "control_enabled" in player_node:
			player_node.control_enabled = false
		if "velocity" in player_node:
			player_node.velocity = Vector2.ZERO
		# Don't call disable_movement() - let AnimationPlayer control the animation
	resume_on_next = true
	if anim_player:
		anim_player.pause()

func show_line_wait(index: int) -> void:
	# Convenience: show line and immediately pause animation until Next
	if index < 0 or index >= dialogue_lines.size():
		push_warning("Dialogue index out of range: " + str(index))
		return
	show_line(index, false)
	wait_for_next()

func show_dialogue_line_wait(speaker: String, text: String) -> void:
	# Helper: show line with speaker/text and pause animation
	var dui: Node = get_node_or_null("/root/DialogueUI")
	if dui == null:
		return
	# Ensure cutscene mode to gate progression on next_pressed
	if dui.has_method("set_cutscene_mode"):
		dui.set_cutscene_mode(true)
	if dui.has_method("show_dialogue_line"):
		dui.show_dialogue_line(speaker, text, false)
		wait_for_next()
	else:

func _on_dialogue_next() -> void:
	# Called when DialogueUI next_pressed signal fires - resume animation
	# Keep player movement disabled even after dialogue line finishes
	# Don't call disable_movement() - it resets animation. Just disable control.
	if player_node != null:
		if "control_enabled" in player_node:
			player_node.control_enabled = false
		if "velocity" in player_node:
			player_node.velocity = Vector2.ZERO
	if resume_on_next and anim_player:
		resume_on_next = false
		anim_player.play()

func show_lines_sequence(lines: Array[Dictionary]) -> void:
	for line in lines:
		var speaker: String = String(line.get("speaker", ""))
		var text: String = String(line.get("text", ""))
		await show_dialogue_line_wait(speaker, text)

func hide_ui() -> void:
	_hide_dialogue_ui()

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
	else:

func _hide_dialogue_ui() -> void:
	var dui: Node = get_node_or_null("/root/DialogueUI")
	if dui and dui.has_method("hide_ui"):
		dui.hide_ui()

func _load_dialogue_if_available() -> void:
	var path := "res://data/dialogues/lower_level_station_cutscene.json"
	if not ResourceLoader.exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var section: Variant = (parsed as Dictionary).get("lower_level_station_cutscene", {})
	if typeof(section) != TYPE_DICTIONARY:
		return
	var arr: Variant = (section as Dictionary).get("dialogue_lines", [])
	if typeof(arr) == TYPE_ARRAY:
		# Ensure array of dictionaries
		for item in (arr as Array):
			if typeof(item) == TYPE_DICTIONARY:
				dialogue_lines.append(item as Dictionary)

# ---- Camera helpers ----
func shake_camera(intensity: float = 6.0, duration: float = 0.3) -> void:
	var cam: Camera2D = _get_camera_2d()
	if cam == null:
		return
	var original_offset: Vector2 = cam.offset
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)  # Smooth easing
	var steps := 10  # More steps for smoother shake
	var step_duration: float = duration / float(steps)
	
	# Create smoother shake with intensity fade-out
	for i in range(steps):
		# Reduce intensity over time for smoother fade-out
		var fade_factor: float = 1.0 - (float(i) / float(steps))
		var current_intensity: float = intensity * fade_factor
		var rand_offset := Vector2(randf_range(-current_intensity, current_intensity), randf_range(-current_intensity, current_intensity))
		
		# Sequential tweens for smooth shake
		tween.tween_property(cam, "offset", original_offset + rand_offset, step_duration)
	
	# Return to original with smooth ease
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(cam, "offset", original_offset, 0.12)
	await tween.finished

func _get_camera_2d() -> Camera2D:
	# Try current viewport camera, then a child node named Camera2D, then search
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

# ---- Post-cutscene positioning ----
func _set_post_cutscene_positions() -> void:
	# Set all characters to their post-cutscene positions
	var root_scene := get_tree().current_scene
	if root_scene == null:
		return
	
	
	# Find and hide Celine
	var celine := _find_character_by_name("celine")
	if celine != null:
		if celine is CanvasItem:
			(celine as CanvasItem).visible = false
			(celine as CanvasItem).modulate.a = 0.0
		_set_character_collision_enabled(celine, false)
	else:
	
	# Find and position station_guard_2
	var station_guard_2 := _find_character_by_name("station_guard_2")
	if station_guard_2 != null and station_guard_2 is Node2D:
		# Ensure visibility first
		if station_guard_2 is CanvasItem:
			(station_guard_2 as CanvasItem).visible = true
		(station_guard_2 as Node2D).global_position = Vector2(672.0, 496.0)
		_set_character_animation(station_guard_2, "idle_right")
	else:
	
	# Find and position station_guard
	var station_guard := _find_character_by_name("station_guard")
	if station_guard != null and station_guard is Node2D:
		# Ensure visibility first
		if station_guard is CanvasItem:
			(station_guard as CanvasItem).visible = true
		(station_guard as Node2D).global_position = Vector2(672.0, 464.0)
		_set_character_animation(station_guard, "idle_right")
	else:
	
	# Find and position erwin
	var erwin := _find_character_by_name("erwin")
	if erwin == null:
		erwin = _find_character_by_name("Erwin")
	if erwin == null:
		erwin = _find_character_by_name("Erwin Boy Trip")
	if erwin != null and erwin is Node2D:
		# Ensure visibility first
		if erwin is CanvasItem:
			(erwin as CanvasItem).visible = true
		(erwin as Node2D).global_position = Vector2(480.0, 360.0)
		_set_character_animation(erwin, "idle_back")
	else:
	
	# Position PlayerM (Miguel)
	if player_node == null:
		player_node = _find_player()
	if player_node != null and player_node is Node2D:
		if player_node is CanvasItem:
			(player_node as CanvasItem).visible = true
		(player_node as Node2D).global_position = Vector2(872.0, 472.0)
	else:
	

func _find_character_by_name(name: String) -> Node:
	var root_scene := get_tree().current_scene
	if root_scene == null:
		return null
	
	# Try direct child first
	var direct := root_scene.get_node_or_null(NodePath(name))
	if direct != null:
		return direct
	
	# Try recursive search
	var lowered := name.to_lower()
	var candidates := root_scene.find_children("*", "", true, false)
	for n in candidates:
		if String(n.name).to_lower() == lowered:
			return n
	
	return null

func _set_character_collision_enabled(character: Node, enabled: bool) -> void:
	if character == null:
		return
	var stack: Array = [character]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		for child in n.get_children():
			stack.push_back(child)
			if child is CollisionShape2D:
				(child as CollisionShape2D).disabled = not enabled

func _set_character_animation(character: Node, animation_name: String) -> void:
	if character == null:
		return
	# Try to find AnimatedSprite2D child
	var anim_sprite := character.get_node_or_null("AnimatedSprite2D")
	if anim_sprite == null:
		# Try recursive search
		for child in character.find_children("*", "AnimatedSprite2D", true, false):
			if child is AnimatedSprite2D:
				anim_sprite = child
				break
	if anim_sprite != null and anim_sprite is AnimatedSprite2D:
		(anim_sprite as AnimatedSprite2D).play(animation_name)

# ---- Camera swipe/pan helpers ----
func _find_first_by_name_substring(substr: String) -> Node2D:
	# Search recursively through the scene tree to find Erwin
	var lowered := substr.to_lower()
	var root_scene := get_tree().current_scene
	if root_scene == null:
		return null
	# Search all descendants
	var candidates := root_scene.find_children("*", "", true, false)
	for n in candidates:
		if n is Node2D:
			var name_lower := String(n.name).to_lower()
			if name_lower.find(lowered) != -1:
				return n as Node2D
	# Fallback: check direct children
	for n in get_children():
		if n is Node2D and String(n.name).to_lower().find(lowered) != -1:
			return n as Node2D
	return null

func _get_node2d_global_position(n: Node) -> Vector2:
	if n is Node2D:
		return (n as Node2D).global_position
	return Vector2.ZERO

func _get_player_global_position() -> Vector2:
	if player_node == null:
		player_node = _find_player()
	return _get_node2d_global_position(player_node)

func camera_swipe_through_target(target: Node, duration_in: float = 0.35, hold_s: float = 0.2, max_distance: float = 220.0) -> void:
	var cam := _get_camera_2d()
	if cam == null:
		return
	if target == null:
		return
	# Store original offset for later return (only if not already stored)
	if original_camera_offset == Vector2.ZERO:
		original_camera_offset = cam.offset
	
	var player_pos := _get_player_global_position()
	var target_pos := _get_node2d_global_position(target)
	
	var delta := target_pos - player_pos
	
	# Don't clamp - use actual distance to target for proper focus
	# But limit to reasonable max to avoid going too far
	if delta.length() > max_distance:
		delta = delta.normalized() * max_distance
	
	var target_offset := original_camera_offset + delta
	
	# Tween in (pan towards target) with smooth easing
	var t_in := create_tween()
	t_in.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)  # Smooth cubic curve
	t_in.tween_property(cam, "offset", target_offset, duration_in)
	await t_in.finished
	
	# Hold briefly on target (optional, can be 0.0 if you want to control timing manually)
	if hold_s > 0.0:
		await get_tree().create_timer(hold_s).timeout
	# Camera stays on target - no auto-return

func camera_swipe_back_to_player(duration: float = 0.35) -> void:
	# Return camera to original position (player)
	var cam := _get_camera_2d()
	if cam == null:
		return
	var t := create_tween()
	t.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)  # Smooth cubic curve
	t.tween_property(cam, "offset", original_camera_offset, duration)
	await t.finished

func camera_swipe_to_nodepath(path: NodePath, duration_in: float = 0.35, hold_s: float = 0.2) -> void:
	var n := get_node_or_null(path)
	camera_swipe_through_target(n, duration_in, hold_s)

func camera_swipe_to_first_named(name_substring: String, duration_in: float = 0.35, hold_s: float = 0.2) -> void:
	var n := _find_first_by_name_substring(name_substring)
	camera_swipe_through_target(n, duration_in, hold_s)

func camera_swipe_to_erwin_quick() -> void:
	# Swipe to Erwin's manual position at (480.0, 368.0)
	# Camera is attached to PlayerM, so we get it from there
	if player_node == null:
		player_node = _find_player()
	if player_node == null:
		return
	
	# Get camera from PlayerM
	var cam: Camera2D = null
	if player_node.has_method("get_camera"):
		cam = player_node.get_camera()
	else:
		cam = player_node.get_node_or_null("Camera2D")
	
	if cam == null:
		return
	
	# Store original offset if not already stored
	if original_camera_offset == Vector2.ZERO:
		original_camera_offset = cam.offset
	
	var erwin_pos := Vector2(480.0, 368.0)
	var player_pos: Vector2 = player_node.global_position
	
	
	# Calculate offset needed: camera.global_position = player.global_position + camera.offset
	# We want camera.global_position to center on Erwin
	# So: camera.offset = erwin_pos - player.global_position
	var target_offset: Vector2 = erwin_pos - player_pos
	
	# Clamp the offset to reasonable bounds (don't go too far from player)
	# Limit offset to avoid going off-map (map is 1280x720)
	var max_offset := Vector2(400.0, 300.0)  # Reasonable pan distance
	if abs(target_offset.x) > max_offset.x:
		target_offset.x = sign(target_offset.x) * max_offset.x
	if abs(target_offset.y) > max_offset.y:
		target_offset.y = sign(target_offset.y) * max_offset.y
	
	
	# Tween to Erwin position with smooth easing
	var t := create_tween()
	t.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)  # Smooth cubic curve
	t.tween_property(cam, "offset", target_offset, 0.4)  # Slightly longer for smoother feel
	await t.finished

# ---- Player helpers ----
func _find_player() -> Node:
	# Try multiple paths to find PlayerM
	var root_scene := get_tree().current_scene
	if root_scene == null:
		return null
	
	# Try direct child
	var n := root_scene.get_node_or_null("PlayerM")
	if n:
		return n
	
	# Try as sibling (if this script is a child of root)
	n = get_node_or_null("../PlayerM")
	if n:
		return n
	
	# Try finding by name recursively
	n = root_scene.find_child("PlayerM", true, false)
	if n:
		return n
	
	# Try group lookup
	for node in get_tree().get_nodes_in_group("player"):
		return node
	
	# Try any node with "player" in name (case insensitive)
	for child in root_scene.get_children():
		if String(child.name).to_lower().find("player") != -1:
			return child
	
	return null

func _set_player_active(active: bool) -> void:
	if player_node == null:
		player_node = _find_player()
	if player_node == null:
		return
	
	if not active:
		# During cutscene: Don't call disable_movement() - it resets animation
		# Just disable control and input/physics, let AnimationPlayer control animation
		if "control_enabled" in player_node:
			player_node.control_enabled = false
		if "velocity" in player_node:
			player_node.velocity = Vector2.ZERO
		if player_node.has_method("set_process_input"):
			player_node.set_process_input(false)
		if player_node.has_method("set_physics_process"):
			player_node.set_physics_process(false)
	else:
		# Re-enable movement normally
		if player_node.has_method("enable_movement"):
			player_node.enable_movement()
		else:
		if player_node.has_method("set_process_input"):
			player_node.set_process_input(true)
		if player_node.has_method("set_physics_process"):
			player_node.set_physics_process(true)
		if "control_enabled" in player_node:
			player_node.control_enabled = true
