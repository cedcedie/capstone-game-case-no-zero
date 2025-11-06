extends Node

# Dedicated spawn for after follow_darwin (separate from recollection spawn)
const FOLLOW_DARWIN_SPAWN: Vector2 = Vector2(768.0, 288.0)

var anim_player: AnimationPlayer = null
var player_node: Node = null
var dialogue_lines: Array[Dictionary] = []
var celine_call_dialogue: Array[Dictionary] = []  # Separate dialogue for celine_call
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
	# Load celine_call dialogue
	_load_celine_call_dialogue()
	
	# Connect DialogueUI next_pressed signal
	var dui: Node = get_node_or_null("/root/DialogueUI")
	if dui and dui.has_signal("next_pressed") and not dui.next_pressed.is_connected(_on_dialogue_next):
		dui.next_pressed.connect(_on_dialogue_next)
	
	# Check if HEAD_POLICE_COMPLETED - hide station lobby nodes permanently
	if CheckpointManager.has_checkpoint(CheckpointManager.CheckpointType.HEAD_POLICE_COMPLETED):
		print("🎬 HEAD_POLICE_COMPLETED - hiding station lobby nodes permanently")
		_hide_station_lobby_nodes()
	
	# FLOW ORDER (from latest to earliest):
	# 1. SECURITY_SERVER_CUTSCENE_2_COMPLETED → celine _call_cutscene (latest in flow)
	# 2. HEAD_POLICE_COMPLETED → follow_darwin (after recollection)
	# 3. LOWER_LEVEL_CUTSCENE_COMPLETED → recollection (earliest in flow)
	
	# Check if SECURITY_SERVER_CUTSCENE_2_COMPLETED - play celine _call_cutscene animation (only once)
	if CheckpointManager.has_checkpoint(CheckpointManager.CheckpointType.SECURITY_SERVER_CUTSCENE_2_COMPLETED):
		if not CheckpointManager.has_checkpoint(CheckpointManager.CheckpointType.CELINE_CALL_COMPLETED):
			print("🎬 SECURITY_SERVER_CUTSCENE_2_COMPLETED - playing celine _call_cutscene animation")
			# Start cutscene
			cutscene_active = true
			
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
			
			# Play celine _call_cutscene animation
			if anim_player != null:
				if anim_player.has_animation("celine _call_cutscene"):
					print("🎬 Playing celine _call_cutscene animation")
					anim_player.play("celine _call_cutscene")
					# Wait for animation to finish
					# Note: _set_celine_call_completed() should be called from AnimationPlayer method call track
					await anim_player.animation_finished
					# Fallback: if not called from animation, call it here
					if not CheckpointManager.has_checkpoint(CheckpointManager.CheckpointType.CELINE_CALL_COMPLETED):
						_set_celine_call_completed()
				else:
					print("⚠️ No 'celine _call_cutscene' animation found. Available animations: ", anim_player.get_animation_list())
					_set_player_active(true)
			else:
				print("⚠️ AnimationPlayer not found!")
				_set_player_active(true)
			return
		else:
			# Celine call already completed - set post-cutscene positions and enable player
			print("🎬 Celine call already completed - setting post-cutscene positions")
			_set_post_cutscene_positions()
			_set_player_active(true)
			return
	
	# Check if HEAD_POLICE_COMPLETED - play follow_darwin animation (after recollection)
	if CheckpointManager.has_checkpoint(CheckpointManager.CheckpointType.HEAD_POLICE_COMPLETED):
		# Check if follow_darwin already played
		if CheckpointManager.has_checkpoint(CheckpointManager.CheckpointType.FOLLOW_DARWIN_COMPLETED):
			print("🎬 Follow Darwin already completed - setting post-cutscene positions")
			_set_post_cutscene_positions()
			_set_player_active(true)
			return
		
		print("🎬 Head police completed - playing follow_darwin animation")
		# Hide "Tanungin ang pulis" task display if it's still showing
		_hide_task_display()
		# Start cutscene
		cutscene_active = true
		
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
		
		# Play follow_darwin animation
		if anim_player != null:
			if anim_player.has_animation("follow_darwin"):
				print("🎬 Playing follow_darwin animation")
				anim_player.play("follow_darwin")
				# Wait for animation to finish
				# Note: _set_follow_darwin_completed() should be called from AnimationPlayer method call track
				await anim_player.animation_finished
				# Fallback: if not called from animation, call it here
				if not CheckpointManager.has_checkpoint(CheckpointManager.CheckpointType.FOLLOW_DARWIN_COMPLETED):
					_set_follow_darwin_completed()
			else:
				print("⚠️ No 'follow_darwin' animation found. Available animations: ", anim_player.get_animation_list())
				_set_player_active(true)
		else:
			print("⚠️ AnimationPlayer not found!")
			_set_player_active(true)
		return
	
	# Check if lower level cutscene is completed - play recollection animation
	if not CheckpointManager.has_checkpoint(CheckpointManager.CheckpointType.LOWER_LEVEL_CUTSCENE_COMPLETED):
		print("🎬 Lower level cutscene not completed yet - skipping recollection")
		# Celine already hidden above
		_set_player_active(true)
		return
	
	# Check if recollection already played (only trigger once)
	if CheckpointManager.has_checkpoint(CheckpointManager.CheckpointType.RECOLLECTION_COMPLETED):
		print("🎬 Recollection already completed - setting post-cutscene positions")
		# Set post-cutscene positions even on revisit
		_set_post_cutscene_positions()
		_set_player_active(true)
		return
	
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
			# Wait for animation to finish
			# Note: end_cutscene() should be called from AnimationPlayer method call track
			await anim_player.animation_finished
			# Fallback: if not called from animation, call it here
			if not CheckpointManager.has_checkpoint(CheckpointManager.CheckpointType.RECOLLECTION_COMPLETED):
				end_cutscene()
		else:
			print("⚠️ No 'recollection_animation' found. Available animations: ", anim_player.get_animation_list())
			_set_player_active(true)
	else:
		print("⚠️ AnimationPlayer not found!")
		_set_player_active(true)

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
	
	# Position all characters after cutscene
	_set_post_cutscene_positions()
	
	# Update task display
	_show_task_display("Tanungin ang pulis")
	
	# Fade in the screen overlay to return to normal gameplay
	await fade_in(0.5)
	
	# Re-enable player control
	_set_player_active(true)
	print("🎬 Police lobby recollection cutscene ended - returning to normal gameplay.")

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
		
		# If auto_advance is true, wait for typing + 2 second delay, then auto-advance
		if auto_advance:
			var typing_speed: float = 0.01  # From DialogueUI
			var text_length: int = text.length()
			var typing_duration: float = float(text_length) * typing_speed
			
			# Wait for typing to complete
			await get_tree().create_timer(typing_duration).timeout
			
			# Wait additional 2 second delay after typing finishes
			await get_tree().create_timer(2.0).timeout
			
			# Auto-advance by emitting next_pressed signal
			if dui.has_signal("next_pressed"):
				dui.emit_signal("next_pressed")
				print("🎬 Auto-advanced after typing + 2s delay")
		return
	print("⚠️ DialogueUI missing show_dialogue_line().")

