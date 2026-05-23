extends Control

@onready var btn_1 = $VBoxContainer/Button1 
@onready var btn_2 = $PanelContainer/VBoxContainer/HBoxContainer/Button2
var is_camera_locked: bool = false # 記錄視角狀態
func _on_return_pressed() -> void:
	get_tree().change_scene_to_file("res://Tscn/menu.tscn")
	pass # Replace with function body.


func _on_button_1_pressed() -> void:
	if EventManager.is_gentle_mode:
		EventManager.is_gentle_mode = false
		$PanelContainer/VBoxContainer/HBoxContainer/Button1.text = "ON"
	else:
		EventManager.is_gentle_mode = true
		$PanelContainer/VBoxContainer/HBoxContainer/Button1.text = "OFF"


func _on_button_2_pressed() -> void:
	# 1. 透過全域事件管理開關
	EventManager.mousecam = !EventManager.mousecam
	
	# 2. 直接使用剛剛定義的 btn_2 變數，它已經幫你鎖定那個按鈕了
	if EventManager.mousecam == true:
		$PanelContainer/VBoxContainer/HBoxContainer2/Button2.text = "OFF"
	else:
		$PanelContainer/VBoxContainer/HBoxContainer2/Button2.text = "ON"
