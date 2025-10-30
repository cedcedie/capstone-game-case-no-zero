extends Node2D

@onready var anim: AnimationPlayer = $AnimationPlayer

var dialogue_lines: Array[Dictionary] = []
var resume_on_next: bool = false
var fade_layer: CanvasLayer
var fade_rect: ColorRect

func _ready() -> void:
	_load_dialogue()
	if DialogueUI and not DialogueUI.next_pressed.is_connected(_on_dialogue_next):
		DialogueUI.next_pressed.connect(_on_dialogue_next)
	_setup_fade()
	# Start cutscene immediately after entering this scene (from intro_story)
	await fade_in(0.25)
	play_cutscene()

func _load_dialogue() -> void:
	var file: FileAccess = FileAccess.open("res://data/dialogues/office_attorney_intro.json", FileAccess.READ)
	if file == null:
		push_error("Cannot open office_attorney_intro.json")
		return
	var text: String = file.get_as_text()
	file.close()
	var parsed: Dictionary = JSON.parse_string(text) as Dictionary
	if parsed.is_empty() or not parsed.has("office_attorney_intro"):
		push_error("Invalid dialogue JSON format")
		return
	var section: Dictionary = parsed["office_attorney_intro"] as Dictionary
	dialogue_lines = (section.get("dialogue_lines", []) as Array[Dictionary])

# Animation hooks (call these from AnimationPlayer 'office_cutscene')
func play_cutscene() -> void:
	if DialogueUI:
		DialogueUI.set_cutscene_mode(true)
	anim.play("office_cutscene")

func show_line(index: int, auto_advance: bool = false) -> void:
	if index < 0 or index >= dialogue_lines.size():
		push_warning("Dialogue index out of range: " + str(index))
		return
	var line: Dictionary = dialogue_lines[index]
	var speaker: String = String(line.get("speaker", ""))
	var text: String = String(line.get("text", ""))
	if DialogueUI:
		DialogueUI.show_dialogue_line(speaker, text, auto_advance)

func show_line_auto(index: int) -> void:
	show_line(index, true)

func next() -> void:
	if DialogueUI and DialogueUI.has_method("_on_next_pressed"):
		DialogueUI._on_next_pressed()

func hide_ui() -> void:
	if DialogueUI:
		DialogueUI.hide_ui()

func wait_for_next() -> void:
	resume_on_next = true
	if anim:
		anim.pause()

func show_line_wait(index: int) -> void:
	# Convenience: show line and immediately pause animation until Next
	show_line(index, false)
	wait_for_next()

func _on_dialogue_next() -> void:
	if resume_on_next and anim:
		resume_on_next = false
		anim.play()

# =============================
# ENV/CHAR HIDE/SHOW + FADE
# =============================
func hide_environment_and_characters() -> void:
	# Hide all TileMapLayer and character instances under this scene
	for child in get_children():
		if child is TileMapLayer:
			child.visible = false
		elif child is Node2D and (child.name == "PlayerM" or child.name == "celine"):
			child.visible = false

func show_environment_and_characters() -> void:
	for child in get_children():
		if child is TileMapLayer:
			child.visible = true
		elif child is Node2D and (child.name == "PlayerM" or child.name == "celine"):
			child.visible = true

func _setup_fade() -> void:
	if fade_layer: return
	fade_layer = CanvasLayer.new()
	add_child(fade_layer)
	fade_rect = ColorRect.new()
	fade_rect.color = Color.BLACK
	fade_rect.visible = true
	fade_rect.modulate.a = 1.0
	fade_rect.anchor_left = 0
	fade_rect.anchor_top = 0
	fade_rect.anchor_right = 1
	fade_rect.anchor_bottom = 1
	fade_rect.offset_left = 0
	fade_rect.offset_top = 0
	fade_rect.offset_right = 0
	fade_rect.offset_bottom = 0
	fade_layer.add_child(fade_rect)

func fade_in(duration: float = 0.3) -> void:
	if not fade_rect: _setup_fade()
	fade_rect.visible = true
	fade_rect.modulate.a = 1.0
	var t := create_tween()
	t.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(fade_rect, "modulate:a", 0.0, duration)
	await t.finished
	fade_rect.visible = false

func fade_out(duration: float = 0.3) -> void:
	if not fade_rect: _setup_fade()
	fade_rect.visible = true
	fade_rect.modulate.a = 0.0
	var t := create_tween()
	t.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(fade_rect, "modulate:a", 1.0, duration)
	await t.finished