func show_line_auto_advance(index: int, delay_after: float = 2.0) -> void:
	"""Show a line with auto-advance: wait for typing to finish + delay, then auto-advance"""
	if index < 0 or index >= dialogue_lines.size():
		push_warning("Dialogue index out of range: " + str(index))
		return
	var line: Dictionary = dialogue_lines[index]
	var _speaker: String = String(line.get("speaker", ""))
	var text: String = String(line.get("text", ""))
	
	# Show the line (typing will start)
	show_line(index, true)  # true = auto_advance mode (hides button)
	
	# Calculate typing duration: text_length * typing_speed (0.01 seconds per character)
	var typing_speed: float = 0.01  # From DialogueUI
	var text_length: int = text.length()
	var typing_duration: float = float(text_length) * typing_speed
	
	# Wait for typing to complete
	await get_tree().create_timer(typing_duration).timeout
	
	# Wait additional delay after typing finishes
	await get_tree().create_timer(delay_after).timeout
	
	# Total time calculation for reference
	var total_time: float = typing_duration + delay_after
	print("🎬 Auto-advance: Text length=", text_length, " chars, Typing=", typing_duration, "s, Delay=", delay_after, "s, Total=", total_time, "s")
	
	# Auto-advance by emitting next_pressed signal
	var dui: Node = get_node_or_null("/root/DialogueUI")
	if dui and dui.has_signal("next_pressed"):
		dui.emit_signal("next_pressed")

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

