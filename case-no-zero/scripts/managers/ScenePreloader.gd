extends Node

# ScenePreloader - Preloads all scenes for instant transitions
signal scene_preloaded(scene_path: String)
signal all_scenes_preloaded()

# Dictionary to store preloaded scenes
var preloaded_scenes: Dictionary = {}

# List of all scenes to preload
var scenes_to_preload: Array = [
	"res://scenes/environments/Police Station/police_lobby.tscn",
	"res://scenes/environments/Police Station/lower_level_station.tscn",
	"res://scenes/environments/Police Station/head_police_room.tscn",
	"res://scenes/environments/Police Station/security_server.tscn",
	"res://scenes/environments/barangay hall/barangay_hall.tscn",
	"res://scenes/environments/barangay hall/barangay_hall_second_floor.tscn",
	"res://scenes/cutscenes/bedroomScene.tscn",
	"res://scenes/cutscenes/intro.tscn"
]

var is_preloading: bool = false
var preload_progress: int = 0

func _ready():
	print("🚀 ScenePreloader: Ready (preloading disabled for debugging)")
	# Comment out preloading for now - enable after game completion
	# await get_tree().create_timer(0.5).timeout
	# preload_all_scenes()

func preload_all_scenes():
	"""Preload all scenes in the background"""
	if is_preloading:
		print("⚠️ ScenePreloader: Already preloading scenes")
		return
	
	is_preloading = true
	preload_progress = 0
	
	print("📦 ScenePreloader: Preloading ", scenes_to_preload.size(), " scenes...")
	
	for scene_path in scenes_to_preload:
		await preload_single_scene(scene_path)
		preload_progress += 1
		var progress_percent = (preload_progress * 100) / scenes_to_preload.size()
		print("📦 ScenePreloader: Progress ", progress_percent, "% - Preloaded: ", scene_path.get_file())
	
	is_preloading = false
	print("✅ ScenePreloader: All scenes preloaded successfully!")
	all_scenes_preloaded.emit()

func preload_single_scene(scene_path: String):
	"""Preload a single scene"""
	if preloaded_scenes.has(scene_path):
		print("📦 ScenePreloader: Scene already preloaded: ", scene_path.get_file())
		return
	
	# Load the scene resource
	var scene_resource = load(scene_path)
	if scene_resource:
		preloaded_scenes[scene_path] = scene_resource
		scene_preloaded.emit(scene_path)
		print("📦 ScenePreloader: Preloaded: ", scene_path.get_file())
	else:
		print("⚠️ ScenePreloader: Failed to preload: ", scene_path)

func get_preloaded_scene(scene_path: String) -> PackedScene:
	"""Get a preloaded scene"""
	if preloaded_scenes.has(scene_path):
		return preloaded_scenes[scene_path]
	else:
		print("⚠️ ScenePreloader: Scene not preloaded: ", scene_path)
		return null

func is_scene_preloaded(scene_path: String) -> bool:
	"""Check if a scene is preloaded"""
	return preloaded_scenes.has(scene_path)

func get_preload_progress() -> float:
	"""Get preloading progress as percentage"""
	if scenes_to_preload.is_empty():
		return 100.0
	return (preload_progress * 100.0) / scenes_to_preload.size()

func get_preloaded_scenes_count() -> int:
	"""Get number of preloaded scenes"""
	return preloaded_scenes.size()

func get_total_scenes_count() -> int:
	"""Get total number of scenes to preload"""
	return scenes_to_preload.size()

func clear_preloaded_scenes():
	"""Clear all preloaded scenes (for memory management if needed)"""
	preloaded_scenes.clear()
	print("🗑️ ScenePreloader: Cleared all preloaded scenes")

func get_debug_info() -> String:
	"""Get debug information about preloaded scenes"""
	var info = "ScenePreloader Debug Info:\n"
	info += "  - Total scenes: " + str(get_total_scenes_count()) + "\n"
	info += "  - Preloaded: " + str(get_preloaded_scenes_count()) + "\n"
	info += "  - Progress: " + str(get_preload_progress()) + "%\n"
	info += "  - Is preloading: " + str(is_preloading) + "\n"
	info += "  - Preloaded scenes:\n"
	
	for scene_path in preloaded_scenes.keys():
		info += "    - " + scene_path.get_file() + "\n"
	
	return info
