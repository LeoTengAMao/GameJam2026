extends CanvasLayer

@onready var hp_label: Label = $HPLabel
var is_showing: bool = false # 記錄目前是否該顯示 UI

func _ready() -> void:
	# 🔌 訂閱電台：聽到地圖廣播時，執行 _on_hover 函式
	EventManager.on_cell_hovered.connect(_on_hover)
	hp_label.hide() # 一開始先隱藏

func _on_hover(is_hovering: bool, type_name: String, current_hp: int, max_hp: int) -> void:
	is_showing = is_hovering # 儲存狀態
	
	if is_hovering:
		# 更新文字內容
		hp_label.text = "[%s]\n血量: %d / %d" % [type_name, current_hp, max_hp]
		hp_label.show()
	else:
		hp_label.hide()

func _process(_delta: float) -> void:
	# 讓 Label 永遠跟著滑鼠跑 (滑鼠座標 + 偏移量)
	if is_showing:
		hp_label.global_position = get_viewport().get_mouse_position() + Vector2(15, 15)
