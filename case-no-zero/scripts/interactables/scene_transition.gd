extends Area2D

var is_transitioning: bool = false
var fade_duration: float = 0.25  # Faster fade since we check scene readiness
var player_reference: Node = null

func _ready():
	# Connect the body_entered signal to handle player entering the area
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	# Check if the body is the player and we're not already transitioning
	if body.name == "PlayerM" and not is_transitioning:
		var target_scene_path = _get_target_scene_path_from_area_name()
		if target_scene_path != "":
			# Check if player has access to barangay hall
			if not _check_barangay_hall_access(target_scene_path):
				# Access denied - no debug spam
				return
			
			# Check if we're completing a task before changing scenes
			_check_and_complete_task(target_scene_path)
			
			# Store player reference and disable movement during transition
			player_reference = body
			if body.has_method("disable_movement"):
				body.disable_movement()
			
			# Set entry point information for the target scene
			_set_entry_point_for_target(target_scene_path)
			
			_start_transition(target_scene_path)

func _set_entry_point_for_target(target_scene_path: String):
	"""Set the entry point information in SpawnManager"""
	var current_scene = get_tree().current_scene
	if not current_scene:
		print("⚠️ Scene Transition: current_scene is null, cannot set entry point")
		return
	
	var current_scene_name = current_scene.scene_file_path.get_file().get_basename()
	var target_scene_name = target_scene_path.get_file().get_basename()
	
	# Map area names to entry point names
	var entry_point_map = {
		"Area2D_lower_level": "lower_level",
		"Area2D_head_police": "head_police", 
		"Area2D_security_server": "security_server",
		"Area2D_police_lobby": "from_lower_level_station",
		"Area2D_police_lobby_from_head": "from_head_police_room",
		"Area2D_police_lobby_to_police_station": "police_station",
		"Area2D_police_lobby_from_security_server": "security_server",
		"Area2D_barangay_hall_second_floor": "barangay_hall_second_floor",
		"Area2D_barangay_hall_return": "from_barangay_hall2nd",
		"Area2D_exterior_police": "police_lobby",
		"Area2D_police_to_lobby": "police_station",
		"Area2D_firestation": "firestation",
		"Area2D_firestation_1st_floor": "firestation_1st_floor",
		"Area2D_hotel_hospital_to_hospital": "from_exterior_hospital_lobby",
		"Area2D_hospital_2nd_floor": "hospital_2nd_floor",
		"Area2D_hospital_2nd_to_lobby": "hospital_2nd_floor",
		"Area2D_hospital_lobby_to_hotel_hospital": "hospital_lobby",
		"Area2D_hotel_hospital_to_hotel_lobby": "from_hotel_hospital",
		"Area2D_to_hotel_hospital": "hotel_lobby",
		"Area2D_to_2nd_floor_hospital": "hotel_lobby",
		"Area2D_2nd_floor_to_hotel_lobby": "hotel_2nd_floor",
		"Area2D_to_terminal_market": "hardware_store",
		"Area2D_to_hardware": "terminal_market",
		"Area2D_to_market": "terminal_market",
		"Area2D_terminal_market": "market",
		"Area2D_barangay_court": "barangay_hall",
		"Area2D_interior_barangay_hall": "barangay_court",
		"Area2D_morgue_interior": "apartment_morgue",
		"Area2D_morgue_exterior": "morgue",
		"Area2D_bedroom_interior": "Area2D_bedroom_interior",
		"Area2D_courtroom": "courtroom",
		"Area2D_to_courtroom": "courtroom",
		"Area2D_apartment_exterior": "apartment_exterior",
		"Area2D_lobby_to_exterior_apartment" :"lobby_to_exterior",
		# Exterior area transitions
		"from_barangay_to_camp": "barangay_to_camp",
		"from_barangay_to_market": "barangay_to_market",
		"from_barangay_to_police_station": "barangay_to_police_station",
		"from_morgue_to_hospital": "morgue_to_hospital",
		"from_morgue_to_camp": "morgue_to_camp",
		"from_morgue_to_police_station": "morgue_to_police_station",
		"from_camp_to_barangay": "camp_to_barangay",
		"from_camp_to_morgue": "camp_to_morgue",
		"from_hospital_to_morgue": "hospital_to_morgue",
		"from_hospital_to_police_station": "hospital_to_police_station",
		"from_hospital_to_market": "hospital_to_market",
		"from_police_to_hospital": "police_to_hospital",
		"from_police_to_baranggay": "police_to_baranggay",
		"from_police_to_morgue": "police_to_morgue",
		"from_police_to_market": "police_to_market",
		"from_market_to_baranggay": "market_to_baranggay",
		"from_market_to_hospital": "market_to_hospital",
		"from_market_to_police": "market_to_police",
		"Area2D_exterior_to_lobby":"hatdog",
		"from_office_main_to_office_balcony": "from_office_main_to_office_balcony",
		"from_office_main_to_office_rooftop" : "from_office_main_to_office_rooftop",
		"from_office_main_to_office_attorney_room" : "from_office_main_to_office_attorney_room",
		"from_office_main_to_office_lobby" : "from_office_main_to_office_lobby",
		"office_balcony_to_office_main": "office_balcony_to_office_main",
		"office_rooftop_to_office_main" : "office_rooftop_to_office_main",
		"office_attorney_room_to_office_main": "office_attorney_room_to_office_main",
		"from_office_lobby_to_office_main" : "from_office_lobby_to_office_main",
		"from_office_lobby_to_apartment_morgue":"from_office_lobby_to_apartment_morgue",
		"from_apartment_morgue_to_office_lobby":"from_apartment_morgue_to_office_lobby"
		
	}
	
	var _entry_point = entry_point_map.get(name, "unknown")
	if has_node("/root/SpawnManager"):
		var spawn_manager = get_node("/root/SpawnManager")
		spawn_manager.set_entry_point(current_scene_name, _entry_point)
		# print("🔄 Scene Transition: Set entry point from ", current_scene_name, " to ", target_scene_name, " via ", _entry_point)
	else:
		print("⚠️ Scene Transition: SpawnManager not found!")

