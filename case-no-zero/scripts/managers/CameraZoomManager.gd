extends Node

# CameraZoomManager - Autoload for managing dynamic camera zoom based on scene type

signal zoom_changed(new_zoom: float)

# Zoom settings for different scene types
var zoom_settings: Dictionary = {
	"interior": 2.0,      # Default zoom for interior scenes
	"exterior": 1.5,     # Default zoom for exterior scenes  
	"map": 1.5,          # Specific zoom for map scenes
	"bedroom": 2.0,      # Bedroom scene (interior)
	"police_lobby": 2.0, # Police lobby (interior)
	"barangay_hall": 2.0, # Barangay hall (interior)
	"lower_level": 2.0,  # Lower level station (interior)
	"police_station": 1.0, # Police station exterior (zoom 1.0)
	"hotel_hospital": 1.0, # Hotel hospital exterior (zoom 1.0)
	"camp": 1.0,           # Camp scene (zoom 1.0)
	"terminal_market": 1.0, # Terminal market (zoom 1.0)
	"market": 2.0,         # Market scene (zoom 2.0)
	"hardware_store": 2.0  # Hardware store (zoom 2.0)
}

# Current zoom level
var current_zoom: float = 2.0
var player_camera: Camera2D = null
var last_scene_path: String = ""

func _ready():
	print("📷 CameraZoomManager: Ready")
	# Connect to tree_changed signal to detect scene changes
	get_tree().tree_changed.connect(_on_tree_changed)
	# Find the player camera when the scene changes
	call_deferred("find_player_camera")

func find_player_camera():
	"""Find the player's camera in the current scene"""
	# Wait a frame to ensure the scene is fully loaded
	await get_tree().process_frame
	
	# Check if current_scene exists
	if not get_tree().current_scene:
		print("📷 CameraZoomManager: No current scene in find_player_camera")
		return
	
	var scene_root = get_tree().current_scene
	if scene_root:
		var player = scene_root.get_node_or_null("PlayerM")
		if not player:
			player = scene_root.get_node_or_null("Player")
		
		if player:
			player_camera = player.get_node_or_null("Camera2D")
			if player_camera:
				print("📷 CameraZoomManager: Player camera found")
				# Set initial zoom based on current scene
				set_zoom_for_current_scene()
				# Remove camera limits for hotel_hospital scene
				remove_camera_limits_for_hotel_hospital()
			else:
				print("⚠️ CameraZoomManager: Player camera not found")
		else:
			print("⚠️ CameraZoomManager: Player not found")

func set_zoom_for_current_scene():
	"""Set zoom based on the current scene name"""
	# Check if current_scene exists
	if not get_tree().current_scene:
		print("📷 CameraZoomManager: No current scene in set_zoom_for_current_scene")
		return
	
	var scene_name = get_tree().current_scene.scene_file_path.get_file().get_basename()
	var target_zoom = get_zoom_for_scene(scene_name)
	set_camera_zoom(target_zoom)
	print("📷 CameraZoomManager: Set zoom to ", target_zoom, " for scene: ", scene_name)
	print("📷 CameraZoomManager: Current zoom level: ", current_zoom)

func get_zoom_for_scene(scene_name: String) -> float:
	"""Get the appropriate zoom level for a scene"""
	print("📷 CameraZoomManager: Getting zoom for scene: ", scene_name)
	
	# Check for exact scene name match first
	if zoom_settings.has(scene_name):
		print("📷 CameraZoomManager: Found exact match for ", scene_name, " -> zoom: ", zoom_settings[scene_name])
		return zoom_settings[scene_name]
	
	# Check for partial matches
	if scene_name.contains("bedroom"):
		print("📷 CameraZoomManager: Bedroom scene detected -> zoom: ", zoom_settings["bedroom"])
		return zoom_settings["bedroom"]
	elif scene_name.contains("police") or scene_name.contains("lobby"):
		print("📷 CameraZoomManager: Police/lobby scene detected -> zoom: ", zoom_settings["police_lobby"])
		return zoom_settings["police_lobby"]
	elif scene_name.contains("barangay"):
		print("📷 CameraZoomManager: Barangay scene detected -> zoom: ", zoom_settings["barangay_hall"])
		return zoom_settings["barangay_hall"]
	elif scene_name.contains("lower_level") or scene_name.contains("station"):
		print("📷 CameraZoomManager: Station scene detected -> zoom: ", zoom_settings["lower_level"])
		return zoom_settings["lower_level"]
	elif scene_name.contains("map"):
		print("📷 CameraZoomManager: Map scene detected -> zoom: ", zoom_settings["map"])
		return zoom_settings["map"]
	elif scene_name.contains("terminal_market"):
		print("📷 CameraZoomManager: Terminal market scene detected -> zoom: ", zoom_settings["terminal_market"])
		return zoom_settings["terminal_market"]
	elif scene_name.contains("market"):
		print("📷 CameraZoomManager: Market scene detected -> zoom: ", zoom_settings["market"])
		return zoom_settings["market"]
	elif scene_name.contains("hardware"):
		print("📷 CameraZoomManager: Hardware scene detected -> zoom: ", zoom_settings["hardware_store"])
		return zoom_settings["hardware_store"]
	elif scene_name.contains("exterior") or scene_name.contains("apartment_morgue") or scene_name.contains("baranggay_court"):
		print("📷 CameraZoomManager: Exterior scene detected -> zoom: 1.0")
		return 1.0
	
	# Default to interior zoom (2.0) for most scenes
	print("📷 CameraZoomManager: Using default interior zoom: ", zoom_settings["interior"])
	return zoom_settings["interior"]

