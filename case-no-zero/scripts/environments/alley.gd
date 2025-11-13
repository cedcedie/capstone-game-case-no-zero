extends Node2D

var anim_player: AnimationPlayer = null
var player_node: Node = null
var dialogue_lines: Array[Dictionary] = []
var fade_layer: CanvasLayer
var fade_rect: ColorRect
var resume_on_next: bool = false
var cutscene_active: bool = false
var original_camera_offset: Vector2 = Vector2.ZERO
var original_camera_zoom: Vector2 = Vector2.ONE
var audio_player: AudioStreamPlayer = null

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
	
	# Capture original camera offset and zoom for camera functions
	var cam := _get_camera_2d()
	if cam != null:
		original_camera_offset = cam.offset
		original_camera_zoom = cam.zoom
	
	# Start cutscene - play alley_cutscene animation
	cutscene_active = true
	show_environment_and_characters()
	await fade_in()
	if anim_player:
		# Play the alley_cutscene animation specifically
		if anim_player.has_animation("alley_cutscene"):
			anim_player.play("alley_cutscene")
		else:
			# Fallback to first available animation
			if anim_player.get_animation_list().size() > 0:
				var first_anim = anim_player.get_animation_list()[0]
				anim_player.play(first_anim)
	else:

func end_cutscene() -> void:
	# Hide dialogue UI
	_hide_dialogue_ui()
	
	# Set checkpoint after cutscene completes
	cutscene_active = false
	CheckpointManager.set_checkpoint(CheckpointManager.CheckpointType.ALLEY_CUTSCENE_COMPLETED)
	
	# Fade out to black after static
	await fade_out(0.5)
	
	# Transition to security server scene and play security_server_cutscene_2 animation
	await transition_to_scene("res://scenes/environments/police_station/security_server.tscn", "security_server_cutscene_2", true)

# Transition to another scene and optionally play an animation
func transition_to_scene(target_scene_path: String, animation_name: String = "", skip_fade: bool = false) -> void:
	"""Transition to another scene and optionally play an animation there"""
	
	# Dramatic fade out current scene before transition (unless already faded)
	if not skip_fade:
		await fade_out(0.5)
	
	# Hide dialogue UI
	_hide_dialogue_ui()
	
	# Change scene
	var tree := get_tree()
	if tree == null:
		return
	
	var result: Error
	if ScenePreloader and ScenePreloader.is_scene_preloaded(target_scene_path):
		var preloaded_scene = ScenePreloader.get_preloaded_scene(target_scene_path)
		result = tree.change_scene_to_packed(preloaded_scene)
	else:
		result = tree.change_scene_to_file(target_scene_path)
	
	if result != OK:
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
				new_anim_player.play(animation_name)
			else:
	
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
	
	
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	for element in elements_to_fade:
		tween.tween_property(element, "modulate:a", 1.0, duration)
	
	await tween.finished

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

