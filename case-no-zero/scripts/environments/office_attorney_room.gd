extends Node2D

@onready var anim: AnimationPlayer = $AnimationPlayer

var dialogue_lines: Array[Dictionary] = []
var resume_on_next: bool = false
var fade_layer: CanvasLayer
var fade_rect: ColorRect
@export var reaction_bubble_path: NodePath = ^"ReactionBubble"
var played_reactions: Dictionary = {}
@onready var reaction_bubble := get_node_or_null(reaction_bubble_path)
@onready var reaction_anim: AnimationPlayer = reaction_bubble if reaction_bubble == null else reaction_bubble.get_node_or_null("AnimationPlayer")
var player_node: Node = null

func _ready() -> void:
	_load_dialogue()
	if DialogueUI and not DialogueUI.next_pressed.is_connected(_on_dialogue_next):
		DialogueUI.next_pressed.connect(_on_dialogue_next)
	_setup_fade()
	
	# Check if cutscene already played
	if CheckpointManager.has_checkpoint(CheckpointManager.CheckpointType.OFFICE_CUTSCENE_COMPLETED):
		print("🎬 Office cutscene already completed, skipping...")
		await fade_in()
		show_environment_and_characters()
		_set_player_active(true)
		_despawn_celine_if_completed()
		return
	
	# Start cutscene for first time
	player_node = _find_player()
	_set_player_active(false)
	await fade_in()
	play_cutscene()

func _load_dialogue() -> void:
	var file: FileAccess = FileAccess.open("res://data/dialogues/office_attorney_intro.json", FileAccess.READ)
	if file == null:
		push_error("Cannot open office_attorney_intro.json")
		return
	var text: String = file.get_as_text()
	file.close()
	var parsed: Dictionary = JSON.parse_string(text) as Dictionary
	if parsed.is_empty() or not parsed.has("office_attorney_intro"):
		push_error("Invalid dialogue JSON format")
		return
	var section: Dictionary = parsed["office_attorney_intro"] as Dictionary
	var raw = section.get("dialogue_lines", [])
	var typed: Array[Dictionary] = []
	for item in raw:
		if typeof(item) == TYPE_DICTIONARY:
			typed.append(item as Dictionary)
	dialogue_lines = typed

# Animation hooks (call these from AnimationPlayer 'office_cutscene')
func play_cutscene() -> void:
	if DialogueUI:
		DialogueUI.set_cutscene_mode(true)
	anim.play("office_cutscene")
	# Mark cutscene as completed when it finishes
	await anim.animation_finished
	end_cutscene()

func end_cutscene() -> void:
	# Called when the office cutscene ends (or via AnimationPlayer method track)
	CheckpointManager.set_checkpoint(CheckpointManager.CheckpointType.OFFICE_CUTSCENE_COMPLETED)
	print("🎬 Office cutscene completed, checkpoint set.")
	_set_player_active(true)
	# Hide Dialogue UI after cutscene
	if DialogueUI:
		DialogueUI.hide_ui()
	# Update next task (no-op safe)
	if Engine.has_singleton("TaskManager") or typeof(TaskManager) != TYPE_NIL:
		if TaskManager.has_method("update_task"):
			TaskManager.update_task("Pumunta sa kulungan")
		if TaskManager.has_method("set_current_task"):
			TaskManager.set_current_task("go_to_jail")
	print("📝 Next task: Pumunta sa kulungan")

	# Unlock first evidence: Broken Body Cam
	_unlock_broken_body_cam()
	# Briefly show task on TaskDisplay if available
	_show_task_display("Pumunta sa kulungan")
	# Briefly show inventory
	_show_inventory_brief(3.0)
	# Prevent Celine from appearing again on revisit
	_despawn_celine_if_completed()

