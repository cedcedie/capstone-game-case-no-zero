extends Node

var anim_player: AnimationPlayer = null
var player_node: Node = null
var dialogue_lines: Array[Dictionary] = []
var fade_layer: CanvasLayer
var fade_rect: ColorRect
var resume_on_next: bool = false
var cutscene_active: bool = false

func _ready() -> void:
	print("🎬 Police lobby cutscene: _ready() started")
	
	# IMPORTANT: Hide Celine immediately on scene load (before any checks)
	# Celine will only be visible during the actual cutscene if conditions are met
	_hide_celine()
	
	# Don't setup fade here - SceneFadeIn handles scene transition fade-in
	# We only need fade setup for end_cutscene()
	
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
	
	# Connect DialogueUI next_pressed signal
	var dui: Node = get_node_or_null("/root/DialogueUI")
	if dui and dui.has_signal("next_pressed") and not dui.next_pressed.is_connected(_on_dialogue_next):
		dui.next_pressed.connect(_on_dialogue_next)
	
	# Check if lower level cutscene is completed
	if not CheckpointManager.has_checkpoint(CheckpointManager.CheckpointType.LOWER_LEVEL_CUTSCENE_COMPLETED):
		print("🎬 Lower level cutscene not completed yet - skipping recollection")
		# Celine already hidden above
		_set_player_active(true)
		return
	
	# Check if recollection already played (only trigger once)
	if CheckpointManager.has_checkpoint(CheckpointManager.CheckpointType.RECOLLECTION_COMPLETED):
		print("🎬 Recollection already completed - skipping")
		# Hide the nodes if already completed (Celine already hidden above)
		_hide_station_lobby_nodes()
		_set_player_active(true)
		return
	
	# Hide station_lobby and StationLobby2
	_hide_station_lobby_nodes()
	
	# Show Celine now - she will be visible during cutscene (AnimationPlayer controls her)
	_show_celine()
	
	# Start cutscene
	cutscene_active = true
	
	# Wait for scene fade-in to complete (from scene transition) before playing animation
	# SceneFadeIn node handles the fade-in, we need to wait for it
	print("🎬 Waiting for scene fade-in to complete...")
	
	# Wait for multiple frames to ensure scene is loaded
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Check for SceneFadeIn node and wait for fade to complete
	var scene_fade_in := root_scene.get_node_or_null("SceneFadeIn")
	if scene_fade_in != null:
		# Wait for the fade-in duration (typically 0.25s based on SceneFadeIn)
		await get_tree().create_timer(0.3).timeout
		print("🎬 Scene fade-in should be complete")
	else:
		# Fallback: wait a bit for scene to settle
		await get_tree().create_timer(0.2).timeout
	
	# Play recollection animation
	if anim_player != null:
		if anim_player.has_animation("recollection_animation"):
			print("🎬 Playing recollection_animation")
			anim_player.play("recollection_animation")
		else:
			print("⚠️ No 'recollection_animation' found. Available animations: ", anim_player.get_animation_list())
	else:
		print("⚠️ AnimationPlayer not found!")

func _process(_delta: float) -> void:
	# Continuously disable movement during cutscene
	if cutscene_active and player_node != null:
		if "control_enabled" in player_node:
			player_node.control_enabled = false
		if "velocity" in player_node:
			player_node.velocity = Vector2.ZERO

func end_cutscene() -> void:
	# Fade out to black for scene transition
	print("🎬 Recollection cutscene ending - fading out...")
	await fade_out(0.5)
	
	# Hide dialogue UI
	_hide_dialogue_ui()
	
	# Set checkpoint
	cutscene_active = false
	CheckpointManager.set_checkpoint(CheckpointManager.CheckpointType.RECOLLECTION_COMPLETED)
	print("🎬 Recollection completed, checkpoint set.")
	
	# Hide Celine after cutscene completion
	_hide_celine()
	
	# Update task display
	_show_task_display("Tanungin ang pulis")
	
	# Fade in the screen overlay to return to normal gameplay
	await fade_in(0.5)
	
	# Re-enable player control
	_set_player_active(true)
	print("🎬 Police lobby recollection cutscene ended - returning to normal gameplay.")

func _hide_station_lobby_nodes() -> void:
	# Hide station_lobby and StationLobby2
	# These are direct children of the scene root
	var root_scene := get_tree().current_scene
	if root_scene == null:
		print("⚠️ Cannot hide station lobby nodes - no root scene")
		return
	
	# Hide station_lobby
	var station_lobby := root_scene.get_node_or_null("station_lobby")
	if station_lobby != null:
		if station_lobby is CanvasItem:
			(station_lobby as CanvasItem).visible = false
			print("🎬 Hidden station_lobby")
		else:
			print("⚠️ station_lobby is not a CanvasItem")
	else:
		print("⚠️ station_lobby node not found in scene root")
	
	# Hide StationLobby2
	var station_lobby2 := root_scene.get_node_or_null("StationLobby2")
	if station_lobby2 != null:
		if station_lobby2 is CanvasItem:
			(station_lobby2 as CanvasItem).visible = false
			print("🎬 Hidden StationLobby2")
		else:
			print("⚠️ StationLobby2 is not a CanvasItem")
	else:
		print("⚠️ StationLobby2 node not found in scene root")

func _hide_celine() -> void:
	# Ensure Celine is hidden and collision disabled
	var celine := _find_celine()
	if celine != null:
		if celine is CanvasItem:
			(celine as CanvasItem).visible = false
			(celine as CanvasItem).modulate.a = 0.0
		_set_celine_collision_enabled(false)
		print("🎬 Celine hidden and collision disabled")

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
	# Show Celine and enable collision for cutscene
	var celine := _find_celine()
	if celine != null:
		if celine is CanvasItem:
			(celine as CanvasItem).visible = true
			(celine as CanvasItem).modulate.a = 1.0
		_set_celine_collision_enabled(true)
		print("🎬 Celine shown and collision enabled for cutscene")

# ---- Player helpers ----
func _find_player() -> Node:
	var root_scene := get_tree().current_scene
	if root_scene == null:
		return null
	
	# Try direct child
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

func _hide_dialogue_ui() -> void:
	var dui: Node = get_node_or_null("/root/DialogueUI")
	if dui and dui.has_method("hide_ui"):
		dui.hide_ui()

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

# ---- Fade helpers ----
func _setup_fade() -> void:
	if fade_layer:
		return
	fade_layer = CanvasLayer.new()
	fade_layer.layer = 100
	# Add to scene root, not as child of this node
	var root_scene := get_tree().current_scene
	if root_scene:
		root_scene.add_child(fade_layer)
	else:
		add_child(fade_layer)
	fade_rect = ColorRect.new()
	fade_rect.color = Color.BLACK
	fade_rect.visible = false  # Start invisible - only show when needed
	fade_rect.modulate.a = 0.0  # Start transparent
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

# ---- Task display ----
func _show_task_display(task_text: String) -> void:
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
