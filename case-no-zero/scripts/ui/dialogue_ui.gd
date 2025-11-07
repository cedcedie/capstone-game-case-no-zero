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

# Cached compiled RegEx objects for keyword bolding (performance optimization)
var _cached_regexes: Dictionary = {}
var _regex_cache_initialized: bool = false

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

func _process(_delta):
	# Handle ui_accept action (Space/Enter) - checked in _process for better reliability
	if waiting_for_next and not is_typing:
		if Input.is_action_just_pressed("ui_accept"):
			_on_next_pressed()

func _input(event):
	# Handle space key or ui_accept action to advance dialogue
	if waiting_for_next and not is_typing:
		# Check for space key press
		if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
			# Prevent space from being processed elsewhere
			get_viewport().set_input_as_handled()
			_on_next_pressed()

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
	
	# Bold only selected keywords/phrases (case-insensitive), no ALL-CAPS auto-bold
	var bbcode_text = _bold_keywords(text)

	# Do not auto-bold ALL-CAPS; rely on explicit **...** only
	
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
		"erwin", "boy trip", "Erwin Boy Trip":
			tex = load("res://assets/sprites/characters/closeup_face/erwin_tambay_closeup.png")
		"celine":
			tex = load("res://assets/sprites/characters/closeup_face/celine_closeup.png")
		"kapitana palma", "kapitana", "kapitana lourdes":
			tex = load("res://kapitana_palma_closeup.png")
		"po1 darwin", "po1_darwin":
			tex = load("res://assets/sprites/characters/closeup_face/po1_closeup.png")
		"leo mendoza":
			tex = load("res://assets/sprites/characters/closeup_face/leo_closeup.png")
		"dr. leticia salvador", "dr leticia salvador", "leticia salvador":
			tex = load("res://assets/sprites/characters/closeup_face/dr_leticia_salvador_closeup.png")
		_:
			tex = null
	portrait_rect.texture = tex

# -----------------------------
# Keyword bolding (BBCode)
# -----------------------------
func _bold_keywords(input_text: String) -> String:
	var result := input_text
	
	# Initialize regex cache on first call (performance optimization)
	if not _regex_cache_initialized:
		_initialize_regex_cache()
	
	# Use cached compiled regexes instead of creating new ones each time
	for kw in _cached_regexes.keys():
		var rx: RegEx = _cached_regexes[kw]
		result = rx.sub(result, "[b]$0[/b]", true)
	
	return result

func _initialize_regex_cache() -> void:
	"""Initialize the regex cache with compiled RegEx objects (called once)"""
	if _regex_cache_initialized:
		return
	
	# Curated keywords/phrases to emphasize; includes all citations and legal terms
	var keywords := [
		# Story/Character keywords (longer phrases first)
		"BATAS AY PARA SA MGA TAO",
		"UNANG MALAKING KASO",
		"KATOTOHANAN",
		# Character Names (full names first, then first names)
		"Dr. Leticia Salvador",
		"Leticia Salvador",
		"Kapitana Lourdes",
		"Kapitana Palma",
		"PO1 Leo Mendoza",
		"Leo Mendoza",
		"PO1 Darwin",
		"Atty. Miguel Ramos",
		"Atty. Miguel",
		"Atty.",
		"Miguel",
		"Celine",
		"Erwin",
		"Erwin Tambay",
		"Leo",
		"Darwin",
		# Legal Citations - Rules of Court (more specific first)
		"Rules of Court",
		"Rule 130, Section 24",
		"Rule 130, Section 49",
		"Rule 130",
		"Rule 133",
		"Rule 112",
		"Rule 110",
		"Section 24",
		"Section 49",
		# Constitutional Citations (more specific first)
		"1987 Const. Art. III, Sec. 14(2)",
		"1987 Const., Art. III, Sec. 1",
		"1987 Const.",
		"Art. III, Sec. 14(2)",
		"Art. III, Sec. 1",
		"Art. III, Sec. 14[2]",
		"Sec. 14(2)",
		"Art. III",
		"Sec. 1",
		"Sec. 14",
		# Revised Penal Code
		"RPC Art. 248",
		# Republic Acts (more specific first)
		"Republic Act No. 6713",
		"RA No. 6713",
		"RA 6713",
		# Professional Code (more specific first)
		"CPRA (2023)",
		"CPRA 2023",
		"CPRA",
		# Other Rules
		"BJMP visitation rules",
		# Legal Terms (longer phrases first to avoid partial matches)
		"medical expert testimony",
		"expert witness",
		"expert testimony",
		"medical confidentiality",
		"medical confidentiality laws",
		"physician-patient privilege",
		"court order",
		"legal proceedings",
		"presumption of innocence",
		"burden of prosecution",
		"chain of custody",
		"documentary evidence",
		"testimonial evidence",
		"evidence tampering",
		"preliminary investigation",
		"due process",
		"authentication",
		"admissible",
		"burden",
		"evidence",
		"ebidensya",
		# Forensic Terms (longer phrases first)
		"autopsy report",
		"autopsy findings",
		"rigor mortis",
		"algor mortis",
		"defensive wounds",
		"ligature marks",
		"time of death",
		"cause of death",
		"gunshot wound",
		"foreign DNA",
		# Barangay/Police Terms
		"patrol logbook",
		"signature discrepancy",
		"signature",
		"discrepancy",
		"handwriting",
		"tampering",
		"forgery",
		"police report",
		"official police report",
	]
	
	# Compile regexes once and cache them
	for kw in keywords:
		var rx := RegEx.new()
		var pattern: String
		if kw.contains("(") or kw.contains(".") or kw.contains("/"):
			# For citations with special chars, escape them but allow flexible matching
			pattern = "(?i)" + _regex_escape(kw)
		else:
			# For regular words, use word boundaries
			pattern = "(?i)(?<!\\w)" + _regex_escape(kw) + "(?!\\w)"
		
		var compile_result = rx.compile(pattern)
		if compile_result == OK:
			_cached_regexes[kw] = rx
		else:
			push_warning("Failed to compile regex for keyword: " + kw)
	
	_regex_cache_initialized = true
	print("✅ DialogueUI: Regex cache initialized with ", _cached_regexes.size(), " compiled patterns")

func _regex_escape(text: String) -> String:
	# Escape common regex metacharacters
	var escaped := text
	var metas := ["\\", ".", "+", "*", "?", "^", "$", "{", "}", "(", ")", "|", "[", "]"]
	for m in metas:
		escaped = escaped.replace(m, "\\" + m)
	return escaped

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
