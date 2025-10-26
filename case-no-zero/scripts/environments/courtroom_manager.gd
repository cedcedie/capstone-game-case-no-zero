extends Node

# Courtroom Manager - Handles courtroom dialogue, evidence testimony, and interactive controls

# --- Node references ---
var dialogue_ui: CanvasLayer = null
var evidence_ui: CanvasLayer = null
@onready var player: CharacterBody2D = $PlayerM
@onready var judge: CharacterBody2D = $Judge
@onready var prosecutor: CharacterBody2D = $Prosecutor
@onready var defendant: CharacterBody2D = $Defendant
@onready var witness: CharacterBody2D = $Witness
var player_camera: Camera2D = null

# --- Task Manager reference ---
var task_manager: Node = null

# --- Audio Manager reference ---
var audio_manager: Node = null

# --- Dialogue data ---
var dialogue_lines: Array = []
var current_line: int = 0
var waiting_for_next: bool = false

# --- Courtroom state ---
var is_courtroom_active: bool = false
var current_phase: String = "intro"  # intro, testimony, evidence, closing
var evidence_presented: Array = []
var testimony_completed: Array = []

# --- Evidence tracking for debug ---
var evidence_already_presented: Array = []
var leo_innocence_evidence: Array = []

# --- Phoenix Wright-style features ---
var objection_mode: bool = false
var current_emotion: String = "neutral"
var dramatic_music: bool = false
var camera_shake_intensity: float = 0.0

# --- BGM System ---
var bgm_player: AudioStreamPlayer = null
var current_bgm: String = ""
var bgm_volume: float = 0.5

# --- Evidence Presentation Control ---
var evidence_presentation_active: bool = false
var waiting_for_evidence_selection: bool = false
var player_movement_disabled: bool = false
var dialogue_typing: bool = false
var text_display_time: float = 0.0

# --- Life System and Branching ---
var lives: int = 3
var max_lives: int = 3
var wrong_evidence_count: int = 0
var current_branch: String = "main"
var backup_dialogues: Array = []
var evidence_presented_wrong: Array = []
var game_over: bool = false

# --- Movement and transition tuning ---
@export var walk_speed: float = 200.0
@export var fade_duration: float = 1.2
@export var text_fade_duration: float = 0.8
@export var transition_pause: float = 0.3

# --- Input handling ---
var can_present_evidence: bool = false
var can_give_testimony: bool = false
var can_object: bool = false
var can_highlight_testimony: bool = false
var current_testimony_highlight: String = ""
var testimony_discrepancies: Array = []
var highlighted_sentences: Array = []
var waiting_for_input: bool = false
var current_input_type: String = "dialogue"

# --- Next button signals ---
signal next_dialogue_pressed
signal next_evidence_pressed
signal next_testimony_pressed

func _ready():
	"""Initialize the courtroom scene"""
	await get_tree().process_frame
	
	# Get autoload references
	dialogue_ui = get_node_or_null("/root/DialogueUI")
	evidence_ui = get_node_or_null("/root/EvidenceInventorySettings")
	task_manager = get_node_or_null("/root/TaskManager")
	audio_manager = get_node_or_null("/root/AudioManager")
	
	# Get camera reference
	player_camera = get_viewport().get_camera_2d()
	if not player_camera and player:
		player_camera = player.get_node("Camera2D")
	
	# Setup BGM player
	setup_bgm_player()
	
	# Connect evidence signals
	if evidence_ui:
		evidence_ui.evidence_displayed.connect(_on_evidence_displayed)
		print("🔗 Connected evidence signals")
	
	# DEBUG: Skip checkpoint requirement for testing
	var debug_mode = true
	if debug_mode:
		print("🔧 DEBUG: Bypassing checkpoint requirement")
	else:
		# Check if morgue is completed (required to access courtroom)
		if not CheckpointManager or not CheckpointManager.has_checkpoint(CheckpointManager.CheckpointType.MORGUE_COMPLETED):
			print("⚠️ Morgue not completed - courtroom access denied")
			# Redirect to morgue or show error
			get_tree().change_scene_to_file("res://scenes/environments/funeral home/morgue.tscn")
			return
	
	# Load courtroom dialogue
	load_courtroom_dialogue()
	
	# ALWAYS start courtroom sequence when accessed
	print("⚖️ Courtroom accessed - starting cutscene")
	start_courtroom_sequence()

func load_courtroom_dialogue() -> void:
	"""Load courtroom dialogue from JSON file"""
	var file: FileAccess = FileAccess.open("res://data/dialogues/courtroom_dialogue.json", FileAccess.READ)
	if file == null:
		push_error("Cannot open courtroom_dialogue.json")
		return

	var text: String = file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("courtroom"):
		push_error("Failed to parse courtroom_dialogue.json correctly")
		return

	dialogue_lines = parsed["courtroom"]["dialogue_lines"]
	current_line = 0
	print("📝 Courtroom dialogue loaded:", dialogue_lines.size(), "lines")

func start_courtroom_sequence() -> void:
	"""Start the courtroom sequence"""
	print("⚖️ Starting courtroom sequence")
	is_courtroom_active = true
	player_movement_disabled = true
	
	# Start courtroom BGM
	play_bgm("courtroom_opening")
	
	# Show intro dialogue
	show_next_line()

func setup_bgm_player() -> void:
	"""Setup BGM audio player"""
	bgm_player = AudioStreamPlayer.new()
	bgm_player.name = "BGMPlayer"
	bgm_player.volume_db = linear_to_db(bgm_volume)
	bgm_player.autoplay = false
	add_child(bgm_player)
	print("🎵 BGM player setup complete")
	
	# Stop any exterior audio
	if audio_manager:
		audio_manager.stop_bgm()
		print("🎵 Stopped exterior audio")

func play_bgm(bgm_name: String) -> void:
	"""Play courtroom BGM using AudioManager"""
	if not audio_manager:
		print("❌ AudioManager not found")
		return
	
	var bgm_path = ""
	match bgm_name:
		"courtroom_opening":
			bgm_path = "res://assets/audio/music/toby fox - UNDERTALE Soundtrack - 46 Spear of Justice.mp3"
		"objection_battle":
			bgm_path = "res://assets/audio/music/toby fox - UNDERTALE Soundtrack - 46 Spear of Justice.mp3"
		"evidence_presentation":
			bgm_path = "res://assets/audio/music/toby fox - UNDERTALE Soundtrack - 46 Spear of Justice.mp3"
		"final_verdict":
			bgm_path = "res://assets/audio/music/toby fox - UNDERTALE Soundtrack - 46 Spear of Justice.mp3"
		"victory":
			bgm_path = "res://assets/audio/music/toby fox - UNDERTALE Soundtrack - 46 Spear of Justice.mp3"
	
	if bgm_path != "" and bgm_path != current_bgm:
		audio_manager.play_bgm(bgm_path)
		current_bgm = bgm_path
		print("🎵 Playing Justice BGM:", bgm_name)

func stop_bgm() -> void:
	"""Stop current BGM using AudioManager"""
	if audio_manager:
		audio_manager.stop_bgm()
		current_bgm = ""
		print("🎵 BGM stopped")

func start_evidence_presentation() -> void:
	"""Start evidence presentation phase"""
	print("📋 Starting evidence presentation phase")
	evidence_presentation_active = true
	waiting_for_evidence_selection = true
	
	# Show evidence inventory
	if evidence_ui:
		evidence_ui.show_evidence_inventory()
		print("📋 Evidence inventory opened - select evidence to present")
	
	# Wait for evidence selection via signal
	wait_for_evidence_selection()

func _on_evidence_displayed(evidence_id: String) -> void:
	"""Handle evidence selection from UI"""
	print("📋 Evidence selected:", evidence_id)
	waiting_for_evidence_selection = false
	
	# Close evidence inventory
	if evidence_ui:
		evidence_ui.hide_evidence_inventory()
	
	# Process the evidence selection
	process_evidence_selection(evidence_id)

func wait_for_evidence_selection() -> void:
	"""Wait for player to select evidence"""
	print("⏳ Waiting for evidence selection...")
	waiting_for_evidence_selection = true
	
	# Show message to player
	show_dialogue("System", "Press TAB to open evidence inventory and select evidence to present")
	
	# Wait for TAB key
	while waiting_for_evidence_selection:
		await get_tree().process_frame

