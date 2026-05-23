extends Node2D
class_name MapManager

# 定義地塊狀態
enum CellType { SEA, LAND, COAST, VOLCANO ,OCEAN_HEART}

var ocean_heart_rect: Rect2i

# 內部類別：每塊土地的專屬資料表
class CellData:
	var type: CellType
	var current_hp: int
	var max_hp: int
	var level: int
	var area: GenerateArea
	
	#  新增：用來連結共用資料的參照 (Reference)
	var core_data: CellData = null

	func _init(_type: CellType, _max_hp: int):
		self.type = _type
		self.max_hp = _max_hp
		self.current_hp = _max_hp
		self.level = 1

# 邏輯層：儲存全地圖資料
# Key: Vector2i (網格座標), Value: CellData
var grid_data: Dictionary = {}

# 定義相鄰的四個方向 (上下左右)
const NEIGHBORS = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]

# 視覺層：Godot 4.3 推薦使用 TileMapLayer
@onready var tilemap: TileMapLayer = $TileMapLayer
# 🌟 新增：抓住選取框層
@onready var selection_tilemap: TileMapLayer = $SelectionLayer

#
var last_hovered_pos: Vector2i = Vector2i(-10000, -10000)

# 🌟 補上這行：記錄玩家現在「點選」了哪一個網格 (給升級系統用的)
var current_selected_pos: Vector2i = Vector2i(-10000, -10000)

# === 動態侵蝕系統參數 ===
var erosion_timer: Timer
var erosion_interval: float = 5.0   # 每 3 秒侵蝕一次不变

var base_erosion_damage: float = 5 # 一開始的基礎傷害（比原本的 10 更溫和）
var damage_growth_per_second: float = 0.1 # 每秒鐘傷害增加 0.1（也就是每過一分鐘傷害增加 6 點）

var elapsed_time: float = 0.0       # 記錄遊戲過去了多少秒

func _process(delta: float) -> void:
	elapsed_time += delta
	
	# 1. 取得當前滑鼠的世界座標與網格座標
	var mouse_global_pos = get_global_mouse_position()
	var grid_pos = tilemap.local_to_map(mouse_global_pos)
	
	# === 🌟 核心修改：黃色邊框提示系統 (陸地與海洋通用) 🌟 ===
	
	# 只有當滑鼠移到「新的格子」時才更新，避免每一幀都重複重畫，節省效能
	if grid_pos != last_hovered_pos:
		# A. 清除舊的邊框
		selection_tilemap.clear()
		
		# B. 在新的網格位置畫上黃色邊框
		# 參數：(網格座標, 圖片集ID, Atlas座標(1,1)是黃色邊框)
		# 註：不論該格有沒有土地(grid_data.has)，都會畫出邊框
		selection_tilemap.set_cell(grid_pos, 0, Vector2i(0, 0)) 
		
		# C. 更新記錄點
		last_hovered_pos = grid_pos
	
	
	# === [原本的 UI 血量廣播邏輯，保持原樣] ===
	if grid_data.has(grid_pos):
		# ... [原本發射 true 訊號的邏輯] ...
		var data = grid_data[grid_pos]
		var target_data = data
		if data.core_data != null: target_data = data.core_data
		var type_name = CellType.keys()[data.type]
		EventManager.on_cell_hovered.emit(true, type_name, target_data.current_hp, target_data.max_hp)
	else:
		# 發射 false 訊號告知滑鼠在海洋上
		EventManager.on_cell_hovered.emit(false, "", 0, 0)

