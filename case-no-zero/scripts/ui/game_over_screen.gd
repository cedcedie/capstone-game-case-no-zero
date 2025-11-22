extends CanvasLayer

# Signal emitted when try again button is pressed
signal try_again_pressed

@onready var container: Control = $Container
@onready var try_again_button: Button = $Container/ButtonContainer/TryAgainButton
@onready var game_over_label: Label = $Container/GameOverLabel

var is_visible: bool = false

# Audio players for UI sounds
var open_player: AudioStreamPlayer = null
var confirm_player: AudioStreamPlayer = null

func _ready():
	"""Initialize the game over screen"""
	# Start hidden
	hide()
	is_visible = false
	
	# Setup audio players
	open_player = AudioStreamPlayer.new()
	open_player.stream = load("res://assets/audio/sfx/SoupTonic UI1 SFX Pack 1 - ogg/SFX_UI_OpenMenu.ogg")
	open_player.bus = "SFX"
	add_child(open_player)
	
	confirm_player = AudioStreamPlayer.new()
	confirm_player.stream = load("res://assets/audio/sfx/SoupTonic UI1 SFX Pack 1 - ogg/SFX_UI_Confirm.ogg")
	confirm_player.bus = "SFX"
	add_child(confirm_player)
	
	# Connect button signals
	if try_again_button:
		try_again_button.pressed.connect(_on_try_again_pressed)
	
	# Hide initially
	if container:
		container.visible = false
		container.modulate = Color.TRANSPARENT
		container.scale = Vector2(0.1, 0.1)

func show_game_over():
	"""Show the game over screen with animation"""
	if is_visible:
		return
	
	# Play open sound
	if open_player:
		open_player.play()
	
	is_visible = true
	show()
	
	if container:
		container.visible = true
		container.pivot_offset = container.size / 2
		
		# Animate in
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(container, "modulate", Color.WHITE, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
		tween.tween_property(container, "scale", Vector2.ONE, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func hide_game_over():
	"""Hide the game over screen with animation"""
	if not is_visible:
		return
	
	is_visible = false
	
	if container:
		container.pivot_offset = container.size / 2
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(container, "modulate", Color.TRANSPARENT, 0.4).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUART)
		tween.tween_property(container, "scale", Vector2(0.1, 0.1), 0.4).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
		await tween.finished
		container.visible = false
	
	hide()

func _on_try_again_pressed():
	"""Handle try again button press"""
	if confirm_player:
		confirm_player.play()
	
	# Emit signal
	try_again_pressed.emit()
	
	# Hide screen
	hide_game_over()