func process_evidence_selection(evidence_id: String) -> void:
	"""Process the selected evidence"""
	print("📋 Evidence selected:", evidence_id)
	
	# Add to presented evidence
	if evidence_id not in evidence_already_presented:
		evidence_already_presented.append(evidence_id)
		leo_innocence_evidence.append(evidence_id)
		print("✅ Evidence added to case:", evidence_id)
		
		# Show evidence presentation dialogue
		show_evidence_dialogue(evidence_id)
	else:
		print("⚠️ Evidence already presented:", evidence_id)
		show_dialogue("Hukom", "Abogado, naipresenta mo na ang ebidensyang ito. Magpakita ng ibang ebidensya.")
		wait_for_evidence_selection()
		return

func show_evidence_dialogue(evidence_id: String) -> void:
	"""Show complete dialogue sequence for specific evidence"""
	print("📋 Showing complete evidence dialogue for:", evidence_id)
	
	# Start evidence BGM
	play_bgm("evidence_presentation")
	
	# Show complete evidence dialogue sequence
	await show_complete_evidence_sequence(evidence_id)
	
	# Check if all 6 evidence have been presented
	if evidence_already_presented.size() >= 6:
		print("✅ All 6 evidence presented - proceeding to verdict")
		proceed_to_verdict()
		return
	
	# Continue with evidence presentation loop
	evidence_presentation_active = false
	waiting_for_evidence_selection = false
	
	# Ask if player wants to present more evidence
	show_dialogue("Hukom", "May iba pa bang ebidensya na gusto mong ipresenta?")
	waiting_for_input = true

func proceed_to_verdict() -> void:
	"""Proceed to verdict after all evidence is presented"""
	print("⚖️ Proceeding to verdict phase")
	
	# Stop evidence presentation
	evidence_presentation_active = false
	waiting_for_evidence_selection = false
	
	# Show verdict dialogue
	show_dialogue("Hukom", "Matapos ang pagpresenta ng lahat ng ebidensya, ang hukuman ay magdedeliberate na.")
	await wait_for_input()
	
	# Start verdict BGM
	play_bgm("final_verdict")
	
	# Show verdict sequence
	await show_verdict_sequence()

func show_complete_evidence_sequence(evidence_id: String) -> void:
	"""Show the complete dialogue sequence for each evidence"""
	match evidence_id:
		"broken_body_cam":
			await show_broken_body_cam_sequence()
		"logbook":
			await show_logbook_sequence()
		"handwriting_sample":
			await show_handwriting_sequence()
		"radio_log":
			await show_radio_log_sequence()
		"autopsy_report":
			await show_autopsy_sequence()
		"leos_notebook":
			await show_notebook_sequence()

func show_broken_body_cam_sequence() -> void:
	"""Complete dialogue sequence for broken body cam"""
	show_dialogue("Miguel", "Your Honor, gusto kong ipresenta ang sirang body camera!")
	await wait_for_input()
	
	show_dialogue("Miguel", "Ang body camera na ito ay nasira sa panahon ng insidente, ngunit naglalaman ito ng mahalagang footage!")
	await wait_for_input()
	
	show_dialogue("Fiscal", "Objection! Ang ebidensyang ito ay hindi maaaring tanggapin dahil nasira ito!")
	await objection_camera_shake()
	await wait_for_input()
	
	show_dialogue("Miguel", "Objection! Your Honor, ang ebidensyang ito ay nagpapakita na wala si Leo sa crime scene!")
	await objection_camera_shake()
	await wait_for_input()
	
	show_dialogue("Hukom", "Sustained. Ang ebidensya ay maaaring tanggapin. Magpatuloy, Abogado.")
	await wait_for_input()

func show_logbook_sequence() -> void:
	"""Complete dialogue sequence for logbook"""
	show_dialogue("Miguel", "Your Honor, gusto kong ipresenta ang police logbook!")
	await wait_for_input()
	
	show_dialogue("Miguel", "Ang logbook na ito ay nagpapakita ng mga inconsistencies sa opisyal na ulat!")
	await wait_for_input()
	
	show_dialogue("Fiscal", "Objection! Ang logbook ay opisyal na dokumento ng pulisya!")
	await objection_camera_shake()
	await wait_for_input()
	
	show_dialogue("Miguel", "Objection! Your Honor, ang inconsistencies ay nagpapakita ng posibleng evidence tampering!")
	await objection_camera_shake()
	await wait_for_input()
	
	show_dialogue("Hukom", "Sustained. Ang ebidensya ay maaaring tanggapin. Magpatuloy, Abogado.")
	await wait_for_input()

func show_handwriting_sequence() -> void:
	"""Complete dialogue sequence for handwriting sample"""
	show_dialogue("Miguel", "Your Honor, gusto kong ipresenta ang handwriting sample!")
	await wait_for_input()
	
	show_dialogue("Miguel", "Ang handwriting analysis ay nagpapatunay na ang confession ay peke at hindi sinulat ni Leo!")
	await wait_for_input()
	
	show_dialogue("Fiscal", "Objection! Ang confession ay may pirma ni Leo!")
	await objection_camera_shake()
	await wait_for_input()
	
	show_dialogue("Miguel", "Objection! Your Honor, ang handwriting analysis ay nagpapatunay na peke ang confession!")
	await objection_camera_shake()
	await wait_for_input()
	
	show_dialogue("Hukom", "Sustained. Ang ebidensya ay maaaring tanggapin. Magpatuloy, Abogado.")
	await wait_for_input()

func show_radio_log_sequence() -> void:
	"""Complete dialogue sequence for radio log"""
	show_dialogue("Miguel", "Your Honor, gusto kong ipresenta ang radio communications log!")
	await wait_for_input()
	
	show_dialogue("Miguel", "Ang radio log ay nagpapakita na ang mga responding officers ay hindi sumusunod sa tamang procedure!")
	await wait_for_input()
	
	show_dialogue("Fiscal", "Objection! Ang mga officers ay sumusunod sa protocol!")
	await objection_camera_shake()
	await wait_for_input()
	
	show_dialogue("Miguel", "Objection! Your Honor, ang radio log ay nagpapakita ng mga violations sa procedure!")
	await objection_camera_shake()
	await wait_for_input()
	
	show_dialogue("Hukom", "Sustained. Ang ebidensya ay maaaring tanggapin. Magpatuloy, Abogado.")
	await wait_for_input()

func show_autopsy_sequence() -> void:
	"""Complete dialogue sequence for autopsy report"""
	show_dialogue("Miguel", "Your Honor, gusto kong ipresenta ang autopsy report!")
	await wait_for_input()
	
	show_dialogue("Miguel", "Ang autopsy report ay nagpapakita na ang sanhi ng kamatayan ay hindi tumugma sa teorya ng prosecution!")
	await wait_for_input()
	
	show_dialogue("Fiscal", "Objection! Ang autopsy report ay sumusuporta sa prosecution!")
	await objection_camera_shake()
	await wait_for_input()
	
	show_dialogue("Miguel", "Objection! Your Honor, ang autopsy report ay nagpapakita ng mga inconsistencies sa teorya ng prosecution!")
	await objection_camera_shake()
	await wait_for_input()
	
	show_dialogue("Hukom", "Sustained. Ang ebidensya ay maaaring tanggapin. Magpatuloy, Abogado.")
	await wait_for_input()

func show_notebook_sequence() -> void:
	"""Complete dialogue sequence for Leo's notebook"""
	show_dialogue("Miguel", "Your Honor, gusto kong ipresenta ang personal na notebook ni Leo!")
	await wait_for_input()
	
	show_dialogue("Miguel", "Ang notebook na ito ay naglalaman ng kanyang alibi at nagpapatunay na siya ay nasa ibang lugar sa panahon ng insidente!")
	await wait_for_input()
	
	show_dialogue("Fiscal", "Objection! Ang notebook ay maaaring ginawa lamang para sa alibi!")
	await objection_camera_shake()
	await wait_for_input()
	
	show_dialogue("Miguel", "Objection! Your Honor, ang notebook ay naglalaman ng detalyadong impormasyon na nagpapatunay sa alibi!")
	await objection_camera_shake()
	await wait_for_input()
	
	show_dialogue("Hukom", "Sustained. Ang ebidensya ay maaaring tanggapin. Magpatuloy, Abogado.")
	await wait_for_input()

