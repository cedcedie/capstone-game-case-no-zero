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
		"from_bedroom_scene": {
			"position": Vector2(185, 184),
			"animation": "idle_down"
		},
		"default": {
			"position": Vector2(272, 480),
			"animation": "idle_down"
		}
	},
	"hotel_hospital": {
		"from_firestation": {
			"position": Vector2(432.0, 438.0),
			"animation": "idle_down"
		},
		"from_hotel_lobby": {
			"position": Vector2(640.0, 2528.0),
			"animation": "idle_down"
		},
		"from_hospital_lobby": {
			"position": Vector2(432.0, 1376.0),
			"animation": "idle_down"
		},
		"default": {
			"position": Vector2(432.0, 438.0),
			"animation": "idle_down"
		}
	},
	"fire_station_1st_floor": {
		"from_firestation_1st_floor": {
			"position": Vector2(400, 500),
			"animation": "idle_down"
		},
		"default": {
			"position": Vector2(400, 500),
			"animation": "idle_down"
		}
	},
	"hospital_lobby": {
		"from_hotel_hospital": {
			"position": Vector2(304.0, 248.0),
			"animation": "idle_down"
		},
		"from_hospital_2nd_floor": {
			"position": Vector2(704.0, 248.0),
			"animation": "idle_down"
		},
		"default": {
			"position": Vector2(304.0, 248.0),
			"animation": "idle_down"
		}
	},
	"hospital_2nd_floor": {
		"from_hospital_lobby": {
			"position": Vector2(528.0, 448.0),
			"animation": "idle_back"
		},
		"default": {
			"position": Vector2(528.0, 448.0),
			"animation": "idle_back"
		}
	},
	"hotel_lobby": {
		"from_hotel_hospital": {
			"position": Vector2(456, 368),
			"animation": "idle_down"
		},
		"from_hotel_2nd_floor": {
			"position": Vector2(792.0, 432.0),
			"animation": "idle_left"
		},
		"default": {
			"position": Vector2(456, 368),
			"animation": "idle_down"
		}
	},
	"hotel_2nd_floor": {
		"from_hotel_lobby": {
			"position": Vector2(630.0, 304),
			"animation": "idle_down"
		},
		"default": {
			"position": Vector2(630.0, 304.0),
			"animation": "idle_down"
		}
	},
	"police_station": {
		"default": {
			"position": Vector2(337.0, 1056.0),
			"animation": "idle_down"
		}
	},
	"terminal_market": {
		"from_hardware_store": {
			"position": Vector2(1024.0, 512.0),
			"animation": "idle_down"
		},
		"from_market": {
			"position": Vector2(2016.0, 528.0),
			"animation": "idle_down"
		},
		"default": {
			"position": Vector2(1024.0, 512.0),
			"animation": "idle_down"
		}
	},
	"hardware_store": {
		"from_terminal_market": {
			"position": Vector2(365.0, 367.0),
			"animation": "idle_down"
		},
		"default": {
			"position": Vector2(365.0, 367.0),
			"animation": "idle_down"
		}
	},
	"market": {
		"from_terminal_market": {
			"position": Vector2(160.0, 360.0),
			"animation": "idle_back"
		},
		"default": {
			"position": Vector2(160.0, 360.0),
			"animation": "idle_back"
		}
	},
	"barangay_hall": {
		"from_barangay_court": {
			"position": Vector2(465.0, 526.0),
			"animation": "idle_down"
		},
		"default": {
			"position": Vector2(465.0, 526.0),
			"animation": "idle_down"
		}
	},
	"baranggay_court": {
		"from_barangay_hall": {
			"position": Vector2(143.0, 464.0),
			"animation": "idle_down"
		},
		"default": {
			"position": Vector2(143.0, 464.0),
			"animation": "idle_down"
		}
	},
	"morgue": {
		"from_apartment_morgue": {
			"position": Vector2(400.0, 512.0),
			"animation": "idle_back"
		},
		"default": {
			"position": Vector2(400.0, 512.0),
			"animation": "idle_back"
		}
	},
	"apartment_morgue": {
		"from_morgue": {
			"position": Vector2(368.0, 768.0),
			"animation": "idle_down"
		},
		"default": {
			"position": Vector2(368.0, 768.0),
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
