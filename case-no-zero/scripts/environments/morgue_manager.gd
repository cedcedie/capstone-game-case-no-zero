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
	_setup_fade()
	
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
	
	# Only play cutscene if BARANGAY_HALL_CUTSCENE_COMPLETED is set and MORGUE_CUTSCENE_COMPLETED is not
	if CheckpointManager.has_checkpoint(CheckpointManager.CheckpointType.BARANGAY_HALL_CUTSCENE_COMPLETED):
		if not CheckpointManager.has_checkpoint(CheckpointManager.CheckpointType.MORGUE_CUTSCENE_COMPLETED):
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
			
			# Play morgue cutscene animation
			if anim_player != null:
				if anim_player.has_animation("morgue_cutscene"):
					anim_player.play("morgue_cutscene")
				else:
					push_warning("No 'morgue_cutscene' animation found. Available animations: " + str(anim_player.get_animation_list()))
					_set_player_active(true)
			else:
				push_warning("AnimationPlayer not found!")
				_set_player_active(true)
		else:
			await fade_in()
			_set_player_active(true)
	else:
		await fade_in()
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
func _load_dialogue_if_available() -> void:
	var dialogue_file_path = "res://data/dialogues/morgue_autopsy_dialogue.json"
	var dialogue_key = "morgue_autopsy"
	
	var file: FileAccess = FileAccess.open(dialogue_file_path, FileAccess.READ)
	if file == null:
		return
	
	var text: String = file.get_as_text()
	file.close()
	
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has(dialogue_key):
		return
	
	var dialogue_data = parsed[dialogue_key]
	if dialogue_data.has("dialogue_lines"):
		var loaded_lines = dialogue_data["dialogue_lines"]
		if typeof(loaded_lines) == TYPE_ARRAY:
			dialogue_lines.clear()
			for item in loaded_lines:
				if typeof(item) == TYPE_DICTIONARY:
					dialogue_lines.append(item as Dictionary)

func _on_dialogue_next() -> void:
	resume_on_next = true


func show_line(index: int, auto_advance: bool = false) -> void:
	if index < 0 or index >= dialogue_lines.size():
		return
	
	var line = dialogue_lines[index]
	var speaker = line.get("speaker", "")
	var text = line.get("text", "")
	
	if DialogueUI:
		DialogueUI.show_dialogue_line(speaker, text)
		if not auto_advance:
			resume_on_next = false
			await wait_for_next()

func wait_for_next() -> void:
	resume_on_next = false
	while not resume_on_next:
		await get_tree().process_frame

func _hide_dialogue_ui() -> void:
	if DialogueUI:
		DialogueUI.hide_ui()

func add_autopsy_evidence() -> void:
	var eis: Node = get_node_or_null("/root/EvidenceInventorySettings")
	if eis == null:
		return
	
	if not eis.has_method("add_evidence"):
		return
	
	eis.add_evidence("autopsy")
	
	# Wait a brief moment to ensure evidence is processed, then show inventory
	await get_tree().create_timer(0.2).timeout
	_show_inventory_brief(3.0)

func _show_inventory_brief(seconds: float = 3.0) -> void:
	var inv: Node = get_node_or_null("/root/EvidenceInventorySettings")
	if inv == null:
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

# ---- Environment visibility helpers ----
func hide_environment_and_characters(duration: float = 0.5) -> void:
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
	
	# Find other character nodes (NPCs, etc.)
	for child in root_scene.get_children():
		if child is Node2D:
			# Check if it's a character (not a TileMapLayer or other environment element)
			var is_character := false
			if child is CharacterBody2D:
				is_character = true
			elif String(child.name).to_lower().contains("npc") or String(child.name).to_lower().contains("character"):
				is_character = true
			# Also include any visible Node2D that's not a TileMapLayer
			elif not (child is TileMapLayer):
				# Check if it has an AnimatedSprite2D child (likely a character)
				if child.find_child("AnimatedSprite2D", true, false) != null:
					is_character = true
			
			if is_character and child is CanvasItem and (child as CanvasItem).visible:
				elements_to_fade.append(child as CanvasItem)
	
	if elements_to_fade.is_empty():
		return
	
	# Ensure all elements start at full alpha and are visible
	for element in elements_to_fade:
		element.modulate.a = 1.0
		element.visible = true
	
	# Smoothly fade out with tween
	var tween := create_tween()
	tween.set_parallel(true)  # Animate all elements simultaneously
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	
	for element in elements_to_fade:
		tween.tween_property(element, "modulate:a", 0.0, duration)
	
	await tween.finished
	
	# Set visibility to false after fade completes
	for element in elements_to_fade:
		element.visible = false
		element.modulate.a = 1.0  # Reset for next time

