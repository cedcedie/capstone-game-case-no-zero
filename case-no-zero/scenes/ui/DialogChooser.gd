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
	"""Find the player character (kept for compatibility)"""
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
	"""Show 2 choices following the player"""
	current_choices = choices
	
	# Hide all first
	hide_all_choices()
	
	# Only support 2 choices now
	if choices.size() >= 2:
		label1.text = choices[0]
		label2.text = choices[1]
		choice1.visible = true
		choice2.visible = true
		
		# Position the entire CanvasLayer to follow the player
		position_canvas_following_player()
	
	# Show the dialog chooser
	visible = true

func position_canvas_following_player():
	"""Position the entire CanvasLayer to follow the player"""
	if not player:
		find_player()
	
	if player:
		# Get player's world position
		var player_pos = player.global_position
		
		# Convert world position to screen position
		var camera = get_viewport().get_camera_2d()
		if camera:
			var player_screen_pos = camera.to_screen_coordinate(player_pos)
			
			# Set the CanvasLayer's offset to center on the player
			# This makes your centered choices appear at the player's screen position
			offset = Vector2(
				player_screen_pos.x - (get_viewport().get_visible_rect().size.x / 2),
				player_screen_pos.y - (get_viewport().get_visible_rect().size.y / 2)
			)
			
			print("🎯 DialogChooser: Following player at screen pos:", player_screen_pos)
		else:
			print("⚠️ DialogChooser: No camera found")
	else:
		print("⚠️ DialogChooser: No player found")

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
