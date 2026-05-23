# GenerateArea.gd
@tool
extends Node2D
class_name GenerateArea

signal collected(area: GenerateArea)

@export var width: float = 200.0:
	set(value):
		width = value
		queue_redraw() # 數值改變時刷新框線

@export var height: float = 200.0:
	set(value):
		height = value
		queue_redraw() # 數值改變時刷新框線

# 計算該區域的面積（權重）
var area_size: float:
	get: return width * height

func _ready() -> void:
	# 如果是在遊戲運行中（非編輯器模式），將自己註冊進 Manager
	if not Engine.is_editor_hint():
		GenerateManager.register_area(self)

# 在該區域的 w * h 範圍內，隨機取得一個區域內的相對座標
func get_random_local_position() -> Vector2:
	var random_x = randf_range(-width / 2.0, width / 2.0)
	var random_y = randf_range(-height / 2.0, height / 2.0)
	return Vector2(random_x, random_y)

# 讓編輯器視覺化：畫出生成的矩形範圍（綠色框線）
func _draw() -> void:
	if Engine.is_editor_hint() or OS.is_debug_build():
		var rect = Rect2(Vector2(-width / 2.0, -height / 2.0), Vector2(width, height))
		draw_rect(rect, Color.GREEN, false, 2.0)
		
func initialize(spawn_position: Vector2) -> void:
	global_position = spawn_position

# 編輯器縮放刷新邏輯已合併至 @export 的 set 語法中，故不需要額外的 _process 函數
