extends Node

# CameraZoomManager - Autoload for managing dynamic camera zoom based on scene type

signal zoom_changed(new_zoom: float)
# Positive values zoom in (lower POV / closer to player)
const PLAYER_POV_BOOST: float = 0.4

# Zoom settings for different scene types
var zoom_settings: Dictionary = {
	"interior": 2.0,       # Default zoom for interior scenes
	"exterior": 1.5,       # Default zoom for exterior scenes  
	"map": 1.5,            # Specific zoom for map scenes
	"bedroom": 2.0,        # Bedroom scene (interior)
	"police_lobby": 2.0,   # Police lobby (interior)
	"barangay_hall": 2.0,  # Barangay hall (interior)
	"lower_level": 2.0,    # Lower level station (interior)
	"police_station": 1.0, # Police station exterior (zoom 1.0)
	"hotel_hospital": 1.0, # Hotel hospital exterior (zoom 1.0)
	"camp": 1.0,           # Camp scene (zoom 1.0)
	"terminal_market": 1.0,# Terminal market (zoom 1.0)
	"market": 2.0,         # Market scene (zoom 2.0)
	"hardware_store": 2.0  # Hardware store (zoom 2.0)
}

# Current zoom level
var current_zoom: float = 2.0
var player_camera: Camera2D = null
var last_scene_path: String = ""

func _ready():
	print("📷 CameraZoomManager: Ready")
	get_tree().tree_changed.connect(_on_tree_changed)
	call_deferred("find_player_camera")

func find_player_camera():
	"""Find the player's camera in the current scene"""
	await get_tree().process_frame
	
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
				set_zoom_for_current_scene()
				set_camera_limits_for_scene()
			else:
				print("⚠️ CameraZoomManager: Player camera not found")
		else:
			print("⚠️ CameraZoomManager: Player not found")

func set_zoom_for_current_scene():
	if not get_tree().current_scene:
		print("📷 CameraZoomManager: No current scene in set_zoom_for_current_scene")
		return
	
	var scene_name = get_tree().current_scene.scene_file_path.get_file().get_basename()
	var target_zoom = get_zoom_for_scene(scene_name) + PLAYER_POV_BOOST
	set_camera_zoom(target_zoom)
	print("📷 CameraZoomManager: Set zoom to ", target_zoom, " for scene: ", scene_name)

func get_zoom_for_scene(scene_name: String) -> float:
	if zoom_settings.has(scene_name):
		return zoom_settings[scene_name]
	elif scene_name.contains("bedroom"):
		return zoom_settings["bedroom"]
	elif scene_name.contains("police") or scene_name.contains("lobby"):
		return zoom_settings["police_lobby"]
	elif scene_name.contains("barangay"):
		return zoom_settings["barangay_hall"]
	elif scene_name.contains("lower_level") or scene_name.contains("station"):
		return zoom_settings["lower_level"]
	elif scene_name.contains("map"):
		return zoom_settings["map"]
	elif scene_name.contains("terminal_market"):
		return zoom_settings["terminal_market"]
	elif scene_name.contains("market"):
		return zoom_settings["market"]
	elif scene_name.contains("hardware"):
		return zoom_settings["hardware_store"]
	elif scene_name.contains("exterior") or scene_name.contains("apartment_morgue") or scene_name.contains("baranggay_court"):
		return 1.0
	
	return zoom_settings["interior"]

func set_camera_zoom(zoom_level: float, animate: bool = true):
	if not player_camera:
		print("⚠️ CameraZoomManager: No camera found, cannot set zoom")
		return
	
	current_zoom = zoom_level
	
	if animate:
		var tween = create_tween()
		tween.tween_property(player_camera, "zoom", Vector2(zoom_level, zoom_level), 0.3)
		tween.finished.connect(_on_zoom_finished.bind(zoom_level))
	else:
		player_camera.zoom = Vector2(zoom_level, zoom_level)
		zoom_changed.emit(zoom_level)

func _on_zoom_finished(zoom_level: float):
	zoom_changed.emit(zoom_level)

func get_current_zoom() -> float:
	return current_zoom

func reset_to_default_zoom():
	set_zoom_for_current_scene()

func set_camera_limits_for_scene():
	if not player_camera:
		return
	
	if not get_tree().current_scene:
		print("📷 CameraZoomManager: No current scene in set_camera_limits_for_scene")
		return
	
	var scene_name = get_tree().current_scene.scene_file_path.get_file().get_basename()
	
	match scene_name:
		"courtroom":
			player_camera.limit_left = 0
			player_camera.limit_top = 0
			player_camera.limit_right = 1407.0
			player_camera.limit_bottom = 774.0
		"baranggay_court":
			player_camera.limit_left = 0
			player_camera.limit_top = 0
			player_camera.limit_right = 1728.0
			player_camera.limit_bottom = 1920.0
		"apartment_morgue":
			player_camera.limit_left = 0
			player_camera.limit_top = 0
			player_camera.limit_right = 2736.0
			player_camera.limit_bottom = 1021.0
		"camp":
			player_camera.limit_left = 0
			player_camera.limit_top = 0
			player_camera.limit_right = 1568.0
			player_camera.limit_bottom = 1064.0
		"hotel_hospital":
			player_camera.limit_left = 0
			player_camera.limit_top = 0
			player_camera.limit_right = 1280.0
			player_camera.limit_bottom = 2700.0
		"police_station":
			player_camera.limit_left = 0
			player_camera.limit_top = 0
			player_camera.limit_right = 2624.0
			player_camera.limit_bottom = 1544.0
		"terminal_market":
			player_camera.limit_left = 0
			player_camera.limit_top = 0
			player_camera.limit_right = 2816.0
			player_camera.limit_bottom = 1080.0
		_:
			player_camera.limit_left = 0
			player_camera.limit_top = 0
			player_camera.limit_right = 1280.0
			player_camera.limit_bottom = 720.0

func _on_tree_changed():
	"""Called when tree changes - check if scene changed"""
	if not get_tree().current_scene:
		print("📷 CameraZoomManager: No current scene, skipping...")
		return
	
	var current_scene_path = get_tree().current_scene.scene_file_path
	
	if current_scene_path != last_scene_path and current_scene_path != "":
		print("📷 CameraZoomManager: Scene changed from ", last_scene_path, " to ", current_scene_path)
		last_scene_path = current_scene_path
		await get_tree().process_frame
		find_player_camera()

func _input(event):
	if event is InputEventKey and event.pressed:
		match event.physical_keycode:
			KEY_F6:
				set_camera_zoom(2.0)
			KEY_F5:
				set_camera_zoom(1.5)
			KEY_F4:
				reset_to_default_zoom()