func _set_post_cutscene_positions() -> void:
	"""Set all characters to their post-cutscene positions"""
	var root_scene := get_tree().current_scene
	if root_scene == null:
		print("⚠️ Cannot set post-cutscene positions - no root scene")
		return
	
	print("🎬 Setting post-cutscene positions...")
	
	# Hide Celine and disable collision
	var celine := _find_celine()
	if celine != null:
		if celine is CanvasItem:
			(celine as CanvasItem).visible = false
			(celine as CanvasItem).modulate.a = 0.0
		_set_celine_collision_enabled(false)
		print("🎬 Celine hidden and collision disabled")
	else:
		print("⚠️ Celine not found")
	
	# Find and position erwin
	var erwin := _find_character_by_name("erwin")
	if erwin == null:
		erwin = _find_character_by_name("Erwin")
	if erwin == null:
		erwin = _find_character_by_name("Erwin Boy Trip")
	if erwin != null and erwin is Node2D:
		# Ensure visibility first
		if erwin is CanvasItem:
			(erwin as CanvasItem).visible = true
		(erwin as Node2D).global_position = Vector2(480.0, 360.0)
		_set_character_animation(erwin, "idle_back")
		print("🎬 erwin positioned at (480.0, 360.0) with idle_back")
	else:
		print("⚠️ erwin not found")
	
	# Find and position station_guard
	var station_guard := _find_character_by_name("station_guard")
	if station_guard != null and station_guard is Node2D:
		# Ensure visibility first
		if station_guard is CanvasItem:
			(station_guard as CanvasItem).visible = true
		(station_guard as Node2D).global_position = Vector2(672.0, 464.0)
		_set_character_animation(station_guard, "idle_right")
		print("🎬 station_guard positioned at (672.0, 464.0) with idle_right")
	else:
		print("⚠️ station_guard not found")
	
	# Find and position station_guard_2
	var station_guard_2 := _find_character_by_name("station_guard_2")
	if station_guard_2 != null and station_guard_2 is Node2D:
		# Ensure visibility first
		if station_guard_2 is CanvasItem:
			(station_guard_2 as CanvasItem).visible = true
		(station_guard_2 as Node2D).global_position = Vector2(672.0, 496.0)
		_set_character_animation(station_guard_2, "idle_right")
		print("🎬 station_guard_2 positioned at (672.0, 496.0) with idle_right")
	else:
		print("⚠️ station_guard_2 not found")
	
	# Position PlayerM (Miguel) at (944.0, 360.0) after recollection cutscene
	if player_node == null:
		player_node = _find_player()
	if player_node != null and player_node is Node2D:
		if player_node is CanvasItem:
			(player_node as CanvasItem).visible = true
		(player_node as Node2D).global_position = Vector2(944.0, 360.0)
		print("🎬 PlayerM positioned at (944.0, 360.0)")
	else:
		print("⚠️ PlayerM not found")
	
	print("🎬 Post-cutscene positioning complete")

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
		print("🎬 Set animation '", animation_name, "' on ", character.name)

func _set_follow_darwin_completed() -> void:
	"""Set the FOLLOW_DARWIN_COMPLETED checkpoint after animation completes - callable from AnimationPlayer"""
	# Prevent duplicate checkpoint setting
	if CheckpointManager.has_checkpoint(CheckpointManager.CheckpointType.FOLLOW_DARWIN_COMPLETED):
		print("🎬 FOLLOW_DARWIN_COMPLETED already set, skipping")
		return
	
	# Hide dialogue UI if visible
	_hide_dialogue_ui()
	
	# Set checkpoint
	CheckpointManager.set_checkpoint(CheckpointManager.CheckpointType.FOLLOW_DARWIN_COMPLETED)
	print("🎬 Follow Darwin completed, checkpoint set.")
	
	# Reposition player to dedicated follow_darwin spawn (not the recollection spawn)
	if player_node == null:
		player_node = _find_player()
	if player_node != null and player_node is Node2D:
		if player_node is CanvasItem:
			(player_node as CanvasItem).visible = true
		(player_node as Node2D).global_position = FOLLOW_DARWIN_SPAWN
		print("🎬 PlayerM positioned at (", FOLLOW_DARWIN_SPAWN.x, ", ", FOLLOW_DARWIN_SPAWN.y, ") after follow_darwin")
	
	# Reset DialogueUI cutscene mode
	var dui: Node = get_node_or_null("/root/DialogueUI")
	if dui and dui.has_method("set_cutscene_mode"):
		dui.set_cutscene_mode(false)
		print("🎬 Reset DialogueUI cutscene_mode to false")
	
	# Cleanup
	cutscene_active = false
	_set_player_active(true)