func set_camera_zoom(zoom_level: float, animate: bool = true):
	"""Set the camera zoom level"""
	if not player_camera:
		print("⚠️ CameraZoomManager: No camera found, cannot set zoom")
		return
	
	current_zoom = zoom_level
	
	if animate:
		# Smooth zoom transition with faster duration for scene changes
		var tween = create_tween()
		tween.tween_property(player_camera, "zoom", Vector2(zoom_level, zoom_level), 0.3)
		# Don't await - let it run in background for better performance
		tween.finished.connect(_on_zoom_finished.bind(zoom_level))
	else:
		# Instant zoom
		player_camera.zoom = Vector2(zoom_level, zoom_level)
		zoom_changed.emit(zoom_level)
	
	print("📷 CameraZoomManager: Zoom set to ", zoom_level)

func _on_zoom_finished(zoom_level: float):
	"""Called when zoom tween finishes"""
	zoom_changed.emit(zoom_level)

func get_current_zoom() -> float:
	"""Get the current zoom level"""
	return current_zoom

func reset_to_default_zoom():
	"""Reset zoom to default for current scene"""
	set_zoom_for_current_scene()

func remove_camera_limits_for_hotel_hospital():
	"""Remove camera limits specifically for hotel_hospital scene"""
	if not player_camera:
		return
	
	# Check if current_scene exists
	if not get_tree().current_scene:
		print("📷 CameraZoomManager: No current scene in remove_camera_limits_for_hotel_hospital")
		return
	
	var scene_name = get_tree().current_scene.scene_file_path.get_file().get_basename()
	
	# Check if we're in the hotel_hospital scene
	if scene_name == "hotel_hospital":
		print("📷 CameraZoomManager: Removing camera limits for hotel_hospital scene")
		# Remove all camera limits by setting them to their default values
		player_camera.limit_left = -10000000
		player_camera.limit_top = -10000000
		player_camera.limit_right = 10000000
		player_camera.limit_bottom = 10000000
		print("📷 CameraZoomManager: Camera limits removed for hotel_hospital")
	else:
		print("📷 CameraZoomManager: Not in hotel_hospital scene, keeping default limits")

# Scene change detection
func _on_tree_changed():
	"""Called when tree changes - check if scene changed"""
	# Check if current_scene exists before accessing it
	if not get_tree().current_scene:
		print("📷 CameraZoomManager: No current scene, skipping...")
		return
	
	var current_scene_path = get_tree().current_scene.scene_file_path
	
	if current_scene_path != last_scene_path and current_scene_path != "":
		print("📷 CameraZoomManager: Scene changed from ", last_scene_path, " to ", current_scene_path)
		last_scene_path = current_scene_path
		# Wait a frame for the scene to fully load
		await get_tree().process_frame
		find_player_camera()

# Manual zoom controls for debugging
func _input(event):
	if event is InputEventKey and event.pressed:
		match event.physical_keycode:
			KEY_F6:
				# F6 - Set zoom to 2.0 (interior)
				set_camera_zoom(2.0)
			KEY_F5:
				# F5 - Set zoom to 1.5 (exterior)
				set_camera_zoom(1.5)
			KEY_F4:
				# F4 - Reset to scene default
				reset_to_default_zoom()
