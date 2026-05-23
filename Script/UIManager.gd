extends CanvasLayer

# ==========================================
# 1. 節點綁定區 (所有 @onready 必須放在最上方)
# ==========================================
# [靜態介面 (HUD)]
@onready var stone_label: Label = $HUD/PanelContainer/VBoxContainer/StoneLabel
@onready var volcano_level_label: Label = $HUD/PanelContainer/VBoxContainer/VolcanoLevelLabel

# [動態提示 (Tooltip)]
@onready var tooltip: Control = $Tooltip
@onready var hp_label: Label = $Tooltip/HPLabel

# [側邊面板 (SidePanel)]
@onready var side_panel: PanelContainer = $SidePanel
@onready var sidebar_hp_label: Label = $SidePanel/VBoxContainer/SidebarHPLabel
@onready var level_label: Label = $SidePanel/VBoxContainer/VolcanoLevelLabel
@onready var name_label: Label = $SidePanel/VBoxContainer/LandNameLabel

# 🌟 動態按鈕的容器
@onready var upgrade_list: VBoxContainer = $SidePanel/VBoxContainer/UpgradeList

# ==========================================
# 2. 狀態變數與常數
# ==========================================
var panel_open: bool = false
var is_showing_tooltip: bool = false
const PANEL_WIDTH: float = 300.0 # 面板寬度，用於 offset 動態動畫

# 🌟 火山科技樹資料表 (Data-Driven)
const VOLCANO_UPGRADES = [
	{"id": "heal_all", "name": "大地治癒 (全體回血)", "base_cost": 100},
	{"id": "random_land", "name": "板塊構造 (隨機造陸)", "base_cost": 150},
	{"id": "defense_up", "name": "堅固岩層 (全體血量+)", "base_cost": 200},
	{"id": "prod_speed", "name": "加速產石 (等級提升)", "base_cost": 50},
	{"id": "volcano_eruption", "name": "🌋 火山大爆炸 (贏得遊戲)", "base_cost": 1000}
]

# ==========================================
# 3. 初始化 (_ready)
# ==========================================
func _ready() -> void:
	# 🛡️ 終極防穿透鎖 A：強制側邊欄和按鈕容器「吃掉」滑鼠事件，不漏給底下的地圖
	
	
	# 綁定全域廣播訊號
	EventManager.on_cell_hovered.connect(_on_hover)
	EventManager.stone_count_changed.connect(_on_stone_count_changed)
	EventManager.volcano_upgraded.connect(_on_volcano_upgraded)
	EventManager.on_cell_selected.connect(_on_cell_selected)
	EventManager.close_ui_requested.connect(close_panel)

	# 初始狀態隱藏
	tooltip.hide()
	volcano_level_label.text = "火山等級: 1"
	
	# 🔧 利用邊距把面板完美藏到螢幕右邊外面
	side_panel.offset_left = 0
	side_panel.offset_right = PANEL_WIDTH

func _process(_delta: float) -> void:
	if is_showing_tooltip:
		tooltip.global_position = get_viewport().get_mouse_position() + Vector2(15, 15)

# ==========================================
# 4. HUD 更新邏輯
# ==========================================
func _on_stone_count_changed(new_amount: int):
	stone_label.text = "🪨 目前石頭: %d" % new_amount
	
	# 🌟 即時檢查側邊欄「動態生成出來的按鈕」，錢夠了就自動亮起來
	for btn in upgrade_list.get_children():
		if btn.has_meta("cost"):
			btn.disabled = new_amount < btn.get_meta("cost")

func _on_volcano_upgraded(level: int, _cur_hp: int, _max_hp: int):
	volcano_level_label.text = "火山等級: %d" % level

func _on_hover(is_hovering: bool, type_name: String, current_hp: int, max_hp: int) -> void:
	is_showing_tooltip = is_hovering
	if is_hovering:
		hp_label.text = "[%s]\n血量: %d / %d" % [type_name, current_hp, max_hp]
		tooltip.show()
	else:
		tooltip.hide()

# ==========================================
# 5. SidePanel 核心動態生成邏輯
# ==========================================
func _on_cell_selected(data: Dictionary):
	print("✅ 收到地塊選取，動態生成面板中... 型態: ", data.type)
	
	# 更新基礎文字
	sidebar_hp_label.text = "血量: %d / %d" % [data.hp, data.max_hp]
	level_label.text = "等級: %d" % data.level
	
	match data.type:
		1: name_label.text = "陸地"
		2: name_label.text = "海岸"
		3: name_label.text = "火山"
		_: name_label.text = "錯誤"

	# 🔧 修正：用 free() 乾淨、立刻刪除舊按鈕，防止 queue_free() 的幀延遲導致點擊錯位
	# 🔧 終極安全修正：不要用 free()，改回 queue_free()，但先移出容器並隱藏！
	for child in upgrade_list.get_children():
		upgrade_list.remove_child(child) # 1. 立刻從畫面上移出，玩家絕對點不到
		child.visible = false            # 2. 確保徹底隱藏
		child.queue_free()               # 3. 讓它在這一幀安全結束後，下一幀乖乖去垃圾桶
		
	# 🌟 根據點選類型，動態產出全新按鈕
	if data.type == 3: # 火山
		level_label.show()
		for upg in VOLCANO_UPGRADES:
			var current_cost = upg.base_cost 
			_create_dynamic_button("%s - %d 🪨" % [upg.name, current_cost], "volcano", upg.id, current_cost)
			
	elif data.type in [1, 2]: # 陸地或海岸
		level_label.hide() # 土地沒有等級，藏起來
		_create_dynamic_button("加固土地 - 10 🪨", "land", "fortify", 10)
	
	# 🔧 修正：使用邊距同步動畫，確保 Click Box 判定區會跟著畫面的位移百分之百對齊！
	if not panel_open:
		var tween = create_tween().set_parallel(true)
		tween.tween_property(side_panel, "offset_left", -PANEL_WIDTH, 0.3).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		tween.tween_property(side_panel, "offset_right", 0.0, 0.3).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		panel_open = true

# 🌟 核心修正：利用「區域變數捕獲」封鎖 Lambda 閉包 Bug，並寫入中介資料 (Metadata)
func _create_dynamic_button(btn_text: String, target: String, upg_id: String, cost: int):
	var btn = Button.new()
	btn.text = btn_text
	
	# 強制將按鈕的滑鼠過濾也設為 STOP，形成雙重防護網
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# 寫入 Metadata 方便隨時比對石頭餘額
	btn.set_meta("cost", cost)
	
	# 🔧 關鍵修正：宣告區域變數，強行鎖定當前迴圈的資料，按鈕就不會全部綁到最後一招
	var captured_target = target
	var captured_id = upg_id
	btn.pressed.connect(func():
		print("🔘 [動態按鈕點擊成功] 發送目標: ", captured_target, " | 技能: ", captured_id)
		EventManager.upgrade_requested.emit(captured_target, captured_id)
	)
	
	# 預設置灰狀態檢查
	btn.disabled = ResourceManager.current_stones < cost
	upgrade_list.add_child(btn)

func close_panel():
	if not panel_open: return
	# 動態邊距縮回右側外面
	var tween = create_tween().set_parallel(true)
	tween.tween_property(side_panel, "offset_left", 0.0, 0.3).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
	tween.tween_property(side_panel, "offset_right", PANEL_WIDTH, 0.3).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
	panel_open = false