func wait_for_input() -> void:
	"""Wait for player input"""
	waiting_for_input = true
	while waiting_for_input:
		await get_tree().process_frame

func show_verdict_sequence() -> void:
	"""Show the verdict sequence"""
	show_dialogue("Hukom", "Matapos ang masusing pag-aaral ng lahat ng ebidensya, ang hukuman ay nagpapatunay na...")
	await wait_for_input()
	
	show_dialogue("Hukom", "Si Leo ay INOSENTE!")
	await dramatic_camera_shake()
	await wait_for_input()
	
	show_dialogue("Hukom", "Ang lahat ng ebidensya ay nagpapatunay na si Leo ay hindi nagkasala!")
	await wait_for_input()
	
	show_dialogue("Hukom", "Ang confession ay peke, ang alibi ay totoo, at ang prosecution ay may mga inconsistencies!")
	await wait_for_input()
	
	show_dialogue("Hukom", "Si Leo ay MALAYA na!")
	await dramatic_camera_shake()
	await wait_for_input()
	
	# Start victory BGM
	play_bgm("victory")
	
	show_dialogue("Miguel", "SALAMAT PO, YOUR HONOR! Ang katotohanan ay nanalo!")
	await wait_for_input()
	
	show_dialogue("Leo", "Salamat po, Your Honor! Salamat sa inyo, Miguel!")
	await wait_for_input()
	
	show_dialogue("Hukom", "Ang kaso ay tapos na. Ang hukuman ay adjourned.")
	await wait_for_input()
	
	# End courtroom sequence
	end_courtroom_sequence()

func show_next_line() -> void:
	"""Simple dialogue progression"""
	
	# Check if we're at the end
	if current_line >= dialogue_lines.size():
		print("🏁 Courtroom sequence completed!")
		end_courtroom_sequence()
		return

	# Get current dialogue line
	var line: Dictionary = dialogue_lines[current_line]
	var speaker: String = line.get("speaker", "")
	var text: String = line.get("text", "")
	var action: String = line.get("action", "")

	print("💬 Line", current_line, ":", speaker, "says:", text)

	# Handle camera actions
	if action == "camera_focus_judge":
		await focus_camera_on_judge()
	elif action == "camera_focus_prosecutor":
		await focus_camera_on_prosecutor()
	elif action == "camera_focus_defendant":
		await focus_camera_on_defendant()
	elif action == "camera_focus_witness":
		await focus_camera_on_witness()
	elif action == "camera_return":
		await return_camera_to_center()
	elif action == "objection_shake":
		await objection_camera_shake()
	elif action == "dramatic_shake":
		await dramatic_camera_shake()
	elif action == "play_objection_bgm":
		play_bgm("objection_battle")
	elif action == "play_evidence_bgm":
		play_bgm("evidence_presentation")
	elif action == "play_verdict_bgm":
		play_bgm("final_verdict")
	elif action == "play_victory_bgm":
		play_bgm("victory")
	elif action == "start_evidence_presentation":
		start_evidence_presentation()
		return
	elif action == "wait_for_evidence":
		wait_for_evidence_selection()
		return

	# Check if this line has choices
	if line.has("choices") and line["choices"].size() > 0:
		show_dialogue_with_choices(speaker, text, line["choices"])
	else:
		# Show the dialogue
		show_dialogue(speaker, text)
		
		# Wait for player to press SPACE/ENTER
		waiting_for_input = true

func show_dialogue(speaker: String, text: String) -> void:
	"""Simple dialogue display with proper timing"""
	if dialogue_ui:
		dialogue_ui.show_dialogue_line(speaker, text, true)
		print("📝 Showing:", speaker, "-", text)
		
		# Calculate proper display time based on text length
		text_display_time = max(1.5, text.length() * 0.03)  # Much longer timing
		dialogue_typing = true
		
		# Wait for text to finish displaying
		await get_tree().create_timer(text_display_time).timeout
		dialogue_typing = false
		print("📝 Text finished displaying")

func show_dialogue_with_choices(speaker: String, text: String, choices: Array) -> void:
	"""Show dialogue with choices"""
	show_dialogue(speaker, text)
	
	# Show choices
	if dialogue_ui:
		dialogue_ui.show_choices(choices)
		print("🎯 Showing choices:", choices)
	
	# Wait for choice selection
	waiting_for_input = true

func show_dialogue_with_auto_advance(speaker: String, text: String) -> void:
	"""Show dialogue with auto-advance"""
	if dialogue_ui:
		dialogue_ui.show_dialogue_line(speaker, text, true)
		
		# Play voice blip
		if has_node("/root/VoiceBlipManager"):
			var voice_manager = get_node("/root/VoiceBlipManager")
			voice_manager.play_voice_blip(speaker)
		
		# Calculate timing based on text length
		var typing_time = text.length() * 0.005
		var reading_time = max(1.0, text.length() * 0.01)
		var total_wait = typing_time + reading_time
		
		await get_tree().create_timer(total_wait).timeout
		waiting_for_input = false

func show_choice_menu(choices: Array) -> void:
	"""Show choice menu for player decisions"""
	print("🎯 Showing choice menu with", choices.size(), "options")
	
	# TODO: Implement choice menu UI
	# For now, just advance to next line
	current_line += 1
	call_deferred("show_next_line")

func show_evidence_panel() -> void:
	"""Show evidence panel for presentation"""
	print("📋 Showing evidence panel")
	
	if evidence_ui:
		evidence_ui.show_evidence_inventory()

func show_evidence_inventory() -> void:
	"""Show evidence inventory for presentation"""
	print("📋 Nagpapakita ng evidence inventory para sa courtroom")
	
	if evidence_ui:
		evidence_ui.show_evidence_inventory()
		print("📋 Evidence inventory ay nakita - pindutin ang TAB para isara")
		
		# Wait for evidence selection
		await evidence_ui.evidence_displayed
		var selected_evidence = evidence_ui.current_evidence
		print("📋 Ebidensya ay napili para sa pagpresenta:", selected_evidence)
		
		# Check if evidence is correct for current context
		var is_correct = check_evidence_correctness(selected_evidence)
		if is_correct:
			await present_correct_evidence(selected_evidence)
		else:
			await present_wrong_evidence(selected_evidence)
		
		# Hide evidence inventory
		await evidence_ui.hide_evidence_inventory()
		print("📋 Evidence inventory ay nagsara")

func check_evidence_correctness(evidence_id: String) -> bool:
	"""Check if the presented evidence is correct for current context"""
	var current_phase = get_current_phase()
	var correct_evidence = get_correct_evidence_for_phase(current_phase)
	return evidence_id in correct_evidence

func get_current_phase() -> String:
	"""Get current phase based on dialogue line"""
	if current_line >= 0 and current_line <= 4:
		return "arraignment_phase"
	elif current_line >= 5 and current_line <= 12:
		return "opening_statements_phase"
	elif current_line >= 13 and current_line <= 18:
		return "prosecution_case_phase"
	elif current_line >= 19 and current_line <= 25:
		return "defense_case_phase"
	elif current_line >= 26 and current_line <= 30:
		return "cross_examination_phase"
	elif current_line >= 31 and current_line <= 35:
		return "closing_arguments_phase"
	else:
		return "opening_statements_phase"

func get_correct_evidence_for_phase(phase: String) -> Array:
	"""Get correct evidence for current phase"""
	# Load from JSON data
	var file: FileAccess = FileAccess.open("res://data/dialogues/courtroom_dialogue.json", FileAccess.READ)
	if file == null:
		# Fallback to hardcoded values
		match phase:
			"evidence_presentation_phase":
				return ["broken_body_cam", "logbook"]
			"testimony_phase":
				return ["handwriting_sample", "radio_log"]
			"character_testimony_phase":
				return ["autopsy_report", "leos_notebook"]
			_:
				return ["broken_body_cam"]
	
	var text: String = file.get_as_text()
	file.close()
	
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("courtroom"):
		# Fallback to hardcoded values
		return ["broken_body_cam"]
	
	var courtroom_data = parsed["courtroom"]
	if courtroom_data.has("evidence_correctness") and courtroom_data["evidence_correctness"].has(phase):
		return courtroom_data["evidence_correctness"][phase]["correct"]
	else:
		# Fallback to hardcoded values
		match phase:
			"evidence_presentation_phase":
				return ["broken_body_cam", "logbook"]
			"testimony_phase":
				return ["handwriting_sample", "radio_log"]
			"character_testimony_phase":
				return ["autopsy_report", "leos_notebook"]
			_:
				return ["broken_body_cam"]

