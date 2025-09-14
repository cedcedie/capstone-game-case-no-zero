extends Node2D

@onready var player = $PlayerM
var player_anim: AnimatedSprite2D
@onready var dialogue_label: RichTextLabel = $RichTextLabel

var dialogues = []

func _ready():
	player_anim = player.get_node("AnimatedSprite2D") as AnimatedSprite2D
	if not player_anim:
		push_error("AnimatedSprite2D not found inside PlayerM!")

	# Correct first position and facing
	player.position = Vector2(65, 438)
	player_anim.play("idle_right")

	dialogue_label.bbcode_enabled = true
	dialogue_label.clear()
	dialogue_label.visible = false
	player.control_enabled = false

	load_dialogue("res://data/bedroom_intro.json")
	start_cutscene()


func load_dialogue(path: String) -> void:
	var file = FileAccess.open(path, FileAccess.READ)
	if file:
		var text = file.get_as_text()
		var parsed = JSON.parse_string(text)
		if typeof(parsed) == TYPE_DICTIONARY and parsed.has("dialogues"):
			dialogues = parsed["dialogues"]
		else:
			push_error("JSON parse failed or missing 'dialogues'")
	else:
		push_error("Cannot open JSON file")


func start_cutscene():
	show_dialogue(dialogues[0]["text"], func():
		move_step(Vector2(209, 438), "walk_right", func():
			move_step(Vector2(209, 398), "walk_back", func():
				move_step(Vector2(385, 398), "walk_right", func():
					move_step(Vector2(385, 230), "walk_back", func():
						move_step(Vector2(465, 230), "walk_right", func():
							move_step(Vector2(465, 214), "walk_back", func():
								move_step(Vector2(497, 214), "walk_right", func():
									move_step(Vector2(497, 206), "walk_back", func():
										player_anim.play("idle_back")
										# Final dialogue after walking
										show_dialogue(dialogues[1]["text"], func():
											player.control_enabled = true
										)
									)
								)
							)
						)
					)
				)
			)
		)
	)


# Move player using actual walk_speed
func move_step(target_pos: Vector2, walk_anim: String, callback: Callable):
	player_anim.play(walk_anim)
	var distance = player.position.distance_to(target_pos)
	var duration = distance / player.walk_speed  # use player's walk speed
	var tween = create_tween()
	tween.tween_property(player, "position", target_pos, duration)
	tween.finished.connect(func():
		# Set idle based on last direction
		if walk_anim.ends_with("right"):
			player_anim.play("idle_right")
		elif walk_anim.ends_with("left"):
			player_anim.play("idle_left")
		elif walk_anim.ends_with("front"):
			player_anim.play("idle_front")
		elif walk_anim.ends_with("back"):
			player_anim.play("idle_back")
		callback.call()
	)


func show_dialogue(text: String, callback: Callable):
	dialogue_label.text = text
	dialogue_label.visible = true
	await _wait_for_input()
	dialogue_label.visible = false
	callback.call()


func _wait_for_input() -> void:
	while true:
		await get_tree().process_frame
		if Input.is_action_just_pressed("ui_accept"):
			break
