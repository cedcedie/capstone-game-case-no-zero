extends Node2D

@onready var player = $PlayerM
var player_anim: AnimatedSprite2D
@onready var dialogue_label: RichTextLabel = $DialogueLabel
@onready var sfx_knock: AudioStreamPlayer = $KnockSFX  # Add an AudioStreamPlayer with knock sound

var dialogues = []

func _ready():
	# Get AnimatedSprite2D inside PlayerM
	player_anim = player.get_node("AnimatedSprite2D") as AnimatedSprite2D
	if not player_anim:
		push_error("AnimatedSprite2D not found inside PlayerM!")

	# Set initial position and facing
	player.position = Vector2(65, 438)
	player_anim.play("idle_right")

	dialogue_label.bbcode_enabled = true
	dialogue_label.clear()
	dialogue_label.visible = false

	player.control_enabled = false  # disable control during cutscene

	# Load dialogue JSON
	load_dialogue("res://data/bedroom_intro.json")

	# Start cutscene
	start_cutscene()


# Load dialogues from JSON
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


# Cutscene sequence
func start_cutscene():
	# Step 1: initial dialogue
	show_dialogue(dialogues[0]["text"], func():
		# Step 2: "I'm hungry..." dialogue
		show_dialogue(dialogues[1]["text"], func():
			# Step 3: walk sequence
			move_step(Vector2(209, 438), "walk_right", func():
				move_step(Vector2(209, 398), "walk_back", func():
					move_step(Vector2(385, 398), "walk_right", func():
						move_step(Vector2(385, 230), "walk_back", func():
							move_step(Vector2(465, 230), "walk_right", func():
								move_step(Vector2(465, 214), "walk_back", func():
									# Move to fridge coordinates
									move_step(Vector2(497, 207), "walk_right", func():
										# Player reached fridge, play knock SFX
										if sfx_knock:
											sfx_knock.play()
										# Player reacts by looking left
										player_anim.play("idle_left")
										# Dialogue about knock (index 2)
										show_dialogue(dialogues[2]["text"], func():
											player_anim.play("idle_back")
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


# Move player using player.walk_speed
func move_step(target_pos: Vector2, walk_anim: String, callback: Callable):
	player_anim.play(walk_anim)
	var distance = player.position.distance_to(target_pos)
	var duration = distance / player.walk_speed  # match normal walk speed
	var tween = create_tween()
	tween.tween_property(player, "position", target_pos, duration)
	tween.finished.connect(func():
		# Set idle based on last movement
		match walk_anim:
			"walk_right": player_anim.play("idle_right")
			"walk_left": player_anim.play("idle_left")
			"walk_back": player_anim.play("idle_back")
			"walk_front": player_anim.play("idle_front")
		callback.call()
	)


# Show dialogue immediately, then wait for input before continuing
func show_dialogue(text: String, callback: Callable):
	dialogue_label.text = text
	dialogue_label.visible = true
	# Wait for player input (Enter/Space)
	await _wait_for_input()
	# Temporarily hide text to simulate talking
	dialogue_label.visible = false
	callback.call()


# Wait for Enter/Space input
func _wait_for_input() -> void:
	while true:
		await get_tree().process_frame
		if Input.is_action_just_pressed("ui_accept"):
			break
