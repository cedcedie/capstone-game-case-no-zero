extends Node

# ScenePreloader - Preloads all scenes for instant transitions
signal scene_preloaded(scene_path: String)
signal all_scenes_preloaded()

# Dictionary to store preloaded scenes
var preloaded_scenes: Dictionary = {}

# List of all scenes to preload - COMPLETE PROJECT SCAN (198 scenes)
var scenes_to_preload: Array = [
	# Addon Scenes
	"res://addons/SignalVisualizer/Debugger/SignalDebugger.tscn",
	"res://addons/SignalVisualizer/Visualizer/signal_graph_node.tscn",
	"res://addons/SignalVisualizer/Visualizer/signal_graph_node_item.tscn",
	"res://addons/SignalVisualizer/Visualizer/signal_visualizer_dock.tscn",
	
	# Root Scenes
	"res://cutscene_boy.tscn",
	"res://Demos/Demo1.tscn",
	"res://Demos/Demo2.tscn",
	"res://Demos/Demo3.tscn",
	"res://EvidenceInventorySettings.tscn",
	"res://head_po1.tscn",
	"res://interior_npc_01.tscn",
	"res://interior_npc_1.tscn",
	"res://interior_npc_1_face.tscn",
	"res://intro_story.tscn",
	"res://judge.tscn",
	"res://judge_portrait.tscn",
	"res://leticia_salvador.tscn",
	"res://node_2d.tscn",
	"res://po1_dar.tscn",
	"res://portrait.tscn",
	"res://portrait_prosecutor.tscn",
	"res://prosecutor.tscn",
	"res://Settings.tscn",
	"res://story_npc.tscn",
	
	# Police Station Characters
	"res://miravil/character_police_station/npc_pl_guy.tscn",
	"res://miravil/character_police_station/npc_pl_guy1.tscn",
	"res://miravil/character_police_station/npc_pl_guy2.tscn",
	"res://miravil/character_police_station/npc_pl_guy3.tscn",
	"res://miravil/character_police_station/npc_pl_guy4.tscn",
	"res://miravil/character_police_station/npc_pl_guy5.tscn",
	"res://miravil/character_police_station/npc_pl_guy6.tscn",
	"res://miravil/character_police_station/npc_pl_guy7.tscn",
	"res://miravil/character_police_station/npc_pl_guy8.tscn",
	"res://miravil/character_police_station/npc_pl_guy9.tscn",
	"res://miravil/character_police_station/npc_pl_po2.tscn",
	"res://miravil/character_police_station/npc_pl_po3.tscn",
	"res://miravil/character_police_station/npc_pl_po4.tscn",
	"res://miravil/character_police_station/npc_pl_po5.tscn",
	"res://miravil/character_police_station/npc_pl_po6.tscn",
	"res://miravil/character_police_station/npc_pl_po7.tscn",
	"res://miravil/character_police_station/po1Darwin.tscn",
	
	# General Characters
	"res://miravil/characters/npc_backpack_man.tscn",
	"res://miravil/characters/npc_beard_man.tscn",
	"res://miravil/characters/npc_boy_1.tscn",
	"res://miravil/characters/npc_boy_icecream_hair.tscn",
	"res://miravil/characters/npc_boy_kunat.tscn",
	"res://miravil/characters/npc_cool_hoodie.tscn",
	"res://miravil/characters/npc_curly_girly.tscn",
	"res://miravil/characters/npc_girl_1.tscn",
	"res://miravil/characters/npc_girl_kid_2.tscn",
	"res://miravil/characters/npc_girl_pinkish.tscn",
	"res://miravil/characters/npc_green_girl.tscn",
	"res://miravil/characters/npc_guy_2.tscn",
	"res://miravil/characters/npc_guy_3.tscn",
	"res://miravil/characters/npc_guy_4.tscn",
	"res://miravil/characters/npc_guy_5.tscn",
	"res://miravil/characters/npc_guy_6.tscn",
	"res://miravil/characters/npc_long_hair.tscn",
	"res://miravil/characters/npc_mustache.tscn",
	"res://miravil/characters/npc_mustache_man.tscn",
	"res://miravil/characters/npc_one_eye.tscn",
	"res://miravil/characters/npc_pinkish.tscn",
	"res://miravil/characters/npc_random_girl.tscn",
	"res://miravil/characters/npc_random_guy.tscn",
	"res://miravil/characters/npc_shaolin_boy.tscn",
	"res://miravil/characters/npc_yellow_glass_man.tscn",
	
	# Characters 2
	"res://miravil/characters_2/npc_bc_boy1.tscn",
	"res://miravil/characters_2/npc_bc_boy2.tscn",
	"res://miravil/characters_2/npc_bc_boy3.tscn",
	"res://miravil/characters_2/npc_bc_boy4.tscn",
	"res://miravil/characters_2/npc_bc_boy5.tscn",
	"res://miravil/characters_2/npc_bc_boy6.tscn",
	"res://miravil/characters_2/npc_bc_boy7.tscn",
	"res://miravil/characters_2/npc_bc_boy8.tscn",
	"res://miravil/characters_2/npc_bc_furry.tscn",
	"res://miravil/characters_2/npc_bc_girl1.tscn",
	"res://miravil/characters_2/npc_bc_girl2.tscn",
	"res://miravil/characters_2/npc_bc_girl3.tscn",
	"res://miravil/characters_2/npc_bc_girl4.tscn",
	"res://miravil/characters_2/npc_bc_girl5.tscn",
	"res://miravil/characters_2/npc_pl_guy3.tscn",
	
	# Camp Characters
	"res://miravil/characters_camp/npc_cmp_b1.tscn",
	"res://miravil/characters_camp/npc_cmp_b10.tscn",
	"res://miravil/characters_camp/npc_cmp_b2.tscn",
	"res://miravil/characters_camp/npc_cmp_b3.tscn",
	"res://miravil/characters_camp/npc_cmp_b4.tscn",
	"res://miravil/characters_camp/npc_cmp_b5.tscn",
	"res://miravil/characters_camp/npc_cmp_b6.tscn",
	"res://miravil/characters_camp/npc_cmp_b7.tscn",
	"res://miravil/characters_camp/npc_cmp_b8.tscn",
	"res://miravil/characters_camp/npc_cmp_b9.tscn",
	"res://miravil/characters_camp/npc_cmp_g1.tscn",
	"res://miravil/characters_camp/npc_cmp_g2.tscn",
	
	# Hotel Hospital Characters
	"res://miravil/characters_hotel_hospital/npc_htl_em1.tscn",
	"res://miravil/characters_hotel_hospital/npc_htl_em2.tscn",
	"res://miravil/characters_hotel_hospital/npc_htl_em3.tscn",
	"res://miravil/characters_hotel_hospital/npc_htl_em4.tscn",
	"res://miravil/characters_hotel_hospital/npc_htl_em5.tscn",
	"res://miravil/characters_hotel_hospital/npc_htl_em6.tscn",
	"res://miravil/characters_hotel_hospital/npc_htl_em7.tscn",
	"res://miravil/characters_hotel_hospital/npc_htl_em8.tscn",
	"res://miravil/characters_hotel_hospital/npc_htl_f1.tscn",
	"res://miravil/characters_hotel_hospital/npc_htl_f2.tscn",
	"res://miravil/characters_hotel_hospital/npc_htl_f3.tscn",
	"res://miravil/characters_hotel_hospital/npc_htl_f4.tscn",
	"res://miravil/characters_hotel_hospital/npc_htl_girl1.tscn",
	"res://miravil/characters_hotel_hospital/npc_htl_girl2.tscn",
	"res://miravil/characters_hotel_hospital/npc_htl_guy1.tscn",
	"res://miravil/characters_hotel_hospital/npc_htl_guy2.tscn",
	
	# Terminal Market Characters
	"res://miravil/characters_terminal_market/npc_tm_girl1.tscn",
	"res://miravil/characters_terminal_market/npc_tm_girl2.tscn",
	"res://miravil/characters_terminal_market/npc_tm_girl3.tscn",
	"res://miravil/characters_terminal_market/npc_tm_girl4.tscn",
	"res://miravil/characters_terminal_market/npc_tm_girl5.tscn",
	"res://miravil/characters_terminal_market/npc_tm_girl6.tscn",
	"res://miravil/characters_terminal_market/npc_tm_guy1.tscn",
	"res://miravil/characters_terminal_market/npc_tm_guy2.tscn",
	"res://miravil/characters_terminal_market/npc_tm_guy3.tscn",
	"res://miravil/characters_terminal_market/npc_tm_guy4.tscn",
	"res://miravil/characters_terminal_market/npc_tm_guy5.tscn",
	"res://miravil/characters_terminal_market/npc_tm_guy6.tscn",
	"res://miravil/characters_terminal_market/npc_tm_guy7.tscn",
	"res://miravil/characters_terminal_market/npc_tm_guy8.tscn",
	"res://miravil/characters_terminal_market/npc_tm_guy9.tscn",
	
	# Sprites and Vehicles
	"res://miravil/sprites/npc_camp.tscn",
	"res://miravil/vehicle/vehicle_1.tscn",
	"res://miravil/vehicle_triyk/triyk_1.tscn",
	"res://miravil/vehicle_triyk/triyk_2.tscn",
	"res://miravil/vehicle_triyk/triyk_3.tscn",
	"res://miravil/vehicle_triyk/triyk_4.tscn",
	"res://miravil/vehicle_triyk/triyk_5.tscn",
	"res://miravil/vehicle_triyk/triyk_6.tscn",
	"res://miravil/vendor/vendor_1.tscn",
	
	# Main Characters
	"res://scenes/characters/barangay_npc.tscn",
	"res://scenes/characters/kapitanaPalma.tscn",
	"res://scenes/characters/main/celine_navarro.tscn",
	"res://scenes/characters/main/erwin.tscn",
	"res://scenes/characters/main/leo_mendoza.tscn",
	"res://scenes/characters/main/playerM.tscn",
	"res://scenes/characters/main/station_guard.tscn",
	"res://scenes/characters/main/station_guard_2.tscn",
	"res://scenes/characters/main/station_guard_3.tscn",
	"res://scenes/characters/npc/npc_police.tscn",
	"res://scenes/characters/npc/robles.tscn",
	
	# Cutscenes
	"res://scenes/cutscenes/bedroomScene.tscn",
	"res://scenes/cutscenes/intro.tscn",
	
	# Environment Scenes - Abandoned Court
	"res://scenes/environments/abandoned court/abandoned court house.tscn",
	
	# Environment Scenes - Alley
	"res://scenes/environments/alley/alley.tscn",
	
	# Environment Scenes - Apartments
	"res://scenes/environments/apartments/apartment_lobby.tscn",
	"res://scenes/environments/apartments/apartment1.tscn",
	"res://scenes/environments/apartments/apartment2.tscn",
	"res://scenes/environments/apartments/leo's apartment.tscn",
	
	# Environment Scenes - Barangay Hall
	"res://scenes/environments/barangay hall/barangay_hall.tscn",
	"res://scenes/environments/barangay hall/barangay_hall_second_floor.tscn",
	
	# Environment Scenes - Courtroom
	"res://scenes/environments/Courtroom/courtroom.tscn",
	
	# Environment Scenes - Exterior
	"res://scenes/environments/exterior/apartment_morgue.tscn",
	"res://scenes/environments/exterior/baranggay_court.tscn",
	"res://scenes/environments/exterior/camp.tscn",
	"res://scenes/environments/exterior/hotel_hospital.tscn",
	"res://scenes/environments/exterior/police_station.tscn",
	"res://scenes/environments/exterior/terminal_market.tscn",
	
	# Environment Scenes - Fire Station
	"res://scenes/environments/fire_station/fire_station_1st_floor.tscn",
	"res://scenes/environments/fire_station/fire_station_2nd_floor.tscn",
	
	# Environment Scenes - Funeral Home
	"res://scenes/environments/funeral home/morgue.tscn",
	
	# Environment Scenes - Hardware
	"res://scenes/environments/hardware/hardware_store.tscn",
	
	# Environment Scenes - Hospital
	"res://scenes/environments/hospital/hospital_2nd_floor.tscn",
	"res://scenes/environments/hospital/hospital_lobby.tscn",
	
	# Environment Scenes - Hotel
	"res://scenes/environments/hotel/hotel_2nd_floor.tscn",
	"res://scenes/environments/hotel/hotel_lobby.tscn",
	
	# Environment Scenes - Market
	"res://scenes/environments/market/market.tscn",
	
	# Environment Scenes - Police Station
	"res://scenes/environments/Police Station/head_police_room.tscn",
	"res://scenes/environments/Police Station/lobby/station_lobby.tscn",
	"res://scenes/environments/Police Station/lobby/station_lobby2.tscn",
	"res://scenes/environments/Police Station/lobby/station_lobby3.tscn",
	"res://scenes/environments/Police Station/lower_level_station.tscn",
	"res://scenes/environments/Police Station/police_lobby.tscn",
	"res://scenes/environments/Police Station/security_server.tscn",
	
	# Environment Scenes - Sample Interior
	"res://scenes/environments/Sample interior/generic/genericInterior.tscn",
	"res://scenes/environments/Sample interior/gym/gymInterior.tscn",
	"res://scenes/environments/Sample interior/iceCreamShop/iceCreamShopInterior.tscn",
	"res://scenes/environments/Sample interior/museum/museumInterior.tscn",
	"res://scenes/environments/Sample interior/shootingrangeInterior/shootingRange.tscn",
	
	# Environment Scenes - Simple Courtroom
	"res://scenes/environments/simple_courtroom.tscn",
	
	# Objects
	"res://scenes/objects/Door.tscn",
	
	# UI Scenes
	"res://scenes/ui/audio_player.tscn",
	"res://scenes/ui/caseOption.tscn",
	"res://scenes/ui/DialogChooser.tscn",
	"res://scenes/ui/dialogueUi.tscn",
	"res://scenes/ui/TaskDisplay.tscn",
	"res://scenes/ui/UI by jer/design/chapter_menu.tscn",
	"res://scenes/ui/UI by jer/design/Control_Guide.tscn",
	"res://scenes/ui/UI by jer/design/DialogueBox.tscn",
	"res://scenes/ui/UI by jer/design/Inventory.tscn",
	"res://scenes/ui/UI by jer/design/main_menu.tscn",
	"res://scenes/ui/UI by jer/design/TaskNotification.tscn",
	"res://scenes/ui/UI not used/TaskManager.tscn",
	"res://scenes/ui/UI not used/Transition.tscn",
	
	# Scripts/Managers
	"res://scripts/managers/TaskManager.tscn"
]

var is_preloading: bool = false
var preload_progress: int = 0

func _ready():
	print("🚀 ScenePreloader: Ready - preloading all scenes for optimal performance")
	# Preloading enabled for exported game
	await get_tree().create_timer(0.5).timeout
	preload_all_scenes()

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
