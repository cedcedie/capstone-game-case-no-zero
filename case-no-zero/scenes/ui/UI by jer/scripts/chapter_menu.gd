extends Control

# Audio players for UI sounds
var confirm_player: AudioStreamPlayer = null
var close_player: AudioStreamPlayer = null

func _ready():
	# Setup audio players for UI sounds
	confirm_player = AudioStreamPlayer.new()
	confirm_player.stream = load("res://assets/audio/sfx/SoupTonic UI1 SFX Pack 1 - ogg/SFX_UI_Confirm.ogg")
	confirm_player.bus = "SFX"
	add_child(confirm_player)
	
	close_player = AudioStreamPlayer.new()
	close_player.stream = load("res://assets/audio/sfx/SoupTonic UI1 SFX Pack 1 - ogg/SFX_UI_CloseMenu.ogg")
	close_player.bus = "SFX"
	add_child(close_player)

func _on_back_to_menu_pressed() -> void:
	if close_player:
		close_player.play()
	await get_tree().create_timer(0.1).timeout  # Small delay for sound
	get_tree().change_scene_to_file("res://scenes/ui/UI by jer/design/main_menu.tscn")

func _on_chapter_1_pressed() -> void:
	"""Start Chapter 1 with full menu fade out and delay"""
	if confirm_player:
		confirm_player.play()
	print("🎬 Chapter Menu: Starting Chapter 1 with full fade out")
	
	# Fade out the menu audio
	if AudioManager:
		print("🎵 Chapter Menu: Fading out menu audio")
		await AudioManager.fade_out_bgm(2.0)  # 2-second fade out
	
	# Fade out the entire menu visually
	print("🎨 Chapter Menu: Fading out menu visually")
	await fade_out_menu(2.0)  # 2-second visual fade out
	
	print("🎵 Chapter Menu: Menu audio and visual faded out")
	
	# Wait additional 1 second for dramatic effect
	await get_tree().create_timer(1.0).timeout
	print("🎮 Chapter Menu: Transitioning to control guide")
	
	# Transition to control guide (which will then go to intro after 10 seconds)
	get_tree().change_scene_to_file("res://scenes/ui/UI by jer/design/Control_Guide.tscn")

func fade_out_menu(duration: float):
	"""Fade out the entire chapter menu visually"""
	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "modulate:a", 0.0, duration)
	await tween.finished
	print("🎨 Chapter Menu: Visual fade out completed")
