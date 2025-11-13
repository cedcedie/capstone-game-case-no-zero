extends Node

const FOLLOW_DARWIN_SPAWN: Vector2 = Vector2(768.0, 288.0)

var anim_player: AnimationPlayer = null
var player_node: Node = null
var dialogue_lines: Array[Dictionary] = []
var celine_call_dialogue: Array[Dictionary] = []
var fade_layer: CanvasLayer
var fade_rect: ColorRect
var resume_on_next: bool = false
var cutscene_active: bool = false

func _ready() -> void:
	_hide_celine()
	
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
	
	# Disable player movement during cutscene
	_set_player_active(false)
	
	# Load dialogue
	_load_dialogue_if_available()
	# Load celine_call dialogue
	_load_celine_call_dialogue()
	
	# Connect DialogueUI next_pressed signal (use autoload directly)
	if DialogueUI and DialogueUI.has_signal("next_pressed") and not DialogueUI.next_pressed.is_connected(_on_dialogue_next):
		DialogueUI.next_pressed.connect(_on_dialogue_next)
	
	if CheckpointManager.has_checkpoint(CheckpointManager.CheckpointType.HEAD_POLICE_COMPLETED):
		_hide_station_lobby_nodes()
	
	if CheckpointManager.has_checkpoint(CheckpointManager.CheckpointType.SECURITY_SERVER_CUTSCENE_2_COMPLETED):
		if not CheckpointManager.has_checkpoint(CheckpointManager.CheckpointType.CELINE_CALL_COMPLETED):
			cutscene_active = true
			
			await get_tree().process_frame
			await get_tree().process_frame
			await get_tree().process_frame
			
			var scene_root := get_tree().current_scene
			var fade_in_node := scene_root.get_node_or_null("SceneFadeIn") if scene_root != null else null
			if fade_in_node != null:
				await get_tree().create_timer(0.3).timeout
			else:
				await get_tree().create_timer(0.2).timeout
			
			if anim_player != null:
				if anim_player.has_animation("celine _call_cutscene"):
					anim_player.play("celine _call_cutscene")
					await anim_player.animation_finished
					if not CheckpointManager.has_checkpoint(CheckpointManager.CheckpointType.CELINE_CALL_COMPLETED):
						_set_celine_call_completed()
				else:
					_set_player_active(true)
	
	if CheckpointManager.has_checkpoint(CheckpointManager.CheckpointType.HEAD_POLICE_COMPLETED):
		if CheckpointManager.has_checkpoint(CheckpointManager.CheckpointType.FOLLOW_DARWIN_COMPLETED):
			_set_post_cutscene_positions()
			_set_player_active(true)
			return
		
		_hide_task_display()
		cutscene_active = true
		
		await get_tree().process_frame
		await get_tree().process_frame
		await get_tree().process_frame
		
		var scene_root := get_tree().current_scene
		var fade_in_node := scene_root.get_node_or_null("SceneFadeIn") if scene_root != null else null
		if fade_in_node != null:
			await get_tree().create_timer(0.3).timeout
		else:
			await get_tree().create_timer(0.2).timeout
		
		if anim_player != null:
			if anim_player.has_animation("follow_darwin"):
				anim_player.play("follow_darwin")
				await anim_player.animation_finished
				if not CheckpointManager.has_checkpoint(CheckpointManager.CheckpointType.FOLLOW_DARWIN_COMPLETED):
					_set_follow_darwin_completed()
			else:
				_set_player_active(true)
		else:
			_set_player_active(true)
		return
	
	if not CheckpointManager.has_checkpoint(CheckpointManager.CheckpointType.LOWER_LEVEL_CUTSCENE_COMPLETED):
		_set_player_active(true)
		return
	
	if CheckpointManager.has_checkpoint(CheckpointManager.CheckpointType.RECOLLECTION_COMPLETED):
		_set_post_cutscene_positions()
		_set_player_active(true)
		return
	
	_show_celine()
	cutscene_active = true
	
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	
	var scene_fade_in := root_scene.get_node_or_null("SceneFadeIn")
	if scene_fade_in != null:
		await get_tree().create_timer(0.3).timeout
	else:
		await get_tree().create_timer(0.2).timeout
	
	if anim_player != null:
		if anim_player.has_animation("recollection_animation"):
			anim_player.play("recollection_animation")
			await anim_player.animation_finished
			if not CheckpointManager.has_checkpoint(CheckpointManager.CheckpointType.RECOLLECTION_COMPLETED):
				end_cutscene()
		else:
			_set_player_active(true)
	else:
		_set_player_active(true)