func dramatic_footage_static(static_duration: float = 3.0) -> void:
	"""Corrupted SD card video effect - digital artifacts, compression errors, frame tearing"""
	if not fade_rect:
		_setup_fade()
	
	
	# Smooth updates for video corruption effect
	var static_frames := int(static_duration * 60.0)  # 60 fps
	var frame_duration := static_duration / float(static_frames)
	
	fade_rect.visible = true
	
	# Get camera for shake effect
	var cam := _get_camera_2d()
	var original_cam_offset := Vector2.ZERO
	var original_cam_zoom := Vector2.ONE
	if cam != null:
		original_cam_offset = cam.offset
		original_cam_zoom = cam.zoom
	
	# Corrupted video error patterns - digital artifacts
	var corruption_types := ["compression", "tearing", "blocking", "freeze", "channel_loss"]
	var current_corruption_type := ""
	var corruption_timer := 0.0
	
	# Track intensity progression
	for i in range(static_frames):
		var progress: float = float(i) / float(static_frames)
		
		# Base intensity ramps from 0.0 to 1.0 (0% to 100% opacity - fully covers screen)
		var base_intensity: float = lerp(0.0, 1.0, ease_in_out_cubic(progress))
		
		# Change corruption type periodically (like corrupted video)
		corruption_timer += frame_duration
		if corruption_timer >= 0.12:  # Change corruption every 0.12 seconds
			current_corruption_type = corruption_types[randi() % corruption_types.size()]
			corruption_timer = 0.0
		
		# Apply corrupted video effects - no red tint, just digital corruption
		match current_corruption_type:
			"compression":
				# Digital compression artifacts - blocky, pixelated
				var compression_intensity: float = base_intensity + randf_range(-0.05, 0.08)
				compression_intensity = clamp(compression_intensity, 0.0, 1.0)
				var gray: float = randf_range(0.4, 0.8)  # Digital gray
				fade_rect.color = Color(gray, gray, gray, compression_intensity)
				fade_rect.modulate.a = compression_intensity
				
			"tearing":
				# Horizontal screen tearing - digital video corruption
				var tear_intensity: float = base_intensity + randf_range(-0.05, 0.05)
				tear_intensity = clamp(tear_intensity, 0.0, 1.0)
				var gray: float = randf_range(0.3, 0.7)  # Darker gray for tears
				fade_rect.color = Color(gray, gray, gray, tear_intensity)
				fade_rect.modulate.a = tear_intensity
				
			"blocking":
				# Macroblocking - large pixel blocks (MPEG corruption)
				var block_intensity: float = base_intensity + randf_range(-0.05, 0.05)
				block_intensity = clamp(block_intensity, 0.0, 1.0)
				var gray: float = randf_range(0.2, 0.6)  # Blocky dark gray
				fade_rect.color = Color(gray, gray, gray, block_intensity)
				fade_rect.modulate.a = block_intensity
				
			"freeze":
				# Frame freeze - corrupted video stuck frame
				var freeze_intensity: float = base_intensity + randf_range(-0.05, 0.05)
				freeze_intensity = clamp(freeze_intensity, 0.0, 1.0)
				var gray: float = randf_range(0.5, 0.7)  # Stable gray for freeze
				fade_rect.color = Color(gray, gray, gray, freeze_intensity)
				fade_rect.modulate.a = freeze_intensity
				
			"channel_loss":
				# Color channel corruption - RGB channel separation
				var channel_intensity: float = base_intensity
				# Random channel corruption - one channel might be weaker
				var r: float = randf_range(0.4, 0.9)
				var g: float = randf_range(0.3, 0.8)
				var b: float = randf_range(0.5, 0.9)
				fade_rect.color = Color(r, g, b, channel_intensity)
				fade_rect.modulate.a = channel_intensity
			
			_:
				# Default digital corruption
				var gray: float = randf_range(0.4, 0.8)
				fade_rect.color = Color(gray, gray, gray, base_intensity)
				fade_rect.modulate.a = base_intensity
		
		# Camera shake - remains for effect
		if cam != null:
			var shake_frequency: float = 12.0 + randf_range(-3.0, 3.0)  # Faster shake updates
			var shake_intensity: float = base_intensity * 2.0  # Moderate intensity
			
			if i % int(shake_frequency) == 0:
				var shake_offset: Vector2 = Vector2(
					randf_range(-shake_intensity, shake_intensity),
					randf_range(-shake_intensity, shake_intensity)
				)
				cam.offset = original_cam_offset + shake_offset
		
		await get_tree().create_timer(frame_duration).timeout
	
	# Reset camera
	if cam != null:
		cam.offset = original_cam_offset
		cam.zoom = original_cam_zoom
	
	# Reset to black
	fade_rect.color = Color.BLACK
	fade_rect.modulate.a = 1.0

func ease_in_out_cubic(t: float) -> float:
	"""Smooth ease in/out cubic curve for intensity progression"""
	return t * t * (3.0 - 2.0 * t) if t < 1.0 else 1.0

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
		
		# If auto_advance is true, wait for typing + 2 second delay, then auto-advance
		if auto_advance:
			var typing_speed: float = 0.01  # From DialogueUI
			var text_length: int = text.length()
			var typing_duration: float = float(text_length) * typing_speed
			
			# Wait for typing to complete
			await get_tree().create_timer(typing_duration).timeout
			
			# Wait additional 2 second delay after typing finishes
			await get_tree().create_timer(2.0).timeout
			
			# Auto-advance by emitting next_pressed signal
			if dui.has_signal("next_pressed"):
				dui.emit_signal("next_pressed")
		return

