extends CharacterBody2D

# Walking pattern variables
var walk_speed: float = 50.0
var current_destination: int = 0
var is_walking: bool = false
var is_reverse: bool = false  # Track if walking in reverse

# Animation reference
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

# Rectangle path points
var path_points: Array[Vector2] = [
	Vector2(160.0, 1387.0),    # Start point
	Vector2(160.0, 480.0),     # Go up
	Vector2(2464.0, 480.0),   # Go right
	Vector2(2464.0, 1422.0),  # Go down
	Vector2(160.0, 1387.0)    # Return to start
]

func _ready():
	# Check if NPC is already at the end point, if so, start from there
	check_initial_position()
	# Start walking
	start_walking()

func check_initial_position():
	"""Check if NPC spawns at end point and adjust accordingly"""
	var current_pos = global_position
	
	# Check if we're close to the last point (end of rectangle)
	if current_pos.distance_to(path_points[3]) < 50.0:  # Close to (2464, 1422)
		print("📍 NPC spawned at end point, will return to start")
		current_destination = 4  # Start from return to start
	else:
		# Normal start from beginning
		global_position = path_points[0]
		print("📍 NPC spawned at start point")

func _physics_process(delta):
	if is_walking:
		move_to_next_point()

func start_walking():
	is_walking = true
	# If current_destination is already set by check_initial_position, use it
	# Otherwise, start from the beginning
	if current_destination == 0:
		current_destination = 1  # Start moving to second point
	print("🚶 NPC started walking rectangle pattern from point: ", current_destination)

func move_to_next_point():
	if not is_reverse:
		# Forward direction
		if current_destination >= path_points.size():
			# Completed forward path, start reverse
			is_reverse = true
			current_destination = path_points.size() - 2  # Start from second to last point
			print("🔄 NPC completed forward path, starting reverse...")
	else:
		# Reverse direction
		if current_destination < 0:
			# Completed reverse path, start forward again
			is_reverse = false
			current_destination = 1  # Start from second point
			print("🔄 NPC completed reverse path, starting forward...")
	
	var target_position = path_points[current_destination]
	var direction = (target_position - global_position).normalized()
	
	# Determine walking direction and play appropriate animation
	update_walking_animation(direction)
	
	# Move towards target
	velocity = direction * walk_speed
	move_and_slide()
	
	# Check if we've reached the destination
	if global_position.distance_to(target_position) < 10.0:
		# Reached destination, move to next point
		if is_reverse:
			current_destination -= 1  # Go backwards in reverse
		else:
			current_destination += 1  # Go forwards normally
		
		print("📍 NPC reached point ", current_destination + (1 if is_reverse else 0), ": ", target_position)
		
		# Stop briefly at each corner
		velocity = Vector2.ZERO
		play_idle_animation()
		await get_tree().create_timer(0.5).timeout  # Brief pause at corners

func update_walking_animation(direction: Vector2):
	"""Update animation based on walking direction"""
	if not animated_sprite:
		return
	
	# Determine primary direction
	if abs(direction.x) > abs(direction.y):
		# Moving horizontally
		if direction.x > 0:
			# Moving right
			animated_sprite.play("walk_right")
		else:
			# Moving left
			animated_sprite.play("walk_left")
	else:
		# Moving vertically
		if direction.y > 0:
			# Moving down
			animated_sprite.play("walk_down")
		else:
			# Moving up
			animated_sprite.play("walk_back")

func play_idle_animation():
	"""Play idle animation when stopped"""
	if not animated_sprite:
		return
	
	# Play idle animation based on last direction
	# You can customize this based on your idle animation names
	animated_sprite.play("idle")

func stop_walking():
	is_walking = false
	velocity = Vector2.ZERO
	play_idle_animation()
	print("🛑 NPC stopped walking")

func resume_walking():
	if not is_walking:
		is_walking = true
		print("🚶 NPC resumed walking")