func fade_environment_and_transition_to_cinematic_text(duration: float = 1.0) -> void:
	_hide_dialogue_ui()
	
	await hide_environment_and_characters(duration)
	await fade_out(0.5)
	var tree := get_tree()
	if tree == null:
		push_error("⚠️ Cannot transition - tree is null")
		return
	
	var cinematic_scene_path := "res://cinematic_text.tscn"
	var result: Error
	
	# Check if ScenePreloader autoload exists
	var scene_preloader = get_node_or_null("/root/ScenePreloader")
	if scene_preloader and scene_preloader.has_method("is_scene_preloaded") and scene_preloader.is_scene_preloaded(cinematic_scene_path):
		var preloaded_scene = scene_preloader.get_preloaded_scene(cinematic_scene_path)
		result = tree.change_scene_to_packed(preloaded_scene)
	else:
		result = tree.change_scene_to_file(cinematic_scene_path)
	
	if result != OK:
		push_error("❌ Failed to change scene to: " + cinematic_scene_path)
		return
	
	await tree.process_frame
	await tree.process_frame
	
	var new_scene := tree.current_scene
	if new_scene:
		var anim_player: AnimationPlayer = new_scene.get_node_or_null("AnimationPlayer")
		if anim_player == null:
			anim_player = new_scene.find_child("AnimationPlayer", true, false) as AnimationPlayer
		
		if anim_player:
			var animation_name = "cinematic_text_cutscene"
			if not anim_player.has_animation(animation_name):
				animation_name = "cinematic_text"
			
			if anim_player.has_animation(animation_name):
				anim_player.play(animation_name)
			else:
				push_warning("⚠️ Animation not found in cinematic_text scene. Available animations: " + str(anim_player.get_animation_list() if anim_player else "No AnimationPlayer found"))

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

func transition_to_scene(target_scene_path: String, animation_name: String = "", skip_fade: bool = false) -> void:
	if not skip_fade:
		await dramatic_fade_out(2.0)
	
	_hide_dialogue_ui()
	
	var tree := get_tree()
	if tree == null:
		push_error("Cannot transition - tree is null")
		return
	
	var result: Error
	var scene_preloader = get_node_or_null("/root/ScenePreloader")
	if scene_preloader and scene_preloader.has_method("is_scene_preloaded") and scene_preloader.is_scene_preloaded(target_scene_path):
		var preloaded_scene = scene_preloader.get_preloaded_scene(target_scene_path)
		result = tree.change_scene_to_packed(preloaded_scene)
	else:
		result = tree.change_scene_to_file(target_scene_path)
	
	if result != OK:
		push_error("Failed to change scene to: " + target_scene_path)
		return
	
	await tree.process_frame
	await tree.process_frame
	
	if animation_name != "":
		var new_scene := tree.current_scene
		if new_scene:
			var new_anim_player: AnimationPlayer = new_scene.get_node_or_null("AnimationPlayer")
			if new_anim_player == null:
				new_anim_player = new_scene.find_child("AnimationPlayer", true, false) as AnimationPlayer
			
			if new_anim_player and new_anim_player.has_animation(animation_name):
				new_anim_player.play(animation_name)
			else:
				push_warning("Animation '" + animation_name + "' not found in new scene.")

func end_cutscene() -> void:
	if CheckpointManager.has_checkpoint(CheckpointManager.CheckpointType.MORGUE_CUTSCENE_COMPLETED):
		return
	
	if DialogueUI:
		DialogueUI.cutscene_mode = false
	
	await fade_environment_and_transition_to_cinematic_text(1.0)
	cutscene_active = false
	CheckpointManager.set_checkpoint(CheckpointManager.CheckpointType.MORGUE_CUTSCENE_COMPLETED)