var _player_movement_disabled: bool = false

func _process(_delta: float) -> void:
	if cutscene_active and player_node != null:
		if not _player_movement_disabled:
			if "control_enabled" in player_node:
				player_node.control_enabled = false
			if "velocity" in player_node:
				player_node.velocity = Vector2.ZERO
			_player_movement_disabled = true
	elif not cutscene_active:
		_player_movement_disabled = false

func end_cutscene() -> void:
	await fade_out(0.5)
	_hide_dialogue_ui()
	cutscene_active = false
	CheckpointManager.set_checkpoint(CheckpointManager.CheckpointType.RECOLLECTION_COMPLETED)
	_set_post_cutscene_positions()
	_show_task_display("Tanungin ang pulis")
	await fade_in(0.5)
	_set_player_active(true)

func _hide_station_lobby_nodes() -> void:
	var root_scene := get_tree().current_scene
	if root_scene == null:
		return
	
	var station_lobby := root_scene.get_node_or_null("station_lobby")
	if station_lobby != null:
		if station_lobby is CanvasItem:
			(station_lobby as CanvasItem).visible = false
		_set_node_collision_enabled(station_lobby, false)
	
	var station_lobby2 := root_scene.get_node_or_null("StationLobby2")
	if station_lobby2 != null:
		if station_lobby2 is CanvasItem:
			(station_lobby2 as CanvasItem).visible = false
		_set_node_collision_enabled(station_lobby2, false)
	
	var station_lobby3 := root_scene.get_node_or_null("StationLobby3")
	if station_lobby3 != null:
		if station_lobby3 is CanvasItem:
			(station_lobby3 as CanvasItem).visible = false
		_set_node_collision_enabled(station_lobby3, false)

func _set_node_collision_enabled(node: Node, enabled: bool) -> void:
	if node == null:
		return
	var stack: Array = [node]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		for child in n.get_children():
			stack.push_back(child)
			if child is CollisionShape2D:
				(child as CollisionShape2D).disabled = not enabled

func _hide_celine() -> void:
	var celine := _find_celine()
	if celine != null:
		if celine is CanvasItem:
			(celine as CanvasItem).visible = false
			(celine as CanvasItem).modulate.a = 0.0
		_set_celine_collision_enabled(false)

func _find_celine() -> Node:
	var root_scene := get_tree().current_scene
	if root_scene == null:
		return null
	
	# Try direct child first
	var direct := root_scene.get_node_or_null("celine")
	if direct != null:
		return direct
	
	# Try recursive search
	var candidates := root_scene.find_children("*", "", true, false)
	for n in candidates:
		if String(n.name).to_lower() == "celine":
			return n
	
	return null

func _set_celine_collision_enabled(enabled: bool) -> void:
	var celine := _find_celine()
	if celine == null:
		return
	var stack: Array = [celine]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		for child in n.get_children():
			stack.push_back(child)
			if child is CollisionShape2D:
				(child as CollisionShape2D).disabled = not enabled

func _show_celine() -> void:
	var celine := _find_celine()
	if celine != null:
		if celine is CanvasItem:
			(celine as CanvasItem).visible = true
			(celine as CanvasItem).modulate.a = 1.0
		_set_celine_collision_enabled(true)

func _find_player() -> Node:
	var root_scene := get_tree().current_scene
	if root_scene == null:
		return null
	
	var n := root_scene.get_node_or_null("PlayerM")
	if n:
		return n
	
	n = root_scene.find_child("PlayerM", true, false)
	if n:
		return n
	
	for node in get_tree().get_nodes_in_group("player"):
		return node
	
	if has_node("/root/PlayerM"):
		return get_node("/root/PlayerM")
	
	var candidates := root_scene.find_children("*", "", true, false)
	for candidate in candidates:
		if String(candidate.name).to_lower().contains("playerm"):
			return candidate
	
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
		if "velocity" in player_node:
			player_node.velocity = Vector2.ZERO