func present_correct_evidence(evidence_id: String) -> void:
	"""Present correct evidence with positive response using fast tween"""
	print("✅ Correct evidence presented:", evidence_id)
	
	# Play fast success effect
	await fast_evidence_presentation_effect()
	
	# Show positive dialogue
	if dialogue_ui:
		dialogue_ui.show_dialogue_line("Hukom", "Mabuti. Ang ebidensyang ito ay may kaugnayan sa kaso.", true)
		await get_tree().create_timer(1.5).timeout
		
		# Show evidence significance
		var evidence_data = get_evidence_testimony(evidence_id)
		if evidence_data:
			dialogue_ui.show_dialogue_line("Miguel", evidence_data["significance"], true)
			await get_tree().create_timer(2.0).timeout

func present_wrong_evidence(evidence_id: String) -> void:
	"""Present wrong evidence with life system consequences"""
	print("❌ Wrong evidence presented:", evidence_id)
	
	# Lose a life
	lives -= 1
	wrong_evidence_count += 1
	evidence_presented_wrong.append(evidence_id)
	
	# Play failure effect
	await play_failure_effect()
	
	# Show backup dialogue based on remaining lives
	await show_backup_dialogue_for_wrong_evidence()
	
	# Check if game over
	if lives <= 0:
		await handle_game_over()
	else:
		# Show remaining lives
		await show_lives_remaining()
		
		# If lives remain, go back to dialogue chooser
		print("🔄 Lives remaining - returning to dialogue chooser")
		# Reset to allow dialogue to continue
		can_present_evidence = false
		can_give_testimony = false
		can_object = false
		can_highlight_testimony = false

func show_backup_dialogue_for_wrong_evidence() -> void:
	"""Show backup dialogue for wrong evidence presentation"""
	var backup_dialogue = get_backup_dialogue_for_lives(lives)
	
	if dialogue_ui:
		# Judge's reaction
		dialogue_ui.show_dialogue_line("Hukom", backup_dialogue["judge_reaction"], true)
		await get_tree().create_timer(2.0).timeout
		
		# Prosecutor's objection
		dialogue_ui.show_dialogue_line("Fiscal", backup_dialogue["prosecutor_reaction"], true)
		await get_tree().create_timer(2.0).timeout
		
		# Miguel's response
		dialogue_ui.show_dialogue_line("Miguel", backup_dialogue["miguel_response"], true)
		await get_tree().create_timer(2.0).timeout

func get_backup_dialogue_for_lives(remaining_lives: int) -> Dictionary:
	"""Get backup dialogue based on remaining lives"""
	match remaining_lives:
		2:
			return {
				"judge_reaction": "Abogado, ang ebidensyang ito ay walang kaugnayan sa kaso. Mag-ingat ka sa susunod na pagpresenta.",
				"prosecutor_reaction": "Objection! Ang ebidensyang ito ay hindi maaaring tanggapin dahil walang kaugnayan sa kaso!",
				"miguel_response": "Patawad po, Your Honor. Magpapakita ako ng mas angkop na ebidensya."
			}
		1:
			return {
				"judge_reaction": "Abogado, ito na ang huling babala. Ang ebidensyang ito ay hindi naaangkop sa kaso.",
				"prosecutor_reaction": "Objection! Ang depensa ay nagpapakita ng kawalan ng paghahanda!",
				"miguel_response": "Your Honor, humihingi ako ng paumanhin. Magiging mas maingat ako sa susunod."
			}
		0:
			return {
				"judge_reaction": "Abogado, ikaw ay napatunayang hindi handa. Ang kaso ay magpapatuloy nang walang karagdagang ebidensya mula sa depensa.",
				"prosecutor_reaction": "Your Honor, ang depensa ay nagpapakita ng kawalan ng paghahanda at hindi karapat-dapat sa karagdagang pagkakataon.",
				"miguel_response": "Your Honor, humihingi ako ng paumanhin. Nais kong magpatuloy sa kaso."
			}
		_:
			return {
				"judge_reaction": "Abogado, ang ebidensyang ito ay walang kaugnayan sa kaso.",
				"prosecutor_reaction": "Objection! Ang ebidensyang ito ay hindi maaaring tanggapin!",
				"miguel_response": "Patawad po, Your Honor."
			}

func show_lives_remaining() -> void:
	"""Show remaining lives to player"""
	if dialogue_ui:
		dialogue_ui.show_dialogue_line("System", "Remaining Lives: " + str(lives) + "/" + str(max_lives), true)
		await get_tree().create_timer(1.5).timeout

func handle_game_over() -> void:
	"""Handle game over scenario - restart from beginning"""
	print("💀 Game Over - No lives remaining! Restarting from beginning...")
	game_over = true
	
	# Show game over dialogue
	if dialogue_ui:
		dialogue_ui.show_dialogue_line("Hukom", "Abogado, ikaw ay napatunayang hindi handa. Ang kaso ay magpapatuloy nang walang karagdagang ebidensya mula sa depensa.", true)
		await get_tree().create_timer(3.0).timeout
		
		dialogue_ui.show_dialogue_line("System", "GAME OVER - No lives remaining. Restarting from beginning...", true)
		await get_tree().create_timer(2.0).timeout
	
	# RESTART FROM THE BEGINNING
	restart_from_beginning()

func restart_from_beginning() -> void:
	"""Restart the game from the beginning"""
	print("🔄 Restarting game from the beginning...")
	
	# Clear all checkpoints
	if CheckpointManager:
		CheckpointManager.debug_clear_file()
		print("🗑️ All checkpoints cleared")
	
	# Reset task manager
	if task_manager:
		task_manager.reset_tasks()
		print("📋 Tasks reset")
	
	# Go back to intro story
	print("🏠 Returning to intro story...")
	get_tree().change_scene_to_file("res://intro_story.tscn")

func continue_with_limited_evidence() -> void:
	"""Continue the case with limited evidence after game over"""
	print("🔄 Continuing with limited evidence...")
	
	# Set branch to limited evidence
	current_branch = "limited_evidence"
	
	# Show limited evidence dialogue
	if dialogue_ui:
		dialogue_ui.show_dialogue_line("Miguel", "Your Honor, kahit na may limitasyon, patuloy kong ipinaglalaban ang inosensya ni Leo.", true)
		await get_tree().create_timer(2.0).timeout
		
		dialogue_ui.show_dialogue_line("Hukom", "Mabuti. Magpatuloy sa inyong depensa.", true)
		await get_tree().create_timer(2.0).timeout

func play_success_effect() -> void:
	"""Play success effect for correct evidence"""
	print("✅ Playing success effect...")
	
	# Green flash effect
	var flash_overlay = ColorRect.new()
	flash_overlay.color = Color.GREEN
	flash_overlay.size = get_viewport().size
	flash_overlay.position = Vector2.ZERO
	add_child(flash_overlay)
	
	var tween = create_tween()
	tween.tween_property(flash_overlay, "modulate", Color.TRANSPARENT, 0.5)
	await tween.finished
	flash_overlay.queue_free()

func play_failure_effect() -> void:
	"""Play failure effect for wrong evidence"""
	print("❌ Playing failure effect...")
	
	# Red flash effect
	var flash_overlay = ColorRect.new()
	flash_overlay.color = Color.RED
	flash_overlay.size = get_viewport().size
	flash_overlay.position = Vector2.ZERO
	add_child(flash_overlay)
	
	var tween = create_tween()
	tween.tween_property(flash_overlay, "modulate", Color.TRANSPARENT, 0.5)
	await tween.finished
	flash_overlay.queue_free()
	
	# Dramatic camera shake
	await camera_shake_dramatic()

func focus_camera_on_judge() -> void:
	"""Focus camera on the judge using fast tween"""
	print("📷 Focusing camera on judge")
	var judge_node = get_node_or_null("Judge")
	if judge_node:
		print("📷 Judge node found:", judge_node.name, "at", judge_node.position)
		await fast_camera_focus(judge_node, 0.5)
	else:
		print("❌ Judge node not found")