func show_line_auto_advance(index: int, delay_after: float = 2.0) -> void:
	"""Show a line with auto-advance: wait for typing to finish + delay, then auto-advance"""
	if index < 0 or index >= dialogue_lines.size():
		push_warning("Dialogue index out of range: " + str(index))
		return
	var line: Dictionary = dialogue_lines[index]
	var speaker: String = String(line.get("speaker", ""))
	var text: String = String(line.get("text", ""))
	
	# Show the line (typing will start)
	show_line(index, true)  # true = auto_advance mode (hides button)
	
	# Calculate typing duration: text_length * typing_speed (0.01 seconds per character)
	var typing_speed: float = 0.01  # From DialogueUI
	var text_length: int = text.length()
	var typing_duration: float = float(text_length) * typing_speed
	
	# Wait for typing to complete
	await get_tree().create_timer(typing_duration).timeout
	
	# Wait additional delay after typing finishes
	await get_tree().create_timer(delay_after).timeout
	
	# Total time calculation for reference
	var total_time: float = typing_duration + delay_after
	
	# Auto-advance by emitting next_pressed signal
	var dui: Node = get_node_or_null("/root/DialogueUI")
	if dui and dui.has_signal("next_pressed"):
		dui.emit_signal("next_pressed")

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

func show_line_wait(index: int) -> void:
	if index < 0 or index >= dialogue_lines.size():
		push_warning("Dialogue index out of range: " + str(index))
		return
	show_line(index, false)
	wait_for_next()

func show_dialogue_line_wait(speaker: String, text: String) -> void:
	var dui: Node = get_node_or_null("/root/DialogueUI")
	if dui == null:
		return
	if dui.has_method("set_cutscene_mode"):
		dui.set_cutscene_mode(true)
	if dui.has_method("show_dialogue_line"):
		dui.show_dialogue_line(speaker, text, false)
		wait_for_next()
	else:

func _on_dialogue_next() -> void:
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

func _hide_dialogue_ui() -> void:
	var dui: Node = get_node_or_null("/root/DialogueUI")
	if dui and dui.has_method("hide_ui"):
		dui.hide_ui()

func _load_dialogue_if_available() -> void:
	var path := "res://data/dialogues/alley_cutscene.json"
	if not ResourceLoader.exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var section: Variant = (parsed as Dictionary).get("alley_cutscene", {})
	if typeof(section) != TYPE_DICTIONARY:
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
	
	# Try to get camera from leo_mendoza (not PlayerM)
	var root_scene := get_tree().current_scene
	if root_scene != null:
		var leo_mendoza := root_scene.get_node_or_null("leo_mendoza")
		if leo_mendoza == null:
			leo_mendoza = root_scene.find_child("leo_mendoza", true, false)
		if leo_mendoza != null:
			if leo_mendoza.has_method("get_camera"):
				cam = leo_mendoza.get_camera()
			else:
				cam = leo_mendoza.get_node_or_null("Camera2D")
			if cam is Camera2D:
				return cam
	
	return null

# ---- Character finding helpers ----
func _find_character_by_name(name_substring: String) -> Node:
	"""Find a character node by name substring (case-insensitive)"""
	var root_scene := get_tree().current_scene
	if root_scene == null:
		return null
	
	var search_name := name_substring.to_lower()
	
	# Try direct child first
	for child in root_scene.get_children():
		if String(child.name).to_lower().contains(search_name):
			return child
	
	# Try recursive search
	var found := root_scene.find_child("*" + search_name + "*", true, false)
	if found:
		return found
	
	# Try exact match
	var exact := root_scene.get_node_or_null(name_substring)
	if exact:
		return exact
	
	# Try case-insensitive exact match
	var candidates := root_scene.find_children("*", "", true, false)
	for candidate in candidates:
		if String(candidate.name).to_lower() == search_name:
			return candidate
	
	return null

func _get_node2d_global_position(node: Node) -> Vector2:
	"""Get the global position of a Node2D, handling CharacterBody2D and regular Node2D"""
	if node is CharacterBody2D:
		return (node as CharacterBody2D).global_position
	elif node is Node2D:
		return (node as Node2D).global_position
	else:
		return Vector2.ZERO

func _get_player_global_position() -> Vector2:
	"""Get player's global position"""
	if player_node == null:
		player_node = _find_player()
	if player_node == null:
		return Vector2.ZERO
	return _get_node2d_global_position(player_node)