func _ready():
	
	EventManager.upgrade_requested.connect(_on_upgrade_requested)
	# -------- TEST ---------
	var monster_scene = preload("res://tscn/Monster.tscn")
	var monster = monster_scene.instantiate()

	add_child(monster)
	monster.initialize(Monster.MonsterType.STARFISH, Vector2i(0, 0), 100, 1, 1)
	# -------- TEST ---------
	var volcano_core = CellData.new(CellType.VOLCANO, 1000)
	
	# === 🌟 1. 上帝視角：直接生成初始地形 (免扣錢、免檢查) ===
	for x in range(-1, 3):
		for y in range(-1, 3):
			var pos = Vector2i(x, y) 
			
			if x >= 0 and x <= 1 and y >= 0 and y <= 1:
				# 放核心火山區
				var grid_cell = CellData.new(CellType.VOLCANO, 0)
				grid_cell.core_data = volcano_core
				grid_data[pos] = grid_cell
			else:
				# 🌟 直接寫入字典，不要呼叫 build_land！
				# 這樣就不會被接壤規則卡住，也不會扣玩家的石頭
				grid_data[pos] = CellData.new(CellType.LAND, 100)
				EventManager.simple_map_data[pos] = "LAND"
				EventManager.on_create_land.emit(Vector2(pos * 128) + Vector2(128/2, 128/2))
	
	# === 🌟 生成海洋之心 (3x3 空間) ===
	# 假設生成在網格 X=15, Y=-1 的位置 (你可以依據地圖大小自行調整 x 的值)
	var heart_pos = Vector2i(35, -1) 
	ocean_heart_rect = Rect2i(heart_pos.x, heart_pos.y, 3, 3)
	
	var ocean_heart_core = CellData.new(CellType.OCEAN_HEART, 99999) # 血量給極高
	for x in range(ocean_heart_rect.position.x, ocean_heart_rect.end.x):
		for y in range(ocean_heart_rect.position.y, ocean_heart_rect.end.y):
			var pos = Vector2i(x, y)
			var grid_cell = CellData.new(CellType.OCEAN_HEART, 0)
			grid_cell.core_data = ocean_heart_core
			grid_data[pos] = grid_cell
			EventManager.simple_map_data[pos] = "OCEAN_HEART"
		
	# === 🌟 2. 全部放好後，一口氣更新海岸線與圖片 ===
	update_all_coasts()
	print("4x4 初始地圖與火山生成完畢！")	
	
	selection_tilemap.clear()
	
	
	# === 啟動侵蝕計時器 ===
	erosion_timer = Timer.new()
	erosion_timer.wait_time = erosion_interval
	erosion_timer.autostart = true
	
	# 將計時器的 timeout 訊號連接到我們等一下要寫的函式
	erosion_timer.timeout.connect(_on_erosion_timer_timeout)
	
	add_child(erosion_timer) # 把計時器加入場景樹中
	print("🌊 海洋侵蝕機制已啟動！")
	
	# 🔌 監聽外部傳來的「破壞指令」，並綁定到 MapManager 自己的函式
	EventManager.command_damage_land.connect(damage_land)
	# 如果你有寫 _destroy_land，也可以這樣接：
	EventManager.command_destroy_land.connect(_destroy_land)

var land_build_cost: int = 5 # MapManager 只需記錄「造陸的標價」

# MapManager.gd 現在的 _on_upgrade_requested 變得超級乾淨
func _on_upgrade_requested(target_type: String, upgrade_id: String):
	if current_selected_pos == Vector2i(-10000, -10000): return
	
	# 火山的升級已經交給 SkillManager 處理了，這裡只管土地！
	if target_type == "land":
		var cost = 10
		if ResourceManager.spend_stones(cost):
			var data = grid_data[current_selected_pos]
			data.max_hp += 100
			data.current_hp = data.max_hp
			print("🏝️ 土地已加固！新血量: ", data.max_hp)
			_refresh_side_panel()

# 🌟 補上這個函式：升級完畢後，呼叫這個讓側邊欄的數字立刻跳動更新
func _refresh_side_panel():
	if current_selected_pos == Vector2i(-10000, -10000) or not grid_data.has(current_selected_pos): 
		return
		
	var data = grid_data[current_selected_pos]
	var target = data.core_data if data.core_data else data
	var info = {
		"type": data.type,
		"hp": target.current_hp,
		"max_hp": target.max_hp,
		"level": target.level if "level" in target else 1
	}
	EventManager.on_cell_selected.emit(info)

# 乾淨俐落的造陸函式
func build_land(pos: Vector2i, starting_hp: int = 100) -> bool:
	# 1. 檢查這格是不是已經有土地
	if grid_data.has(pos) and grid_data[pos].type != CellType.SEA:
		print("這裡已經有土地了！")
		return false
		
	# 2. 土地相連
	if not _is_adjacent_to_land(pos):
		print("❌ 必須蓋在現有土地或海岸的旁邊！")
		return false
	
	# 3. 向資源銀行申請扣款
	if not ResourceManager.spend_stones(land_build_cost):
		return false # 銀行回傳 false (錢不夠)，造陸直接失敗終止
	
		
	# 4. 扣款成功，執行造陸邏輯
	grid_data[pos] = CellData.new(CellType.LAND, starting_hp)
	EventManager.simple_map_data[pos] = "LAND"
	
	EventManager.on_create_land.emit(Vector2(pos * 128) + Vector2(128/2, 128/2))
	update_all_coasts()
	check_ocean_heart_surrounded()
	return true

