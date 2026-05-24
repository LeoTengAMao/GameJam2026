# Rock.gd
extends Area2D
class_name Rock

# 透過訊號通知物件池：「我被收集了，請把我回收」
signal collected(rock: Rock)

# 石頭的屬性，暴露給編輯器
@export var resource_amount: int = 1

func _ready() -> void:
	# 1. 必須開啟輸入監聽，Area2D 才能偵測滑鼠事件
	input_pickable = true

	# 2. 訂閱 Godot 內建的滑鼠移入訊號
	mouse_entered.connect(_on_mouse_entered)

# 初始化石頭的狀態（每次從物件池被借出來時呼叫）
func initialize(spawn_position: Vector2) -> void:
	global_position = spawn_position
	# 這裡可以重設一些動畫或隨機大小、角度
	rotation = randf_range(0.0, TAU) # TAU 等於 2 * PI

# 當滑鼠游標碰到這顆石頭時觸發
func _on_mouse_entered() -> void:
	_collect()

func _collect() -> void:
	# 1. 這裡可以處理遊戲邏輯（例如：玩家金幣 + resource_amount）
	#print("成功收集石頭！獲得 ", resource_amount, " 個資源。")

	# 2. 播放收集音效或特效（可選）

	# 3. 發送訊號通知物件池持有人來回收我
	SFXManager.play_sfx("getstone")
	collected.emit(self)
	var get_num = randi() % 3;
	get_num += 3
	EventManager.stone_collected.emit(get_num)

func destroy() -> void:
	# 1. 這裡可以處理遊戲邏輯（例如：玩家金幣 + resource_amount）
	#print("成功收集石頭！獲得 ", resource_amount, " 個資源。")

	# 2. 播放收集音效或特效（可選）

	# 3. 發送訊號通知物件池持有人來回收我
	collected.emit(self)
