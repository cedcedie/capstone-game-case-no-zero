extends CharacterBody2D

@export var walk_speed: float = 200.0
@export var run_speed: float = 400.0
@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D

var direction: Vector2 = Vector2.ZERO
var last_facing: String = "front"
var control_enabled: bool = true


func _physics_process(delta: float) -> void:
	if control_enabled:
		_handle_input()
	else:
		velocity = Vector2.ZERO
		move_and_slide()


func _handle_input() -> void:
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

	_update_animation(direction)


func _update_animation(dir: Vector2) -> void:
	if dir == Vector2.ZERO:
		anim_sprite.play("idle_" + last_facing)
	else:
		if abs(dir.x) > abs(dir.y):
			last_facing = "right" if dir.x > 0 else "left"
		else:
			last_facing = "front" if dir.y > 0 else "back"

		anim_sprite.play("walk_" + last_facing)


# --- Helpers for cutscenes ---
func play_animation(anim_name: String) -> void:
	if anim_sprite.has_animation(anim_name):
		anim_sprite.play(anim_name)


func face_direction(direction: String) -> void:
	last_facing = direction
	if anim_sprite.has_animation("idle_" + direction):
		anim_sprite.play("idle_" + direction)
