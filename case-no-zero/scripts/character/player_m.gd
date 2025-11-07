extends CharacterBody2D

@export var walk_speed: float = 200.0
@export var run_speed: float = 400.0
@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D

var direction: Vector2 = Vector2.ZERO
var last_facing: String = "down"
var control_enabled: bool = true
var last_direction: Vector2 = Vector2.ZERO

func _ready() -> void:
	_check_and_reposition_based_on_entry()
	
	if Engine.has_singleton("Minimap"):
		Minimap.set_player(self)
		var map_node := get_tree().current_scene.get_node_or_null("Map")
		if map_node:
			Minimap.load_map(map_node)
func _check_and_reposition_based_on_entry():
	"""Check if we need to reposition based on entry point"""
	if not has_node("/root/SpawnManager"):
		return
	
	var spawn_manager = get_node("/root/SpawnManager")
	var scene_name = get_tree().current_scene.scene_file_path.get_file().get_basename()
	var spawn_data = spawn_manager.get_spawn_data(scene_name)
	
	if not spawn_data.is_empty():
		global_position = spawn_data.position
		var animation = spawn_data.animation
		anim_sprite.play(animation)
		
		if animation.contains("down"):
			last_facing = "down"
		elif animation.contains("back"):
			last_facing = "back"
		elif animation.contains("left"):
			last_facing = "left"
		elif animation.contains("right"):
			last_facing = "right"
	
	spawn_manager.clear_entry_point()


func disable_movement():
	control_enabled = false
	anim_sprite.play("idle_" + last_facing)

func enable_movement():
	control_enabled = true

func get_camera() -> Camera2D:
	return $Camera2D


func _physics_process(_delta: float) -> void:
	if control_enabled:
		_handle_input()
	else:
		velocity = Vector2.ZERO
		move_and_slide()


func _handle_input() -> void:
	direction = Vector2.ZERO

	# 4-directional movement only (no diagonals)
	var pressed_directions = []

	if Input.is_action_pressed("ui_right"):
		pressed_directions.append(Vector2.RIGHT)
	if Input.is_action_pressed("ui_left"):
		pressed_directions.append(Vector2.LEFT)
	if Input.is_action_pressed("ui_down"):
		pressed_directions.append(Vector2.DOWN)
	if Input.is_action_pressed("ui_up"):
		pressed_directions.append(Vector2.UP)

	if pressed_directions.size() > 0:
		if Input.is_action_just_pressed("ui_right"):
			direction = Vector2.RIGHT
			last_direction = Vector2.RIGHT
		elif Input.is_action_just_pressed("ui_left"):
			direction = Vector2.LEFT
			last_direction = Vector2.LEFT
		elif Input.is_action_just_pressed("ui_down"):
			direction = Vector2.DOWN
			last_direction = Vector2.DOWN
		elif Input.is_action_just_pressed("ui_up"):
			direction = Vector2.UP
			last_direction = Vector2.UP
		else:
			if last_direction in pressed_directions:
				direction = last_direction
			else:
				direction = pressed_directions[0]
				last_direction = direction

	var current_speed = walk_speed
	if Input.is_action_pressed("ui_select"):
		current_speed = run_speed
		anim_sprite.speed_scale = 2.0
	else:
		anim_sprite.speed_scale = 1.0

	velocity = direction * current_speed
	move_and_slide()

	_update_animation(direction)


func _update_animation(dir: Vector2) -> void:
	if dir == Vector2.ZERO:
		if last_facing == "front":
			last_facing = "down"
		anim_sprite.play("idle_" + last_facing)
	else:
		if abs(dir.x) > abs(dir.y):
			last_facing = "right" if dir.x > 0 else "left"
		else:
			last_facing = "down" if dir.y > 0 else "back"

		anim_sprite.play("walk_" + last_facing)
