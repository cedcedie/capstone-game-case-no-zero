extends Node

# SpawnManager - Handles dynamic player spawning based on entry points
# This autoload tracks which scene the player came from and provides appropriate spawn positions

var previous_scene: String = ""
var entry_point: String = ""

# Define spawn positions for each scene based on entry points
var spawn_positions: Dictionary = {
	"police_lobby": {
		"from_head_police_room": {
			"position": Vector2(768, 288), 
			"animation": "idle_down"
		},
		"from_lower_level_station": {
			"position": Vector2(992, 488),
			"animation": "idle_back"
		},
		"security_server": {
			"position": Vector2(400, 480),
			"animation": "idle_back"
		},
		"police_station": {
			"position": Vector2(272.0, 480),
			"animation": "idle_back"
		},
		"default": {
			"position": Vector2(272, 480),
			"animation": "idle_front"
		}
	},
	
	"head_police_room": {
		"head_police": {
		"position": Vector2(824.0, 476),
		"animation": "idle_back"
		}
	},
	
	"hotel_hospital": {
		"morgue_to_hospital": {
			"position": Vector2(256.0, 360.0),
			"animation": "idle_right"
		},
		"from_firestation": {
			"position": Vector2(432.0, 438.0),
			"animation": "idle_down"
		},
		"hotel_lobby": {
			"position": Vector2(640.0, 2528.0),
			"animation": "idle_down"
		},
		"from_hospital_lobby": {
			"position": Vector2(432.0, 1376.0),
			"animation": "idle_down"
		},
		"police_to_hospital": {
			"position": Vector2(208.0, 1760.0),
			"animation": "idle_right"
		},
		"market_to_hospital": {
			"position": Vector2(176.0, 2088.0),
			"animation": "idle_right"
		},
		"hospital_to_morgue": {
			"position": Vector2(2584.0, 240.0),
			"animation": "idle_down"
		},
		"hospital_to_police_station": {
			"position": Vector2(2456.0, 808.0),
			"animation": "idle_down"
		},
		"hospital_to_market": {
			"position": Vector2(2720.0, 208.0),
			"animation": "idle_down"
		},
		"default": {
			"position": Vector2(432.0, 1376.0),
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
	"lower_level_station": {
		"lower_level": {
			"position": Vector2(1056.0, 352.0),
			"animation": "idle_down"
		},
		
		"default": {
			"position": Vector2(1056.0, 352.0),
			"animation": "idle_right"
		}
	},
	"hospital_lobby": {
		"from_exterior_hospital_lobby": {
			"position": Vector2(462.0, 568.0),
			"animation": "idle_back"
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
			"position": Vector2(792.0, 432.0),
			"animation": "idle_left"
		},
		"hotel_2nd_floor": {
			"position": Vector2(456, 368),
			"animation": "idle_down"
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
		"morgue_to_police_station": {
			"position": Vector2(928.0, 232.0),
			"animation": "idle_down"
		},
		"barangay_to_police_station": {
			"position": Vector2(128.0, 1424.0),
			"animation": "idle_down"
		},
		"hospital_to_police_station": {
			"position": Vector2(2456.0, 808.0),
			"animation": "idle_down"
		},
		"market_to_police": {
			"position": Vector2(1496.0, 1424.0),
			"animation": "idle_back"
		},
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
		"market": {
			"position": Vector2(2016.0, 528.0),
			"animation": "idle_down"
		},
		"barangay_to_market": {
			"position": Vector2(120.0, 464.0),
			"animation": "idle_down"
		},
		"hospital_to_market": {
			"position": Vector2(2704.0, 463.0),
			"animation": "idle_down"
		},
		"police_to_market": {
			"position": Vector2(768.0, 152.0),
			"animation": "idle_down"
		},
		"market_to_baranggay": {
			"position": Vector2(1632.0, 1264.0),
			"animation": "idle_left"
		},
		"market_to_hospital": {
			"position": Vector2(176.0, 2088.0),
			"animation": "idle_right"
		},
		"market_to_police": {
			"position": Vector2(1496.0, 1424.0),
			"animation": "idle_back"
		},
		"lobby_to_exterior": {
			"position": Vector2(1584.00, 592.0),
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
		"from_barangay_hall2nd": {
			"position": Vector2(640.0, 416.0),
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
		"camp_to_barangay": {
			"position": Vector2(688.0, 127.0),
			"animation": "idle_down"
		},
		"police_to_baranggay": {
			"position": Vector2(1632.0, 616.0),
			"animation": "idle_left"
		},
		"barangay_to_camp": {
			"position": Vector2(816.0, 1024.0),
			"animation": "idle_back"
		},
		"barangay_to_market": {
			"position": Vector2(128.0, 199.0),
			"animation": "idle_down"
		},
		"barangay_to_police_station": {
			"position": Vector2(128.0, 1424.0),
			"animation": "idle_down"
		},
		"market_to_baranggay": {
			"position": Vector2(1632.0, 1264.0),
			"animation": "idle_left"
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
			"position": Vector2(368.0, 704.0),
			"animation": "idle_down"
		},
		"police_to_morgue": {
			"position": Vector2(1144.0, 1009.0),
			"animation": "idle_back"
		},
		"camp_to_morgue": {
			"position": Vector2(168.0, 176.0),
			"animation": "idle_down"
		},
		"hospital_to_morgue": {
			"position": Vector2(2584.0, 240.0),
			"animation": "idle_down"
		},
		"from_office_lobby_to_apartment_morgue":{
			"position": Vector2(2072.0,891.0),
			"animation": "idle_down"
	},
		"from_police_to_morgue":{
			"position": Vector2(1144.0,1009.0),
			"animation": "idle_down"
	},
		"default": {
			"position": Vector2(368.0, 704.0),
			"animation": "idle_down"
		}
		
	},
	"camp": {
		"morgue_to_camp": {
			"position": Vector2(1475.0, 272.0),
			"animation": "idle_left"
		},
		"barangay_to_camp": {
			"position": Vector2(816.0, 1024.0),
			"animation": "idle_back"
		},
		"default": {
			"position": Vector2(1488.0, 280.0),
			"animation": "idle_left"
		}
	},
	"bedroomScene": {
		"Area2D_bedroom_interior": {
			"position": Vector2(377.0, 292.0),
			"animation": "idle_down"
		},
		"default": {
			"position": Vector2(377.0, 292.0),
			"animation": "idle_down"
		}
	},
	"apartment_lobby": {
		"hatdog": {
			"position": Vector2(1034.0, 360.0),
			"animation": "idle_left"
			
			
		},
	
		"apartment_exterior": {
			"position": Vector2(864.0, 344.0),
			"animation": "idle_down"
			
		}
		},
	"office_main": {
		"office_balcony_to_office_main": {
			"position": Vector2(200.0, 576.0),
			"animation": "idle_back"
		},
		"office_rooftop_to_office_main": {
			"position": Vector2(168.0, 288.0),
			"animation": "idle_down"
		},
		"office_attorney_room_to_office_main": {
			"position": Vector2(1047.0, 240.0),
			"animation": "idle_back"
		},
		"from_office_lobby_to_office_main": {
			"position": Vector2(312.0, 248.0),
			"animation": "idle_down"
		}
		
	},

	"office_balcony": {
		"from_office_main_to_office_balcony": {
			"position": Vector2(816.0, 376.0),
			"animation": "idle_down"
		}
		
	},

	"office rooftop": {
		"from_office_main_to_office_rooftop": {
			"position": Vector2(390, 363),
			"animation": "idle_down"
		}
		
	},

	"office_attorney_room": {
		"from_office_main_to_office_attorney_room": {
			"position": Vector2(732.0, 488.0),
			"animation": "idle_back"
		}
	},
	"office_lobby": {
		"from_office_main_to_office_lobby": {
			"position": Vector2(465.0, 208.0),
			"animation": "idle_down"
		},
			"from_apartment_morgue_to_office_lobby": {
			"position": Vector2(672.0, 464.0),
			"animation": "idle_back"
		}
		
	},
	
	
	
}




func set_entry_point(scene_name: String, entry: String):
	"""Set the entry point information for the next scene"""
	previous_scene = scene_name
	entry_point = entry
	# print("📍 SpawnManager: Set entry point - Scene: ", scene_name, ", Entry: ", entry)

func get_spawn_data(scene_name: String) -> Dictionary:
	"""Get the appropriate spawn position and animation for the given scene"""
	var scene_spawns = spawn_positions.get(scene_name, {})
	
	# Try to get data based on entry point
	var spawn_key = entry_point
	if scene_spawns.has(spawn_key):
		# print("📍 SpawnManager: Using entry-specific spawn for ", scene_name, " from ", entry_point)
		return scene_spawns[spawn_key]
	
	# Fall back to default
	if scene_spawns.has("default"):
		# print("📍 SpawnManager: Using default spawn for ", scene_name)
		return scene_spawns["default"]
	
	# If no spawn data exists, return empty
	# print("⚠️ SpawnManager: No spawn data for ", scene_name, ", using scene default")
	return {}

func clear_entry_point():
	"""Clear the entry point information"""
	previous_scene = ""
	entry_point = ""
	# print("📍 SpawnManager: Cleared entry point")
