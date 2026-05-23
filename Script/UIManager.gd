extends CanvasLayer

# 🌟 靜態介面 (HUD)
@onready var stone_label: Label = $HUD/PanelContainer/VBoxContainer/StoneLabel
@onready var volcano_level_label: Label = $HUD/PanelContainer/VBoxContainer/VolcanoLevelLabel
@onready var upgrade_button: Button = $HUD/PanelContainer/HBoxContainer/UpgradeButton

# 🌟 動態提示 (Tooltip)
@onready var tooltip: Control = $Tooltip
@onready var hp_label: Label = $Tooltip/HPLabel

var is_showing_tooltip: bool = false

func _ready() -> void:
	EventManager.on_cell_hovered.connect(_on_hover)
	EventManager.stone_count_changed.connect(_on_stone_count_changed)
	EventManager.volcano_upgraded.connect(_on_volcano_upgraded)
	
	# 按鈕連線
	upgrade_button.pressed.connect(func(): EventManager.upgrade_requested.emit("volcano"))
	
	tooltip.hide()
	volcano_level_label.text = "火山等級: 1"

# --- HUD 靜態介面更新邏輯 ---

func _on_stone_count_changed(new_amount: int):
	stone_label.text = "🪨 目前石頭: %d" % new_amount

func _on_volcano_upgraded(level: int, _cur_hp: int, _max_hp: int):
	volcano_level_label.text = "火山等級: %d" % level
	upgrade_button.text = "升級火山 (%d 顆石頭)" % (level * 50)

# --- Tooltip 動態提示更新邏輯 ---

func _on_hover(is_hovering: bool, type_name: String, current_hp: int, max_hp: int) -> void:
	is_showing_tooltip = is_hovering
	
	if is_hovering:
		hp_label.text = "[%s]\n血量: %d / %d" % [type_name, current_hp, max_hp]
		tooltip.show() # 顯示整個 Tooltip 群組
	else:
		tooltip.hide()

func _process(_delta: float) -> void:
	# 只要讓 Tooltip 這個節點跟著滑鼠跑，HUD 完全不受影響
	if is_showing_tooltip:
		tooltip.global_position = get_viewport().get_mouse_position() + Vector2(15, 15)
