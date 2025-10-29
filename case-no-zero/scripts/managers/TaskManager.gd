extends Node

signal task_started(task_name: String)
signal task_completed(task_name: String)
signal task_updated(task_name: String)

var current_task: Dictionary = {}
var task_queue: Array = []
var task_history: Array = []

var task_display: CanvasLayer = null

func _ready():
	pass

func set_task_display(display: CanvasLayer):
	task_display = display

func start_next_task():
	# No-op: tasks disabled
	current_task = {}

func complete_current_task():
	# No-op: record and clear if any
	if not current_task.is_empty():
		task_history.append(current_task)
		current_task = {}

func update_task(new_description: String):
	# No-op
	pass

func get_current_task() -> Dictionary:
	return current_task

func is_task_active() -> bool:
	return false

func get_current_task_scene_target() -> String:
	return ""

func set_current_task(task_id: String) -> void:
	# No-op
	pass

func has_next_task() -> bool:
	return false

func reset_tasks() -> void:
	task_queue.clear()
	current_task = {}
	task_history.clear()

func fade_task_display():
	# Kept for compatibility; no-op
	pass
