extends Node

# SpawnManager - Handles dynamic player spawning based on entry points
# This autoload tracks which scene the player came from and provides appropriate spawn positions

var previous_scene: String = ""
var entry_point: String = ""

# Define spawn positions for each scene based on entry points
var spawn_positions: Dictionary = {
	"police_lobby": {
		"from_security_server": {
			"position": Vector2(400, 488),
			"animation": "idle_back"
		},
		"from_head_police_room": {
			"position": Vector2(768, 288), 
			"animation": "idle_down"
		},
		"from_lower_level_station": {
			"position": Vector2(992, 488),
			"animation": "idle_back"
		},
		"default": {
			"position": Vector2(272, 480),
			"animation": "idle_down"
		}
	}
}

func set_entry_point(scene_name: String, entry: String):
	"""Set the entry point information for the next scene"""
	previous_scene = scene_name
	entry_point = entry
	print("📍 SpawnManager: Set entry point - Scene: ", scene_name, ", Entry: ", entry)

func get_spawn_data(scene_name: String) -> Dictionary:
	"""Get the appropriate spawn position and animation for the given scene"""
	var scene_spawns = spawn_positions.get(scene_name, {})
	
	# Try to get data based on entry point
	var spawn_key = "from_" + entry_point
	if scene_spawns.has(spawn_key):
		print("📍 SpawnManager: Using entry-specific spawn for ", scene_name, " from ", entry_point)
		return scene_spawns[spawn_key]
	
	# Fall back to default
	if scene_spawns.has("default"):
		print("📍 SpawnManager: Using default spawn for ", scene_name)
		return scene_spawns["default"]
	
	# If no spawn data exists, return empty
	print("⚠️ SpawnManager: No spawn data for ", scene_name, ", using scene default")
	return {}

func clear_entry_point():
	"""Clear the entry point information"""
	previous_scene = ""
	entry_point = ""
	print("📍 SpawnManager: Cleared entry point")
