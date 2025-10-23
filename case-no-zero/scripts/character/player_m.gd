extends CharacterBody2D

@export var walk_speed: float = 200.0
@export var run_speed: float = 400.0
@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D

var direction: Vector2 = Vector2.ZERO
var last_facing: String = "down"
var control_enabled: bool = true   # can the player move?
var last_direction: Vector2 = Vector2.ZERO  # Track last movement direction

# Add this new function
func _ready():
	# Wait a frame to ensure scene is fully loaded
	await get_tree().process_frame
	
	# Check if we need to reposition based on entry point
	_check_and_reposition_based_on_entry()

func _check_and_reposition_based_on_entry():
	"""Check if we need to reposition based on entry point"""
	# print("🔍 Player: Checking for repositioning...")
	
	if not has_node("/root/SpawnManager"):
		# print("⚠️ Player: SpawnManager not found!")
		return
	
	var spawn_manager = get_node("/root/SpawnManager")
	var scene_name = get_tree().current_scene.scene_file_path.get_file().get_basename()
	# print("🔍 Player: Current scene name: ", scene_name)
	# print("🔍 Player: SpawnManager entry_point: ", spawn_manager.entry_point)
	
	var spawn_data = spawn_manager.get_spawn_data(scene_name)
	# print("🔍 Player: Spawn data: ", spawn_data)
	
	if not spawn_data.is_empty():
		# Set position
		global_position = spawn_data.position
		
		# Set animation and facing direction
		var animation = spawn_data.animation
		anim_sprite.play(animation)
		
		# Update last_facing based on animation
		if animation.contains("down"):
			last_facing = "down"
		elif animation.contains("back"):
			last_facing = "back"
		elif animation.contains("left"):
			last_facing = "left"
		elif animation.contains("right"):
			last_facing = "right"
		
		# print("📍 Player: Repositioned to ", spawn_data.position, " with animation ", animation, " for scene ", scene_name)
	else:
		# print("⚠️ Player: No spawn data found, using default position")
		pass
	
	# Clear the entry point after use
	spawn_manager.clear_entry_point()

# Function to disable movement (called by NPCs during dialogue)
func disable_movement():
	control_enabled = false
	# Stop animation and set to idle
	anim_sprite.play("idle_" + last_facing)
	# print("🚫 Player movement DISABLED - control_enabled = false")
	print_stack()  # Print call stack to see who called this

# Function to enable movement (called by NPCs after dialogue)
func enable_movement():
	control_enabled = true
	# print("✅ Player movement ENABLED - control_enabled = true")
	print_stack()  # Print call stack to see who called this

# Function to get camera reference
func get_camera() -> Camera2D:
	return $Camera2D

func _physics_process(_delta: float) -> void:
	if control_enabled:
		_handle_input()
	else:
		velocity = Vector2.ZERO
		move_and_slide()


# --------------------
# INPUT + MOVEMENT
# --------------------
func _handle_input() -> void:
	direction = Vector2.ZERO

	# 4-directional movement only (no diagonals)
	# Check all currently pressed keys and use the most recent one
	var pressed_directions = []
	
	# Collect all currently pressed directions
	if Input.is_action_pressed("ui_right"):
		pressed_directions.append(Vector2.RIGHT)
	if Input.is_action_pressed("ui_left"):
		pressed_directions.append(Vector2.LEFT)
	if Input.is_action_pressed("ui_down"):
		pressed_directions.append(Vector2.DOWN)
	if Input.is_action_pressed("ui_up"):
		pressed_directions.append(Vector2.UP)
	
	# If any keys are pressed, choose the direction
	if pressed_directions.size() > 0:
		# If multiple keys are pressed, prioritize the most recently pressed one
		# Check for newly pressed keys first
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
			# No new key pressed, continue in last direction if it's still held
			if last_direction in pressed_directions:
				direction = last_direction
			else:
				# Last direction not held, use the first available direction
				direction = pressed_directions[0]
				last_direction = direction

	var current_speed = walk_speed
	if Input.is_action_pressed("ui_select"):  # run key
		current_speed = run_speed
		anim_sprite.speed_scale = 2.0
	else:
		anim_sprite.speed_scale = 1.0

	velocity = direction * current_speed
	move_and_slide()

	_update_animation(direction)


func _update_animation(dir: Vector2) -> void:
	if dir == Vector2.ZERO:
		# Safety check: ensure last_facing is valid for player animations
		if last_facing == "front":
			last_facing = "down"  # Player doesn't have idle_front, use idle_down instead
		anim_sprite.play("idle_" + last_facing)
	else:
		if abs(dir.x) > abs(dir.y):
			last_facing = "right" if dir.x > 0 else "left"
		else:
			last_facing = "down" if dir.y > 0 else "back"

		anim_sprite.play("walk_" + last_facing)