func _unlock_broken_body_cam() -> void:
	# Attempts several common APIs on EvidenceInventorySettings autoload/node
	# Autoload path (if configured): /root/EvidenceInventorySettings
	var eis: Node = get_node_or_null("/root/EvidenceInventorySettings")
	if eis == null:
		print("⚠️ EvidenceInventorySettings node not found at /root/EvidenceInventorySettings")
		return
	# Try common method names
	if eis.has_method("unlock_evidence"):
		eis.unlock_evidence(1)
		print("🔎 Evidence unlocked via unlock_evidence(1)")
		return
	elif eis.has_method("add_evidence"):
		# Some implementations expect a String identifier; try common forms
		eis.add_evidence("1")
		print("🔎 Evidence unlocked via add_evidence(\"1\")")
		return
	elif eis.has_method("set_evidence_unlocked"):
		# Try both int and string ids
		if eis.get_method_argument_count("set_evidence_unlocked") >= 2:
			eis.set_evidence_unlocked("1", true)
			print("🔎 Evidence unlocked via set_evidence_unlocked(\"1\", true)")
		else:
			eis.set_evidence_unlocked(1, true)
			print("🔎 Evidence unlocked via set_evidence_unlocked(1, true)")
		return
	elif eis.has_method("mark_found"):
		# String id fallback
		eis.mark_found("1")
		print("🔎 Evidence unlocked via mark_found(\"1\")")
		return
	print("⚠️ Could not find a method to unlock evidence id 1 on EvidenceInventorySettings")

func show_line(index: int, auto_advance: bool = false) -> void:
	if index < 0 or index >= dialogue_lines.size():
		push_warning("Dialogue index out of range: " + str(index))
		return
	var line: Dictionary = dialogue_lines[index]
	var speaker: String = String(line.get("speaker", ""))
	var text: String = String(line.get("text", ""))
	if DialogueUI:
		DialogueUI.show_dialogue_line(speaker, text, auto_advance)

func show_line_auto(index: int) -> void:
	show_line(index, true)

func next() -> void:
	if DialogueUI and DialogueUI.has_method("_on_next_pressed"):
		DialogueUI._on_next_pressed()

func hide_ui() -> void:
	if DialogueUI:
		DialogueUI.hide_ui()

func wait_for_next() -> void:
	resume_on_next = true
	if anim:
		anim.pause()

func show_line_wait(index: int) -> void:
	# Convenience: show line and immediately pause animation until Next
	show_line(index, false)
	wait_for_next()

func _on_dialogue_next() -> void:
	if resume_on_next and anim:
		resume_on_next = false
		anim.play()

# =============================
# ENV/CHAR HIDE/SHOW + FADE
# =============================
func hide_environment_and_characters() -> void:
	# Hide all TileMapLayer and character instances under this scene
	for child in get_children():
		if child is TileMapLayer:
			child.visible = false
		elif child is Node2D and (child.name == "PlayerM" or child.name == "celine"):
			child.visible = false

func show_environment_and_characters() -> void:
	for child in get_children():
		if child is TileMapLayer:
			child.visible = true
		elif child is Node2D and (child.name == "PlayerM" or child.name == "celine"):
			child.visible = true

func _setup_fade() -> void:
	if fade_layer: return
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
	if not fade_rect: _setup_fade()
	fade_rect.visible = true
	fade_rect.modulate.a = 1.0
	var t := create_tween()
	t.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(fade_rect, "modulate:a", 0.0, duration)
	await t.finished
	fade_rect.visible = false

func fade_out(duration: float = 0.5) -> void:
	if not fade_rect: _setup_fade()
	fade_rect.visible = true
	fade_rect.modulate.a = 0.0
	var t := create_tween()
	t.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(fade_rect, "modulate:a", 1.0, duration)
	await t.finished

# =============================
# REACTION BUBBLE HELPERS
# =============================
func play_reaction_once(reaction_anim_name: String, fade_after_s: float = 0.35) -> void:
	if reaction_anim == null or reaction_bubble == null:
		return
	if played_reactions.has(reaction_anim_name):
		return
	played_reactions[reaction_anim_name] = true
	reaction_bubble.visible = true
	if reaction_bubble is CanvasItem:
		reaction_bubble.modulate.a = 1.0
	reaction_anim.play(reaction_anim_name)
	await reaction_anim.animation_finished
	await _fade_out_reaction(fade_after_s)

func play_reaction(reaction_anim_name: String, fade_after_s: float = 0.35) -> void:
	if reaction_anim == null or reaction_bubble == null:
		return
	reaction_bubble.visible = true
	if reaction_bubble is CanvasItem:
		reaction_bubble.modulate.a = 1.0
	reaction_anim.play(reaction_anim_name)
	await reaction_anim.animation_finished
	await _fade_out_reaction(fade_after_s)

