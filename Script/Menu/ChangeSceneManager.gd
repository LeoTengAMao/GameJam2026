extends Node

func _on_start_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Tscn/MapManager.tscn")
	
func _on_setting_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Tscn/setting.tscn")

func _on_staff_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Tscn/Staff.tscn")

func _on_exit_button_pressed() -> void:
	get_tree().quit();