func _get_target_scene_path_from_area_name() -> String:
	# Get the scene path based on the Area2D's name
	var area_name = name
	match area_name:
		"Area2D_police_lobby_from_head":
			return "res://scenes/environments/Police Station/police_lobby.tscn"
		"Area2D_lower_level":
			return "res://scenes/environments/police_station/lower_level_station.tscn"
		"Area2D_head_police":
			return "res://scenes/environments/Police Station/head_police_room.tscn"
		"Area2D_security_server":
			return "res://scenes/environments/Police Station/security_server.tscn"
		"Area2D_police_lobby":
			return "res://scenes/environments/Police Station/police_lobby.tscn"
		"Area2D_police_lobby_to_police_station":
			return "res://scenes/environments/exterior/police_station.tscn"
		"Area2D_barangay_hall_second_floor":
			return "res://scenes/environments/barangay hall/barangay_hall_second_floor.tscn"
		"Area2D_barangay_hall_return":
			return "res://scenes/environments/barangay hall/barangay_hall.tscn"
		"Area2D_exterior_police":
			return "res://scenes/environments/Police Station/police_lobby.tscn"
		"Area2D_police_lobby_from_security_server":
			return "res://scenes/environments/Police Station/police_lobby.tscn"
		"Area2D_police_to_lobby":
			return "res://scenes/environments/police_station/police_lobby.tscn"
		# Hotel and Hospital Area2D transitions
		"Area2D_firestation":
			return "res://scenes/environments/fire_station/fire_station_1st_floor.tscn"
		"Area2D_firestation_1st_floor":
			return "res://scenes/environments/fire_station/fire_station_1st_floor.tscn"
		"Area2D_hotel_hospital_to_hospital":
			return "res://scenes/environments/hospital/hospital_lobby.tscn"
		"Area2D_hospital_2nd_floor":
			return "res://scenes/environments/hospital/hospital_2nd_floor.tscn"
		"Area2D_hospital_2nd_to_lobby":
			return "res://scenes/environments/hospital/hospital_lobby.tscn"
		"Area2D_hospital_lobby_to_hotel_hospital":
			return "res://scenes/environments/exterior/hotel_hospital.tscn"
		"Area2D_hotel_lobby_to_hotel_hospital":
			return "res://scenes/environments/exterior/hotel_hospital.tscn"
		"Area2D_hotel_hospital_to_hotel":
			return "res://scenes/environments/hotel/hotel_lobby.tscn"
		"Area2D_hotel_hospital_to_hotel_lobby":
			return "res://scenes/environments/hotel/hotel_lobby.tscn"
		"Area2D_to_hotel_hospital":
			return "res://scenes/environments/exterior/hotel_hospital.tscn"
		"Area2D_to_2nd_floor_hospital":
			return "res://scenes/environments/hotel/hotel_2nd_floor.tscn"
		"Area2D_2nd_floor_to_hotel_lobby":
			return "res://scenes/environments/hotel/hotel_lobby.tscn"
		"Area2D_to_terminal_market":
			return "res://scenes/environments/exterior/terminal_market.tscn"
		"Area2D_to_hardware":
			return "res://scenes/environments/hardware/hardware_store.tscn"
		"Area2D_to_market":
			return "res://scenes/environments/market/market.tscn"
		"Area2D_terminal_market":
			return "res://scenes/environments/exterior/terminal_market.tscn"
		"Area2D_barangay_court":
			return "res://scenes/environments/exterior/baranggay_court.tscn"
		"Area2D_interior_barangay_hall":
			return "res://scenes/environments/barangay hall/barangay_hall.tscn"
		"Area2D_morgue_interior":
			return "res://scenes/environments/funeral home/morgue.tscn"
		"Area2D_morgue_exterior":
			return "res://scenes/environments/exterior/apartment_morgue.tscn"
		"Area2D_courtroom":
			return "res://scenes/environments/Courtroom/courtroom.tscn"
		"Area2D_to_courtroom":
			return "res://scenes/environments/Courtroom/courtroom.tscn"
		# New Area2D transitions from apartment_morgue
		"from_morgue_to_baranggay":
			return "res://scenes/environments/barangay hall/baranggay_court.tscn"
		"from_morgue_to_morgue":
			return "res://scenes/environments/funeral home/morgue.tscn"
		"from_morgue_to_hospital":
			return "res://scenes/environments/exterior/hotel_hospital.tscn"
		"from_morgue_to_market":
			return "res://scenes/environments/exterior/terminal_market.tscn"
		"Area2D_bedroom_interior":
			return "res://scenes/cutscenes/bedroomScene.tscn"
		"Area2D_exterior_to_lobby":
			return "res://scenes/environments/apartments/apartment_lobby.tscn"
		"Area2D_apartment_exterior":
			return "res://scenes/environments/apartments/apartment_lobby.tscn"
		# Exterior area transitions
		"from_barangay_to_camp":
			return "res://scenes/environments/exterior/camp.tscn"
		"from_barangay_to_market":
			return "res://scenes/environments/exterior/terminal_market.tscn"
		"from_barangay_to_police_station":
			return "res://scenes/environments/exterior/police_station.tscn"
		"from_morgue_to_hospital":
			return "res://scenes/environments/exterior/hotel_hospital.tscn"
		"from_morgue_to_camp":
			return "res://scenes/environments/exterior/camp.tscn"
		"from_morgue_to_police_station":
			return "res://scenes/environments/exterior/police_station.tscn"
		"from_camp_to_barangay":
			return "res://scenes/environments/exterior/baranggay_court.tscn"
		"from_camp_to_morgue":
			return "res://scenes/environments/exterior/apartment_morgue.tscn"
		"from_hospital_to_morgue":
			return "res://scenes/environments/exterior/apartment_morgue.tscn"
		"from_hospital_to_police_station":
			return "res://scenes/environments/exterior/police_station.tscn"
		"from_hospital_to_market":
			return "res://scenes/environments/exterior/terminal_market.tscn"
		"from_police_to_hospital":
			return "res://scenes/environments/exterior/hotel_hospital.tscn"
		"from_police_to_baranggay":
			return "res://scenes/environments/exterior/baranggay_court.tscn"
		"from_police_to_morgue":
			return "res://scenes/environments/exterior/apartment_morgue.tscn"
		"from_police_to_market":
			return "res://scenes/environments/exterior/terminal_market.tscn"
		"from_market_to_baranggay":
			return "res://scenes/environments/exterior/baranggay_court.tscn"
		"from_market_to_hospital":
			return "res://scenes/environments/exterior/hotel_hospital.tscn"
		"from_market_to_police":
			return "res://scenes/environments/exterior/police_station.tscn"
		# New Area2D transitions from barangay_court
		"from_barangay_to_camp":
			return "res://scenes/environments/exterior/camp.tscn"
		"from_barangay_to_market":
			return "res://scenes/environments/exterior/terminal_market.tscn"
		"Area2D_lobby_to_exterior_apartment" :
			return "res://scenes/environments/exterior/terminal_market.tscn"
		"from_barangay_to_police_station":
			return "res://scenes/environments/exterior/police_station.tscn"
		"from_camp_to_barangay":
			return "res://scenes/environments/barangay hall/baranggay_court.tscn"
		"from_camp_to_morgue":
			return "res://scenes/environments/exterior/apartment_morgue.tscn"
		"from_hospital_to_morgue":
			return "res://scenes/environments/exterior/apartment_morgue.tscn"
		"from_hospital_to_police_station":
			return "res://scenes/environments/exterior/police_station.tscn"
		"from_hospital_to_market":
			return "res://scenes/environments/exterior/terminal_market.tscn"
		"from_police_to_hospital":
			return "res://scenes/environments/exterior/hotel_hospital.tscn"
		"from_police_to_camp":
			return "res://scenes/environments/exterior/camp.tscn"
		"from_police_to_police_station":
			return "res://scenes/environments/Police Station/police_lobby.tscn"
		"from_market_to_baranggay":
			return "res://scenes/environments/barangay hall/baranggay_court.tscn"
		"from_market_to_hospital":
			return "res://scenes/environments/exterior/hotel_hospital.tscn"
		"from_market_to_police":
			return "res://scenes/environments/exterior/police_station.tscn"
		"office_balcony_to_office_main":
			return "res://scenes/environments/office/office_main.tscn"
		"from_office_main_to_office_balcony":
			return "res://scenes/environments/office/office_balcony.tscn"
		"from_office_main_to_office_rooftop":
			return "res://scenes/environments/office/office rooftop.tscn"
		"office_rooftop_to_office_main":
			return "res://scenes/environments/office/office_main.tscn"
		"from_office_main_to_office_attorney_room":
			return "res://scenes/environments/office/office_attorney_room.tscn"
		"office_attorney_room_to_office_main":
			return "res://scenes/environments/office/office_main.tscn"
		"from_office_main_to_office_lobby":
			return "res://scenes/environments/office/office_lobby.tscn"
		"from_office_lobby_to_office_main":
			return "res://scenes/environments/office/office_main.tscn"
		"from_office_lobby_to_apartment_morgue":
			return "res://scenes/environments/exterior/apartment_morgue.tscn"
		"from_apartment_morgue_to_office_lobby":
			return "res://scenes/environments/office/office_lobby.tscn"
		_:
			return ""