# ---- Camera position functions ----
func camera_move_to_position(target_position: Vector2, target_zoom: float = 1.5, move_duration: float = 0.5, hold_duration: float = 0.0) -> void:
	"""Move camera to center on specific world position with instant zoom
	
	Args:
		target_position: World position to center camera on
		target_zoom: Zoom level (applied instantly, default: 1.5)
		move_duration: Time it takes to move camera to position (default: 0.5 seconds)
		hold_duration: Time to stay at position before returning (0 = stay forever, default: 0.0)
	"""
	var cam: Camera2D = _get_camera_2d()
	if cam == null:
		return
	
	# Get the camera's parent (likely the character node)
	var cam_parent: Node2D = cam.get_parent() as Node2D
	if cam_parent == null:
		return
	
	# Store original position and zoom if not already stored
	if original_camera_offset == Vector2.ZERO:
		original_camera_offset = cam.offset
	if original_camera_zoom == Vector2.ZERO or original_camera_zoom == Vector2.ONE:
		original_camera_zoom = cam.zoom
	
	# Calculate offset needed to center on target position
	# Camera's global position = cam_parent.global_position + cam.offset
	var current_global_pos: Vector2 = cam_parent.global_position + cam.offset
	var offset_needed: Vector2 = target_position - cam_parent.global_position
	
	
	# Apply zoom instantly
	var target_zoom_vec := Vector2(target_zoom, target_zoom)
	cam.zoom = target_zoom_vec
	
	# Tween camera offset to move to target position
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(cam, "offset", offset_needed, move_duration)
	await tween.finished
	
	# If hold_duration > 0, wait then return to original position
	if hold_duration > 0.0:
		await get_tree().create_timer(hold_duration).timeout
		var return_tween := create_tween()
		return_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		return_tween.tween_property(cam, "offset", original_camera_offset, move_duration)
		await return_tween.finished
		# Return zoom to original
		cam.zoom = original_camera_zoom

func camera_zoom_to_body2d(target: CharacterBody2D, target_zoom: float = 1.5, duration_in: float = 0.5, hold_duration: float = 1.0, duration_out: float = 0.5) -> void:
	"""Zoom camera to a specific CharacterBody2D node"""
	if target == null:
		return
	
	var cam: Camera2D = _get_camera_2d()
	if cam == null:
		return
	
	# Store original values if not already stored
	if original_camera_offset == Vector2.ZERO:
		original_camera_offset = cam.offset
	if original_camera_zoom == Vector2.ZERO or original_camera_zoom == Vector2.ONE:
		original_camera_zoom = cam.zoom
	
	var target_pos := target.global_position
	var player_pos := _get_player_global_position()
	
	
	# Calculate target offset to center on character
	var delta := target_pos - player_pos
	var max_offset := Vector2(400.0, 300.0)  # Reasonable pan distance
	if abs(delta.x) > max_offset.x:
		delta.x = sign(delta.x) * max_offset.x
	if abs(delta.y) > max_offset.y:
		delta.y = sign(delta.y) * max_offset.y
	
	var target_offset := original_camera_offset + delta
	var target_zoom_vec := Vector2(target_zoom, target_zoom)
	
	# Zoom in and pan to character simultaneously
	var tween_in := create_tween()
	tween_in.set_parallel(true)
	tween_in.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween_in.tween_property(cam, "offset", target_offset, duration_in)
	tween_in.tween_property(cam, "zoom", target_zoom_vec, duration_in)
	await tween_in.finished
	
	# Hold at zoomed position
	if hold_duration > 0.0:
		await get_tree().create_timer(hold_duration).timeout
	
	# Zoom back and return to original position
	var tween_out := create_tween()
	tween_out.set_parallel(true)
	tween_out.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween_out.tween_property(cam, "offset", original_camera_offset, duration_out)
	tween_out.tween_property(cam, "zoom", original_camera_zoom, duration_out)
	await tween_out.finished

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

