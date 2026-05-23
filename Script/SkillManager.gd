extends Node
class_name SkillManager

# 抓住爸爸 (MapManager) 以便讀取地圖資料
@onready var map: MapManager = get_parent()
@export var CD : PackedScene
@onready var passive_timer: Timer = $PassiveBuildTimer # 抓取剛剛建立的 Timer

# 🌟 新增：被動技能等級變數
var random_land_level: int = 0

func _ready():
	# 由 SkillManager 來監聽升級訊號，分擔 MapManager 的工作
	EventManager.upgrade_requested.connect(_on_upgrade_requested)
	# 連接 Timer 的訊號 (每過一段時間自動觸發一次)
	passive_timer.timeout.connect(_on_passive_timer_timeout)
	passive_timer.stop() # 初始狀態不自動啟動，等買了第一級再開

func _on_upgrade_requested(target_type: String, upgrade_id: String):
	if map.current_selected_pos == Vector2i(-10000, -10000): return
	
	if target_type == "volcano":
		var volcano_core = map.grid_data[Vector2i(0,0)].core_data
		
		# === 🌋 處理火山的各種技能 ===
		if upgrade_id == "heal_all" and ResourceManager.spend_stones(100):
			_skill_heal_all_land()
		
		elif upgrade_id == "random_land" and ResourceManager.spend_stones(150):
			random_land_level += 1
			_upgrade_passive_build_speed()
				
		elif upgrade_id == "defense_up" and ResourceManager.spend_stones(200):
			_skill_global_defense_up()
				
		elif upgrade_id == "prod_speed" and ResourceManager.spend_stones(50):
			volcano_core.level += 1 
		
		if upgrade_id == "volcano_eruption":
			# 1. 檢查前置條件：海洋之心是否被包圍？
			if not EventManager.is_heart_surrounded:
				print("❌ 條件未滿足：必須用土地將海洋之心 (3x3) 完全包圍，才能發動大爆炸！")
				# 這裡未來可以做一個畫面震動或紅色錯誤音效提示玩家
				return
				
			# 2. 檢查資源並扣除 (假設要 1000 顆石頭)
			var cost = 1000
			if ResourceManager.spend_stones(cost):
				print("🌋💥 轟隆隆隆！火山大爆炸發動！！！海洋之心被徹底摧毀！！！玩家獲勝！")
				
				# 發送勝利廣播給其他 UI 接收
				EventManager.game_won.emit()
			
			# 🌟 火山核心資料庫升級完後，立刻廣播！(把新等級、新血量傳出去)
			EventManager.volcano_upgraded.emit(volcano_core.level, volcano_core.current_hp, volcano_core.max_hp)
			
			print("🌋 產石等級提升至 ", volcano_core.level)
			
		# 呼叫爸爸的函式更新 UI
		map._refresh_side_panel()

func _upgrade_passive_build_speed():
	# 等級 1: 30秒, 等級 2: 20秒, 等級 3: 10秒 ...
	var new_time = max(30.0 - (random_land_level * 10.0), 5.0) 
	passive_timer.wait_time = new_time
	
	if passive_timer.is_stopped():
		passive_timer.start() # 買了第一級後，正式啟動自動機制
	print("⏱️ 自動造陸速度調整為每 ", new_time, " 秒一次")

func _on_passive_timer_timeout():
	if random_land_level > 0:
		_skill_random_build_land()

# --- 神級技能實作區 ---

func _skill_heal_all_land():
	print("✨ 施放：大地治癒！所有土地恢復滿血！")
	for pos in map.grid_data.keys():
		var cell = map.grid_data[pos]
		if cell.type == map.CellType.LAND or cell.type == map.CellType.COAST:
			cell.current_hp = cell.max_hp

func _skill_global_defense_up():
	print("🛡️ 施放：堅固岩層！所有土地最大血量 +50！")
	for pos in map.grid_data.keys():
		var cell = map.grid_data[pos]
		if cell.type == map.CellType.LAND or cell.type == map.CellType.COAST:
			cell.max_hp += 50
			cell.current_hp += 50

func _skill_random_build_land():
	print("🎲 施放：板塊構造！尋找適合的海洋造陸...")
	
	# 使用 Dictionary 當作 Set 來儲存，確保不會有重複的海洋格子
	var possible_seas = {} 
	
	for pos in map.grid_data.keys():
		for dir in map.NEIGHBORS:
			var target_pos = pos + dir
			
			# 如果該位置沒有資料，代表是海洋
			if not map.grid_data.has(target_pos):
				possible_seas[target_pos] = true
	
	# 檢查是否有找到適合的地方
	if possible_seas.size() > 0:
		# 將 Dictionary 的 keys 轉成 Array，這樣隨機挑選才公平
		var keys = possible_seas.keys()
		var lucky_pos = keys.pick_random()
		
		# 執行造陸
		map.grid_data[lucky_pos] = map.CellData.new(map.CellType.LAND, 100)
		EventManager.simple_map_data[lucky_pos] = "LAND"
		map.update_all_coasts()
		EventManager.on_create_land.emit(Vector2(lucky_pos * 128) + Vector2(128/2, 128/2))
		
		print("✅ 成功在座標 ", lucky_pos, " 隨機生成了一塊土地！")
	else:
		print("⚠️ 沒有空間可以造陸了！")
