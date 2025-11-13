extends Node

signal task_started(task_name: String)
signal task_completed(task_name: String)
signal task_updated(task_name: String)
signal waypoint_set(target_scene: String, target_position: Vector2)
signal waypoint_cleared()

var current_task: Dictionary = {}
var task_queue: Array = []
var task_history: Array = []

var task_display: CanvasLayer = null

# Waypoint system for "go to" tasks
var active_waypoint_scene: String = ""
var active_waypoint_position: Vector2 = Vector2.ZERO

# Map of task keywords to target scenes and positions
const TASK_WAYPOINTS := {
	"kulangan": {
		"scene": "res://scenes/environments/exterior/police_station.tscn",
		"position": Vector2(336.0, 992.0)  # Actual police station position in police_station.tscn
	},
	"kulungan": {
		"scene": "res://scenes/environments/exterior/police_station.tscn",
		"position": Vector2(336.0, 992.0)
	},
	"police": {
		"scene": "res://scenes/environments/exterior/police_station.tscn",
		"position": Vector2(336.0, 992.0)
	},
	"station": {
		"scene": "res://scenes/environments/exterior/police_station.tscn",
		"position": Vector2(336.0, 992.0)
	},
	"barangay": {
		"scene": "res://scenes/environments/exterior/baranggay_court.tscn",
		"position": Vector2(144.0, 395.0)  # Barangay hall position in baranggay_court.tscn
	},
	"baranggay": {
		"scene": "res://scenes/environments/exterior/baranggay_court.tscn",
		"position": Vector2(144.0, 395.0)
	},
	"morgue": {
		"scene": "res://scenes/environments/exterior/apartment_morgue.tscn",
		"position": Vector2(359.0, 768.0)
	}
}

func _ready():
	pass

func set_task_display(display: CanvasLayer):
	task_display = display

func start_next_task():
	# No-op: tasks disabled
	current_task = {}

func complete_current_task():
	# Clear waypoint when task completes
	clear_waypoint()
	# No-op: record and clear if any
	if not current_task.is_empty():
		task_history.append(current_task)
		current_task = {}

func update_task(new_description: String):
	# Check if this is a "go to" task and set waypoint
	_check_and_set_waypoint(new_description)
	# Show task in display
	if task_display != null and task_display.has_method("show_task"):
		task_display.show_task(new_description)

func _check_and_set_waypoint(task_text: String) -> void:
	"""Check if task text contains waypoint keywords and set waypoint if found"""
	var text_lower := task_text.to_lower()
	
	# Check each waypoint keyword
	for keyword in TASK_WAYPOINTS.keys():
		if keyword in text_lower:
			var waypoint_data: Dictionary = TASK_WAYPOINTS[keyword]
			var target_scene: String = waypoint_data.get("scene", "")
			var target_pos: Vector2 = waypoint_data.get("position", Vector2.ZERO)
			set_waypoint(target_scene, target_pos)
			return
	
	# If no keyword found, clear waypoint
	clear_waypoint()

func set_waypoint(target_scene: String, target_position: Vector2) -> void:
	"""Set an active waypoint to show on minimap"""
	active_waypoint_scene = target_scene
	active_waypoint_position = target_position
	waypoint_set.emit(target_scene, target_position)

func clear_waypoint() -> void:
	"""Clear the active waypoint"""
	if active_waypoint_scene != "":
		active_waypoint_scene = ""
		active_waypoint_position = Vector2.ZERO
		waypoint_cleared.emit()

func get_current_task() -> Dictionary:
	return current_task

func is_task_active() -> bool:
	return not current_task.is_empty()

func get_current_task_scene_target() -> String:
	return active_waypoint_scene

func get_current_waypoint_position() -> Vector2:
	return active_waypoint_position

func has_waypoint() -> bool:
	return active_waypoint_scene != ""

func set_current_task(task_id: String) -> void:
	# No-op
	pass

func has_next_task() -> bool:
	return false

func reset_tasks() -> void:
	task_queue.clear()
	current_task = {}
	task_history.clear()
	clear_waypoint()

func fade_task_display():
	# Kept for compatibility; no-op
	pass