func show_line(index: int, auto_advance: bool = false) -> void:
	if index < 0 or index >= dialogue_lines.size():
		push_warning("Dialogue index out of range: " + str(index))
		return
	var line: Dictionary = dialogue_lines[index]
	var speaker: String = String(line.get("speaker", ""))
	var text: String = String(line.get("text", ""))
	if DialogueUI == null:
		return
	if DialogueUI.has_method("show_dialogue_line"):
		DialogueUI.show_dialogue_line(speaker, text, auto_advance)
		
		if auto_advance:
			var typing_speed: float = 0.01
			var text_length: int = text.length()
			var typing_duration: float = float(text_length) * typing_speed
			
			await get_tree().create_timer(typing_duration).timeout
			await get_tree().create_timer(2.0).timeout
			
			if DialogueUI and DialogueUI.has_signal("next_pressed"):
				DialogueUI.emit_signal("next_pressed")
		return

func show_line_auto_advance(index: int, delay_after: float = 2.0) -> void:
	if index < 0 or index >= dialogue_lines.size():
		push_warning("Dialogue index out of range: " + str(index))
		return
	var line: Dictionary = dialogue_lines[index]
	var _speaker: String = String(line.get("speaker", ""))
	var text: String = String(line.get("text", ""))
	
	show_line(index, true)
	
	var typing_speed: float = 0.01
	var text_length: int = text.length()
	var typing_duration: float = float(text_length) * typing_speed
	
	await get_tree().create_timer(typing_duration).timeout
	await get_tree().create_timer(delay_after).timeout
	
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

func show_dialogue_line_wait(speaker: String, text: String) -> void:
	if DialogueUI == null:
		return
	if DialogueUI.has_method("set_cutscene_mode"):
		DialogueUI.set_cutscene_mode(true)
	if DialogueUI.has_method("show_dialogue_line"):
		DialogueUI.show_dialogue_line(speaker, text, false)
		wait_for_next()

func _set_post_cutscene_positions() -> void:
	var root_scene := get_tree().current_scene
	if root_scene == null:
		return
	
	var celine := _find_celine()
	if celine != null:
		if celine is CanvasItem:
			(celine as CanvasItem).visible = false
			(celine as CanvasItem).modulate.a = 0.0
		_set_celine_collision_enabled(false)
	
	var erwin := _find_character_by_name("erwin")
	if erwin == null:
		erwin = _find_character_by_name("Erwin")
	if erwin == null:
		erwin = _find_character_by_name("Erwin Boy Trip")
	if erwin != null and erwin is Node2D:
		if erwin is CanvasItem:
			(erwin as CanvasItem).visible = true
		(erwin as Node2D).global_position = Vector2(480.0, 360.0)
		_set_character_animation(erwin, "idle_back")
	
	var station_guard := _find_character_by_name("station_guard")
	if station_guard != null and station_guard is Node2D:
		if station_guard is CanvasItem:
			(station_guard as CanvasItem).visible = true
		(station_guard as Node2D).global_position = Vector2(672.0, 464.0)
		_set_character_animation(station_guard, "idle_right")
	
	var station_guard_2 := _find_character_by_name("station_guard_2")
	if station_guard_2 != null and station_guard_2 is Node2D:
		if station_guard_2 is CanvasItem:
			(station_guard_2 as CanvasItem).visible = true
		(station_guard_2 as Node2D).global_position = Vector2(672.0, 496.0)
		_set_character_animation(station_guard_2, "idle_right")
	
	if player_node == null:
		player_node = _find_player()
	if player_node != null and player_node is Node2D:
		if player_node is CanvasItem:
			(player_node as CanvasItem).visible = true
		(player_node as Node2D).global_position = Vector2(944.0, 360.0)

func _find_character_by_name(character_name: String) -> Node:
	var root_scene := get_tree().current_scene
	if root_scene == null:
		return null
	
	# Try direct child first
	var direct := root_scene.get_node_or_null(NodePath(character_name))
	if direct != null:
		return direct
	
	# Try recursive search
	var lowered := character_name.to_lower()
	var candidates := root_scene.find_children("*", "", true, false)
	for n in candidates:
		if String(n.name).to_lower() == lowered:
			return n
	
	return null

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

func _set_follow_darwin_completed() -> void:
	if CheckpointManager.has_checkpoint(CheckpointManager.CheckpointType.FOLLOW_DARWIN_COMPLETED):
		return
	
	_hide_dialogue_ui()
	CheckpointManager.set_checkpoint(CheckpointManager.CheckpointType.FOLLOW_DARWIN_COMPLETED)
	
	if player_node == null:
		player_node = _find_player()
	if player_node != null and player_node is Node2D:
		if player_node is CanvasItem:
			(player_node as CanvasItem).visible = true
		(player_node as Node2D).global_position = FOLLOW_DARWIN_SPAWN
	
	if DialogueUI and DialogueUI.has_method("set_cutscene_mode"):
		DialogueUI.set_cutscene_mode(false)
	
	cutscene_active = false
	_set_player_active(true)

