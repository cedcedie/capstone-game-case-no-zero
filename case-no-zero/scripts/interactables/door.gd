extends Area2D

@onready var anim = $AnimatedSprite2D
@onready var collider = $CollisionShape2D

@export var allowed_players: Array = ["PlayerM", "Celine"]
@export var target_scene: String = "res://scenes/environments/Police Station/police_lobby.tscn"  # Optional: if you want to change scenes

var player_in_range: Node2D = null
var is_open = false

func _ready():
	anim.play("idle") 
	connect("body_entered", Callable(self, "_on_body_entered"))
	connect("body_exited", Callable(self, "_on_body_exited"))

func _process(_delta):
	if player_in_range and Input.is_action_just_pressed("interact"):
		open_door()

func _on_body_entered(body):
	if body.name in allowed_players:
		player_in_range = body
		print("Player near door")

func _on_body_exited(body):
	if body == player_in_range:
		player_in_range = null
		print("Player left door")

func open_door():
	if is_open:
		return
	is_open = true
	print("🚪 Door opened with E")
	print("📍 Target scene:", target_scene)

	if target_scene != "":
		# Check if we're completing a task before changing scenes
		if TaskManager:
			print("🔍 DEBUG: TaskManager found")
			if TaskManager.is_task_active():
				var current_target = TaskManager.get_current_task_scene_target()
				print("🔍 DEBUG: Active task target:", current_target)
				print("🔍 DEBUG: Door target scene:", target_scene)
				
				if target_scene.to_lower().contains(current_target.to_lower()):
					print("✅ DEBUG: Target matches! Completing task before scene change")
					TaskManager.complete_current_task()
				else:
					print("⚠️ DEBUG: Target doesn't match - not completing task")
			else:
				print("⚠️ DEBUG: No active task")
		else:
			print("⚠️ DEBUG: TaskManager not found")
		
		print("🔄 DEBUG: Changing scene to:", target_scene)
		var result = get_tree().change_scene_to_file(target_scene)
		if result != OK:
			print("❌ Scene load failed! Check the file path.")
