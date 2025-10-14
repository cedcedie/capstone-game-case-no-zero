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
	
	# Enable mouse input on NinePatchRect nodes
	choice1.mouse_filter = Control.MOUSE_FILTER_PASS
	choice2.mouse_filter = Control.MOUSE_FILTER_PASS
	
	# Connect mouse input to choices
	choice1.gui_input.connect(_on_choice1_input)
	choice2.gui_input.connect(_on_choice2_input)
	
	# Connect mouse enter/exit for hover effects
	choice1.mouse_entered.connect(_on_choice1_entered)
	choice1.mouse_exited.connect(_on_choice1_exited)
	choice2.mouse_entered.connect(_on_choice2_entered)
	choice2.mouse_exited.connect(_on_choice2_exited)
	
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
	"""Position the choices centered on screen"""
	# Reset offset to center the choices on screen
	offset = Vector2.ZERO
	
	# Position choices in the center of the screen
	var screen_size = get_viewport().get_visible_rect().size
	var center_x = screen_size.x / 2
	var center_y = screen_size.y / 2
	
	# Position choice1 above center
	choice1.position = Vector2(center_x - choice1.size.x / 2, center_y - 60)
	# Position choice2 below center  
	choice2.position = Vector2(center_x - choice2.size.x / 2, center_y + 20)
	
	print("🎯 DialogChooser: Choices positioned at center of screen")

func hide_all_choices():
	"""Hide all choice boxes"""
	choice1.visible = false
	choice2.visible = false
	# Reset hover effects
	choice1.modulate = Color.WHITE
	choice2.modulate = Color.WHITE
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

func _on_choice1_entered():
	choice1.modulate = Color(1.2, 1.2, 1.2, 1.0)

func _on_choice1_exited():
	choice1.modulate = Color.WHITE

func _on_choice2_entered():
	choice2.modulate = Color(1.2, 1.2, 1.2, 1.0)

func _on_choice2_exited():
	choice2.modulate = Color.WHITE

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
