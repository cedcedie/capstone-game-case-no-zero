extends CharacterBody2D

@export var dialogue_file_path: String = "res://data/dialogues/npc_beard_man_dialogue.json"
@export var dialogue_key: String = "npc_beard_man"
@export var default_idle_animation: String = "idle_front"

# Node references
@onready var interaction_label: Label = $Label
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var interaction_area: Area2D = $Area2D

# Dialogue system
var dialogue_lines: Array = []
var dialogue_data: Dictionary = {}
var has_interacted: bool = false
var is_player_nearby: bool = false
var player_reference: Node2D = null
var is_in_dialogue: bool = false
var _player_search_attempted: bool = false
var label_fade_duration: float = 0.3
var label_slide_offset: float = 10.0
var label_show_position: float = -72.0

func _ready():
	interaction_label.modulate = Color(1.0, 1.0, 0.0, 0.0)
	interaction_label.position.y = label_show_position + label_slide_offset
	interaction_label.text = "Press E to interact"
	
	if interaction_area:
		interaction_area.monitoring = true
		interaction_area.monitorable = false
		interaction_area.connect("body_entered", Callable(self, "_on_body_entered"))
		interaction_area.connect("body_exited", Callable(self, "_on_body_exited"))
	
	load_dialogue()
	
	if animated_sprite:
		animated_sprite.play(default_idle_animation)

func _process(_delta):
	if is_player_nearby and Input.is_action_just_pressed("interact") and not is_in_dialogue:
		interact()

func load_dialogue():
	var file: FileAccess = FileAccess.open(dialogue_file_path, FileAccess.READ)
	if file == null:
		push_error("Cannot open dialogue file: " + dialogue_file_path)
		return
	
	var text: String = file.get_as_text()
	file.close()
	
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has(dialogue_key):
		push_error("Failed to parse dialogue file or missing key: " + dialogue_key)
		return
	
	dialogue_data = parsed[dialogue_key]

func _on_body_entered(body):
	if body.name == "PlayerM" and body is CharacterBody2D and body != self:
		is_player_nearby = true
		player_reference = body
		show_interaction_label()

func _on_body_exited(body):
	if body == player_reference:
		is_player_nearby = false
		player_reference = null
		restore_original_animation()
		hide_interaction_label()

func show_interaction_label():
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(interaction_label, "modulate", Color(1.0, 1.0, 0.0, 1.0), label_fade_duration)
	tween.tween_property(interaction_label, "position:y", label_show_position, label_fade_duration)

func hide_interaction_label():
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(interaction_label, "modulate", Color(1.0, 1.0, 0.0, 0.0), label_fade_duration)
	tween.tween_property(interaction_label, "position:y", label_show_position + label_slide_offset, label_fade_duration)

func face_player(player_position: Vector2):
	if not animated_sprite:
		return
	
	var npc_sprite_pos = global_position
	if animated_sprite:
		npc_sprite_pos += animated_sprite.position
	
	var player_pos = player_position
	if player_reference and player_reference.has_node("AnimatedSprite2D"):
		var player_sprite = player_reference.get_node("AnimatedSprite2D")
		if player_sprite:
			player_pos = player_reference.global_position + player_sprite.position
	
	var direction = player_pos - npc_sprite_pos
	
	if not animated_sprite.sprite_frames:
		return
	
	var target_anim = ""
	if abs(direction.x) > abs(direction.y):
		if direction.x > 0:
			target_anim = "idle_right"
		else:
			target_anim = "idle_left"
	else:
		if direction.y > 0:
			target_anim = "idle_front"
		else:
			target_anim = "idle_back"
	
	if animated_sprite.sprite_frames.has_animation(target_anim):
		animated_sprite.play(target_anim)
		animated_sprite.frame = 0

func restore_original_animation():
	animated_sprite.play(default_idle_animation)

func interact():
	is_in_dialogue = true
	hide_interaction_label()
	
	if player_reference:
		face_player(player_reference.global_position)
	else:
		player_reference = _find_player_cached()
		if player_reference:
			face_player(player_reference.global_position)
	
	if player_reference and player_reference.has_method("disable_movement"):
		player_reference.disable_movement()
	
	if not has_interacted:
		dialogue_lines = dialogue_data.get("first_interaction", [])
		has_interacted = true
	else:
		dialogue_lines = dialogue_data.get("repeated_interaction", [])
	
	if dialogue_lines.size() > 0:
		show_dialogue()
	else:
		is_in_dialogue = false
		if player_reference and player_reference.has_method("enable_movement"):
			player_reference.enable_movement()

func _find_player_cached() -> Node2D:
	if player_reference != null:
		return player_reference
	
	if _player_search_attempted:
		return null
	
	_player_search_attempted = true
	
	var root_scene = get_tree().current_scene
	if root_scene:
		var player = root_scene.get_node_or_null("PlayerM")
		if player:
			return player
	
	var player = get_tree().get_first_node_in_group("player")
	if player:
		return player
	
	if root_scene:
		var candidates = root_scene.find_children("*", "", true, false)
		for n in candidates:
			var name_lower = String(n.name).to_lower()
			if name_lower.contains("playerm") or name_lower.contains("player"):
				return n
	
	return null

func show_dialogue():
	if not DialogueUI:
		return
	
	for line in dialogue_lines:
		var speaker = line.get("speaker", "")
		var text = line.get("text", "")
		DialogueUI.show_dialogue_line(speaker, text)
		await DialogueUI.next_pressed
	
	DialogueUI.hide_ui()
	is_in_dialogue = false
	restore_original_animation()
	
	if player_reference and player_reference.has_method("enable_movement"):
		player_reference.enable_movement()
	
	if is_player_nearby:
		show_interaction_label()
