extends Node

# 銀行金庫：掌管全遊戲的資源
var current_stones: int = 100

func _ready() -> void:
	# 遊戲一開始，廣播存款餘額給 UI 顯示
	EventManager.stone_count_changed.emit.call_deferred(current_stones)
	EventManager.stone_collected.connect(add_stones)

func add_stones(amount: int) -> void:
	current_stones += amount
	EventManager.stone_count_changed.emit(current_stones)
	print("獲得石頭！目前總數: ", current_stones)

func spend_stones(cost: int) -> bool:
	if current_stones >= cost:
		current_stones -= cost
		EventManager.stone_count_changed.emit(current_stones)
		return true
	else:
		print("❌ 資源不足！需要 %d 顆石頭，但你只有 %d 顆！" % [cost, current_stones])
		return false