# 當侵蝕計時器時間到時觸發
func _on_erosion_timer_timeout():
	var current_damage = floori(base_erosion_damage + (elapsed_time * damage_growth_per_second))
	
	# 用來追蹤火山是否碰到海
	var volcano_touching_sea = false
	var volcano_core_pos = Vector2i(0, 0) # 火山核心位置
	
	# 1. 遍歷地圖，找出誰該受傷
	for pos in grid_data.keys():
		var cell = grid_data[pos]
		
		# A. 海岸線一律受傷
		if cell.type == CellType.COAST:
			damage_land(pos, current_damage)
		
		# B. 火山檢查：只要火山的「任一塊格子」碰到海，整座火山就判定為「接觸海」
		elif cell.type == CellType.VOLCANO:
			if _is_adjacent_to_sea(pos):
				volcano_touching_sea = true
	
	# 2. 如果火山接觸到海，對核心扣血一次
	if volcano_touching_sea:
		damage_land(volcano_core_pos, current_damage*4)
		print("🌋 火山接觸到海水！受到侵蝕傷害: ", current_damage)
		
	# 遊戲時間顯示
	var minutes = floori(elapsed_time / 60.0)
	var seconds = floori(int(elapsed_time) % 60)
	print(" 遊戲時間 [%02d:%02d] | 侵蝕循環完成" % [minutes, seconds])
# 遍歷所有土地，重新計算誰靠海
func update_all_coasts():
	for pos in grid_data.keys():
		var data: CellData = grid_data[pos]
		
		if data.type == CellType.VOLCANO:
			_set_visual_tile(pos, CellType.VOLCANO)
		if data.type == CellType.OCEAN_HEART:
			_set_visual_tile(pos, CellType.OCEAN_HEART)
		# 只有陸地或海岸需要被重新判定
		if data.type == CellType.LAND or data.type == CellType.COAST:
			if _is_adjacent_to_sea(pos):
				data.type = CellType.COAST
				EventManager.simple_map_data[pos] = "COAST"
				_set_visual_tile(pos, CellType.COAST)
			else:
				data.type = CellType.LAND
				EventManager.simple_map_data[pos] = "LAND"
				_set_visual_tile(pos, CellType.LAND)

# 檢查某座標的上下左右是否有海洋 (或者沒有資料＝海洋)
func _is_adjacent_to_sea(pos: Vector2i) -> bool:
	for dir in NEIGHBORS:
		var neighbor_pos = pos + dir
		# 如果相鄰座標不在字典裡，或是狀態為 SEA，代表靠海
		if not grid_data.has(neighbor_pos) or grid_data[neighbor_pos].type == CellType.SEA:
			return true
	return false

# 對指定網格造成傷害
func damage_land(pos: Vector2i, amount: int):
	if not grid_data.has(pos): return
	
	var data: CellData = grid_data[pos]
	
	# 🌟 判斷：有沒有共用核心？
	var target_data = data
	if data.core_data != null:
		target_data = data.core_data # 將傷害轉移給核心
		
	# 扣血
	target_data.current_hp -= amount
	print("網格 ", pos, " (", CellType.keys()[data.type] ,") 受到攻擊！ 目前血量: ", target_data.current_hp)
	
	# 血量歸零的判定
	if target_data.current_hp <= 0:
		if data.type == CellType.VOLCANO:
			print("🔥 火山被摧毀了！遊戲結束！")
			# 這裡未來可以呼叫 GameManager.game_over()
			_destroy_volcano() # 呼叫專屬的火山毀滅函式
		else:
			print("🏝️ 土地沉沒了！")
			_destroy_land(pos)

#  新增：摧毀整個火山的邏輯
func _destroy_volcano():
	# 找出所有屬於火山的格子，把它們全部變成海洋
	var positions_to_erase = []
	
	for pos in grid_data.keys():
		if grid_data[pos].type == CellType.VOLCANO:
			positions_to_erase.append(pos)
			EventManager.simple_map_data.erase(pos)
			
	for pos in positions_to_erase:
		grid_data.erase(pos)
		tilemap.set_cell(pos, -1, Vector2i(-1, -1)) # 清除圖塊
		
	# 重新計算海岸線
	EventManager.game_over.emit()
	update_all_coasts()
	
# 土地被摧毀的處理
func _destroy_land(pos: Vector2i):
	# 1. 將該網格狀態改回海洋 (從字典移除，或設為 SEA)
	grid_data.erase(pos) 
	EventManager.simple_map_data.erase(pos)
	# 2. 視覺上清除該圖塊 (例如設為 -1 表示清空)
	tilemap.set_cell(pos, -1, Vector2i(-1, -1))
	
	# 3. 因為有土地消失了，原本在它旁邊的內陸可能會變成新的海岸！
	update_all_coasts()
	EventManager.on_destory_land.emit(Vector2(pos * 128) + Vector2(128/2, 128/2))


func _set_visual_tile(pos: Vector2i, type: CellType):
	match type:
		CellType.VOLCANO:
			tilemap.set_cell(pos, 1, Vector2i(0, 1))# 火山
		CellType.LAND:
			tilemap.set_cell(pos, 1, Vector2i(0, 0)) # 綠色陸地
		CellType.COAST:
			tilemap.set_cell(pos, 1, Vector2i(1, 0)) # 藍色海岸\
		CellType.OCEAN_HEART:
			# 🌟 給海洋之心一個專屬的圖塊 (假設在圖集裡的座標是 0, 2)
			tilemap.set_cell(pos, 1, Vector2i(1, 1))
		

