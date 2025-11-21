extends CanvasLayer

@onready var container = $Container
@onready var name_label = $Container/Name
@onready var dialogue_label: RichTextLabel = $Container/Dialogue
@onready var next_button = $Container/Button
@onready var typing_sound = $Container/TypingSound 
@onready var portrait_rect: TextureRect = $Container/Face/TextureRect if has_node("Container/Face/TextureRect") else null
@onready var face_container: Control = $Container/Face if has_node("Container/Face") else null

# Store current animated sprite instance for cleanup
var current_animated_sprite_instance: Node = null
var current_viewport_container: SubViewportContainer = null

signal next_pressed
var waiting_for_next: bool = false
var is_typing: bool = false
var typing_speed := 0.01
var cutscene_mode: bool = false
var blip_interval: int = 3  # play a voice blip every N characters

# Cached compiled RegEx objects for keyword bolding (performance optimization)
var _cached_regexes: Dictionary = {}
var _regex_cache_initialized: bool = false

# Helper function to map dialogue file paths to face scene paths
func get_face_scene_path_from_dialogue_file(dialogue_file_path: String) -> String:
	"""Maps NPC dialogue file path to corresponding face scene path
	Example: res://data/npc/npc_bc_boy_1_dialogue.json -> res://scenes/face/bc_boy_1.tscn
	Handles typos like 'diaogue' instead of 'dialogue'"""
	var file_name = dialogue_file_path.get_file()  # e.g., "npc_bc_boy_1_dialogue.json"
	
	# Remove various suffixes (handles both "dialogue" and "diaogue" typo)
	var base_name = file_name
	base_name = base_name.replace("_dialogue.json", "")
	base_name = base_name.replace("_diaogue.json", "")  # Handle typo in npc_bc_girl_5_diaogue.json
	base_name = base_name.replace(".json", "")
	# e.g., "npc_bc_boy_1" or "npc_bc_girl_5"
	
	# Handle special case: shaolin_boy_dialogue.json (no npc_ prefix)
	if base_name == "shaolin_boy":
		return "res://scenes/face/shaolin_boy.tscn"
	
	# Try without npc_ prefix first (most common case)
	var face_name_without_prefix = base_name
	if base_name.begins_with("npc_"):
		face_name_without_prefix = base_name.substr(4)  # Remove "npc_" prefix
	
	var face_path_without_prefix = "res://scenes/face/" + face_name_without_prefix + ".tscn"
	var face_path_with_prefix = "res://scenes/face/" + base_name + ".tscn"
	
	# Check which one exists (some face scenes keep the npc_ prefix)
	if ResourceLoader.exists(face_path_without_prefix):
		return face_path_without_prefix
	elif ResourceLoader.exists(face_path_with_prefix):
		return face_path_with_prefix
	else:
		# Return the one without prefix as default (most common)
		return face_path_without_prefix

func get_face_scene_path_from_dialogue_key(dialogue_key: String) -> String:
	"""Maps dialogue key to corresponding face scene path
	Example: npc_bc_boy_1 -> res://scenes/face/bc_boy_1.tscn
	Example: shaolin_boy -> res://scenes/face/shaolin_boy.tscn"""
	var base_name = dialogue_key  # e.g., "npc_bc_boy_1" or "shaolin_boy"
	
	# Handle special case: shaolin_boy (no npc_ prefix)
	if base_name == "shaolin_boy":
		return "res://scenes/face/shaolin_boy.tscn"
	
	# Try without npc_ prefix first (most common case)
	var face_name_without_prefix = base_name
	if base_name.begins_with("npc_"):
		face_name_without_prefix = base_name.substr(4)  # Remove "npc_" prefix
	
	var face_path_without_prefix = "res://scenes/face/" + face_name_without_prefix + ".tscn"
	var face_path_with_prefix = "res://scenes/face/" + base_name + ".tscn"
	
	# Check which one exists (some face scenes keep the npc_ prefix)
	if ResourceLoader.exists(face_path_without_prefix):
		return face_path_without_prefix
	elif ResourceLoader.exists(face_path_with_prefix):
		return face_path_with_prefix
	else:
		# Return the one without prefix as default (most common)
		return face_path_without_prefix

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
	t.set_parallel(true)  # Allow multiple properties to tween simultaneously
	t.tween_property(container, "modulate:a", 0.0, 0.4)
	
	# Fade out the NPC face sprite smoothly too
	var npc_face = get_node_or_null("NPCFaceSprite")
	if npc_face:
		# Find all AnimatedSprite2D nodes in the wrapper and fade them out
		var sprites = []
		if npc_face.get_child_count() > 0:
			var face_instance = npc_face.get_child(0)
			if face_instance is AnimatedSprite2D:
				sprites.append(face_instance)
			else:
				# Find all AnimatedSprite2D children
				for child in face_instance.get_children():
					if child is AnimatedSprite2D:
						sprites.append(child)
				# Also check recursively
				var found = face_instance.find_children("*", "", true, false)
				for node in found:
					if node is AnimatedSprite2D:
						sprites.append(node)
		
		# Fade out all sprites
		for sprite in sprites:
			t.tween_property(sprite, "modulate:a", 0.0, 0.4)
	
	await t.finished
	_cleanup_animated_sprite()  # Clean up animated sprite when hiding UI
	hide()