func focus_camera_on_prosecutor() -> void:
	"""Focus camera on the prosecutor using fast tween"""
	print("📷 Focusing camera on prosecutor")
	var prosecutor_node = get_node_or_null("Prosecutor")
	if prosecutor_node:
		await fast_camera_focus(prosecutor_node, 0.5)
	else:
		print("❌ Prosecutor node not found")

func focus_camera_on_defendant() -> void:
	"""Focus camera on the defendant using fast tween"""
	print("📷 Focusing camera on defendant")
	var defendant_node = get_node_or_null("Defendant")
	if defendant_node:
		await fast_camera_focus(defendant_node, 0.5)
	else:
		print("❌ Defendant node not found")

func focus_camera_on_witness() -> void:
	"""Focus camera on the witness using fast tween"""
	print("📷 Focusing camera on witness")
	var witness_node = get_node_or_null("Witness")
	if witness_node:
		await fast_camera_focus(witness_node, 0.5)
	else:
		print("❌ Witness node not found")

func return_camera_to_center() -> void:
	"""Return camera to focus on main character using Camera2D"""
	print("📷 Returning camera to main character")
	if player_camera:
		# Try to find PlayerM's Camera2D
		var player_node = get_node_or_null("PlayerM")
		if player_node:
			var player_camera_node = player_node.get_node_or_null("Camera2D")
			if player_camera_node:
				print("📷 Using PlayerM's Camera2D at:", player_camera_node.global_position)
				var tween = create_tween()
				tween.tween_property(player_camera, "position", player_camera_node.global_position, 0.5)
				tween.parallel().tween_property(player_camera, "zoom", Vector2(1.0, 1.0), 0.5)
				await tween.finished
				print("📷 Camera returned to PlayerM using Camera2D")
			else:
				print("📷 No PlayerM Camera2D found, using position fallback")
				var tween = create_tween()
				tween.tween_property(player_camera, "position", player_node.global_position, 0.5)
				tween.parallel().tween_property(player_camera, "zoom", Vector2(1.0, 1.0), 0.5)
				await tween.finished
				print("📷 Camera returned to PlayerM using position")
		else:
			print("❌ PlayerM node not found")
	else:
		print("❌ Player camera not found")

func end_courtroom_sequence() -> void:
	"""End the courtroom sequence"""
	print("⚖️ Courtroom sequence completed")
	is_courtroom_active = false
	
	# Fade out and return to main menu
	await fade_to_main_menu()

func fade_to_main_menu() -> void:
	"""Fade out and return to main menu"""
	print("🎬 Fading to main menu...")
	
	# Create fade overlay
	var fade_overlay = ColorRect.new()
	fade_overlay.color = Color.BLACK
	fade_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_tree().current_scene.add_child(fade_overlay)
	
	# Fade out
	var fade_tween = create_tween()
	fade_tween.tween_property(fade_overlay, "modulate:a", 1.0, 2.0)
	await fade_tween.finished
	
	# Stop BGM
	stop_bgm()
	
	# Change to main menu
	get_tree().change_scene_to_file("res://intro_story.tscn")
	
	# Set checkpoint for courtroom completion
	if has_node("/root/CheckpointManager"):
		var checkpoint_manager = get_node("/root/CheckpointManager")
		checkpoint_manager.set_checkpoint(checkpoint_manager.CheckpointType.COURTROOM_COMPLETED)
		print("🎯 Courtroom checkpoint set")

# --------------------------
# INPUT HANDLING
# --------------------------

func _unhandled_input(event: InputEvent) -> void:
	"""Handle input for courtroom interactions"""
	if not is_courtroom_active:
		return
	
	# DEBUG KEYS - Unlock everything for testing
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_F1:
				debug_unlock_all_checkpoints()
				return
			KEY_F2:
				debug_unlock_all_evidence()
				return
			KEY_F3:
				debug_reset_courtroom()
				return
			KEY_F4:
				debug_add_life()
				return
	
	# SIMPLE NEXT BUTTON - SPACE/ENTER (with strict spam protection)
	if event is InputEventKey and event.pressed and not event.echo:
		if (event.keycode == KEY_SPACE or event.keycode == KEY_ENTER) and waiting_for_input and not dialogue_typing:
			print("⏭️ Next button pressed!")
			waiting_for_input = false
			# Wait for text to completely finish before advancing
			await get_tree().create_timer(0.5).timeout
			current_line += 1
			show_next_line()
			return
		elif (event.keycode == KEY_SPACE or event.keycode == KEY_ENTER) and dialogue_typing:
			print("⚠️ WAIT FOR TEXT TO FINISH! Dialogue still typing...")
			return
		elif (event.keycode == KEY_SPACE or event.keycode == KEY_ENTER) and evidence_presentation_active:
			print("⚠️ Evidence presentation active - cannot advance dialogue")
			return
	
	# Evidence presentation (TAB key)
	if event.is_action_pressed("evidence_inventory") and can_present_evidence:
		print("📋 Evidence presentation requested")
		show_evidence_inventory()
		return
	
	# Testimony highlighting (Mouse click or H key)
	if event.is_action_pressed("ui_accept") and can_highlight_testimony:
		print("🔍 Testimony highlighting requested")
		# This would be triggered by clicking on testimony sentences
		# For now, simulate highlighting a sentence
		highlight_testimony_sentence("Sa aking pagkakaalam, si Leo ay isang mabuting tao")
		return
	
	# Present evidence against testimony (TAB key when highlighting)
	if event.is_action_pressed("evidence_inventory") and can_highlight_testimony and testimony_discrepancies.size() > 0:
		print("⚖️ Presenting evidence against testimony")
		show_evidence_inventory()
		return
	
	# Testimony (Enter key)
	if event.is_action_pressed("ui_accept") and can_give_testimony:
		print("🗣️ Testimony requested")
		give_testimony()
		return
	
	# Objection (O key)
	if event.is_action_pressed("ui_accept") and can_object:
		print("⚖️ OBJECTION! requested")
		play_objection_sequence()
		return
	
	# Next dialogue (Space key)
	if event.is_action_pressed("ui_accept") and not can_give_testimony and not can_object and not can_highlight_testimony:
		print("▶️ Next dialogue requested")
		show_next_line()
		return

func give_testimony() -> void:
	"""Handle testimony giving"""
	print("🗣️ Giving testimony...")
	
	# Add testimony to completed list
	testimony_completed.append("testimony_" + str(testimony_completed.size() + 1))
	
	# Show testimony dialogue
	if dialogue_ui:
		dialogue_ui.show_dialogue_line("Miguel", "Gusto kong ipresenta ang aking testimonya, Your Honor!", true)
		await get_tree().create_timer(2.0).timeout
	
	print("🗣️ Testimony completed")

func present_character_testimony(character_name: String) -> void:
	"""Present character testimony with Phoenix Wright-style objections"""
	print("🗣️ Presenting testimony from:", character_name)
	
	# Get character testimony data
	var testimony_data = get_character_testimony(character_name)
	if testimony_data:
		# Play objection sequence
		await play_objection_sequence()
		
		# Show character testimony
		if dialogue_ui:
			dialogue_ui.show_dialogue_line(character_name, testimony_data["testimony"], true)
			await get_tree().create_timer(3.0).timeout
			
			# Show prosecution objection
			dialogue_ui.show_dialogue_line("Fiscal", testimony_data["objection"], true)
			await get_tree().create_timer(2.0).timeout
			
			# Show counter-objection
			dialogue_ui.show_dialogue_line("Miguel", testimony_data["counter_objection"], true)
			await get_tree().create_timer(2.0).timeout
			
			# Show significance
			dialogue_ui.show_dialogue_line("Miguel", testimony_data["significance"], true)
			await get_tree().create_timer(2.0).timeout
			
			# Judge's decision
			dialogue_ui.show_dialogue_line("Hukom", "Sustained. Ang testimonya ay maaaring tanggapin. Magpatuloy, " + character_name + ".", true)
			await get_tree().create_timer(2.0).timeout

