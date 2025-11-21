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
	
	# Setup fade layer
	_setup_fade()
	await fade_in()
	
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
	
	# Only play cutscene if BARANGAY_HALL_CUTSCENE_COMPLETED is set and MORGUE_COMPLETED is not
	if CheckpointManager.has_checkpoint(CheckpointManager.CheckpointType.BARANGAY_HALL_CUTSCENE_COMPLETED):
		if not CheckpointManager.has_checkpoint(CheckpointManager.CheckpointType.MORGUE_CUTSCENE_COMPLETED):
			print("🎬 BARANGAY_HALL_CUTSCENE_COMPLETED found - playing morgue cutscene")
			# Start cutscene
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
					print("🎬 Playing morgue_cutscene animation")
					anim_player.play("morgue_cutscene")
				else:
					print("⚠️ No 'morgue_cutscene' animation found. Available animations: ", anim_player.get_animation_list())
					_set_player_active(true)
			else:
				print("⚠️ AnimationPlayer not found!")
				_set_player_active(true)
		else:
			print("🎬 MORGUE_COMPLETED already set - cutscene already played")
			await fade_in()
			_set_player_active(true)
	else:
		print("⚠️ BARANGAY_HALL_CUTSCENE_COMPLETED not set - cutscene will not play")
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
	var dialogue_file_path = "res://data/dialogues/morgue_autopsy_dialogue.json"
	var dialogue_key = "morgue_autopsy"
	
	var file: FileAccess = FileAccess.open(dialogue_file_path, FileAccess.READ)
	if file == null:
		print("⚠️ Morgue dialogue file not found: ", dialogue_file_path)
		return
	
	var text: String = file.get_as_text()
	file.close()
	
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has(dialogue_key):
		print("⚠️ Failed to parse morgue dialogue file or missing key: ", dialogue_key)
		return
	
	var dialogue_data = parsed[dialogue_key]
	if dialogue_data.has("dialogue_lines"):
		var raw_lines: Variant = dialogue_data["dialogue_lines"]
		dialogue_lines.clear()
		if typeof(raw_lines) == TYPE_ARRAY:
			for item in (raw_lines as Array):
				if typeof(item) == TYPE_DICTIONARY:
					dialogue_lines.append(item as Dictionary)
			print("✅ Loaded morgue dialogue: ", dialogue_lines.size(), " lines")
		else:
			print("⚠️ Morgue dialogue 'dialogue_lines' is not an array")
	else:
		print("⚠️ Morgue dialogue data missing 'dialogue_lines' key")

func _on_dialogue_next() -> void:
	if not cutscene_active:
		return
	
	resume_on_next = false
	if anim_player:
		print("🎬 Morgue: resuming animation after next_pressed")
		anim_player.play()


func show_line(index: int, auto_advance: bool = false) -> void:
	if index < 0 or index >= dialogue_lines.size():
		print("⚠️ Dialogue line ", index, " not available")
		return
	
	var line = dialogue_lines[index]
	var speaker = line.get("speaker", "")
	var text = line.get("text", "")
	
	if DialogueUI:
		DialogueUI.show_dialogue_line(speaker, text, false)
		resume_on_next = true
		await wait_for_next()
	else:
		print("⚠️ DialogueUI not found")

func wait_for_next() -> void:
	resume_on_next = true
	if anim_player:
		anim_player.pause()
		print("🎬 Morgue: animation paused, waiting for next_pressed")
	
	while resume_on_next:
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
	# Check if ScenePreloader autoload exists
	var scene_preloader = get_node_or_null("/root/ScenePreloader")
	if scene_preloader and scene_preloader.has_method("is_scene_preloaded") and scene_preloader.is_scene_preloaded(target_scene_path):
		print("🚀 Using preloaded scene: ", target_scene_path.get_file())
		var preloaded_scene = scene_preloader.get_preloaded_scene(target_scene_path)
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
				print("⚠️ Animation '", animation_name, "' not found in new scene. Available animations: ", new_anim_player.get_animation_list() if new_anim_player else "No AnimationPlayer found")

func end_cutscene() -> void:
	"""End the cutscene - callable from AnimationPlayer"""
	# Prevent duplicate checkpoint setting
	if CheckpointManager.has_checkpoint(CheckpointManager.CheckpointType.MORGUE_CUTSCENE_COMPLETED):
		print("🎬 MORGUE_COMPLETED already set, skipping")
		return
	
	# Dramatic fade out before scene transition
	print("🎬 Morgue cutscene ending - dramatic fade out...")
	await dramatic_fade_out(2.0)
	
	# Hide dialogue UI during fade
	_hide_dialogue_ui()
	
	# Set checkpoint before transitioning
	cutscene_active = false
	CheckpointManager.set_checkpoint(CheckpointManager.CheckpointType.MORGUE_CUTSCENE_COMPLETED)
	print("🎬 Morgue cutscene completed - checkpoint set.")
	
	# Reset DialogueUI cutscene mode
	if DialogueUI:
		DialogueUI.cutscene_mode = false
	
	# Transition to apartment scene and play apartment_cutscene animation
	# Skip fade since we already did dramatic_fade_out above
	await transition_to_scene("res://scenes/environments/apartments/leo's apartment.tscn", "apartment_cutscene", true)
