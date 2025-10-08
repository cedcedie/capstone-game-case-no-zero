extends Node

# --- Node references ---
@onready var dialogue_ui: Control = $CanvasLayer/DialogueUi
@onready var player: CharacterBody2D = $PlayerM
@onready var celine: CharacterBody2D = $Celine
@onready var knock_sfx: AudioStreamPlayer = $KnockSFX

# --- Dialogue data ---
var dialogue_lines: Array = []
var current_line: int = 0
var waiting_for_next: bool = false

# --- Movement tuning ---
@export var walk_speed: float = 200.0  # match player movement speed


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

	await get_tree().create_timer(1.0).timeout
	show_next_line()


# --------------------------
# STEP 3–5: Show dialogue line
# --------------------------
func show_next_line() -> void:
	if current_line >= dialogue_lines.size():
		print("⚡ End of dialogue reached for Step 5")
		return

	var line: Dictionary = dialogue_lines[current_line]
	var speaker: String = String(line.get("speaker", ""))
	var text: String = String(line.get("text", ""))

	print("🗨️ Showing line", current_line, "Speaker:", speaker)

	match current_line:
		0:
			# Step 1: Miguel idle front, first line
			player.anim_sprite.play("idle_front")
			dialogue_ui.show_dialogue_line(speaker, text)
			waiting_for_next = true

		1:
			# Step 2: Knock + Miguel peek left
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
			# Step 3: Celine enters
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

			# Miguel peek: left then right
			player.anim_sprite.play("idle_left")
			await get_tree().create_timer(0.4).timeout
			player.anim_sprite.play("idle_right")
			await get_tree().create_timer(0.4).timeout

			dialogue_ui.show()
			dialogue_ui.show_dialogue_line(speaker, text)
			waiting_for_next = true

		3:
			# Step 4: Miguel reacts idle right
			player.anim_sprite.play("idle_right")
			dialogue_ui.show()
			dialogue_ui.show_dialogue_line(speaker, text)
			waiting_for_next = true

		4:
			# Step 5: Miguel banter continues, facing right away from Celine
			dialogue_ui.hide()

			# Optional: subtle idle/chuckle animation
			if "anim_sprite" in player:
				player.anim_sprite.play("idle_chuckle")  # fallback to idle_right if not available

			player.last_facing = "right"  # facing away

			await get_tree().create_timer(0.3).timeout
			dialogue_ui.show()
			dialogue_ui.show_dialogue_line(speaker, text)
			waiting_for_next = true

		_:
			print("📘 End of Step 5 sequence")
			dialogue_ui.hide()


# --------------------------
# STEP 6: On next pressed
# --------------------------
func _on_next_pressed() -> void:
	print("➡️ Next pressed, waiting:", waiting_for_next)
	if waiting_for_next:
		waiting_for_next = false
		current_line += 1
		show_next_line()


# --------------------------
# STEP 7: End intro
# --------------------------
func end_intro() -> void:
	dialogue_ui.hide()
	if "control_enabled" in player:
		player.control_enabled = true
	print("✅ Intro complete — control re-enabled.")


# --------------------------
# STEP 8: Ready
# --------------------------
func _ready() -> void:
	await get_tree().process_frame  # ensure all nodes ready

	if dialogue_ui:
		var cb: Callable = Callable(self, "_on_next_pressed")
		if not dialogue_ui.is_connected("next_pressed", cb):
			dialogue_ui.connect("next_pressed", cb)

	print("🟢 Scene ready — starting intro...")
	start_intro()
