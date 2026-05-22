extends Node2D
class_name MapManager

# 定義地塊狀態
enum CellType { SEA, LAND, COAST, VOLCANO }

# 內部類別：每塊土地的專屬資料表
class CellData:
	var type: CellType
	var current_hp: int
	var max_hp: int
	var level: int
	
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

# === 動態侵蝕系統參數 ===
var erosion_timer: Timer
var erosion_interval: float = 5.0   # 每 3 秒侵蝕一次不变

var base_erosion_damage: float = 5 # 一開始的基礎傷害（比原本的 10 更溫和）
var damage_growth_per_second: float = 0.1 # 每秒鐘傷害增加 0.1（也就是每過一分鐘傷害增加 6 點）

var elapsed_time: float = 0.0       # 記錄遊戲過去了多少秒

func _process(delta: float) -> void:
	elapsed_time += delta
	
	# 取得滑鼠指著的網格
	var mouse_grid_pos = tilemap.local_to_map(get_global_mouse_position())
	
	# 檢查該網格是否有土地
	if grid_data.has(mouse_grid_pos):
		var data = grid_data[mouse_grid_pos]
		var target_data = data
		if data.core_data != null:
			target_data = data.core_data # 處理 2x2 火山血量
			
		var type_name = CellType.keys()[data.type]
		
		# 📢 重點：發射廣播訊號給 UI
		EventManager.on_cell_hovered.emit(true, type_name, target_data.current_hp, target_data.max_hp)
	else:
		# 📢 重點：發射廣播告知滑鼠在海洋上 (隱藏 UI)
		EventManager.on_cell_hovered.emit(false, "", 0, 0)

func _ready():
	
	var volcano_core = CellData.new(CellType.VOLCANO, 1000)
	
	for x in range(-1, 3):
		for y in range(-1, 3):
			var pos = Vector2i(x, y)
			
			# 判斷是否為正中間的 2x2 火山區：(0,0), (0,1), (1,0), (1,1)
			if x >= 0 and x <= 1 and y >= 0 and y <= 1:
				# 🌟 2. 創建這格專屬的資料，但把它的 core_data 指向我們剛剛建好的大腦
				var grid_cell = CellData.new(CellType.VOLCANO, 0) # 這裡本身的血量設為 0 不重要
				grid_cell.core_data = volcano_core # 建立連結！
				grid_data[pos] = grid_cell
			else:
				# 其他外圍部分是普通土地 (自己就是自己的核心)
				grid_data[pos] = CellData.new(CellType.LAND, 100)
		
		# 計算並更新海岸線狀態與視覺
	update_all_coasts()
	print("4x4 初始地圖與火山生成完畢！")
	
	# ... [你原本的 4x4 與火山生成邏輯] ...
	
	# === 啟動侵蝕計時器 ===
	erosion_timer = Timer.new()
	erosion_timer.wait_time = erosion_interval
	erosion_timer.autostart = true
	
	# 將計時器的 timeout 訊號連接到我們等一下要寫的函式
	erosion_timer.timeout.connect(_on_erosion_timer_timeout)
	
	add_child(erosion_timer) # 把計時器加入場景樹中
	print("🌊 海洋侵蝕機制已啟動！")
# 玩家呼叫此函式來填海造陸
func build_land(pos: Vector2i, starting_hp: int = 100):
	if grid_data.has(pos) and grid_data[pos].type != CellType.SEA:
		print("這裡已經有土地了！")
		return false
		
	# 1. 邏輯層：新增土地資料
	grid_data[pos] = CellData.new(CellType.LAND, starting_hp)
	
	# 2. 更新周圍所有格子的海岸線狀態
	update_all_coasts()
	return true

# 當侵蝕計時器時間到時觸發
func _on_erosion_timer_timeout():
	# 1. 找出一份所有海岸線格子的清單
	var coasts_to_damage = []
	for pos in grid_data.keys():
		if grid_data[pos].type == CellType.COAST:
			coasts_to_damage.append(pos)
			
	if coasts_to_damage.is_empty():
		return
		
	# 2.計算當前動態傷害：基礎傷害 + (秒數 * 成長率)
	# 使用 floori 將浮點數轉換為整數傷害
	var current_damage = floori(base_erosion_damage + (elapsed_time * damage_growth_per_second))
	
	# 算一下目前是遊戲的第幾分鐘，方便看 Log
	var minutes = floori(elapsed_time / 60.0)
	var seconds = floori(int(elapsed_time) % 60)
	print(" 遊戲時間 [%02d:%02d] |  海洋暴走度！當前侵蝕傷害: %d" % [minutes, seconds, current_damage])
	
	# 3. 對每一塊海岸造成動態傷害
	for pos in coasts_to_damage:
		damage_land(pos, current_damage)
# 遍歷所有土地，重新計算誰靠海
func update_all_coasts():
	for pos in grid_data.keys():
		var data: CellData = grid_data[pos]
		
		if data.type == CellType.VOLCANO:
			_set_visual_tile(pos, CellType.VOLCANO)
		# 只有陸地或海岸需要被重新判定
		if data.type == CellType.LAND or data.type == CellType.COAST:
			if _is_adjacent_to_sea(pos):
				data.type = CellType.COAST
				_set_visual_tile(pos, CellType.COAST)
			else:
				data.type = CellType.LAND
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
			
	for pos in positions_to_erase:
		grid_data.erase(pos)
		tilemap.set_cell(pos, -1, Vector2i(-1, -1)) # 清除圖塊
		
	# 重新計算海岸線
	update_all_coasts()
	
# 土地被摧毀的處理
func _destroy_land(pos: Vector2i):
	# 1. 將該網格狀態改回海洋 (從字典移除，或設為 SEA)
	grid_data.erase(pos) 
	
	# 2. 視覺上清除該圖塊 (例如設為 -1 表示清空)
	tilemap.set_cell(pos, -1, Vector2i(-1, -1))
	
	# 3. 因為有土地消失了，原本在它旁邊的內陸可能會變成新的海岸！
	update_all_coasts()


func _set_visual_tile(pos: Vector2i, type: CellType):
	match type:
		CellType.VOLCANO:
			tilemap.set_cell(pos, 1, Vector2i(0, 1))# 火山
		CellType.LAND:
			tilemap.set_cell(pos, 1, Vector2i(0, 0)) # 綠色陸地
		CellType.COAST:
			tilemap.set_cell(pos, 1, Vector2i(1, 0)) # 藍色海岸
		

# 處理玩家的輸入事件
# 處理玩家的輸入事件
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var mouse_global_pos = get_global_mouse_position()
		var grid_pos = tilemap.local_to_map(mouse_global_pos)
		
		# 如果點擊的地方已經有土地或火山，就當作是在「攻擊它」
		if grid_data.has(grid_pos):
			damage_land(grid_pos, 100) # 每次點擊扣 100 滴血
		
		# 如果點擊的是海洋，且可以造陸，就造陸
		elif _is_adjacent_to_land(grid_pos):
			var success = build_land(grid_pos)
			if success:
				print("成功在網格 ", grid_pos, " 填海造陸！")
		else:
			print("只能在現有的土地邊緣進行擴張！")

# 輔助函式：檢查某個座標旁邊是否有我們現有的土地
func _is_adjacent_to_land(pos: Vector2i) -> bool:
	for dir in NEIGHBORS:
		var neighbor_pos = pos + dir
		# 如果旁邊有資料，而且不是海洋，就代表有跟現有土地接壤
		if grid_data.has(neighbor_pos) and grid_data[neighbor_pos].type != CellType.SEA:
			return true
	return false
