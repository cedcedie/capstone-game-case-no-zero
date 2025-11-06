extends CharacterBody2D

var walk_speed: float = 50.0
var current_destination: int = 1
var going_backward: bool = false
var is_waiting: bool = false
var last_direction: String = "down"

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

# ✅ EDIT THESE PATH POINTS IF YOU WANT NEW DESTINATIONS
var path_points: Array[Vector2] = [
	Vector2(853.0, 836.0),
	Vector2(920.0, 836.0),
	Vector2(920.0, 704.0),
	Vector2(976.0, 704.0),
	Vector2(976.0, 581.0)
]

func _ready():
	global_position = path_points[0]

func _physics_process(delta):
	if not is_waiting:
		move_to_next_point()

func move_to_next_point():
	var target = path_points[current_destination]
	var diff = target - global_position

	# ✅ Close enough → stop once, wait, then continue
	if diff.length() < 2 and not is_waiting:
		is_waiting = true
		global_position = target  # Snap into exact point
		velocity = Vector2.ZERO
		play_idle_animation()
		
		# ✅ Only wait at first (index 0) and last (index size-1) destinations
		if current_destination == 0 or current_destination == path_points.size() - 1:
			await wait_before_move()  # Random wait 10-20s
		else:
			# Middle destinations: very brief pause (0.1s) or no wait
			await get_tree().create_timer(0.1).timeout
		
		advance_destination()
		return

	# ✅ Normal walking movement
	var dir = diff.normalized()
	update_walking_animation(dir)
	velocity = dir * walk_speed
	move_and_slide()

func wait_before_move() -> void:
	# ✅ Random pause at first/last destination only (adjust if needed)
	var wait_time: float = randf_range(10.0, 20.0)
	await get_tree().create_timer(wait_time).timeout

func advance_destination():
	# ✅ Forward movement in array
	if not going_backward:
		current_destination += 1
		if current_destination >= path_points.size():
			current_destination = path_points.size() - 2
			going_backward = true

	# ✅ Reverse movement
	else:
		current_destination -= 1
		if current_destination < 0:
			current_destination = 1
			going_backward = false

	is_waiting = false  # ✅ Allow moving again

func update_walking_animation(dir: Vector2):
	if abs(dir.x) > abs(dir.y):
		if dir.x > 0:
			animated_sprite.play("walk_right")
			last_direction = "right"
		else:
			animated_sprite.play("walk_left")
			last_direction = "left"
	else:
		if dir.y > 0:
			animated_sprite.play("walk_down")
			last_direction = "down"
		else:
			animated_sprite.play("walk_back")
			last_direction = "up"

func play_idle_animation():
	# ✅ Play read_front only at first (index 0) and last (index size-1) positions
	# For all other destinations, use direction-based idle animation
	if current_destination == 0 or current_destination == path_points.size() - 1:
		animated_sprite.play("read_front")
	else:
		# Use direction-based idle animation for middle destinations
		match last_direction:
			"right": animated_sprite.play("idle_right")
			"left": animated_sprite.play("idle_left")
			"up": animated_sprite.play("idle_back")
			"down": animated_sprite.play("idle_front")
