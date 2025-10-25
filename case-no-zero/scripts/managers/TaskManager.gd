extends Node

# Singleton TaskManager for handling game tasks/objectives

signal task_started(task_name: String)
signal task_completed(task_name: String)
signal task_updated(task_name: String)

# Task queue
var current_task: Dictionary = {}
var task_queue: Array = []
var task_history: Array = []

# Reference to the UI
var task_display: CanvasLayer = null

func _ready():
	# Initialize default tasks (can be loaded from JSON later)
	initialize_tasks()
	
	# Auto-connect to TaskDisplay autoload
	if TaskDisplay:
		set_task_display(TaskDisplay)
		print("✅ TaskDisplay autoload connected")
	else:
		print("⚠️ TaskDisplay autoload not found")

func initialize_tasks():
	# Define the task sequence for the game
	task_queue = [
		{
			"id": "go_to_police_station",
			"name": "Pumunta sa Police Station",
			"description": "Pumunta sa police station lobby para sa unang araw mo.",
			"scene_target": "police_lobby"
		},
		{
			"id": "go_to_barangay_hall",
			"name": "Pumunta sa Barangay Hall",
			"description": "Imbestigahan ang crime scene sa likod ng barangay hall.",
			"scene_target": "barangay_hall"
		},
		{
			"id": "go_to_morgue",
			"name": "Pumunta sa morgue para sa autopsy report",
			"description": "Tingnan ang autopsy report sa morgue para sa karagdagang ebidensya.",
			"scene_target": "morgue"
		},
		{
			"id": "next_task_placeholder",
			"name": "Ipagpatuloy ang Imbestigasyon",
			"description": "Placeholder para sa susunod na task.",
			"scene_target": ""
		}
	]

func set_task_display(display: CanvasLayer):
	task_display = display
	print("✅ TaskManager: Task display connected")

func start_next_task():
	if task_queue.is_empty():
		print("⚠️ TaskManager: No more tasks in queue")
		return
	
	current_task = task_queue.pop_front()
	print("==================================================")
	print("📋 TaskManager: STARTING NEW TASK")
	print("✨ Task Name:", current_task.name)
	print("📝 Description:", current_task.description)
	print("🎯 Target Scene:", current_task.scene_target)
	print("==================================================")
	
	# Show task in UI
	if task_display:
		task_display.show_task(current_task.name)
	
	emit_signal("task_started", current_task.name)

func complete_current_task():
	if current_task.is_empty():
		print("⚠️ TaskManager: No active task to complete")
		return
	
	print("==================================================")
	print("✅ TaskManager: COMPLETING TASK -", current_task.name)
	print("📋 Task ID:", current_task.id)
	print("🎯 Task Target:", current_task.scene_target)
	print("🔍 DEBUG: Awaiting task confirmation at Police Station")
	print("==================================================")
	
	task_history.append(current_task)
	
	emit_signal("task_completed", current_task.name)
	
	# Hide task display temporarily
	if task_display:
		task_display.hide_task()
	
	current_task = {}

func update_task(new_description: String):
	if current_task.is_empty():
		return
	
	current_task.description = new_description
	emit_signal("task_updated", current_task.name)

func get_current_task() -> Dictionary:
	return current_task

func is_task_active() -> bool:
	return not current_task.is_empty()

func get_current_task_scene_target() -> String:
	if current_task.is_empty():
		return ""
	return current_task.get("scene_target", "")

func set_current_task(task_id: String) -> void:
	"""Set the current task by ID (for development/testing)"""
	for task in task_queue:
		if task.id == task_id:
			current_task = task
			print("==================================================")
			print("📋 TaskManager: SET CURRENT TASK")
			print("✨ Task Name:", current_task.name)
			print("📝 Description:", current_task.description)
			print("🎯 Target Scene:", current_task.scene_target)
			print("==================================================")
			
			# Show task in UI
			if task_display:
				task_display.show_task(current_task.name)
			
			emit_signal("task_started", current_task.name)
			return
	
	print("⚠️ TaskManager: Task ID not found:", task_id)
