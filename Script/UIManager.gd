extends CanvasLayer

# 靜態介面 (HUD)
@onready var stone_label: Label = $HUD/PanelContainer/VBoxContainer/StoneLabel
@onready var volcano_level_label: Label = $HUD/PanelContainer/VBoxContainer/VolcanoLevelLabel
@onready var upgrade_button: Button = $HUD/PanelContainer/HBoxContainer/UpgradeButton

# 動態提示 (Tooltip)
@onready var tooltip: Control = $Tooltip
@onready var hp_label: Label = $Tooltip/HPLabel

# 動態提示 (Sidebar)
@onready var side_panel: PanelContainer = $SidePanel
@onready var sidebar_hp_label: Label = $SidePanel/VBoxContainer/SidebarHPLabel
@onready var level_label: Label = $SidePanel/VBoxContainer/VolcanoLevelLabel

var panel_open: bool = false
var current_target_pos: Vector2i # 紀錄目前選中的是哪一格

var is_showing_tooltip: bool = false

func _ready() -> void:
	EventManager.on_cell_hovered.connect(_on_hover)
	EventManager.stone_count_changed.connect(_on_stone_count_changed)
	EventManager.volcano_upgraded.connect(_on_volcano_upgraded)
	
	# -------- TEST ---------
	var monster_scene = preload("res://tscn/Monster.tscn")
	var monster = monster_scene.instantiate()

	add_child(monster)
	monster.initialize(Monster.MonsterType.STARFISH, Vector2(0, 0), 100, 1, 1)
	# -------- TEST ---------
	
	# 按鈕連線
	upgrade_button.pressed.connect(func(): EventManager.upgrade_requested.emit("volcano"))
	
	tooltip.hide()
	volcano_level_label.text = "火山等級: 1"
	
	# 預設把面板藏到螢幕右邊外面
	side_panel.position.x = get_viewport().get_visible_rect().size.x
	# 監聽地圖點擊訊號 (等一下要在 EventManager 補上)
	EventManager.on_cell_selected.connect(_on_cell_selected)

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
		

func _on_cell_selected(data: Dictionary):
	# 更新 UI 內容
	hp_label.text = "血量: %d / %d" % [data.hp, data.max_hp]
	level_label.text = "等級: %d" % data.level
	
	# 執行滑出動畫
	var screen_width = get_viewport().get_visible_rect().size.x
	var tween = create_tween()
	# 滑到螢幕內 (螢幕寬度 - 面板寬度)
	tween.tween_property(side_panel, "position:x", screen_width - side_panel.size.x, 0.3).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	panel_open = true

# 點擊空白處或海洋時可以縮回面板
func close_panel():
	var screen_width = get_viewport().get_visible_rect().size.x
	var tween = create_tween()
	tween.tween_property(side_panel, "position:x", screen_width, 0.3).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
	panel_open = false