func _set_celine_call_completed() -> void:
	if CheckpointManager.has_checkpoint(CheckpointManager.CheckpointType.CELINE_CALL_COMPLETED):
		return
	
	_hide_dialogue_ui()
	CheckpointManager.set_checkpoint(CheckpointManager.CheckpointType.CELINE_CALL_COMPLETED)
	_show_task_display("Pumunta sa baranggay")
	
	# Update task in TaskManager to trigger waypoint indicator change
	if TaskManager and TaskManager.has_method("update_task"):
		TaskManager.update_task("Pumunta sa baranggay")
		print("📍 TaskManager: Updated task to 'Pumunta sa baranggay' - waypoint should now point to barangay hall")
	
	if DialogueUI and DialogueUI.has_method("set_cutscene_mode"):
		DialogueUI.set_cutscene_mode(false)

	cutscene_active = false
	_player_movement_disabled = false
	
	if player_node == null:
		player_node = _find_player()
	
	_set_player_active(true)

func play_phone_ringtone(ring_count: int = 3) -> float:
	if VoiceBlipManager and VoiceBlipManager.has_method("play_ringtone"):
		var duration = await VoiceBlipManager.play_ringtone(ring_count, 0.2, 0.3)
		return duration
	else:
		return 0.0

func call_ringtone(ring_count: int = 3) -> void:
	call_deferred("_start_ringtone_async", ring_count)

func _start_ringtone_async(ring_count: int = 3) -> void:
	await play_phone_ringtone(ring_count)

func stop_phone_in_at_last_frame() -> void:
	if player_node == null:
		player_node = _find_player()
	if player_node == null:
		return
	
	var anim_sprite: AnimatedSprite2D = player_node.get_node_or_null("AnimatedSprite2D")
	if anim_sprite == null:
		return
	
	var sprite_frames = anim_sprite.sprite_frames
	if sprite_frames == null:
		return
	
	if not sprite_frames.has_animation("phone_in"):
		return
	
	var frame_count = sprite_frames.get_frame_count("phone_in")
	if frame_count == 0:
		return
	
	if anim_sprite.is_playing() and anim_sprite.animation == "phone_in":
		await anim_sprite.animation_finished
	
	anim_sprite.animation = "phone_in"
	anim_sprite.frame = frame_count - 1
	anim_sprite.stop()

func stop_phone_out_at_last_frame() -> void:
	if player_node == null:
		player_node = _find_player()
	if player_node == null:
		return
	
	var anim_sprite: AnimatedSprite2D = player_node.get_node_or_null("AnimatedSprite2D")
	if anim_sprite == null:
		return
	
	var sprite_frames = anim_sprite.sprite_frames
	if sprite_frames == null:
		return
	
	if not sprite_frames.has_animation("phone_out"):
		return
	
	var frame_count = sprite_frames.get_frame_count("phone_out")
	if frame_count == 0:
		return
	
	if anim_sprite.is_playing() and anim_sprite.animation == "phone_out":
		await anim_sprite.animation_finished
	
	anim_sprite.animation = "phone_out"
	anim_sprite.frame = frame_count - 1
	anim_sprite.stop()

func show_celine_call_line_0() -> void:
	if celine_call_dialogue.size() > 0:
		show_line_from_array(celine_call_dialogue, 0)
	else:
		_load_celine_call_dialogue()
		if celine_call_dialogue.size() > 0:
			show_line_from_array(celine_call_dialogue, 0)

func show_celine_call_line_1() -> void:
	if celine_call_dialogue.size() > 1:
		show_line_from_array(celine_call_dialogue, 1)

func show_celine_call_line_2() -> void:
	if celine_call_dialogue.size() > 2:
		show_line_from_array(celine_call_dialogue, 2)

func show_celine_call_line_3() -> void:
	if celine_call_dialogue.size() > 3:
		show_line_from_array(celine_call_dialogue, 3)

func show_celine_call_line_4() -> void:
	if celine_call_dialogue.size() > 4:
		show_line_from_array(celine_call_dialogue, 4)

