# ClickDetector.gd
extends Area2D
class_name ClickDetector

@export var _rock_pool: RockPool

func _input_event(viewport: Viewport, event: InputEvent, shape_idx: int) -> void:
	# 檢查這個輸入事件是不是「滑鼠左鍵點下」
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_on_clicked()

func _spawn_one_rock() -> void:
	# 1. 讓 Manager 依照面積權重計算，吐出一個地圖上的全域座標
	var spawn_global_pos = GenerateManager.get_random_spawn_global_position()
	
	if spawn_global_pos != null:
		# 2. 從物件池借出一顆石頭
		_rock_pool.spawn_rock(spawn_global_pos)

func _on_clicked() -> void:
	print("空物件被點擊了！觸發事件。")
	_spawn_one_rock()