func _fade_out_reaction(duration: float) -> void:
	if reaction_bubble == null:
		return
	if reaction_bubble is CanvasItem:
		var t := create_tween()
		t.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		t.tween_property(reaction_bubble, "modulate:a", 0.0, duration)
		await t.finished
	reaction_bubble.visible = false

# =============================
# REACTION POSITION HELPERS
# =============================
func set_reaction_position(x: float, y: float) -> void:
	if reaction_bubble == null:
		return
	if reaction_bubble is Node2D:
		reaction_bubble.position = Vector2(x, y)
	elif reaction_bubble is Control:
		reaction_bubble.position = Vector2(x, y)

func set_reaction_global_position(x: float, y: float) -> void:
	if reaction_bubble == null:
		return
	if reaction_bubble is Node2D:
		reaction_bubble.global_position = Vector2(x, y)
	elif reaction_bubble is Control:
		reaction_bubble.global_position = Vector2(x, y)

func nudge_reaction(dx: float, dy: float) -> void:
	if reaction_bubble == null:
		return
	if reaction_bubble is Node2D or reaction_bubble is Control:
		reaction_bubble.position += Vector2(dx, dy)

# Convenience one-shot wrappers for AnimationPlayer method tracks
func reaction_alert() -> void:
	play_reaction_once("alert")

func reaction_angry() -> void:
	play_reaction_once("angry")

func reaction_heartbreak() -> void:
	play_reaction_once("heartbreak")

func reaction_music() -> void:
	play_reaction_once("music")

func reaction_police() -> void:
	play_reaction_once("police")

func reaction_talking() -> void:
	play_reaction_once("talking")

func reaction_worry() -> void:
	play_reaction_once("worry")

# Testing helper: reset one-shot gating
func clear_reactions() -> void:
	played_reactions.clear()

# =============================
# DEBUG FUNCTIONS
# =============================
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_F1:
				# Reset office cutscene checkpoint and replay
				CheckpointManager.clear_checkpoint(CheckpointManager.CheckpointType.OFFICE_CUTSCENE_COMPLETED)
				print("🔄 F1: Reset office cutscene checkpoint, replaying...")
				play_cutscene()
			KEY_F2:
				# Force play cutscene (even if already completed)
				print("🎬 F2: Force playing office cutscene...")
				play_cutscene()
			KEY_F3:
				# Skip to end of cutscene
				print("⏭️ F3: Skipping to end of cutscene...")
				CheckpointManager.set_checkpoint(CheckpointManager.CheckpointType.OFFICE_CUTSCENE_COMPLETED)
				show_environment_and_characters()
				hide_ui()
		_set_player_active(true)

# =============================
# PLAYER CONTROL HELPERS
# =============================
func _find_player() -> Node:
	# Try common names or group membership
	var candidate := get_node_or_null("PlayerM")
	if candidate != null:
		return candidate
	# Scan children shallowly for a likely player node
	for c in get_children():
		if String(c.name).to_lower().find("player") != -1:
			return c
	return null

func _set_player_active(active: bool) -> void:
	if player_node == null:
		player_node = _find_player()
	if player_node == null:
		return
	# Disable input/physics processing during cutscene
	if player_node.has_method("set_process_input"):
		player_node.set_process_input(active)
	if player_node.has_method("set_physics_process"):
		player_node.set_physics_process(active)

# =============================
# CHARACTER FADE HELPERS (CELINE)
# =============================
func _find_celine() -> CanvasItem:
	var n := get_node_or_null("celine")
	if n != null and n is CanvasItem:
		return n
	# Fallback search by name
	for c in get_children():
		if String(c.name).to_lower() == "celine" and c is CanvasItem:
			return c
	return null

func fade_out_celine(duration: float = 0.4) -> void:
	var celine := _find_celine()
	if celine == null:
		return
	var t := create_tween()
	t.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(celine, "modulate:a", 0.0, duration)
	await t.finished
	_set_celine_collision_enabled(false)

