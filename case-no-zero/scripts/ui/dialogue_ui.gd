extends CanvasLayer

@onready var container = $Container
@onready var name_label = $Container/Name
@onready var dialogue_label = $Container/Dialogue
@onready var next_button = $Container/Button
@onready var typing_sound = $Container/TypingSound 
@onready var portrait_rect: TextureRect = $Container/Face/TextureRect if has_node("Container/Face/TextureRect") else null

signal next_pressed
var waiting_for_next: bool = false
var is_typing: bool = false
var typing_speed := 0.01
var cutscene_mode: bool = false
var blip_interval: int = 3  # play a voice blip every N characters

func set_cutscene_mode(enabled: bool) -> void:
	cutscene_mode = enabled
	print("🎬 DialogueUI cutscene mode set to:", enabled)
	# No special handling for cutscene mode - next button works normally

func _ready():
	hide()
	container.modulate.a = 0.0
	next_button.hide()
	next_button.pressed.connect(_on_next_pressed)
	
	# Setup autosizing for labels
	_setup_autosizing()

func _input(event):
	# No special input handling - let the next button handle everything
	pass

# Smooth fade-in
func show_ui():
	show()
	var t = create_tween()
	t.tween_property(container, "modulate:a", 1.0, 0.4)

# Smooth fade-out
func hide_ui():
	var t = create_tween()
	t.tween_property(container, "modulate:a", 0.0, 0.4)
	await t.finished
	hide()

# Typing animation with sound
func show_dialogue_line(speaker: String, text: String) -> void:
	show_ui()
	name_label.text = speaker
	_apply_portrait_for_speaker(speaker)
	next_button.hide()
	dialogue_label.text = ""
	waiting_for_next = false
	is_typing = true

	# Blips are triggered rhythmically during typing; no initial blip

	for i in text.length():
		dialogue_label.text = text.substr(0, i + 1)
		if not typing_sound.playing:
			typing_sound.play() # Play the typing sound each step (short "tick" or "blip" sound works best)
		
		# Play voice blip every few characters during typing (like Undertale)
		if VoiceBlipManager and blip_interval > 0 and i % blip_interval == 0:
			VoiceBlipManager.play_voice_blip(speaker)
		
		await get_tree().create_timer(typing_speed).timeout

	is_typing = false
	# Always show the next button after typing finishes, regardless of cutscene mode
	waiting_for_next = true
	next_button.show() # Show the next button only after typing finishes
	print("🎬 Next button shown after typing finished")

func _apply_portrait_for_speaker(speaker: String) -> void:
	if portrait_rect == null:
		return
	var tex: Texture2D = null
	match speaker.to_lower():
		"miguel":
			tex = load("res://Main_character_closeup.png")
		"erwin", "boy trip":
			tex = load("res://erwin_tambay_closeup.png")
		"celine":
			tex = load("res://new_celine_closeup.png")
		"kapitana palma", "kapitana", "kapitana lourdes":
			tex = load("res://kapitana_palma_closeup.png")
		"po1 darwin", "po1_darwin":
			tex = load("res://po1_closeup.png")
		_:
			tex = null
	portrait_rect.texture = tex

func _setup_autosizing():
	"""Setup scrolling for dialogue UI labels"""
	# Enable scrolling for name label
	if name_label:
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_label.clip_contents = true
		# Use size_flags_vertical for autosizing in Godot 4.4.1
		name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		print("📝 Dialogue UI: Name label scrolling enabled")
	
	# Enable scrolling for dialogue label
	if dialogue_label:
		dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dialogue_label.clip_contents = true
		# Use size_flags_vertical for autosizing in Godot 4.4.1
		dialogue_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		print("📝 Dialogue UI: Dialogue label scrolling enabled")

func _on_next_pressed():
	if cutscene_mode:
		# In cutscene mode, emit signal immediately when input is received
		emit_signal("next_pressed")
		return
	if waiting_for_next and not is_typing:
		waiting_for_next = false
		next_button.hide()
		emit_signal("next_pressed")