func _unhandled_input(event):
	# 確保是滑鼠點擊事件，且是「按下」的瞬間
	if event is InputEventMouseButton and event.pressed:
		
		var grid_pos = tilemap.local_to_map(get_global_mouse_position())
		
		# === 🟢 情況 A：玩家按下【左鍵】(互動 / 造陸) ===
		if event.button_index == MOUSE_BUTTON_LEFT:
			if grid_data.has(grid_pos):
				
				# 🌟🌟🌟 補上這行：記住玩家選了哪裡！ 🌟🌟🌟
				current_selected_pos = grid_pos 
				
				# 1. 點到了已有的土地或火山 -> 開啟/更新右側升級面板
				var data = grid_data[grid_pos]
				var target = data.core_data if data.core_data else data
				
				var info = {
					"type": data.type,
					"hp": target.current_hp,
					"max_hp": target.max_hp,
					"level": target.level if "level" in target else 1
				}
				EventManager.on_cell_selected.emit(info)
				
			else:
				# 2. 點到了海洋 -> 執行造陸邏輯！
				build_land(grid_pos)
				
		
		# === 情況 B：玩家按下【右鍵】(取消 / 關閉面板) ===
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			
			
			current_selected_pos = Vector2i(-10000, -10000) 
			
			# 廣播：請把 UI 關掉！
			EventManager.close_ui_requested.emit()

func _is_adjacent_to_land(pos: Vector2i) -> bool:
	for dir in NEIGHBORS:
		var neighbor_pos = pos + dir
		# 如果旁邊有資料，而且不是海洋，就代表有跟現有土地接壤
		if grid_data.has(neighbor_pos) and grid_data[neighbor_pos].type != CellType.SEA and grid_data[neighbor_pos].type != CellType.OCEAN_HEART:
			return true
	return false

# 檢查海洋之心周圍的一圈 (共 16 格) 是否都是土地
func check_ocean_heart_surrounded():
	var surrounded = true
	
	# 掃描 3x3 外圍擴展 1 格的範圍 (也就是 5x5)
	for x in range(ocean_heart_rect.position.x - 1, ocean_heart_rect.end.x + 1):
		for y in range(ocean_heart_rect.position.y - 1, ocean_heart_rect.end.y + 1):
			var pos = Vector2i(x, y)
			
			# 如果是海洋之心內部的 3x3 格子，跳過不檢查
			if ocean_heart_rect.has_point(pos):
				continue
				
			# 如果外圍有任何一格是「沒有資料(海洋)」或是「SEA狀態」，代表沒包好！
			if not grid_data.has(pos) or grid_data[pos].type == CellType.SEA:
				surrounded = false
				break
				
	# 更新給全域知道，並在第一次包圍成功時印出提示
	if surrounded and not EventManager.is_heart_surrounded:
		print("✨ 神聖封印完成！海洋之心已被完全包圍！火山大爆炸解鎖！")
	elif not surrounded and EventManager.is_heart_surrounded:
		print("⚠️ 封印破裂！海洋之心的包圍網被破壞了！")
		
	EventManager.is_heart_surrounded = surrounded
	
func get_ocean_side_land_position() -> Vector2:
	var valid_ocean_positions: Array[Vector2i] = []
	
	# 1. 遍歷地圖，找出所有「海岸」格子
	for pos in grid_data.keys():
		var cell = grid_data[pos]
		
		if cell.type == CellType.COAST:
			# 2. 檢查這格海岸的四周，找出哪幾格是海洋
			for dir in NEIGHBORS:
				var neighbor_pos = pos + dir
				
				# 如果鄰居格子不存在於字典，或是狀態為 SEA，那它就是我們要的「邊緣海洋」
				if grid_data.get(neighbor_pos) == null or grid_data[neighbor_pos].type == CellType.SEA:
					# 避免重複加入相同的海洋格子
					if (grid_data.get(neighbor_pos) != null): print(grid_data[neighbor_pos].type)
					else: print(neighbor_pos)
					if not valid_ocean_positions.has(neighbor_pos):
						valid_ocean_positions.append(neighbor_pos)
	
	# 3. 安全檢查：防呆機制
	if valid_ocean_positions.is_empty():
		print("⚠️ 找不到任何與海岸相鄰的海洋格子！")
		return Vector2(0, 0)
		
	# 4. 隨機挑選一格「真正的海洋網格」
	var random_grid_pos = valid_ocean_positions.pick_random()
	print("random", random_grid_pos)
	
	return random_grid_pos
