extends Node

@onready var anim_player: AnimationPlayer = $AnimationPlayer if has_node("AnimationPlayer") else null
var player_node: Node = null
var dialogue_lines: Array[Dictionary] = []
var fade_layer: CanvasLayer
var fade_rect: ColorRect

func _ready() -> void:
	# Prepare cutscene: disable player, load dialogue, and optionally auto-start animation
	_setup_fade()
	player_node = _find_player()
	_set_player_active(false)
	_load_dialogue_if_available()
	if anim_player and anim_player.has_animation("cutscene"):
		await fade_in()
		anim_player.play("cutscene")
	else:
		print("ℹ️ No cutscene animation found in lower_level_station. Call end_cutscene() to resume control.")

func end_cutscene() -> void:
	# Re-enable player control and hide dialogue UI
	CheckpointManager.set_checkpoint(CheckpointManager.CheckpointType.LOWER_LEVEL_CUTSCENE_COMPLETED)
	print("🎬 Lower level station cutscene completed, checkpoint set.")
	_set_player_active(true)
	_hide_dialogue_ui()
	print("🎬 Lower level station cutscene ended.")

# ---- Environment visibility helpers ----
func hide_environment_and_characters() -> void:
	for child in get_children():
		if child is TileMapLayer:
			child.visible = false
		elif child is Node2D and (String(child.name).to_lower().find("player") != -1):
			child.visible = false

func show_environment_and_characters() -> void:
	for child in get_children():
		if child is TileMapLayer:
			child.visible = true
		elif child is Node2D and (String(child.name).to_lower().find("player") != -1):
			child.visible = true

# ---- Fade helpers ----
func _setup_fade() -> void:
	if fade_layer:
		return
	fade_layer = CanvasLayer.new()
	add_child(fade_layer)
	fade_rect = ColorRect.new()
	fade_rect.color = Color.BLACK
	fade_rect.visible = true
	fade_rect.modulate.a = 1.0
	fade_rect.anchor_left = 0
	fade_rect.anchor_top = 0
	fade_rect.anchor_right = 1
	fade_rect.anchor_bottom = 1
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
func show_dialogue_line(speaker: String, text: String, auto_advance: bool = false) -> void:
	var dui: Node = get_node_or_null("/root/DialogueUI")
	if dui == null:
		print("⚠️ DialogueUI autoload not found.")
		return
	if dui.has_method("show_dialogue_line"):
		dui.show_dialogue_line(speaker, text, auto_advance)
		return
	print("⚠️ DialogueUI missing show_dialogue_line().")

func show_dialogue_line_wait(speaker: String, text: String, auto_advance: bool = false) -> void:
	var dui: CanvasLayer = get_node_or_null("/root/DialogueUI") as CanvasLayer
	if dui == null:
		print("⚠️ DialogueUI autoload not found.")
		return
	# Ensure cutscene mode to gate progression on next_pressed
	if dui.has_method("set_cutscene_mode"):
		dui.set_cutscene_mode(true)
	if dui.has_method("show_dialogue_line"):
		dui.show_dialogue_line(speaker, text, auto_advance)
		if auto_advance:
			# Let auto-advance proceed without waiting for input
			await get_tree().process_frame
			return
		# Wait until the player advances
		await dui.next_pressed
	else:
		print("⚠️ DialogueUI missing show_dialogue_line().")

func show_lines_sequence(lines: Array[Dictionary]) -> void:
	for line in lines:
		var speaker: String = String(line.get("speaker", ""))
		var text: String = String(line.get("text", ""))
		var auto_advance: bool = bool(line.get("auto_advance", false))
		await show_dialogue_line_wait(speaker, text, auto_advance)

func hide_ui() -> void:
	_hide_dialogue_ui()

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
		print("⚠️ No Camera2D found to shake.")
		return
	var original_offset := cam.offset
	var tween := create_tween()
	var steps := 6
	for i in range(steps):
		var rand_offset := Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
		tween.tween_property(cam, "offset", original_offset + rand_offset, duration / float(steps))
	# Return to original
	tween.tween_property(cam, "offset", original_offset, 0.08)

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

# ---- Camera swipe/pan helpers ----
func _find_first_by_name_substring(substr: String) -> Node2D:
	var lowered := substr.to_lower()
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

func camera_swipe_through_target(target: Node, duration_in: float = 0.35, hold_s: float = 0.2, duration_out: float = 0.35, max_distance: float = 220.0) -> void:
	var cam := _get_camera_2d()
	if cam == null or target == null:
		return
	var original_offset: Vector2 = cam.offset
	var player_pos := _get_player_global_position()
	var target_pos := _get_node2d_global_position(target)
	var delta := target_pos - player_pos
	# Clamp swipe distance so we don't overshoot off-screen
	if delta.length() > max_distance:
		delta = delta.normalized() * max_distance
	# Tween in (pan towards target)
	var t_in := create_tween()
	t_in.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t_in.tween_property(cam, "offset", original_offset + delta, duration_in)
	await t_in.finished
	# Hold briefly on target
	await get_tree().create_timer(max(0.0, hold_s)).timeout
	# Tween out (pan back to original/player)
	var t_out := create_tween()
	t_out.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t_out.tween_property(cam, "offset", original_offset, duration_out)
	await t_out.finished

func camera_swipe_to_nodepath(path: NodePath, duration_in: float = 0.35, hold_s: float = 0.2, duration_out: float = 0.35) -> void:
	var n := get_node_or_null(path)
	camera_swipe_through_target(n, duration_in, hold_s, duration_out)

func camera_swipe_to_first_named(name_substring: String, duration_in: float = 0.35, hold_s: float = 0.2, duration_out: float = 0.35) -> void:
	var n := _find_first_by_name_substring(name_substring)
	camera_swipe_through_target(n, duration_in, hold_s, duration_out)

func camera_swipe_to_erwin_quick() -> void:
	# Convenience for AnimationPlayer method tracks
	camera_swipe_to_first_named("erwin", 0.3, 0.15, 0.3)

# ---- Player helpers ----
func _find_player() -> Node:
	# Common paths or group lookup
	var n := get_node_or_null("../playerM")
	if n:
		return n
	for node in get_tree().get_nodes_in_group("player"):
		return node
	return null

func _set_player_active(active: bool) -> void:
	if player_node == null:
		return
	if player_node.has_method("set_process_input"):
		player_node.set_process_input(active)
	if player_node.has_method("set_physics_process"):
		player_node.set_physics_process(active)
	var collider := player_node.get_node_or_null("CollisionShape2D")
	if collider and collider is CollisionShape2D:
		(collider as CollisionShape2D).disabled = not active
