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
	"lower_level": 2.0   # Lower level station (interior)
}

# Current zoom level
var current_zoom: float = 2.0
var player_camera: Camera2D = null

func _ready():
	print("📷 CameraZoomManager: Ready")
	# Find the player camera when the scene changes
	call_deferred("find_player_camera")

func find_player_camera():
	"""Find the player's camera in the current scene"""
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
	var scene_name = get_tree().current_scene.scene_file_path.get_file().get_basename()
	var target_zoom = get_zoom_for_scene(scene_name)
	set_camera_zoom(target_zoom)
	print("📷 CameraZoomManager: Set zoom to ", target_zoom, " for scene: ", scene_name)

func get_zoom_for_scene(scene_name: String) -> float:
	"""Get the appropriate zoom level for a scene"""
	# Check for exact scene name match first
	if zoom_settings.has(scene_name):
		return zoom_settings[scene_name]
	
	# Check for partial matches
	if scene_name.contains("bedroom"):
		return zoom_settings["bedroom"]
	elif scene_name.contains("police") or scene_name.contains("lobby"):
		return zoom_settings["police_lobby"]
	elif scene_name.contains("barangay"):
		return zoom_settings["barangay_hall"]
	elif scene_name.contains("lower_level") or scene_name.contains("station"):
		return zoom_settings["lower_level"]
	elif scene_name.contains("map"):
		return zoom_settings["map"]
	
	# Default to interior zoom (2.0) for most scenes
	return zoom_settings["interior"]

func set_camera_zoom(zoom_level: float, animate: bool = true):
	"""Set the camera zoom level"""
	if not player_camera:
		print("⚠️ CameraZoomManager: No camera found, cannot set zoom")
		return
	
	current_zoom = zoom_level
	
	if animate:
		# Smooth zoom transition
		var tween = create_tween()
		tween.tween_property(player_camera, "zoom", Vector2(zoom_level, zoom_level), 0.5)
		await tween.finished
	else:
		# Instant zoom
		player_camera.zoom = Vector2(zoom_level, zoom_level)
	
	zoom_changed.emit(zoom_level)
	print("📷 CameraZoomManager: Zoom set to ", zoom_level)

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
func _on_scene_changed():
	"""Called when scene changes - find new camera and set zoom"""
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