func get_character_testimony(character_name: String) -> Dictionary:
	"""Get character testimony data"""
	# This would load from the JSON file
	# For now, return sample data based on character
	match character_name:
		"Kapitana":
			return {
				"testimony": "Ako si Kapitana, at ako ay magbibigay ng aking testimonya tungkol sa insidente. Sa aking pagkakaalam, si Leo ay isang mabuting tao at hindi niya kayang gumawa ng krimen na iyon!",
				"objection": "Objection! Ang testimonya ng Kapitana ay hindi maaaring tanggapin dahil siya ay may personal na relasyon sa akusado!",
				"counter_objection": "Objection! Your Honor, ang testimonya ng Kapitana ay may mahalagang impormasyon tungkol sa karakter ni Leo!",
				"significance": "Ang testimonya ng Kapitana ay nagpapakita ng mabuting karakter ni Leo at nagpapatunay na siya ay hindi kayang gumawa ng krimen."
			}
		"PO1":
			return {
				"testimony": "Ako si PO1, at ako ay magbibigay ng aking testimonya tungkol sa imbestigasyon. Sa aking pagkakaalam, may mga inconsistencies sa imbestigasyon at hindi lahat ng ebidensya ay na-proseso nang maayos.",
				"objection": "Objection! Ang testimonya ng PO1 ay hindi maaaring tanggapin dahil siya ay may conflict of interest!",
				"counter_objection": "Objection! Your Honor, ang testimonya ng PO1 ay nagpapakita ng mga problema sa imbestigasyon!",
				"significance": "Ang testimonya ng PO1 ay nagpapakita ng mga problema sa imbestigasyon at nagpapatunay na may mga inconsistencies sa proseso."
			}
		"Leticia":
			return {
				"testimony": "Ako si Leticia, at ako ay magbibigay ng aking testimonya tungkol sa insidente. Sa aking pagkakaalam, si Leo ay nasa ibang lugar sa panahon ng insidente at hindi niya kayang gumawa ng krimen na iyon!",
				"objection": "Objection! Ang testimonya ni Leticia ay hindi maaaring tanggapin dahil siya ay may personal na relasyon sa akusado!",
				"counter_objection": "Objection! Your Honor, ang testimonya ni Leticia ay nagbibigay ng mahalagang impormasyon tungkol sa alibi ni Leo!",
				"significance": "Ang testimonya ni Leticia ay nagbibigay ng mahalagang impormasyon tungkol sa alibi ni Leo at nagpapatunay na siya ay nasa ibang lugar sa panahon ng insidente."
			}
		_:
			return {}

func play_dramatic_effect() -> void:
	"""Play dramatic Phoenix Wright-style effect using fast tween"""
	print("🎭 Playing dramatic effect...")
	
	# Use fast parallel effects
	await fast_parallel_effects()
	
	# Dramatic music
	if audio_manager:
		# Play dramatic courtroom music
		print("🎵 Playing dramatic courtroom music")

func play_objection_sequence() -> void:
	"""Play Phoenix Wright-style objection sequence using fast tween"""
	print("⚖️ OBJECTION! Playing objection sequence...")
	
	# Use fast objection effect
	await fast_objection_effect()
	
	# Play objection sound effect
	if audio_manager:
		print("🔊 Playing objection sound effect")
	
	# Dramatic pause
	await get_tree().create_timer(1.0).timeout

func camera_shake_dramatic() -> void:
	"""Dramatic camera shake for objections"""
	print("📷 Dramatic camera shake...")
	
	var camera = get_viewport().get_camera_2d()
	if not camera:
		return
	
	var original_pos = camera.position
	var shake_tween = create_tween()
	
	# Intense shake for objections
	shake_tween.tween_property(camera, "position", original_pos + Vector2(20, 15), 0.1)
	shake_tween.tween_property(camera, "position", original_pos + Vector2(-18, 12), 0.1)
	shake_tween.tween_property(camera, "position", original_pos + Vector2(15, -10), 0.1)
	shake_tween.tween_property(camera, "position", original_pos + Vector2(-12, 8), 0.1)
	shake_tween.tween_property(camera, "position", original_pos + Vector2(8, -5), 0.1)
	shake_tween.tween_property(camera, "position", original_pos, 0.2)

func objection_camera_shake() -> void:
	"""Camera shake for objections"""
	print("📷 Objection camera shake...")
	
	var camera = get_viewport().get_camera_2d()
	if not camera:
		return
	
	var original_pos = camera.position
	var shake_tween = create_tween()
	
	# Quick objection shake
	shake_tween.tween_property(camera, "position", original_pos + Vector2(10, 8), 0.05)
	shake_tween.tween_property(camera, "position", original_pos + Vector2(-8, 6), 0.05)
	shake_tween.tween_property(camera, "position", original_pos + Vector2(6, -4), 0.05)
	shake_tween.tween_property(camera, "position", original_pos, 0.1)

func dramatic_camera_shake() -> void:
	"""Dramatic camera shake for big reveals"""
	print("📷 Dramatic camera shake...")
	
	var camera = get_viewport().get_camera_2d()
	if not camera:
		return
	
	var original_pos = camera.position
	var shake_tween = create_tween()
	
	# Big dramatic shake
	shake_tween.tween_property(camera, "position", original_pos + Vector2(25, 20), 0.08)
	shake_tween.tween_property(camera, "position", original_pos + Vector2(-22, 18), 0.08)
	shake_tween.tween_property(camera, "position", original_pos + Vector2(20, -15), 0.08)
	shake_tween.tween_property(camera, "position", original_pos + Vector2(-18, 12), 0.08)
	shake_tween.tween_property(camera, "position", original_pos + Vector2(15, -10), 0.08)
	shake_tween.tween_property(camera, "position", original_pos + Vector2(-12, 8), 0.08)
	shake_tween.tween_property(camera, "position", original_pos, 0.3)

func screen_flash_effect() -> void:
	"""Screen flash effect for dramatic moments"""
	print("⚡ Screen flash effect...")
	
	# Create flash overlay
	var flash_overlay = ColorRect.new()
	flash_overlay.color = Color.WHITE
	flash_overlay.size = get_viewport().size
	flash_overlay.position = Vector2.ZERO
	add_child(flash_overlay)
	
	# Flash animation
	var tween = create_tween()
	tween.tween_property(flash_overlay, "modulate", Color.TRANSPARENT, 0.3)
	await tween.finished
	
	flash_overlay.queue_free()

func present_evidence_with_objection(evidence_id: String) -> void:
	"""Present evidence with Phoenix Wright-style objection sequence"""
	print("📋 Presenting evidence with objection:", evidence_id)
	
	# Play objection sequence
	await play_objection_sequence()
	
	# Show evidence testimony
	var evidence_data = get_evidence_testimony(evidence_id)
	if evidence_data:
		if dialogue_ui:
			dialogue_ui.show_dialogue_line("Miguel", evidence_data["testimony"], true)
			await get_tree().create_timer(3.0).timeout
			
			# Show prosecution objection
			dialogue_ui.show_dialogue_line("Fiscal", evidence_data["objection"], true)
			await get_tree().create_timer(2.0).timeout
			
			# Show counter-objection
			dialogue_ui.show_dialogue_line("Miguel", evidence_data["counter_objection"], true)
			await get_tree().create_timer(2.0).timeout
			
			# Show significance
			dialogue_ui.show_dialogue_line("Miguel", evidence_data["significance"], true)
			await get_tree().create_timer(2.0).timeout

func get_evidence_testimony(evidence_id: String) -> Dictionary:
	"""Get evidence testimony data"""
	# This would load from the JSON file
	# For now, return sample data
	return {
		"testimony": "OBJECTION! Ang ebidensyang ito ay nagpapatunay sa inosensya ni Leo!",
		"objection": "Objection! Ang ebidensyang ito ay hindi maaaring tanggapin!",
		"counter_objection": "Objection! Your Honor, ang ebidensyang ito ay may mahalagang impormasyon!",
		"significance": "Ang ebidensyang ito ay direktang sumasalungat sa kaso ng prosecution!"
	}

# --------------------------
# DEBUG CONTROLS
# --------------------------

