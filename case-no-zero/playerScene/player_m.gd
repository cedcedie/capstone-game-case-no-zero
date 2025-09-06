extends CharacterBody2D

@export var walk_speed: float = 200.0
@export var run_speed: float = 400.0
@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D

var direction: Vector2 = Vector2.ZERO
var last_facing: String = "front"

func _physics_process(delta: float) -> void:
	direction = Vector2.ZERO

	if Input.is_action_pressed("ui_right"):
		direction.x += 1
	if Input.is_action_pressed("ui_left"):
		direction.x -= 1
	if Input.is_action_pressed("ui_down"):
		direction.y += 1
	if Input.is_action_pressed("ui_up"):
		direction.y -= 1

	direction = direction.normalized()

	var current_speed = walk_speed
	if Input.is_action_pressed("ui_select"):
		current_speed = run_speed
		anim_sprite.speed_scale = 2.0  
	else:
		anim_sprite.speed_scale = 1.0   

	velocity = direction * current_speed
	move_and_slide()

	if direction == Vector2.ZERO:
		anim_sprite.play("idle_" + last_facing)
	else:
		if abs(direction.x) > abs(direction.y):
			last_facing = "right" if direction.x > 0 else "left"
		else:
			last_facing = "front" if direction.y > 0 else "back"

		anim_sprite.play("walk_" + last_facing)
