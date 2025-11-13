extends Node2D

var label: Label = null

func _ready() -> void:
	# Get the Label node
	label = get_node_or_null("Label")
	if label == null:
		push_error("⚠️ Label node not found in cinematic_text scene")
		return
	
	# Initialize label to be invisible
	label.modulate.a = 0.0
	label.visible = false

func show_sinister_text(fade_in_duration: float = 1.5, hold_duration: float = 2.0, fade_out_duration: float = 1.5) -> void:
	"""Show the text with a sinister fade-in effect, hold, then auto fade-out - callable from AnimationPlayer"""
	if label == null:
		label = get_node_or_null("Label")
		if label == null:
			push_error("⚠️ Label node not found")
			return
	
	# Set the text
	label.text = "May pupuntahan pa ako na baka makatulong din sa kaso."
	
	# Make label visible and start at transparent
	label.visible = true
	label.modulate.a = 0.0
	
	# Create a sinister fade-in effect with a slight red tint
	var tween_in := create_tween()
	tween_in.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	
	# Fade in with a slightly red/dark tint for sinister effect
	label.modulate = Color(0.9, 0.7, 0.7, 0.0)  # Slight red tint, transparent
	tween_in.parallel().tween_property(label, "modulate:a", 1.0, fade_in_duration)
	
	# Slight scale effect for dramatic entrance
	label.scale = Vector2(0.95, 0.95)
	tween_in.parallel().tween_property(label, "scale", Vector2(1.0, 1.0), fade_in_duration)
	
	await tween_in.finished
	
	# Hold the text visible for the specified duration
	await get_tree().create_timer(hold_duration).timeout
	
	# Auto fade-out
	var tween_out := create_tween()
	tween_out.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween_out.tween_property(label, "modulate:a", 0.0, fade_out_duration)
	
	await tween_out.finished
	
	# Hide the label after fade-out
	label.visible = false

func show_inventory_with_masked_last_evidence(duration: float = 3.0) -> void:
	"""Briefly show the inventory - last evidence is already masked as ??????????? when first added - callable from AnimationPlayer"""
	var eis: Node = get_node_or_null("/root/EvidenceInventorySettings")
	if eis == null:
		push_error("⚠️ EvidenceInventorySettings node not found")
		return
	
	if not eis.has_method("show_evidence_inventory"):
		push_error("⚠️ EvidenceInventorySettings missing show_evidence_inventory method")
		return
	
	# Ensure evidence data is loaded from JSON file first
	if eis.has_method("_load_evidence_data"):
		eis._load_evidence_data()
	
	# Select the last evidence if available (it's already masked in the data)
	if eis.collected_evidence.size() > 0:
		var last_evidence_index = eis.collected_evidence.size() - 1
		eis._select_evidence(last_evidence_index)
	
	# Show the inventory (last evidence will display as ??????????? since it's already masked in data)
	eis.show_evidence_inventory()
	
	# Wait for the specified duration
	await get_tree().create_timer(duration).timeout
	
	# Hide the inventory
	if eis.has_method("hide_evidence_inventory"):
		eis.hide_evidence_inventory()
	

func end_cutscene() -> void:
	"""End the cinematic_text cutscene - callable from AnimationPlayer"""
	# Prevent duplicate checkpoint setting
	if CheckpointManager.has_checkpoint(CheckpointManager.CheckpointType.CINEMATIC_TEXT_CUTSCENE_COMPLETED):
		return
	
	# Fade out to black
	var fade_rect: ColorRect = null
	var fade_layer: CanvasLayer = null
	
	# Create fade layer if needed
	fade_layer = CanvasLayer.new()
	fade_layer.layer = 100
	var root_scene := get_tree().current_scene
	if root_scene:
		root_scene.add_child(fade_layer)
	else:
		add_child(fade_layer)
	
	fade_rect = ColorRect.new()
	fade_rect.color = Color.BLACK
	fade_rect.visible = true
	fade_rect.modulate.a = 0.0
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_rect.offset_left = 0
	fade_rect.offset_top = 0
	fade_rect.offset_right = 0
	fade_rect.offset_bottom = 0
	fade_layer.add_child(fade_rect)
	
	# Fade out
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(fade_rect, "modulate:a", 1.0, 1.5)
	await tween.finished
	
	# Set checkpoint
	CheckpointManager.set_checkpoint(CheckpointManager.CheckpointType.CINEMATIC_TEXT_CUTSCENE_COMPLETED)
	
	# Transition to courtroom scene
	var tree := get_tree()
	if tree == null:
		push_error("⚠️ Cannot transition - tree is null")
		return
	
	var courtroom_scene_path := "res://scenes/environments/Courtroom/courtroom.tscn"
	var result: Error
	
	# Check if ScenePreloader autoload exists
	var scene_preloader = get_node_or_null("/root/ScenePreloader")
	if scene_preloader and scene_preloader.has_method("is_scene_preloaded") and scene_preloader.is_scene_preloaded(courtroom_scene_path):
		var preloaded_scene = scene_preloader.get_preloaded_scene(courtroom_scene_path)
		result = tree.change_scene_to_packed(preloaded_scene)
	else:
		result = tree.change_scene_to_file(courtroom_scene_path)
	
	if result != OK:
		push_error("❌ Failed to change scene to: " + courtroom_scene_path)
		return
	
	# Wait for scene to be ready
	await tree.process_frame
	await tree.process_frame
	
	# Find the AnimationPlayer named "courtroom_animation" and play the animation
	var new_scene := tree.current_scene
	if new_scene:
		# First try to find by name
		var courtroom_anim_player: AnimationPlayer = new_scene.get_node_or_null("courtroom_animation")
		if courtroom_anim_player == null:
			# Try recursive search for node named "courtroom_animation"
			var found = new_scene.find_child("courtroom_animation", true, false)
			if found is AnimationPlayer:
				courtroom_anim_player = found
		
		if courtroom_anim_player:
			if courtroom_anim_player.has_animation("courtroom_animation"):
				courtroom_anim_player.play("courtroom_animation")
			else:
				push_warning("⚠️ Animation 'courtroom_animation' not found in courtroom_animation AnimationPlayer. Available animations: " + str(courtroom_anim_player.get_animation_list()))
		else:
			push_warning("⚠️ AnimationPlayer named 'courtroom_animation' not found in courtroom scene")