func fade_in_celine(duration: float = 0.4) -> void:
	var celine := _find_celine()
	if celine == null:
		return
	celine.modulate.a = 0.0
	_set_celine_collision_enabled(true)
	var t := create_tween()
	t.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(celine, "modulate:a", 1.0, duration)
	await t.finished

func _set_celine_collision_enabled(enabled: bool) -> void:
	var celine := _find_celine()
	if celine == null:
		return
	# Disable/enable all CollisionShape2D descendants under celine
	var stack: Array = [celine]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		for child in n.get_children():
			stack.push_back(child)
			if child is CollisionShape2D:
				(child as CollisionShape2D).disabled = not enabled

func _despawn_celine_if_completed() -> void:
	if not CheckpointManager.has_checkpoint(CheckpointManager.CheckpointType.OFFICE_CUTSCENE_COMPLETED):
		return
	var celine := _find_celine()
	if celine != null:
		_set_celine_collision_enabled(false)
		celine.queue_free()

func _show_inventory_brief(seconds: float = 3.0) -> void:
	var inv: Node = get_node_or_null("/root/EvidenceInventorySettings")
	if inv == null:
		print("⚠️ EvidenceInventorySettings not found for brief show")
		return
	# If it's a CanvasItem, tween it in/out for a quick popup effect
	if inv is CanvasItem:
		var ci := inv as CanvasItem
		ci.visible = true
		# Prepare initial state
		ci.modulate.a = 0.0
		if inv is Node2D or inv is Control:
			inv.scale = Vector2(0.9, 0.9)
		# Tween in
		var tin := create_tween()
		tin.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tin.tween_property(ci, "modulate:a", 1.0, 0.25)
		if inv is Node2D or inv is Control:
			tin.tween_property(inv, "scale", Vector2(1.0, 1.0), 0.25)
		await tin.finished
		# Hold
		await get_tree().create_timer(max(0.1, seconds)).timeout
		# Tween out
		var tout := create_tween()
		tout.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tout.tween_property(ci, "modulate:a", 0.0, 0.25)
		await tout.finished
		ci.visible = false
		return
	# Fallback to open/close methods if not a CanvasItem
	if inv.has_method("open"):
		inv.open()
		await get_tree().create_timer(max(0.1, seconds)).timeout
		if inv.has_method("close"):
			inv.close()

func _show_task_display(text: String) -> void:
	var td: Node = get_node_or_null("/root/TaskDisplay")
	if td == null:
		return
	# Try common task display APIs
	if td.has_method("show_task"):
		td.show_task(text)
		return
	if td.has_method("update_task"):
		td.update_task(text)
		return
	if td.has_method("set_text"):
		td.set_text(text)
		return
	# Fallback: if it is CanvasItem, briefly flash visibility
	if td is CanvasItem:
		(td as CanvasItem).show()
		await get_tree().create_timer(2.0).timeout
		(td as CanvasItem).hide()

# =============================
# CAMERA SHAKE HELPERS
# =============================
func camera_shake(duration: float = 0.25, magnitude: float = 8.0, frequency: float = 30.0) -> void:
	var cam := _find_camera()
	if cam == null:
		return
	await _shake_camera(cam, duration, magnitude, frequency)

func camera_shake_quick() -> void:
	# Preset for AnimationPlayer method tracks
	camera_shake(0.25, 8.0, 30.0)

func _find_camera() -> Camera2D:
	# Prefer current viewport camera
	var cam: Camera2D = get_viewport().get_camera_2d()
	if cam != null:
		return cam
	# Fallback: search descendants for first Camera2D
	return _find_camera_in_tree(self)

func _find_camera_in_tree(node: Node) -> Camera2D:
	for c in node.get_children():
		if c is Camera2D:
			return c
		var found: Camera2D = _find_camera_in_tree(c)
		if found != null:
			return found
	return null

func _shake_camera(cam: Camera2D, duration: float, magnitude: float, frequency: float) -> void:
	var original_position: Vector2 = cam.position
	var elapsed: float = 0.0
	var interval: float = float(max(0.01, 1.0 / max(1.0, frequency)))
	while elapsed < duration:
		var offset := Vector2(randf_range(-magnitude, magnitude), randf_range(-magnitude, magnitude))
		cam.position = original_position + offset
		await get_tree().create_timer(interval).timeout
		elapsed += interval
	cam.position = original_position