func show_line_from_array(dialogue_array: Array[Dictionary], index: int, auto_advance: bool = true) -> void:
	if index < 0 or index >= dialogue_array.size():
		push_warning("Dialogue index out of range: " + str(index))
		return
	var line: Dictionary = dialogue_array[index]
	var speaker: String = String(line.get("speaker", ""))
	var text: String = String(line.get("text", ""))
	
	if DialogueUI == null:
		return
	if DialogueUI.has_method("set_cutscene_mode"):
		DialogueUI.set_cutscene_mode(true)
	if DialogueUI.has_method("show_dialogue_line"):
		DialogueUI.show_dialogue_line(speaker, text, auto_advance)
		
		if auto_advance:
			var typing_speed: float = 0.01
			var text_length: int = text.length()
			var typing_duration: float = float(text_length) * typing_speed
			
			await get_tree().create_timer(typing_duration).timeout
			await get_tree().create_timer(2.0).timeout
			
			if DialogueUI and DialogueUI.has_signal("next_pressed"):
				DialogueUI.emit_signal("next_pressed")

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
	var path := "res://data/dialogues/police_lobby_cutscene_dialogue.json"
	if not ResourceLoader.exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var section: Variant = (parsed as Dictionary).get("police_lobby_cutscene", {})
	if typeof(section) != TYPE_DICTIONARY:
		return
	var arr: Variant = (section as Dictionary).get("dialogue_lines", [])
	if typeof(arr) == TYPE_ARRAY:
		for item in (arr as Array):
			if typeof(item) == TYPE_DICTIONARY:
				dialogue_lines.append(item as Dictionary)

func _load_celine_call_dialogue() -> void:
	var path := "res://data/dialogues/celine_call_dialogue.json"
	if not ResourceLoader.exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var section: Variant = (parsed as Dictionary).get("celine_call", {})
	if typeof(section) != TYPE_DICTIONARY:
		return
	var arr: Variant = (section as Dictionary).get("dialogue_lines", [])
	if typeof(arr) == TYPE_ARRAY:
		celine_call_dialogue.clear()
		for item in (arr as Array):
			if typeof(item) == TYPE_DICTIONARY:
				celine_call_dialogue.append(item as Dictionary)

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
	# Try to get camera from PlayerM first
	if player_node == null:
		player_node = _find_player()
	
	if player_node != null:
		var player_cam := player_node.get_node_or_null("Camera2D")
		if player_cam is Camera2D:
			return player_cam
	
	# Fallback to viewport camera
	var viewport_cam := get_viewport().get_camera_2d()
	if viewport_cam:
		return viewport_cam
	if has_node("Camera2D"):
		var c := get_node("Camera2D")
		if c is Camera2D:
			return c
	for child in get_tree().get_nodes_in_group("cameras"):
		if child is Camera2D:
			return child
	return null

func camera_zoom_in_out(target_zoom: float = 1.5, duration: float = 0.5, hold_duration: float = 1.0) -> void:
	"""Zoom camera to target_zoom, hold for hold_duration, then smoothly zoom back to original zoom level"""
	var cam: Camera2D = _get_camera_2d()
	if cam == null:
		return
	
	var original_zoom: Vector2 = cam.zoom
	var target_zoom_vec := Vector2(target_zoom, target_zoom)
	var tween_in := create_tween()
	tween_in.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween_in.tween_property(cam, "zoom", target_zoom_vec, duration)
	await tween_in.finished
	
	await get_tree().create_timer(hold_duration).timeout
	
	var tween_out := create_tween()
	tween_out.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween_out.tween_property(cam, "zoom", original_zoom, duration)
	await tween_out.finished

func _setup_fade() -> void:
	if fade_layer:
		return
	fade_layer = CanvasLayer.new()
	fade_layer.layer = 100
	var root_scene := get_tree().current_scene
	if root_scene:
		root_scene.add_child(fade_layer)
	else:
		add_child(fade_layer)
	fade_rect = ColorRect.new()
	fade_rect.color = Color.BLACK
	fade_rect.visible = false
	fade_rect.modulate.a = 0.0
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


func _input(event: InputEvent) -> void:
	# Debug controls
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_F1:
				if CheckpointManager:
					CheckpointManager.debug_set_phase("SECURITY_SERVER_CUTSCENE_2_COMPLETED")