func _set_celine_call_completed() -> void:
	"""Set the CELINE_CALL_COMPLETED checkpoint after animation completes - callable from AnimationPlayer"""
	# Prevent duplicate checkpoint setting
	if CheckpointManager.has_checkpoint(CheckpointManager.CheckpointType.CELINE_CALL_COMPLETED):
		print("🎬 CELINE_CALL_COMPLETED already set, skipping")
		return
	
	# Hide dialogue UI first
	_hide_dialogue_ui()
	
	# Set checkpoint
	CheckpointManager.set_checkpoint(CheckpointManager.CheckpointType.CELINE_CALL_COMPLETED)
	print("🎬 Celine call completed, checkpoint set.")
	
	# Update task display to "Pumunta sa baranggay hall"
	_show_task_display("Pumunta sa baranggay hall")
	
	# Reset DialogueUI cutscene mode FIRST
	var dui: Node = get_node_or_null("/root/DialogueUI")
	if dui and dui.has_method("set_cutscene_mode"):
		dui.set_cutscene_mode(false)
		print("🎬 Reset DialogueUI cutscene_mode to false")
	
	# Mark cutscene as inactive FIRST - this stops _process() from disabling movement
	cutscene_active = false
	print("🎬 cutscene_active set to FALSE - _process() will stop disabling movement")
	
	# Re-enable player movement - fully restore all processing
	if player_node == null:
		player_node = _find_player()
	
	if player_node != null:
		print("🔧 Celine Call: Restoring player movement...")
		# Re-enable input/physics processing FIRST
		if player_node.has_method("set_process_input"):
			player_node.set_process_input(true)
			print("   ✅ Enabled set_process_input(true)")
		if player_node.has_method("set_physics_process"):
			player_node.set_physics_process(true)
			print("   ✅ Enabled set_physics_process(true)")
		
		# Re-enable movement control - call enable_movement() which sets control_enabled
		if player_node.has_method("enable_movement"):
			player_node.enable_movement()
			print("   ✅ Called enable_movement()")
		
		# Force set control_enabled to true - make absolutely sure
		if "control_enabled" in player_node:
			player_node.control_enabled = true
			print("   ✅ Force set control_enabled = true")
		
		# Wait a frame to ensure everything is applied
		await get_tree().process_frame
		
		# Final check
		var final_control = player_node.get("control_enabled") if "control_enabled" in player_node else "N/A"
		var final_mode = player_node.get("process_mode") if "process_mode" in player_node else "N/A"
		print("   Final state - control_enabled: ", final_control, ", process_mode: ", final_mode)
		print("🎬 Celine Call: Player movement fully restored - YOU SHOULD BE ABLE TO MOVE NOW!")
	else:
		print("⚠️ Celine Call: player_node is null! Cannot restore movement!")
		_set_player_active(true)  # Fallback

func play_phone_ringtone(ring_count: int = 3) -> float:
	"""Play phone ringtone using VoiceBlipManager
	Returns the total duration of the ringtone sequence
	"""
	var voice_blip_manager = get_node_or_null("/root/VoiceBlipManager")
	if voice_blip_manager and voice_blip_manager.has_method("play_ringtone"):
		print("📞 Playing phone ringtone...")
		var duration = await voice_blip_manager.play_ringtone(ring_count, 0.2, 0.3)
		return duration
	else:
		print("⚠️ VoiceBlipManager not found or missing play_ringtone method")
		return 0.0

func call_ringtone(ring_count: int = 3) -> void:
	"""Call ringtone from AnimationPlayer - non-blocking method call
	This method can be called from AnimationPlayer's method call track
	"""
	print("📞 AnimationPlayer called ringtone with ", ring_count, " rings")
	# Use call_deferred to start the async function without blocking
	call_deferred("_start_ringtone_async", ring_count)

func _start_ringtone_async(ring_count: int = 3) -> void:
	"""Internal async function to start the ringtone"""
	var duration = await play_phone_ringtone(ring_count)
	print("📞 Ringtone duration was: ", duration, " seconds")

