extends Node

# ScenePreloader - Preloads all scenes for instant transitions
signal scene_preloaded(scene_path: String)
signal all_scenes_preloaded()

# Dictionary to store preloaded scenes
var preloaded_scenes: Dictionary = {}

# List of all scenes to preload
var scenes_to_preload: Array = [
	# Police Station Environments
	"res://scenes/environments/Police Station/police_lobby.tscn",
	"res://scenes/environments/Police Station/lower_level_station.tscn",
	"res://scenes/environments/Police Station/head_police_room.tscn",
	"res://scenes/environments/Police Station/security_server.tscn",
	"res://scenes/environments/Police Station/lobby/station_lobby.tscn",
	"res://scenes/environments/Police Station/lobby/station_lobby2.tscn",
	"res://scenes/environments/Police Station/lobby/station_lobby3.tscn",
	
	# Barangay Hall Environments
	"res://scenes/environments/barangay hall/barangay_hall.tscn",
	"res://scenes/environments/barangay hall/barangay_hall_second_floor.tscn",
	"res://scenes/environments/exterior/baranggay_court.tscn",
	
	# Cutscenes
	"res://scenes/cutscenes/bedroomScene.tscn",
	"res://scenes/cutscenes/intro.tscn",
	
	# Main Characters
	"res://scenes/characters/main/playerM.tscn",
	"res://scenes/characters/main/celine_navarro.tscn",
	"res://scenes/characters/main/erwin.tscn",
	"res://scenes/characters/main/leo_mendoza.tscn",
	
	# NPCs
	"res://scenes/characters/kapitanaPalma.tscn",
	"res://scenes/characters/barangay_npc.tscn",
	"res://scenes/characters/npc/npc_police.tscn",
	"res://scenes/characters/npc/robles.tscn",
	"res://scenes/characters/main/station_guard.tscn",
	"res://scenes/characters/main/station_guard_2.tscn",
	"res://scenes/characters/main/station_guard_3.tscn",
	
	# UI Scenes
	"res://scenes/ui/dialogueUi.tscn",
	"res://scenes/ui/DialogChooser.tscn",
	"res://scenes/ui/TaskDisplay.tscn",
	"res://scenes/ui/TaskManager.tscn",
	"res://scenes/ui/settings.tscn",
	"res://scenes/ui/caseOption.tscn",
	"res://scenes/ui/Transition.tscn",
	"res://scenes/ui/Main Menu.tscn",
	
	# Environment Scenes
	"res://scenes/environments/exterior/Police Station.tscn",
	"res://scenes/environments/exterior/Barangay Hall & CityHall Courtroom.tscn",
	"res://scenes/environments/exterior/camp and court.tscn",
	"res://scenes/environments/hardware/hardware store.tscn",
	"res://scenes/environments/hotel/hotel_lobby.tscn",
	"res://scenes/environments/hotel/hotel_2nd_floor.tscn",
	"res://scenes/environments/hospital/hospital_lobby.tscn",
	"res://scenes/environments/hospital/hospital_2nd_floor.tscn",
	"res://scenes/environments/market/market interior.tscn",
	"res://scenes/environments/fire_station/fire_station_1st_floor.tscn",
	"res://scenes/environments/fire_station/fire_station_2nd_floor.tscn",
	"res://scenes/environments/funeral home/morgue.tscn",
	"res://scenes/environments/Courtroom/courtroom.tscn",
	"res://scenes/environments/abandoned court/abandoned court house.tscn",
	"res://scenes/environments/abandoned court/court.tscn",
	
	# Apartment Scenes
	"res://scenes/environments/apartments/apartment1.tscn",
	"res://scenes/environments/apartments/apartment2.tscn",
	"res://scenes/environments/apartments/apartment3.tscn",
	"res://scenes/maps/apartments/apartment1.tscn",
	"res://scenes/maps/apartments/apartment2.tscn",
	"res://scenes/maps/apartments/apartment3.tscn",
	"res://scenes/maps/apartments/abandoned court house.tscn",
	
	# Sample Interior Scenes
	"res://scenes/environments/Sample interior/generic/genericInterior.tscn",
	"res://scenes/environments/Sample interior/gym/gymInterior.tscn",
	"res://scenes/environments/Sample interior/iceCreamShop/iceCreamShopInterior.tscn",
	"res://scenes/environments/Sample interior/museum/museumInterior.tscn",
	"res://scenes/environments/Sample interior/shootingrangeInterior/shootingRange.tscn",
	
	# Objects
	"res://scenes/objects/Door.tscn",
	
	# Root Scenes
	"res://EvidenceInventory.tscn",
	"res://EvidenceInventorySettings.tscn",
	"res://Settings.tscn",
	"res://hardware store.tscn",
	"res://npc_camp.tscn"
]

var is_preloading: bool = false
var preload_progress: int = 0

func _ready():
	print("🚀 ScenePreloader: Ready (preloading disabled for debugging - will be much faster in exported game)")
	# Comment out preloading for debugging - enable after game completion
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
