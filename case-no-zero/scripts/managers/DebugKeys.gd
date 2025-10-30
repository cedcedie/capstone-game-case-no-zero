extends Node

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_F1:
				pass
			KEY_F2:
				pass
			KEY_F3:
				pass
			KEY_F4:
				pass
			KEY_F5:
				pass
			KEY_F6:
				pass
			KEY_F7:
				pass
			KEY_F8:
				pass
			KEY_F9:
				pass
			KEY_F10:
				pass