# ---- Phone Animation Helpers (callable from AnimationPlayer) ----
func stop_phone_in_at_last_frame() -> void:
	"""Stop phone_in animation at last frame - callable from AnimationPlayer"""
	if player_node == null:
		player_node = _find_player()
	if player_node == null:
		print("⚠️ Cannot stop phone_in - player not found")
		return
	
	var anim_sprite: AnimatedSprite2D = player_node.get_node_or_null("AnimatedSprite2D")
	if anim_sprite == null:
		print("⚠️ Cannot stop phone_in - AnimatedSprite2D not found on player")
		return
	
	# Wait for animation to finish if it's playing
	if anim_sprite.is_playing() and anim_sprite.animation == "phone_in":
		# Wait for animation to complete
		await anim_sprite.animation_finished
	
	# Get the sprite frames resource
	var sprite_frames = anim_sprite.sprite_frames
	if sprite_frames == null:
		print("⚠️ Cannot stop phone_in - SpriteFrames not found")
		return
	
	# Get the phone_in animation
	if not sprite_frames.has_animation("phone_in"):
		print("⚠️ Cannot stop phone_in - animation 'phone_in' not found")
		return
	
	# Get the last frame index
	var frame_count = sprite_frames.get_frame_count("phone_in")
	if frame_count == 0:
		print("⚠️ Cannot stop phone_in - animation has no frames")
		return
	
	# Play the animation and seek to last frame
	anim_sprite.play("phone_in")
	# Wait a frame to ensure animation starts
	await get_tree().process_frame
	# Seek to the last frame (frame_count - 1, since it's 0-indexed)
	anim_sprite.frame = frame_count - 1
	# Stop the animation so it stays on the last frame
	anim_sprite.stop()
	print("📞 phone_in stopped at last frame (frame ", frame_count - 1, ")")

func stop_phone_out_at_last_frame() -> void:
	"""Stop phone_out animation at last frame - callable from AnimationPlayer"""
	if player_node == null:
		player_node = _find_player()
	if player_node == null:
		print("⚠️ Cannot stop phone_out - player not found")
		return
	
	var anim_sprite: AnimatedSprite2D = player_node.get_node_or_null("AnimatedSprite2D")
	if anim_sprite == null:
		print("⚠️ Cannot stop phone_out - AnimatedSprite2D not found on player")
		return
	
	# Wait for animation to finish if it's playing
	if anim_sprite.is_playing() and anim_sprite.animation == "phone_out":
		# Wait for animation to complete
		await anim_sprite.animation_finished
	
	# Get the sprite frames resource
	var sprite_frames = anim_sprite.sprite_frames
	if sprite_frames == null:
		print("⚠️ Cannot stop phone_out - SpriteFrames not found")
		return
	
	# Get the phone_out animation
	if not sprite_frames.has_animation("phone_out"):
		print("⚠️ Cannot stop phone_out - animation 'phone_out' not found")
		return
	
	# Get the last frame index
	var frame_count = sprite_frames.get_frame_count("phone_out")
	if frame_count == 0:
		print("⚠️ Cannot stop phone_out - animation has no frames")
		return
	
	# Play the animation and seek to last frame
	anim_sprite.play("phone_out")
	# Wait a frame to ensure animation starts
	await get_tree().process_frame
	# Seek to the last frame (frame_count - 1, since it's 0-indexed)
	anim_sprite.frame = frame_count - 1
	# Stop the animation so it stays on the last frame
	anim_sprite.stop()
	print("📞 phone_out stopped at last frame (frame ", frame_count - 1, ")")

# ---- Celine Call Dialogue Methods (callable from AnimationPlayer) ----
func show_celine_call_line_0() -> void:
	"""Show first line of celine call dialogue - callable from AnimationPlayer"""
	print("📞 show_celine_call_line_0 called - celine_call_dialogue size: ", celine_call_dialogue.size())
	if celine_call_dialogue.size() > 0:
		show_line_from_array(celine_call_dialogue, 0)
	else:
		print("⚠️ Celine call dialogue not loaded - attempting to reload...")
		_load_celine_call_dialogue()
		if celine_call_dialogue.size() > 0:
			show_line_from_array(celine_call_dialogue, 0)
		else:
			print("⚠️ Celine call dialogue still not loaded after reload attempt")

func show_celine_call_line_1() -> void:
	"""Show second line of celine call dialogue - callable from AnimationPlayer"""
	if celine_call_dialogue.size() > 1:
		show_line_from_array(celine_call_dialogue, 1)
	else:
		print("⚠️ Celine call dialogue line 1 not available")

func show_celine_call_line_2() -> void:
	"""Show third line of celine call dialogue - callable from AnimationPlayer"""
	if celine_call_dialogue.size() > 2:
		show_line_from_array(celine_call_dialogue, 2)
	else:
		print("⚠️ Celine call dialogue line 2 not available")

func show_celine_call_line_3() -> void:
	"""Show fourth line of celine call dialogue - callable from AnimationPlayer"""
	if celine_call_dialogue.size() > 3:
		show_line_from_array(celine_call_dialogue, 3)
	else:
		print("⚠️ Celine call dialogue line 3 not available")