func _check_and_complete_task(target_scene_path: String):
	"""Check if we're completing a task before changing scenes"""
	if TaskManager:
		print("🔍 DEBUG: TaskManager found in scene transition")
		if TaskManager.is_task_active():
			var current_target = TaskManager.get_current_task_scene_target()
			var target_scene_name = target_scene_path.get_file().get_basename()
			print("🔍 DEBUG: Active task target:", current_target)
			print("🔍 DEBUG: Scene transition target:", target_scene_name)
			
			if target_scene_name.to_lower().contains(current_target.to_lower()):
				print("✅ DEBUG: Target matches! Completing task before scene change")
				TaskManager.complete_current_task()
			else:
				print("⚠️ DEBUG: Target doesn't match - not completing task")
		else:
			print("⚠️ DEBUG: No active task")
	else:
		print("⚠️ DEBUG: TaskManager not found")

func _check_barangay_hall_access(target_scene_path: String) -> bool:
	"""Check if player has access to barangay hall"""
	var scene_name = target_scene_path.get_file().get_basename()
	
	# Barangay hall is ALWAYS accessible for exploration
	# The cutscene only triggers if police lobby is completed (handled in barangay_hall_manager.gd)
	if scene_name == "barangay_hall" or scene_name == "barangay_hall_second_floor":
		return true  # Always allow access - cutscene logic is in the manager script
	
	# Allow access to all other scenes
	return true

