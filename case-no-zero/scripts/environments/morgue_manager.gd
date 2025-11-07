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
	print("🎬 Morgue cutscene: _ready() started")
	
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
func _load_dialogue_if_available() -> void:
	# Load dialogue if needed - implement based on your dialogue file
	pass

func _on_dialogue_next() -> void:
	resume_on_next = true

# ---- AnimationPlayer callable functions ----
func show_dialogue_line_0() -> void:
	show_line(0, true)

func show_dialogue_line_1() -> void:
	show_line(1, true)

func show_dialogue_line_2() -> void:
	show_line(2, true)

func show_dialogue_line_3() -> void:
	show_line(3, true)

func show_dialogue_line_4() -> void:
	show_line(4, true)

func show_dialogue_line_5() -> void:
	show_line(5, true)

func show_dialogue_line_6() -> void:
	show_line(6, true)

func show_dialogue_line_7() -> void:
	show_line(7, true)

func show_dialogue_line_8() -> void:
	show_line(8, true)

func show_dialogue_line_9() -> void:
	show_line(9, true)

func show_dialogue_line_10() -> void:
	show_line(10, true)

func show_dialogue_line_11() -> void:
	show_line(11, true)

func show_line(index: int, auto_advance: bool = false) -> void:
	if index < 0 or index >= dialogue_lines.size():
		print("⚠️ Dialogue line ", index, " not available")
		return
	
	var line = dialogue_lines[index]
	var speaker = line.get("speaker", "")
	var text = line.get("text", "")
	
	if DialogueUI:
		DialogueUI.show_dialogue_line(speaker, text)
		if not auto_advance:
			resume_on_next = false
			await wait_for_next()
	else:
		print("⚠️ DialogueUI not found")

func wait_for_next() -> void:
	resume_on_next = false
	while not resume_on_next:
		await get_tree().process_frame

func _hide_dialogue_ui() -> void:
	if DialogueUI:
		DialogueUI.hide_ui()

func add_autopsy_evidence() -> void:
	"""Add autopsy evidence and show inventory - callable from AnimationPlayer"""
	var eis: Node = get_node_or_null("/root/EvidenceInventorySettings")
	if eis == null:
		print("⚠️ EvidenceInventorySettings node not found at /root/EvidenceInventorySettings")
		return
	
	if not eis.has_method("add_evidence"):
		print("⚠️ EvidenceInventorySettings missing add_evidence method")
		return
	
	eis.add_evidence("autopsy")
	print("🔎 Autopsy evidence added")
	
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

func end_cutscene() -> void:
	"""End the cutscene - callable from AnimationPlayer"""
	cutscene_active = false
	_hide_dialogue_ui()
	if DialogueUI:
		DialogueUI.cutscene_mode = false
	_set_player_active(true)
	print("🎬 Morgue cutscene ended")
