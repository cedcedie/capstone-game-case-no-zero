extends Node

# --- Node references ---
@onready var dialogue_ui: Control = $CanvasLayer/DialogueUi
@onready var player: CharacterBody2D = $PlayerM
@onready var celine: CharacterBody2D = $Celine
@onready var knock_sfx: AudioStreamPlayer = $KnockSFX
@onready var bgm_mystery: AudioStreamPlayer = $BGM_Mystery
@onready var cinematic_text: RichTextLabel = $CanvasLayer/CinematicText
@onready var fade_overlay: ColorRect = $CanvasLayer/FadeOverlay
@onready var tilemaps: Array = [$"Ground layer", $"border layer", $misc, $uppermisc , $upperuppermisc]

# --- Dialogue data ---
var dialogue_lines: Array = []
var current_line: int = 0
var waiting_for_next: bool = false

# --- Movement tuning ---
@export var walk_speed: float = 200.0  # match player speed

# --------------------------
# STEP 1: Load JSON dialogue
# --------------------------
func load_dialogue() -> void:
	var file: FileAccess = FileAccess.open("res://dialogue/mainStory/Intro.json", FileAccess.READ)
	if file == null:
		push_error("Cannot open Intro.json")
		return

	var text: String = file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("Intro"):
		push_error("Failed to parse Intro.json correctly")
		return

	dialogue_lines = parsed["Intro"]
	current_line = 0
	print("✅ Loaded dialogue lines:", dialogue_lines.size())

# --------------------------
# STEP 2: Start intro
# --------------------------
func start_intro() -> void:
	print("🎬 Intro starting...")
	load_dialogue()

	# Disable player control
	if "control_enabled" in player:
		player.control_enabled = false

	# Setup initial states
	player.anim_sprite.play("idle_front")
	player.last_facing = "front"

	celine.position = Vector2(49, 86)
	celine.visible = false

	fade_overlay.visible = false
	cinematic_text.visible = false

	await get_tree().create_timer(1.0).timeout
	show_next_line()

# --------------------------
# STEP 3–19: Show dialogue lines
# --------------------------
func show_next_line() -> void:
	if current_line >= dialogue_lines.size():
		end_intro()
		return

	var line: Dictionary = dialogue_lines[current_line]
	var speaker: String = String(line.get("speaker", ""))
	var text: String = String(line.get("text", ""))

	print("🗨️ Showing line", current_line, "Speaker:", speaker)

	match current_line:
		0:
			player.anim_sprite.play("idle_front")
			dialogue_ui.show_dialogue_line(speaker, text)
			waiting_for_next = true

		1:
			dialogue_ui.hide()
			if knock_sfx:
				knock_sfx.play()
				await knock_sfx.finished
			player.anim_sprite.play("idle_left")
			await get_tree().create_timer(0.5).timeout
			dialogue_ui.show()
			dialogue_ui.show_dialogue_line(speaker, text)
			waiting_for_next = true

		2:
			dialogue_ui.hide()
			celine.visible = true
			if "anim_sprite" in celine:
				celine.anim_sprite.play("walk_down")
			var start_pos: Vector2 = celine.position
			var end_pos: Vector2 = Vector2(49, 206)
			var distance: float = start_pos.distance_to(end_pos)
			var duration: float = distance / walk_speed
			var t: Tween = create_tween()
			t.tween_property(celine, "position", end_pos, duration)
			await t.finished
			if "anim_sprite" in celine:
				celine.anim_sprite.play("idle_right")
			player.anim_sprite.play("idle_left")
			await get_tree().create_timer(0.4).timeout
			player.anim_sprite.play("idle_right")
			await get_tree().create_timer(0.4).timeout
			dialogue_ui.show()
			dialogue_ui.show_dialogue_line(speaker, text)
			waiting_for_next = true

		3:
			player.anim_sprite.play("idle_right")
			dialogue_ui.show_dialogue_line(speaker, text)
			waiting_for_next = true

		4:
			player.anim_sprite.play("idle_chuckle")
			player.last_facing = "right"
			await get_tree().create_timer(0.3).timeout
			dialogue_ui.show_dialogue_line(speaker, text)
			waiting_for_next = true

		5:
			dialogue_ui.show_dialogue_line(speaker, text)
			waiting_for_next = true

		6:
			player.anim_sprite.play("idle_left")
			await get_tree().create_timer(0.3).timeout
			dialogue_ui.show_dialogue_line(speaker, text)
			waiting_for_next = true

		7:
			if celine:
				celine.anim_sprite.play("walk_right")
				var start_pos: Vector2 = celine.position
				var end_pos: Vector2 = Vector2(177, celine.position.y)
				var distance: float = start_pos.distance_to(end_pos)
				var duration: float = distance / walk_speed
				var t: Tween = create_tween()
				t.tween_property(celine, "position", end_pos, duration)
				await t.finished
				celine.anim_sprite.play("idle_right")
			dialogue_ui.show_dialogue_line(speaker, text)
			waiting_for_next = true

		8, 9:
			player.anim_sprite.play("idle_front")
			dialogue_ui.show_dialogue_line(speaker, text)
			waiting_for_next = true
			if bgm_mystery and not bgm_mystery.playing:
				bgm_mystery.volume_db = -20
				bgm_mystery.play()
				var fade: Tween = create_tween()
				fade.tween_property(bgm_mystery, "volume_db", 0, 2.0)

		10, 11, 12, 13, 14, 15:
			dialogue_ui.show_dialogue_line(speaker, text)
			waiting_for_next = true

		16, 17, 18:
			# Lines 17–19: normal dialogue before cinematic
			dialogue_ui.show_dialogue_line(speaker, text)
			waiting_for_next = true

		19:
			# Final cinematic line
			await start_final_line_cinematic(text)