func _start_transition(target_scene_path: String):
	is_transitioning = true
	
	# Create full-screen fade overlay on the CanvasLayer to be above everything
	var canvas_layer = CanvasLayer.new()
	var fade_rect = ColorRect.new()
	fade_rect.color = Color.BLACK
	fade_rect.color.a = 0.0
	fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas_layer.add_child(fade_rect)
	
	var current_scene = get_tree().current_scene
	if current_scene:
		current_scene.add_child(canvas_layer)
	else:
		print("⚠️ Scene Transition: current_scene is null, cannot add canvas layer")
		return
	
	# Move canvas layer to be on top of everything
	canvas_layer.layer = 100
	
	# Smooth fade in to cover entire scene
	var tween = create_tween()
	tween.tween_property(fade_rect, "color:a", 1.0, fade_duration)
	
	# Wait for fade in, then change scene
	await tween.finished
	
	# Small delay to ensure fade is complete before scene change
	await get_tree().create_timer(0.05).timeout
	
	# Use preloaded scenes for optimal performance in exported game
	var result = OK
	if ScenePreloader and ScenePreloader.is_scene_preloaded(target_scene_path):
		print("🚀 Using preloaded scene: ", target_scene_path.get_file())
		var preloaded_scene = ScenePreloader.get_preloaded_scene(target_scene_path)
		result = get_tree().change_scene_to_packed(preloaded_scene)
	else:
		print("📁 Loading scene from file: ", target_scene_path.get_file())
		result = get_tree().change_scene_to_file(target_scene_path)
	
	if result != OK:
		print("❌ Failed to change scene to: ", target_scene_path)
		print("❌ Scene transition error - possible file path issue or scene corruption")
		is_transitioning = false
		# If scene change failed, fade out and reset state
		_fade_out_and_cleanup(canvas_layer)
		# Reset player reference to prevent memory leaks
		if player_reference:
			player_reference = null
	else:
		# Scene change successful, canvas layer will be destroyed with old scene
		pass

func _fade_out_and_cleanup(canvas_layer: CanvasLayer):
	# Fade out and clean up if scene change failed
	var fade_rect = canvas_layer.get_child(0) as ColorRect
	var tween = create_tween()
	tween.tween_property(fade_rect, "color:a", 0.0, fade_duration)
	await tween.finished
	canvas_layer.queue_free()
	is_transitioning = false	
	# Re-enable player movement if scene change failed
	if player_reference and player_reference.has_method("enable_movement"):
		player_reference.enable_movement()
	player_reference = null
