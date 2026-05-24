# Rock.gd
extends Area2D
class_name ClickMonster

@export var monster : Monster

var _is_collected: bool = false

func _ready() -> void:
	# 1. 必須開啟輸入監聽，Area2D 才能偵測滑鼠事件
	input_pickable = true

	# 2. 訂閱 Godot 內建的滑鼠移入訊號
	input_event.connect(_input_event)
	monster.on_generate.connect(reset_collected)

func reset_collected() -> void:
	_is_collected = false

func _input_event(viewport: Viewport, event: InputEvent, shape_idx: int) -> void:
	if _is_collected:
		return
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed && ResourceManager.spend_stones(1):
			print("🎯 你點到了這隻怪物/這個地塊！")
			_collect()

func _collect() -> void:
	_is_collected = true
	# 1. 這裡可以處理遊戲邏輯（例如：玩家金幣 + resource_amount）
	#print("成功收集石頭！獲得 ", resource_amount, " 個資源。")

	# 2. 播放收集音效或特效（可選）

	# 3. 發送訊號通知物件池持有人來回收我
	monster.collected.emit(monster)

func destroy() -> void:
	# 1. 這裡可以處理遊戲邏輯（例如：玩家金幣 + resource_amount）
	#print("成功收集石頭！獲得 ", resource_amount, " 個資源。")

	# 2. 播放收集音效或特效（可選）

	# 3. 發送訊號通知物件池持有人來回收我
	monster.collected.emit(monster)