func show_celine_call_line_4() -> void:
	"""Show fifth line of celine call dialogue - callable from AnimationPlayer"""
	if celine_call_dialogue.size() > 4:
		show_line_from_array(celine_call_dialogue, 4)
	else:
		print("⚠️ Celine call dialogue line 4 not available")

func show_line_from_array(dialogue_array: Array[Dictionary], index: int, auto_advance: bool = true) -> void:
	"""Helper function to show a line from any dialogue array with auto-advance"""
	if index < 0 or index >= dialogue_array.size():
		push_warning("Dialogue index out of range: " + str(index))
		return
	var line: Dictionary = dialogue_array[index]
	var speaker: String = String(line.get("speaker", ""))
	var text: String = String(line.get("text", ""))
	
	var dui: Node = get_node_or_null("/root/DialogueUI")
	if dui == null:
		print("⚠️ DialogueUI autoload not found.")
		return
	if dui.has_method("set_cutscene_mode"):
		dui.set_cutscene_mode(true)
	if dui.has_method("show_dialogue_line"):
		dui.show_dialogue_line(speaker, text, auto_advance)
		
		# If auto_advance is true, wait for typing + 2 second delay, then auto-advance
		if auto_advance:
			var typing_speed: float = 0.01  # From DialogueUI
			var text_length: int = text.length()
			var typing_duration: float = float(text_length) * typing_speed
			
			# Wait for typing to complete
			await get_tree().create_timer(typing_duration).timeout
			
			# Wait additional 2 second delay after typing finishes
			await get_tree().create_timer(2.0).timeout
			
			# Auto-advance by emitting next_pressed signal
			if dui.has_signal("next_pressed"):
				dui.emit_signal("next_pressed")
				print("🎬 Auto-advanced celine call dialogue after typing + 2s delay")
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

func _load_celine_call_dialogue() -> void:
	"""Load celine_call dialogue from JSON file"""
	var path := "res://data/dialogues/celine_call_dialogue.json"
	if not ResourceLoader.exists(path):
		print("⚠️ Celine call dialogue file not found: ", path)
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		print("⚠️ Cannot open celine call dialogue file: ", path)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		print("⚠️ Invalid celine call dialogue JSON format")
		return
	var section: Variant = (parsed as Dictionary).get("celine_call", {})
	if typeof(section) != TYPE_DICTIONARY:
		print("⚠️ Missing 'celine_call' section in dialogue file")
		return
	var arr: Variant = (section as Dictionary).get("dialogue_lines", [])
	if typeof(arr) == TYPE_ARRAY:
		celine_call_dialogue.clear()
		for item in (arr as Array):
			if typeof(item) == TYPE_DICTIONARY:
				celine_call_dialogue.append(item as Dictionary)
		print("📞 Loaded ", celine_call_dialogue.size(), " celine call dialogue lines from celine_call_dialogue.json")
		# Debug: print first line to verify
		if celine_call_dialogue.size() > 0:
			var first_line = celine_call_dialogue[0]
			print("📞 First line - Speaker: ", first_line.get("speaker", ""), ", Text: ", first_line.get("text", ""))
	else:
		print("⚠️ No dialogue_lines array found in celine_call section")

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
		print("⚠️ No Camera2D found for zoom")
		return
	
	# Store original zoom level before zooming
	var original_zoom: Vector2 = cam.zoom
	print("🎬 Camera zoom: Starting zoom. Original zoom = ", original_zoom)
	
	# Zoom in to target_zoom smoothly
	var target_zoom_vec := Vector2(target_zoom, target_zoom)
	var tween_in := create_tween()
	tween_in.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)  # Smooth cubic easing
	tween_in.tween_property(cam, "zoom", target_zoom_vec, duration)
	await tween_in.finished
	print("🎬 Camera zoom: Zoomed in to ", target_zoom_vec)
	
	# Hold at zoomed in level for specified duration
	await get_tree().create_timer(hold_duration).timeout
	
	# Smoothly zoom back to original zoom level
	var tween_out := create_tween()
	tween_out.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)  # Smooth cubic easing for return
	tween_out.tween_property(cam, "zoom", original_zoom, duration)
	await tween_out.finished
	print("🎬 Camera zoom: Smoothly zoomed back to original zoom = ", original_zoom)

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
func _hide_task_display() -> void:
	"""Hide the task display"""
	var task_display: Node = get_node_or_null("/root/TaskDisplay")
	if task_display == null:
		# Try to find it in scene tree
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
