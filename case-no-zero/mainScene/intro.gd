extends Node2D

@onready var leo_sprite := $leo_mendoza
@onready var label := $RichTextLabel
@onready var bgm_player := $AudioStreamPlayer
@onready var screen_fade := $ScreenFade  

var timeline : Array = []
var index : int = 0
var input_locked : bool = false  

# Fade durations
var text_fade_duration := 0.5
var sprite_fade_duration := 0.5
var scene_fade_duration := 1.0
var audio_fade_duration := 2.0  

func _ready():
	leo_sprite.visible = false
	leo_sprite.modulate.a = 0.0

	# Start background music with fade-in
	if bgm_player and not bgm_player.playing:
		bgm_player.volume_db = -40.0   # start quiet
		bgm_player.play()
		fade_audio_in()

	var file = FileAccess.open("res://json/intro_timeline.json", FileAccess.READ)
	if not file:
		push_error("Cannot open res://json/intro_timeline.json")
		return

	var data = file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(data)
	if typeof(parsed) != TYPE_ARRAY:
		push_error("Timeline JSON is not an array")
		return

	timeline = parsed
	set_process_input(true)
	play_next_event()

# -------------------------
# Scene & Audio Fade-Out helpers
# -------------------------

func fade_screen_out():
	var tween = create_tween()
	tween.tween_property(screen_fade, "color:a", 1.0, scene_fade_duration)
	await tween.finished

func fade_audio_in():
	var tween = create_tween()
	tween.tween_property(bgm_player, "volume_db", 0.0, audio_fade_duration)
	await tween.finished

func fade_audio_out():
	var tween = create_tween()
	tween.tween_property(bgm_player, "volume_db", -40.0, audio_fade_duration)
	await tween.finished

func change_scene_with_fade(scene_path: String):
	# fade out both audio and screen in parallel
	var tween = create_tween()
	tween.parallel().tween_property(screen_fade, "color:a", 1.0, scene_fade_duration)
	tween.parallel().tween_property(bgm_player, "volume_db", -40.0, audio_fade_duration)
	await tween.finished
	get_tree().change_scene_to_file(scene_path)

# -------------------------
# Timeline playback
# -------------------------

func play_next_event():
	if index >= timeline.size():
		await fade_text_out()
		await change_scene_with_fade("res://scenes/next_scene.tscn")
		return  

	input_locked = true 
	var entry = timeline[index]
	index += 1

	match entry.type:
		"narration":
			await fade_text_out()
			label.text = entry.text
			await fade_text_in()
			input_locked = false
			await wait_for_input()
			play_next_event()

		"show_sprite":
			var node = get_node(entry.target)
			if node:
				fade_in(node, sprite_fade_duration)
			input_locked = false
			play_next_event()

		"hide_sprite":
			var node = get_node(entry.target)
			if node:
				fade_out(node, sprite_fade_duration)
			input_locked = false
			play_next_event()

func fade_text_in():
	label.visible = true
	label.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(label, "modulate:a", 1.0, text_fade_duration)
	await tween.finished

func fade_text_out():
	var tween = create_tween()
	tween.tween_property(label, "modulate:a", 0.0, text_fade_duration)
	await tween.finished

func wait_for_input() -> void:
	while true:
		await get_tree().process_frame
		if input_locked:
			continue  
		if Input.is_action_just_pressed("ui_accept") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			break

func _input(event):
	if input_locked:
		return  # prevent double-click
	if event is InputEventKey or event is InputEventMouseButton:
		pass

# Fade-in for sprite
func fade_in(node: Node2D, duration: float = 0.5):
	node.visible = true
	node.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(node, "modulate:a", 1.0, duration)

# Fade-out for sprite
func fade_out(node: Node2D, duration: float = 0.5):
	var tween = create_tween()
	tween.tween_property(node, "modulate:a", 0.0, duration)
	tween.finished.connect(func(): node.visible = false)
