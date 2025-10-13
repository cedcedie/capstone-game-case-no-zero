extends CanvasLayer

signal choice_selected(choice_index: int)

@onready var choice1: NinePatchRect = $Choice1
@onready var choice2: NinePatchRect = $Choice2
@onready var label1: Label = $Choice1/Label
@onready var label2: Label = $Choice2/Label

var current_choices: Array = []
var selected_choice: int = -1
var player: CharacterBody2D = null

func _ready():
	# Initially hide all choices
	hide_all_choices()
	
	# Connect mouse input to choices
	choice1.gui_input.connect(_on_choice1_input)
	choice2.gui_input.connect(_on_choice2_input)
	
	# Find the player character
	find_player()

func find_player():
	"""Find the player character to follow"""
	# Try to find player in current scene
	var current_scene = get_tree().current_scene
	if current_scene:
		player = current_scene.get_node_or_null("PlayerM")
		if not player:
			# Try alternative names
			player = current_scene.get_node_or_null("Player")
			if not player:
				player = current_scene.get_node_or_null("Miguel")
	
	print("🎯 DialogChooser: Player found:", player != null)

func show_choices(choices: Array):
	"""Show 2 choices, positioned relative to player"""
	current_choices = choices
	
	# Hide all first
	hide_all_choices()
	
	# Only support 2 choices now
	if choices.size() >= 2:
		label1.text = choices[0]
		label2.text = choices[1]
		choice1.visible = true
		choice2.visible = true
		
		# Position choices relative to player/camera
		position_choices_relative_to_player()
	
	# Show the dialog chooser
	visible = true

func position_choices_relative_to_player():
	"""Position choices relative to player position"""
	if not player:
		find_player()
	
	if player:
		# Get player's screen position
		var player_screen_pos = get_viewport().get_camera_2d().to_screen_coordinate(player.global_position)
		
		# Position choices above player
		var choice_y_offset = -80  # Above player
		var choice_spacing = 40    # Space between choices
		
		# Choice 1 position
		choice1.position = Vector2(
			player_screen_pos.x - 160,  # Center horizontally (320px / 2)
			player_screen_pos.y + choice_y_offset
		)
		
		# Choice 2 position
		choice2.position = Vector2(
			player_screen_pos.x - 160,  # Center horizontally (320px / 2)
			player_screen_pos.y + choice_y_offset + choice_spacing
		)
		
		print("🎯 DialogChooser: Positioned at player screen pos:", player_screen_pos)
	else:
		# Fallback to center of screen if no player found
		var screen_size = get_viewport().get_visible_rect().size
		choice1.position = Vector2(screen_size.x / 2 - 160, screen_size.y / 2 - 40)
		choice2.position = Vector2(screen_size.x / 2 - 160, screen_size.y / 2)
		print("⚠️ DialogChooser: No player found, using screen center")

func hide_all_choices():
	"""Hide all choice boxes"""
	choice1.visible = false
	choice2.visible = false
	visible = false

func _on_choice1_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		selected_choice = 0
		choice_selected.emit(0)
		hide_all_choices()

func _on_choice2_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		selected_choice = 1
		choice_selected.emit(1)
		hide_all_choices()

func _input(event):
	# Handle keyboard input for choices
	if not visible:
		return
		
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				if current_choices.size() >= 1:
					selected_choice = 0
					choice_selected.emit(0)
					hide_all_choices()
			KEY_2:
				if current_choices.size() >= 2:
					selected_choice = 1
					choice_selected.emit(1)
					hide_all_choices()
