extends Node2D

signal fade_finished

@export var fade_duration: float = 1.5

var fade_layer: CanvasLayer = null
var fade_rect: ColorRect = null
var fade_in_progress: bool = false
var fade_complete: bool = false
var anim_player: AnimationPlayer = null
var cutscene_active: bool = false
var player_node: Node = null

func _ready() -> void:
	_setup_fade_layer()
	
	# Find AnimationPlayer
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
	
	# Check if we should auto-play apartment cutscene after morgue cutscene
	# Only play if morgue cutscene was completed and animation isn't already playing
	if CheckpointManager.has_checkpoint(CheckpointManager.CheckpointType.MORGUE_CUTSCENE_COMPLETED):
		print("🎬 Leo Apartment: Morgue cutscene completed - preparing to play apartment cutscene")
		
		# Wait for scene to fully initialize
		await get_tree().process_frame
		await get_tree().process_frame
		await get_tree().process_frame
		
		# Wait a bit more for scene to fully initialize and for transition_to_scene to finish
		await get_tree().create_timer(0.8).timeout
		
		# Try to find AnimationPlayer again if not found
		if anim_player == null:
			var current_scene := get_tree().current_scene
			if current_scene != null:
				anim_player = current_scene.get_node_or_null("AnimationPlayer")
				if anim_player == null:
					var found := current_scene.find_child("AnimationPlayer", true, false)
					if found is AnimationPlayer:
						anim_player = found
		
		# Play apartment cutscene if AnimationPlayer and animation exist
		if anim_player != null:
			if anim_player.has_animation("apartment_cutscene"):
				# Check if animation is already playing (might have been started by transition_to_scene)
				if not anim_player.is_playing() or anim_player.current_animation != "apartment_cutscene":
					print("🎬 Leo Apartment: Auto-playing apartment_cutscene after morgue cutscene")
					cutscene_active = true
					if player_node != null:
						_set_player_active(false)
					# Ensure player is disabled
					if player_node == null:
						player_node = _find_player()
					if player_node != null:
						_set_player_active(false)
					anim_player.play("apartment_cutscene")
					print("🎬 Leo Apartment: apartment_cutscene started")
				else:
					print("🎬 Leo Apartment: apartment_cutscene already playing")
			else:
				print("⚠️ Leo Apartment: 'apartment_cutscene' animation not found. Available: ", anim_player.get_animation_list())
		else:
			print("⚠️ Leo Apartment: AnimationPlayer not found! Retrying...")
			# Retry once more after a delay
			await get_tree().create_timer(0.5).timeout
			var retry_scene := get_tree().current_scene
			if retry_scene != null:
				anim_player = retry_scene.get_node_or_null("AnimationPlayer")
				if anim_player == null:
					anim_player = retry_scene.find_child("AnimationPlayer", true, false) as AnimationPlayer
				if anim_player and anim_player.has_animation("apartment_cutscene"):
					print("🎬 Leo Apartment: Found AnimationPlayer on retry - playing apartment_cutscene")
					cutscene_active = true
					if player_node != null:
						_set_player_active(false)
					anim_player.play("apartment_cutscene")
				else:
					print("⚠️ Leo Apartment: Still cannot find AnimationPlayer or animation")

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

func fade_scene_elements(duration: float = -1.0) -> void:
	"""Fade the entire Leo apartment scene to black."""
	if fade_in_progress:
		return
	
	var actual_duration := fade_duration if duration <= 0.0 else duration
	_setup_fade_layer()
	
	fade_rect.visible = true
	fade_rect.modulate.a = 0.0
	fade_in_progress = true
	fade_complete = false
	
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(fade_rect, "modulate:a", 1.0, actual_duration)
	tween.finished.connect(_on_fade_finished)

func end_cutscene() -> void:
	"""Fade out Leo's apartment and jump to the cinematic text scene."""
	call_deferred("_end_cutscene_async")

func _end_cutscene_async() -> void:
	if not fade_complete:
		if not fade_in_progress:
			fade_scene_elements()
		await fade_finished
	
	var tree := get_tree()
	if tree:
		var result := tree.change_scene_to_file("res://cinematic_text.tscn")
		if result != OK:
			push_warning("Failed to load cinematic_text.tscn, error: %s" % result)

func _on_fade_finished() -> void:
	fade_in_progress = false
	fade_complete = true
	fade_finished.emit()

func _setup_fade_layer() -> void:
	if fade_layer and fade_rect:
		return
	
	fade_layer = CanvasLayer.new()
	fade_layer.layer = 200
	add_child(fade_layer)
	
	fade_rect = ColorRect.new()
	fade_rect.color = Color.BLACK
	fade_rect.visible = false
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_layer.add_child(fade_rect)
