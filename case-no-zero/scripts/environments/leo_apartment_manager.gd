extends Node2D

signal fade_finished

@export var fade_duration: float = 1.5

var fade_layer: CanvasLayer = null
var fade_rect: ColorRect = null
var fade_in_progress: bool = false
var fade_complete: bool = false

func _ready() -> void:
	_setup_fade_layer()

func fade_scene_elements(duration: float = -1.0) -> void:
	"""Fade the entire Leo apartment scene to black."""
	if fade_in_progress:
		return
	
	var actual_duration := fade_duration if duration <= 0.0 else duration
	_setup_fade_layer()
	
	fade_rect.visible = true
	fade_rect.modulate.a = 0.0
	fade_in_progress = true
	fade_complete = false
	
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(fade_rect, "modulate:a", 1.0, actual_duration)
	tween.finished.connect(_on_fade_finished)

func end_cutscene() -> void:
	"""Fade out Leo's apartment and jump to the cinematic text scene."""
	call_deferred("_end_cutscene_async")

func _end_cutscene_async() -> void:
	if not fade_complete:
		if not fade_in_progress:
			fade_scene_elements()
		await fade_finished
	
	var tree := get_tree()
	if tree:
		var result := tree.change_scene_to_file("res://cinematic_text.tscn")
		if result != OK:
			push_warning("Failed to load cinematic_text.tscn, error: %s" % result)

func _on_fade_finished() -> void:
	fade_in_progress = false
	fade_complete = true
	fade_finished.emit()

func _setup_fade_layer() -> void:
	if fade_layer and fade_rect:
		return
	
	fade_layer = CanvasLayer.new()
	fade_layer.layer = 200
	add_child(fade_layer)
	
	fade_rect = ColorRect.new()
	fade_rect.color = Color.BLACK
	fade_rect.visible = false
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_layer.add_child(fade_rect)

