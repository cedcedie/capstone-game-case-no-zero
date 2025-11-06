extends Node2D

var anim_player: AnimationPlayer = null
var player_node: Node = null
var dialogue_lines: Array[Dictionary] = []
var fade_layer: CanvasLayer
var fade_rect: ColorRect
var resume_on_next: bool = false
var cutscene_active: bool = false

func _ready() -> void:
	print("🎬 Head police room: _ready() started")
	# Prepare cutscene: disable player, load dialogue, and optionally auto-start animation
	_setup_fade()
	print("🎬 Fade setup complete")
	player_node = _find_player()
	print("🎬 Player found: ", player_node != null, " - Node: ", player_node)
	if player_node != null:
		print("🎬 Player has disable_movement method: ", player_node.has_method("disable_movement"))
	_set_player_active(false)
	_load_dialogue_if_available()
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
	
	# Check if cutscene already played
	if CheckpointManager.has_checkpoint(CheckpointManager.CheckpointType.HEAD_POLICE_COMPLETED):
		print("🎬 Head police cutscene already completed, skipping...")
		# Permanently hide station lobby nodes
		_hide_station_lobby_nodes()
		await fade_in()
		show_environment_and_characters()
		_set_player_active(true)
		return
	
	# Check if recollection is completed (required to play this cutscene)
	if not CheckpointManager.has_checkpoint(CheckpointManager.CheckpointType.RECOLLECTION_COMPLETED):
		print("🎬 Recollection not completed yet - skipping head police cutscene")
		await fade_in()
		show_environment_and_characters()
		_set_player_active(true)
		return
	
	# Hide task display when cutscene plays (task is now done)
	_hide_task_display()
	
	# Start cutscene for first time
	print("🎬 Starting fade in...")
	cutscene_active = true
	show_environment_and_characters()
	await fade_in()
	print("🎬 Fade in complete, checking animation...")
	if anim_player:
		print("🎬 AnimationPlayer found, available animations: ", anim_player.get_animation_list())
		# Play the head_police animation
		if anim_player.has_animation("head_police"):
			print("🎬 Playing 'head_police' animation")
			anim_player.play("head_police")
		elif anim_player.has_animation("head_police_cutscene"):
			print("🎬 Playing 'head_police_cutscene' animation")
			anim_player.play("head_police_cutscene")
		elif anim_player.get_animation_list().size() > 0:
			var first_anim = anim_player.get_animation_list()[0]
			print("🎬 Playing first available animation: ", first_anim)
			anim_player.play(first_anim)
		else:
			print("⚠️ No animations found in AnimationPlayer")
	else:
		print("⚠️ AnimationPlayer node not found!")

func end_cutscene() -> void:
	# Fade out to black for scene transition
	print("🎬 Cutscene ending - fading out...")
	await fade_out(0.5)
	
	# Hide dialogue UI during fade
	_hide_dialogue_ui()
	
	# Set checkpoint
	cutscene_active = false
	CheckpointManager.set_checkpoint(CheckpointManager.CheckpointType.HEAD_POLICE_COMPLETED)
	print("🎬 Head police room cutscene completed, checkpoint set.")
	
	# Permanently hide station lobby nodes
	_hide_station_lobby_nodes()
	
	# Set task display to follow PO1 Darwin
	_show_task_display("Sundin ang PO1 Darwin")
	
	# Set everything visible first
	var root_scene := get_tree().current_scene
	if root_scene:
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
	print("🎬 Head police room cutscene ended - returning to normal gameplay.")

func _process(_delta: float) -> void:
	# Continuously disable movement during cutscene
	if cutscene_active and player_node != null:
		if "control_enabled" in player_node and player_node.control_enabled:
			player_node.control_enabled = false
		if "velocity" in player_node:
			player_node.velocity = Vector2.ZERO

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

func _load_dialogue_if_available() -> void:
	var path := "res://data/dialogues/head_police_room_cutscene.json"
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
	var section: Variant = (parsed as Dictionary).get("head_police_room_cutscene", {})
	if typeof(section) != TYPE_DICTIONARY:
		print("⚠️ Missing 'head_police_room_cutscene' section in dialogue file")
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

# ---- Station lobby nodes ----
func _hide_station_lobby_nodes() -> void:
	# Hide station_lobby, StationLobby2, and StationLobby3 and disable their collision
	# These are direct children of the scene root
	var root_scene := get_tree().current_scene
	if root_scene == null:
		print("⚠️ Cannot hide station lobby nodes - no root scene")
		return
	
	# Hide station_lobby and disable collision
	var station_lobby := root_scene.get_node_or_null("station_lobby")
	if station_lobby != null:
		if station_lobby is CanvasItem:
			(station_lobby as CanvasItem).visible = false
		_set_node_collision_enabled(station_lobby, false)
		print("🎬 Hidden station_lobby and disabled collision")
	else:
		print("⚠️ station_lobby node not found in scene root")
	
	# Hide StationLobby2 and disable collision
	var station_lobby2 := root_scene.get_node_or_null("StationLobby2")
	if station_lobby2 != null:
		if station_lobby2 is CanvasItem:
			(station_lobby2 as CanvasItem).visible = false
		_set_node_collision_enabled(station_lobby2, false)
		print("🎬 Hidden StationLobby2 and disabled collision")
	else:
		print("⚠️ StationLobby2 node not found in scene root")
	
	# Hide StationLobby3 and disable collision
	var station_lobby3 := root_scene.get_node_or_null("StationLobby3")
	if station_lobby3 != null:
		if station_lobby3 is CanvasItem:
			(station_lobby3 as CanvasItem).visible = false
		_set_node_collision_enabled(station_lobby3, false)
		print("🎬 Hidden StationLobby3 and disabled collision")
	else:
		print("⚠️ StationLobby3 node not found in scene root")

func _set_node_collision_enabled(node: Node, enabled: bool) -> void:
	# Recursively disable/enable all CollisionShape2D nodes within the given node
	if node == null:
		return
	var stack: Array = [node]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		for child in n.get_children():
			stack.push_back(child)
			if child is CollisionShape2D:
				(child as CollisionShape2D).disabled = not enabled

# ---- Task display ----
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
		print("📝 Task display hidden")
	else:
		print("⚠️ TaskDisplay not found or missing hide_task() method")

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
		print("📝 Task display updated: ", task_text)
	else:
		print("⚠️ TaskDisplay not found or missing show_task() method")

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
