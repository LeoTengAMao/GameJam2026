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
@onready var upgrade_list: VBoxContainer = $SidePanel/VBoxContainer/UpgradeList
 
# ==========================================
# 2. 狀態變數與常數
# ==========================================
var panel_open: bool = false
var is_showing_tooltip: bool = false
 
# 🔧 修正：記錄面板寬度，用於動畫計算
const PANEL_WIDTH: float = 300.0
 
# 火山科技樹
const VOLCANO_UPGRADES = [
	{"id": "heal_all", "name": "大地治癒 (全體回血)", "base_cost": 100},
	{"id": "random_land", "name": "板塊構造 (隨機造陸)", "base_cost": 150},
	{"id": "defense_up", "name": "堅固岩層 (全體血量+)", "base_cost": 200},
	{"id": "prod_speed", "name": "加速產石 (等級提升)", "base_cost": 50}
]
 
# ==========================================
# 3. 初始化 (_ready)
# ==========================================
func _ready() -> void:
	# 強制讓側邊欄本身「吃掉」所有滑鼠事件，絕對不傳給地圖
	side_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	upgrade_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$HUD.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# 確認 upgrade_list 裡面的東西沒被擋
	print("Tooltip mouse_filter: ", tooltip.mouse_filter)
 
	# 綁定廣播訊號
	EventManager.on_cell_hovered.connect(_on_hover)
	EventManager.stone_count_changed.connect(_on_stone_count_changed)
	EventManager.volcano_upgraded.connect(_on_volcano_upgraded)
	EventManager.on_cell_selected.connect(_on_cell_selected)
	EventManager.close_ui_requested.connect(close_panel)
 
	# 初始狀態設定
	tooltip.hide()
	volcano_level_label.text = "火山等級: 1"
 
	# 🔧 修正：面板初始位置躲在螢幕右側外面
	# AnchorRight=1 時，offset_left 和 offset_right 是相對螢幕右邊的偏移
	# 讓面板完全躲到右側外：left=0, right=PANEL_WIDTH（兩者都在螢幕右邊緣之外）
	side_panel.offset_left = 0
	side_panel.offset_right = PANEL_WIDTH
 
func _process(_delta: float) -> void:
	# 讓 Tooltip 跟著滑鼠跑
	if is_showing_tooltip:
		tooltip.global_position = get_viewport().get_mouse_position() + Vector2(15, 15)
 
# ==========================================
# 4. HUD 靜態介面更新邏輯
# ==========================================
func _on_stone_count_changed(new_amount: int):
	stone_label.text = "🪨 目前石頭: %d" % new_amount
	
	# 即時檢查側邊欄的按鈕，錢夠了就自動亮起來
	for btn in upgrade_list.get_children():
		if btn.has_meta("cost"):
			btn.disabled = new_amount < btn.get_meta("cost")
 
func _on_volcano_upgraded(level: int, _cur_hp: int, _max_hp: int):
	volcano_level_label.text = "火山等級: %d" % level
 
# ==========================================
# 5. Tooltip 動態提示更新邏輯
# ==========================================
func _on_hover(is_hovering: bool, type_name: String, current_hp: int, max_hp: int) -> void:
	is_showing_tooltip = is_hovering
	
	if is_hovering:
		hp_label.text = "[%s]\n血量: %d / %d" % [type_name, current_hp, max_hp]
		tooltip.show()
	else:
		tooltip.hide()
 
# ==========================================
# 6. SidePanel 側邊選單邏輯
# ==========================================
func _on_cell_selected(data: Dictionary):
	print("✅ _on_cell_selected 被呼叫了！type=", data.type)
	
	for node in get_children():
		if node is Control:
			print("節點: ", node.name, " | mouse_filter: ", node.mouse_filter, " | visible: ", node.visible)
	# 1. 更新文字內容
	match data.type:
		1: name_label.text = "陸地"
		2: name_label.text = "海岸"
		3: name_label.text = "火山"
		_: name_label.text = "錯誤"
 
	sidebar_hp_label.text = "血量: %d / %d" % [data.hp, data.max_hp]
	level_label.text = "等級: %d" % data.level
 
	# 🔧 修正：用 free() 立刻刪除，避免 queue_free() 延遲導致新舊按鈕重疊
	for child in upgrade_list.get_children():
		upgrade_list.remove_child(child)
		child.free()
 
	# 3. 動態生成新按鈕
	if name_label.text == "火山":
		for upg in VOLCANO_UPGRADES:
			var current_cost = upg.base_cost
			_create_upgrade_button("%s - %d 🪨" % [upg.name, current_cost], "volcano", upg.id, current_cost)
	elif name_label.text in ["陸地", "海岸"]:
		_create_upgrade_button("加固土地 - 10 🪨", "land", "fortify", 10)
 
	# 4. 執行滑出動畫（從右側外面滑進來）
	# 🔧 修正：面板收起時 left=0, right=PANEL_WIDTH（在螢幕右邊外）
	#         面板展開時 left=-PANEL_WIDTH, right=0（貼齊螢幕右邊）
	if not panel_open:
		var tween = create_tween().set_parallel(true)
		tween.tween_property(side_panel, "offset_left", -PANEL_WIDTH, 0.3).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		tween.tween_property(side_panel, "offset_right", 0.0, 0.3).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		panel_open = true
	# 如果面板已開，只更新內容，不重跑動畫
 
# 輔助函式：建立按鈕並綁定 Metadata
# 🔧 修正：用區域變數明確捕獲 target 和 upg_id，避免 lambda 閉包抓到錯誤值
func _create_upgrade_button(btn_text: String, target: String, upg_id: String, cost: int):
	var btn = Button.new()
	btn.text = btn_text
	btn.set_meta("cost", cost)
	
	var captured_target = target
	var captured_id = upg_id
	btn.pressed.connect(func():
		print("🔘 pressed 訊號！", captured_target, captured_id)
		EventManager.upgrade_requested.emit(captured_target, captured_id)
	)
	
	# 🔍 加這個，直接監聽原始輸入事件
	btn.gui_input.connect(func(event):
		print("🖱️ 按鈕收到 gui_input: ", event)
	)
	
	btn.disabled = ResourceManager.current_stones < cost
	upgrade_list.add_child(btn)
func close_panel():
	if not panel_open: return
 
	# 🔧 修正：縮回螢幕右側外面（left=0, right=PANEL_WIDTH）
	var tween = create_tween().set_parallel(true)
	tween.tween_property(side_panel, "offset_left", 0.0, 0.3).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
	tween.tween_property(side_panel, "offset_right", PANEL_WIDTH, 0.3).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
	panel_open = false