# ---- Audio helpers ----
func stop_audio_fade(audio_node_path: NodePath, fade_duration: float = 0.5) -> void:
	"""Stop AudioStreamPlayer with fade out - call from AnimationPlayer with NodePath to the AudioStreamPlayer"""
	var root_scene := get_tree().current_scene
	if root_scene == null:
		return
	
	var audio_node: Node = root_scene.get_node_or_null(audio_node_path)
	if audio_node == null:
		return
	
	if not audio_node is AudioStreamPlayer:
		return
	
	var audio_player: AudioStreamPlayer = audio_node as AudioStreamPlayer
	if not audio_player.playing:
		return
	
	var original_volume: float = audio_player.volume_db
	var fade_tween := create_tween()
	fade_tween.set_ease(Tween.EASE_IN_OUT)
	fade_tween.set_trans(Tween.TRANS_CUBIC)
	fade_tween.tween_property(audio_player, "volume_db", -80.0, fade_duration)
	await fade_tween.finished
	audio_player.stop()
	audio_player.volume_db = original_volume

func stop_main_bg(fade_duration: float = 0.5) -> void:
	"""Stop MainBG AudioStreamPlayer with fade out (can be called from AnimationPlayer)"""
	var root_scene := get_tree().current_scene
	if root_scene == null:
		return
	
	var main_bg: AudioStreamPlayer = root_scene.get_node_or_null("MainBG") as AudioStreamPlayer
	if main_bg == null:
		main_bg = root_scene.find_child("MainBG", true, false) as AudioStreamPlayer
	
	if main_bg == null:
		return
	
	if not main_bg.playing:
		return
	
	var original_volume: float = main_bg.volume_db
	var fade_tween := create_tween()
	fade_tween.set_ease(Tween.EASE_IN_OUT)
	fade_tween.set_trans(Tween.TRANS_CUBIC)
	fade_tween.tween_property(main_bg, "volume_db", -80.0, fade_duration)
	await fade_tween.finished
	main_bg.stop()
	main_bg.volume_db = original_volume

func stop_suspense_bg(fade_duration: float = 0.5) -> void:
	"""Stop SuspenseBG AudioStreamPlayer with fade out (can be called from AnimationPlayer)"""
	var root_scene := get_tree().current_scene
	if root_scene == null:
		return
	
	var suspense_bg: AudioStreamPlayer = root_scene.get_node_or_null("SuspenseBG") as AudioStreamPlayer
	if suspense_bg == null:
		suspense_bg = root_scene.find_child("SuspenseBG", true, false) as AudioStreamPlayer
	
	if suspense_bg == null:
		return
	
	if not suspense_bg.playing:
		return
	
	var original_volume: float = suspense_bg.volume_db
	var fade_tween := create_tween()
	fade_tween.set_ease(Tween.EASE_IN_OUT)
	fade_tween.set_trans(Tween.TRANS_CUBIC)
	fade_tween.tween_property(suspense_bg, "volume_db", -80.0, fade_duration)
	await fade_tween.finished
	suspense_bg.stop()
	suspense_bg.volume_db = original_volume

func start_main_bg() -> void:
	"""Start MainBG AudioStreamPlayer (no fade in) - can be called from AnimationPlayer"""
	var root_scene := get_tree().current_scene
	if root_scene == null:
		return
	
	# Try multiple ways to find the node
	var main_bg: AudioStreamPlayer = root_scene.get_node_or_null("MainBG") as AudioStreamPlayer
	if main_bg == null:
		main_bg = get_node_or_null("../MainBG") as AudioStreamPlayer
	if main_bg == null:
		main_bg = root_scene.find_child("MainBG", true, false) as AudioStreamPlayer
	
	if main_bg == null:
		var children_names: Array[String] = []
		for child in root_scene.get_children():
			children_names.append(child.name)
		return
	
	if main_bg.playing:
		return
	
	main_bg.play()

func start_suspense_bg() -> void:
	"""Start SuspenseBG AudioStreamPlayer (no fade in) - can be called from AnimationPlayer"""
	var root_scene := get_tree().current_scene
	if root_scene == null:
		return
	
	# Try multiple ways to find the node
	var suspense_bg: AudioStreamPlayer = root_scene.get_node_or_null("SuspenseBG") as AudioStreamPlayer
	if suspense_bg == null:
		suspense_bg = get_node_or_null("../SuspenseBG") as AudioStreamPlayer
	if suspense_bg == null:
		suspense_bg = root_scene.find_child("SuspenseBG", true, false) as AudioStreamPlayer
	
	if suspense_bg == null:
		var children_names: Array[String] = []
		for child in root_scene.get_children():
			children_names.append(child.name)
		return
	
	if suspense_bg.playing:
		return
	
	suspense_bg.play()