func _input(event: InputEvent) -> void:
	"""Handle debug input"""
	if event is InputEventKey and event.pressed:
		match event.physical_keycode:
			KEY_F10:
				# F10 - Complete courtroom sequence instantly (DEBUG ONLY)
				var debug_mode = false  # Set to true only for development
				if debug_mode:
					end_courtroom_sequence()
					print("🚀 DEBUG: Courtroom sequence skipped")
				else:
					print("⚠️ Debug skip disabled - complete courtroom normally")
			KEY_F1:
				# F1 - Show evidence inventory
				show_evidence_inventory()
			KEY_F2:
				# F2 - Give testimony
				give_testimony()
			KEY_F3:
				# F3 - Focus on judge
				await focus_camera_on_judge()
			KEY_F4:
				# F4 - Focus on prosecutor
				await focus_camera_on_prosecutor()
			KEY_F5:
				# F5 - Focus on defendant
				await focus_camera_on_defendant()
			KEY_F6:
				# F6 - Focus on witness
				await focus_camera_on_witness()
			KEY_F7:
				# F7 - Return camera to center
				await return_camera_to_center()
			KEY_F8:
				# F8 - Restart courtroom (DEBUG)
				restart_courtroom()
			KEY_F9:
				# F9 - Add life (DEBUG)
				add_life_debug()

func restart_courtroom() -> void:
	"""Restart the courtroom sequence"""
	print("🔄 Restarting courtroom...")
	
	# Reset all variables
	lives = max_lives
	wrong_evidence_count = 0
	current_branch = "main"
	evidence_presented_wrong.clear()
	game_over = false
	current_line = 0
	
	# Restart dialogue
	start_courtroom_sequence()

func add_life_debug() -> void:
	"""Add a life (DEBUG ONLY)"""
	if lives < max_lives:
		lives += 1
		print("❤️ Life added. Current lives:", lives)
	else:
		print("❤️ Already at max lives:", max_lives)

func start_testimony_analysis() -> void:
	"""Start testimony analysis mode"""
	print("🔍 Starting testimony analysis...")
	can_highlight_testimony = true
	
	# Show analysis instructions
	if dialogue_ui:
		dialogue_ui.show_dialogue_line("System", "🔍 TESTIMONY ANALYSIS MODE: Click on sentences to highlight discrepancies. Press ENTER to present evidence against highlighted testimony.", true)
		await get_tree().create_timer(3.0).timeout

func highlight_testimony_sentence(sentence: String) -> void:
	"""Highlight a testimony sentence for analysis"""
	print("🔍 Highlighting testimony sentence:", sentence)
	
	if sentence not in highlighted_sentences:
		highlighted_sentences.append(sentence)
		print("🔍 Sentence highlighted:", sentence)
		
		# Show highlighting effect
		await play_highlight_effect()
		
		# Check for discrepancies
		var discrepancy = find_testimony_discrepancy(sentence)
		if discrepancy:
			print("🔍 Discrepancy found:", discrepancy)
			testimony_discrepancies.append(discrepancy)
			
			# Show discrepancy dialogue
			if dialogue_ui:
				dialogue_ui.show_dialogue_line("Miguel", "OBJECTION! Your Honor, may pagkakasalungatan sa testimonya na ito!", true)
				await get_tree().create_timer(2.0).timeout
				
				dialogue_ui.show_dialogue_line("Miguel", discrepancy["analysis"], true)
				await get_tree().create_timer(3.0).timeout
				
				dialogue_ui.show_dialogue_line("Miguel", "Gusto kong ipresenta ang ebidensya laban sa testimonyang ito!", true)
				await get_tree().create_timer(2.0).timeout

func find_testimony_discrepancy(sentence: String) -> Dictionary:
	"""Find discrepancies in highlighted testimony"""
	# Define testimony discrepancies
	var discrepancies = {
		"Sa aking pagkakaalam, si Leo ay isang mabuting tao": {
			"analysis": "Your Honor, ang testimonya na ito ay sumasalungat sa mga ebidensya ng police report na nagpapakita ng mga inconsistencies sa character ni Leo!",
			"evidence_needed": "handwriting_sample"
		},
		"may mga inconsistencies sa imbestigasyon": {
			"analysis": "Your Honor, ang testimonya na ito ay nagpapakita na ang imbestigasyon ay may mga problema, ngunit ang prosecution ay nagtatago ng mga impormasyon!",
			"evidence_needed": "radio_log"
		},
		"si Leo ay nasa ibang lugar sa panahon ng insidente": {
			"analysis": "Your Honor, ang testimonya na ito ay sumasalungat sa timeline ng prosecution at nagpapakita ng mga inconsistencies sa alibi!",
			"evidence_needed": "leos_notebook"
		}
	}
	
	# Check for partial matches
	for key in discrepancies.keys():
		if key in sentence or sentence in key:
			return discrepancies[key]
	
	return {}

func play_highlight_effect() -> void:
	"""Play visual effect for highlighting testimony"""
	print("✨ Playing highlight effect...")
	
	# Yellow flash effect for highlighting
	var flash_overlay = ColorRect.new()
	flash_overlay.color = Color.YELLOW
	flash_overlay.size = get_viewport().size
	flash_overlay.position = Vector2.ZERO
	add_child(flash_overlay)
	
	var tween = create_tween()
	tween.tween_property(flash_overlay, "modulate", Color.TRANSPARENT, 0.3)
	await tween.finished
	flash_overlay.queue_free()

func present_evidence_against_testimony(evidence_id: String) -> void:
	"""Present evidence against highlighted testimony"""
	print("⚖️ Presenting evidence against testimony:", evidence_id)
	
	# Check if evidence is correct for the discrepancy
	var is_correct_evidence = check_evidence_against_discrepancy(evidence_id)
	
	if is_correct_evidence:
		await present_damning_evidence(evidence_id)
	else:
		await present_wrong_evidence(evidence_id)

func check_evidence_against_discrepancy(evidence_id: String) -> bool:
	"""Check if evidence is correct for current discrepancy"""
	if testimony_discrepancies.size() == 0:
		return false
	
	var current_discrepancy = testimony_discrepancies[-1]
	return evidence_id == current_discrepancy["evidence_needed"]

func present_damning_evidence(evidence_id: String) -> void:
	"""Present damning evidence with dramatic effect"""
	print("💥 Presenting damning evidence:", evidence_id)
	
	# Play dramatic effect
	await play_dramatic_effect()
	
	# Show damning evidence dialogue
	if dialogue_ui:
		dialogue_ui.show_dialogue_line("Miguel", "OBJECTION! Your Honor, ang ebidensyang ito ay nagpapatunay na may pagkakasalungatan sa testimonya!", true)
		await get_tree().create_timer(3.0).timeout
		
		# Show evidence significance
		var evidence_data = get_evidence_testimony(evidence_id)
		if evidence_data:
			dialogue_ui.show_dialogue_line("Miguel", evidence_data["significance"], true)
			await get_tree().create_timer(3.0).timeout
			
			# Show damning conclusion
			dialogue_ui.show_dialogue_line("Miguel", "Ang ebidensyang ito ay nagpapatunay na ang testimonya ay may mga inconsistencies at hindi maaaring pagkatiwalaan!", true)
			await get_tree().create_timer(3.0).timeout
			
			# Show legal significance
			dialogue_ui.show_dialogue_line("Miguel", "Your Honor, ang ebidensyang ito ay nagpapatunay na ang prosecution ay hindi nakapagpatunay ng kaso beyond reasonable doubt!", true)
			await get_tree().create_timer(3.0).timeout
		
		# Prosecutor's reaction
		dialogue_ui.show_dialogue_line("Fiscal", "Objection! Your Honor, ang depensa ay nagpapakita ng kawalan ng respeto sa korte!", true)
		await get_tree().create_timer(2.0).timeout
		
		# Judge's decision
		dialogue_ui.show_dialogue_line("Hukom", "Sustained. Ang ebidensya ay may kaugnayan sa kaso. Magpatuloy, Abogado.", true)
		await get_tree().create_timer(2.0).timeout

func show_legal_procedure_info() -> void:
	"""Show information about current legal procedure"""
	var current_phase = get_current_phase()
	var procedure_info = get_legal_procedure_info(current_phase)
	
	if dialogue_ui:
		dialogue_ui.show_dialogue_line("System", "📋 Current Phase: " + current_phase.replace("_", " ").capitalize(), true)
		await get_tree().create_timer(1.5).timeout
		
		dialogue_ui.show_dialogue_line("System", "📋 " + procedure_info, true)
		await get_tree().create_timer(2.0).timeout

