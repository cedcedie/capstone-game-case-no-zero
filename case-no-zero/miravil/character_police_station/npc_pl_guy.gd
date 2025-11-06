extends CharacterBody2D

var walk_speed: float = 50.0
var current_destination: int = 1
var is_reverse: bool = false
var last_direction: String = "down"  # Track the last direction faced

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var path_points := [
	Vector2(603.0, 1426.0),
	Vector2(603.0, 1426.0),
	Vector2(603.0, 1426.0),
	Vector2(603.0, 1426.0),
]

func _ready():
	global_position = path_points[0]
	start_walking()

func _physics_process(delta):
	move_to_next_point()

func start_walking():
	velocity = Vector2.ZERO

func move_to_next_point():
	var target_position = path_points[current_destination]
	var direction = (target_position - global_position).normalized()

	update_walking_animation(direction)

	velocity = direction * walk_speed
	move_and_slide()

	if global_position.distance_to(target_position) < 8:
		await stop_at_corner()

		if not is_reverse:
			current_destination += 1
			if current_destination >= path_points.size():
				is_reverse = true
				current_destination = path_points.size() - 2
		else:
			current_destination -= 1
			if current_destination < 0:
				is_reverse = false
				current_destination = 1

func stop_at_corner():
	velocity = Vector2.ZERO
	play_idle_animation()
	await get_tree().create_timer(0.6).timeout

func update_walking_animation(direction: Vector2):
	if abs(direction.x) > abs(direction.y):
		if direction.x > 0:
			animated_sprite.play("walk_right")
			last_direction = "right"
		else:
			animated_sprite.play("walk_left")
			last_direction = "left"
	else:
		if direction.y > 0:
			animated_sprite.play("walk_down")
			last_direction = "down"
		else:
			animated_sprite.play("walk_back")
			last_direction = "up"

func play_idle_animation():
	match last_direction:
		"right":
			animated_sprite.play("idle_right")
		"left":
			animated_sprite.play("idle_left")
		"up":
			animated_sprite.play("idle_back")
		"down":
			animated_sprite.play("idle_front")