# Typing animation with sound
func show_dialogue_line(speaker: String, text: String, auto_advance: bool = false, dialogue_key: String = "") -> void:
	show_ui()
	name_label.text = speaker
	_apply_portrait_for_speaker(speaker, dialogue_key)
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

func _apply_portrait_for_speaker(speaker: String, dialogue_key: String = "") -> void:
	if portrait_rect == null or face_container == null:
		return
	
	# Always clean up previous portrait first to prevent persistence
	_cleanup_animated_sprite()
	# Clear and hide portrait rect initially
	if portrait_rect:
		portrait_rect.texture = null
		portrait_rect.visible = false
	
	var tex: Texture2D = null
	var animated_sprite: AnimatedSprite2D = null
	
	# If dialogue_key is provided, try to load face scene from it (NPCs only)
	if dialogue_key != "":
		_setup_npc_face_sprite(dialogue_key)
		return
	
	# Fall back to speaker name matching (for main characters) if no face scene found
	if animated_sprite == null:
		match speaker.to_lower():
			"miguel":
				tex = load("res://assets/sprites/characters/closeup_face/Main_character_closeup.png")
			"erwin", "boy trip", "erwin boy trip":
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
			"hukom", "judge":
				tex = load("res://assets/sprites/characters/closeup_face/judge_closeup.png") if ResourceLoader.exists("res://assets/sprites/characters/closeup_face/judge_closeup.png") else null
			"fiscal", "prosecutor":
				tex = load("res://assets/sprites/characters/closeup_face/fiscal_closeup.png") if ResourceLoader.exists("res://assets/sprites/characters/closeup_face/fiscal_closeup.png") else null
			"po1 cordero":
				tex = load("res://assets/sprites/characters/closeup_face/po1_cordero_closeup.png") if ResourceLoader.exists("res://assets/sprites/characters/closeup_face/po1_cordero_closeup.png") else null
	
	# Set the texture to the portrait rect for static images
	if portrait_rect:
		if tex != null:
			portrait_rect.texture = tex
			portrait_rect.visible = true
		else:
			# No texture found - clear and hide to prevent persistence
			portrait_rect.texture = null
			portrait_rect.visible = false
		# Make sure any animated sprite viewport is hidden
		if current_viewport_container:
			current_viewport_container.visible = false

func _setup_npc_face_sprite(dialogue_key: String) -> void:
	"""Simple function to setup NPC face sprites - just instantiate and position"""
	# Clean up any existing NPC face sprite first
	_cleanup_animated_sprite()
	
	var face_scene_path = get_face_scene_path_from_dialogue_key(dialogue_key)
	if not ResourceLoader.exists(face_scene_path):
		return
	
	# Load and instantiate the face scene directly
	var face_scene = load(face_scene_path) as PackedScene
	if not face_scene:
		return
	
	var face_instance = face_scene.instantiate()
	if not face_instance:
		return
	
	# Create a simple Node2D wrapper to position it (since CanvasLayer is Control-based)
	var wrapper = Node2D.new()
	wrapper.name = "NPCFaceSprite"
	wrapper.position = Vector2(472.0, 596.0)
	wrapper.add_child(face_instance)
	
	# Add to CanvasLayer
	add_child(wrapper)
	
	# Store reference for cleanup
	current_animated_sprite_instance = wrapper
	
	# Play animation if it's an AnimatedSprite2D
	var animated_sprite: AnimatedSprite2D = null
	if face_instance is AnimatedSprite2D:
		animated_sprite = face_instance
	else:
		animated_sprite = face_instance.find_child("*", true, false) as AnimatedSprite2D
	
	if animated_sprite and animated_sprite.sprite_frames:
		var animation_names = animated_sprite.sprite_frames.get_animation_names()
		if animation_names.size() > 0:
			animated_sprite.play(animation_names[0])
		# Ensure sprite is fully visible when shown
		animated_sprite.modulate.a = 1.0
	
	# Hide the TextureRect
	portrait_rect.visible = false

func _cleanup_animated_sprite() -> void:
	# Simply find and remove the NPCFaceSprite wrapper
	var npc_face = get_node_or_null("NPCFaceSprite")
	if npc_face:
		npc_face.queue_free()
	
	current_animated_sprite_instance = null
	current_viewport_container = null

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