func get_legal_procedure_info(phase: String) -> String:
	"""Get legal procedure information for current phase"""
	match phase:
		"arraignment_phase":
			return "Ang akusado ay binabasa ng akusasyon at nagpahayag ng hindi nagkasala"
		"opening_statements_phase":
			return "Ang prosecution at depensa ay naglalahad ng kanilang mga argumento"
		"prosecution_case_phase":
			return "Ang prosecution ay naglalahad ng kanilang ebidensya at saksi"
		"defense_case_phase":
			return "Ang depensa ay naglalahad ng kanilang ebidensya at saksi"
		"cross_examination_phase":
			return "Ang prosecution ay nag-cross-examine sa mga saksi ng depensa"
		"closing_arguments_phase":
			return "Ang prosecution at depensa ay naglalahad ng kanilang final arguments"
		_:
			return "Ang hukuman ay magdedeliberate at magbibigay ng hatol"

# ===== FAST TWEEN-BASED ANIMATIONS =====

func fast_camera_focus(target: Node2D, duration: float = 0.5) -> void:
	"""Fast camera focus using target's Camera2D node"""
	if not player_camera or not target:
		return
	
	print("📷 Fast camera focus on:", target.name)
	
	# Try to find Camera2D child in target
	var target_camera = target.get_node_or_null("Camera2D")
	if target_camera:
		print("📷 Using target's Camera2D at:", target_camera.global_position)
		var tween = create_tween()
		tween.tween_property(player_camera, "position", target_camera.global_position, duration)
		tween.parallel().tween_property(player_camera, "zoom", Vector2(1.0, 1.0), duration)
		await tween.finished
		print("📷 Camera focused on:", target.name, "using Camera2D")
	else:
		# Fallback to position-based focus
		print("📷 No Camera2D found, using position fallback")
		var tween = create_tween()
		tween.tween_property(player_camera, "position", target.global_position, duration)
		tween.parallel().tween_property(player_camera, "zoom", Vector2(1.0, 1.0), duration)
		await tween.finished
		print("📷 Camera focused on:", target.name, "using position")

func fast_camera_shake(intensity: float = 10.0, duration: float = 0.3) -> void:
	"""Fast camera shake using tween"""
	if not player_camera:
		return
	
	var original_pos = player_camera.global_position
	var shake_tween = create_tween()
	
	# Quick shake
	for i in range(3):
		var random_offset = Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
		shake_tween.tween_property(player_camera, "global_position", original_pos + random_offset, duration / 3)
	
	# Return to original
	shake_tween.tween_property(player_camera, "global_position", original_pos, duration / 3)
	await shake_tween.finished

func fast_screen_flash(color: Color = Color.WHITE, duration: float = 0.2) -> void:
	"""Fast screen flash using tween"""
	var flash_overlay = ColorRect.new()
	flash_overlay.color = color
	flash_overlay.size = get_viewport().size
	flash_overlay.modulate.a = 0.0
	get_tree().current_scene.add_child(flash_overlay)
	
	var flash_tween = create_tween()
	flash_tween.tween_property(flash_overlay, "modulate:a", 1.0, duration / 2)
	flash_tween.tween_property(flash_overlay, "modulate:a", 0.0, duration / 2)
	await flash_tween.finished
	
	flash_overlay.queue_free()

func fast_ui_fade_in(ui_element: Control, duration: float = 0.3) -> void:
	"""Fast UI fade in using tween"""
	if not ui_element:
		return
	
	ui_element.modulate.a = 0.0
	ui_element.visible = true
	
	var fade_tween = create_tween()
	fade_tween.tween_property(ui_element, "modulate:a", 1.0, duration)
	await fade_tween.finished

func fast_ui_fade_out(ui_element: Control, duration: float = 0.3) -> void:
	"""Fast UI fade out using tween"""
	if not ui_element:
		return
	
	var fade_tween = create_tween()
	fade_tween.tween_property(ui_element, "modulate:a", 0.0, duration)
	await fade_tween.finished
	ui_element.visible = false

func fast_scale_effect(node: Node2D, scale_factor: float = 1.2, duration: float = 0.2) -> void:
	"""Fast scale effect using tween"""
	if not node:
		return
	
	var original_scale = node.scale
	var scale_tween = create_tween()
	scale_tween.tween_property(node, "scale", original_scale * scale_factor, duration / 2)
	scale_tween.tween_property(node, "scale", original_scale, duration / 2)
	await scale_tween.finished

func fast_parallel_effects() -> void:
	"""Run multiple effects in parallel for speed"""
	var parallel_tween = create_tween()
	parallel_tween.set_parallel(true)
	
	# Camera shake
	await fast_camera_shake(15.0, 0.4)
	
	# Screen flash
	await fast_screen_flash(Color.WHITE, 0.3)
	
	# Scale effect on judge
	if judge:
		await fast_scale_effect(judge, 1.1, 0.3)

func fast_evidence_presentation_effect() -> void:
	"""Fast effect for evidence presentation"""
	var parallel_tween = create_tween()
	parallel_tween.set_parallel(true)
	
	# Green flash for success
	await fast_screen_flash(Color.GREEN, 0.2)
	
	# Quick camera shake
	await fast_camera_shake(5.0, 0.2)

func fast_objection_effect() -> void:
	"""Fast objection effect"""
	var parallel_tween = create_tween()
	parallel_tween.set_parallel(true)
	
	# Red flash for objection
	await fast_screen_flash(Color.RED, 0.3)
	
	# Intense camera shake
	await fast_camera_shake(20.0, 0.5)
	
	# Scale effect on prosecutor
	if prosecutor:
		await fast_scale_effect(prosecutor, 1.2, 0.3)

# ===== DEBUG FUNCTIONS =====

func debug_unlock_all_checkpoints() -> void:
	"""Debug: Unlock all checkpoints for testing"""
	print("🔧 DEBUG: Unlocking all checkpoints...")
	
	if CheckpointManager:
		# Set all required checkpoints
		CheckpointManager.set_checkpoint(CheckpointManager.CheckpointType.BEDROOM_COMPLETED)
		CheckpointManager.set_checkpoint(CheckpointManager.CheckpointType.BEDROOM_CUTSCENE_COMPLETED)
		CheckpointManager.set_checkpoint(CheckpointManager.CheckpointType.LOWER_LEVEL_COMPLETED)
		CheckpointManager.set_checkpoint(CheckpointManager.CheckpointType.POLICE_LOBBY_CUTSCENE_COMPLETED)
		CheckpointManager.set_checkpoint(CheckpointManager.CheckpointType.BARANGAY_HALL_CUTSCENE_COMPLETED)
		CheckpointManager.set_checkpoint(CheckpointManager.CheckpointType.HEAD_POLICE_COMPLETED)
		CheckpointManager.set_checkpoint(CheckpointManager.CheckpointType.MORGUE_COMPLETED)
		print("✅ All checkpoints unlocked!")
	else:
		print("❌ CheckpointManager not found!")

func debug_unlock_all_evidence() -> void:
	"""Debug: Unlock all evidence for testing"""
	print("🔧 DEBUG: Unlocking all evidence...")
	
	if EvidenceInventorySettings:
		# Add all 6 evidence types
		EvidenceInventorySettings.add_evidence("broken_body_cam")
		EvidenceInventorySettings.add_evidence("logbook")
		EvidenceInventorySettings.add_evidence("handwriting_sample")
		EvidenceInventorySettings.add_evidence("radio_log")
		EvidenceInventorySettings.add_evidence("autopsy_report")
		EvidenceInventorySettings.add_evidence("leos_notebook")
		print("✅ All evidence unlocked!")
	else:
		print("❌ EvidenceInventorySettings not found!")

func debug_reset_courtroom() -> void:
	"""Debug: Reset courtroom state"""
	print("🔧 DEBUG: Resetting courtroom...")
	
	# Reset courtroom state
	current_line = 0
	lives = 3
	wrong_evidence_count = 0
	game_over = false
	current_branch = "main"
	evidence_presented.clear()
	testimony_completed.clear()
	evidence_presented_wrong.clear()
	backup_dialogues.clear()
	testimony_discrepancies.clear()
	highlighted_sentences.clear()
	
	# Reset input states
	can_present_evidence = false
	can_give_testimony = false
	can_object = false
	can_highlight_testimony = false
	
	print("✅ Courtroom reset!")

func debug_add_life() -> void:
	"""Debug: Add a life"""
	if lives < max_lives:
		lives += 1
		print("🔧 DEBUG: Life added. Current lives:", lives)
		show_lives_remaining()
	else:
		print("🔧 DEBUG: Already at max lives:", max_lives)
