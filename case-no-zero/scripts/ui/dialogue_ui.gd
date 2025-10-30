extends CanvasLayer

@onready var container = $Container
@onready var name_label = $Container/Name
@onready var dialogue_label: RichTextLabel = $Container/Dialogue
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
func show_dialogue_line(speaker: String, text: String, auto_advance: bool = false) -> void:
	show_ui()
	name_label.text = speaker
	_apply_portrait_for_speaker(speaker)
	next_button.hide()  # Hide next button during typing

	# If this is an internal thought, do not display and auto-advance
	var trimmed := text.strip_edges()
	var is_internal_thought := trimmed.begins_with("*thinking*") or trimmed.begins_with("[thought]")
	if is_internal_thought:
		# Skip showing UI for internal thoughts
		hide_ui()
		waiting_for_next = false
		is_typing = false
		# Immediately advance to next line
		emit_signal("next_pressed")
		return
	
	# Convert **text** to [b]text[/b] for BBCode
	var bbcode_text = text.replace("**", "[b]").replace("**", "[/b]")
	# Fix the conversion by doing it properly
	bbcode_text = text.replace("**", "[b]").replace("**", "[/b]")
	# Better approach: replace **text** with [b]text[/b]
	var regex = RegEx.new()
	regex.compile("\\*\\*(.*?)\\*\\*")
	bbcode_text = regex.sub(bbcode_text, "[b]$1[/b]")
	
	dialogue_label.text = ""
	waiting_for_next = false
	is_typing = true
	print("⌨️ Starting typing animation for:", speaker)

	# Blips are triggered rhythmically during typing; no initial blip

	for i in bbcode_text.length():
		dialogue_label.text = bbcode_text.substr(0, i + 1)
		if not typing_sound.playing:
			typing_sound.play() # Play the typing sound each step (short "tick" or "blip" sound works best)
		
		# Play voice blip every few characters during typing (like Undertale)
		if VoiceBlipManager and blip_interval > 0 and i % blip_interval == 0:
			VoiceBlipManager.play_voice_blip(speaker)
		
		await get_tree().create_timer(typing_speed).timeout

	is_typing = false
	print("⌨️ Typing animation completed")
	
	# Only show next button if not in auto-advance mode
	if not auto_advance:
		waiting_for_next = true
		next_button.show() # Show the next button only after typing finishes
		print("🎬 Next button shown after typing finished")
	else:
		print("🎬 Auto-advance mode: Next button hidden")

func _apply_portrait_for_speaker(speaker: String) -> void:
	if portrait_rect == null:
		return
	var tex: Texture2D = null
	match speaker.to_lower():
		"miguel":
			tex = load("res://assets/sprites/characters/closeup_face/Main_character_closeup.png")
		"erwin", "boy trip":
			tex = load("res://erwin_tambay_closeup.png")
		"celine":
			tex = load("res://assets/sprites/characters/closeup_face/celine_closeup.png")
		"kapitana palma", "kapitana", "kapitana lourdes":
			tex = load("res://kapitana_palma_closeup.png")
		"po1 darwin", "po1_darwin":
			tex = load("res://po1_closeup.png")
		"dr. leticia salvador", "dr leticia salvador", "leticia salvador":
			tex = load("res://dr_leticia_salvador_closeup.png")
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
	print("🔘 Next button pressed - is_typing:", is_typing, "cutscene_mode:", cutscene_mode, "waiting_for_next:", waiting_for_next)
	
	# Always check if typing is finished before allowing next
	if is_typing:
		print("⏳ Typing in progress, ignoring next button press")
		return
	
	if cutscene_mode:
		# In cutscene mode, emit signal only when typing is finished
		if waiting_for_next:
			print("🎬 Cutscene mode: Emitting next_pressed signal")
			emit_signal("next_pressed")
		else:
			print("🎬 Cutscene mode: Not waiting for next, ignoring")
		return
		
	if waiting_for_next and not is_typing:
		waiting_for_next = false
		next_button.hide()
		print("📝 Normal mode: Emitting next_pressed signal")
		emit_signal("next_pressed")