# --------------------------
# STEP 4: On next pressed
# --------------------------
func _on_next_pressed() -> void:
	if waiting_for_next:
		waiting_for_next = false
		current_line += 1
		show_next_line()

# --------------------------
# STEP 5: Final cinematic
# --------------------------
func start_final_line_cinematic(text: String) -> void:
	# Hide everything else
	dialogue_ui.hide()
	celine.visible = false
	for tilemap in tilemaps:
		tilemap.visible = false

	# Fade overlay in
	fade_overlay.visible = true
	fade_overlay.modulate.a = 0
	var fade_in: Tween = create_tween()
	fade_in.tween_property(fade_overlay, "modulate:a", 0.8, 1.0)
	await fade_in.finished

	# Center player
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	player.position = viewport_size / 2


	# Show cinematic text
	cinematic_text.visible = true
	cinematic_text.bbcode_text = "[center]" + text + "[/center]"
	cinematic_text.modulate.a = 0
	var text_fade: Tween = create_tween()
	text_fade.tween_property(cinematic_text, "modulate:a", 1.0, 1.0)
	await text_fade.finished

	# Hold cinematic
	await get_tree().create_timer(2.0).timeout

	# Fade out text & overlay
	var fade_out: Tween = create_tween()
	fade_out.tween_property(cinematic_text, "modulate:a", 0.0, 1.0)
	fade_out.tween_property(fade_overlay, "modulate:a", 0.0, 1.0)
	await fade_out.finished

	# Hide overlay & text
	cinematic_text.visible = false
	fade_overlay.visible = false

	# Restore bedroom scene (tilemaps visible)
	for tilemap in tilemaps:
		tilemap.visible = true

	# Re-enable player control
	if "control_enabled" in player:
		player.control_enabled = true
	print("🎬 Final cinematic done — control re-enabled.")

# --------------------------
# STEP 6: Ready
# --------------------------
func _ready() -> void:
	await get_tree().process_frame

	if dialogue_ui:
		var cb: Callable = Callable(self, "_on_next_pressed")
		if not dialogue_ui.is_connected("next_pressed", cb):
			dialogue_ui.connect("next_pressed", cb)

	print("🟢 Scene ready — starting intro...")
	start_intro()
func end_intro() -> void:
	# Just in case something reaches here without cinematic
	print("✅ Intro complete — control re-enabled.")
	if "control_enabled" in player:
		player.control_enabled = true
