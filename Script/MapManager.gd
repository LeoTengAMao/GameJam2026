extends Node2D
class_name MapManager

enum CellType { SEA, LAND, COAST, VOLCANO, OCEAN_HEART }
const TILE_SOURCE_ID = 2 # 確保這對應你在 TileSet 編輯器中設定的 Source ID

var ocean_heart_rect: Rect2i
class CellData:
	var type: CellType
	var current_hp: int
	var max_hp: int
	var level: int
	var area: GenerateArea
	var core_data: CellData = null
	var origin_pos: Vector2i = Vector2i.ZERO 
	func _init(_type: CellType, _max_hp: int, _origin: Vector2i = Vector2i.ZERO):
		self.type = _type
		self.max_hp = _max_hp
		self.current_hp = _max_hp
		self.level = 1
		self.origin_pos = _origin 

var grid_data: Dictionary = {}
const NEIGHBORS = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]

@onready var tilemap: TileMapLayer = $TileMapLayer
@onready var selection_tilemap: TileMapLayer = $SelectionLayer

var last_hovered_pos: Vector2i = Vector2i(-10000, -10000)
var current_selected_pos: Vector2i = Vector2i(-10000, -10000)

var erosion_timer: Timer
var erosion_interval: float = 5.0
var base_erosion_damage: float = 5
var damage_growth_per_second: float = 0.1
var elapsed_time: float = 0.0

func _process(delta: float) -> void:
	elapsed_time += delta
	var mouse_global_pos = get_global_mouse_position()
	var grid_pos = tilemap.local_to_map(mouse_global_pos)
	
	if grid_pos != last_hovered_pos:
		selection_tilemap.clear()
		selection_tilemap.set_cell(grid_pos, 0, Vector2i(0, 0)) 
		last_hovered_pos = grid_pos
	
	if grid_data.has(grid_pos):
		var data = grid_data[grid_pos]
		var target_data = data
		if data.core_data != null: target_data = data.core_data
		var type_name = CellType.keys()[data.type]
		EventManager.on_cell_hovered.emit(true, type_name, target_data.current_hp, target_data.max_hp)
	else:
		EventManager.on_cell_hovered.emit(false, "", 0, 0)
func _ready():
	EventManager.upgrade_requested.connect(_on_upgrade_requested)
	var volcano_core = CellData.new(CellType.VOLCANO, 1000)
	
	for x in range(-1, 3):
		for y in range(-1, 3):
			var pos = Vector2i(x, y) 
			# 如果在 0~1 的範圍內，就是火山
			if x >= 0 and x <= 1 and y >= 0 and y <= 1:
				var grid_cell = CellData.new(CellType.VOLCANO, 0, Vector2i(0, 0))
				grid_cell.core_data = volcano_core
				grid_data[pos] = grid_cell
			else:
				# 否則就是陸地
				grid_data[pos] = CellData.new(CellType.LAND, 100)
				EventManager.simple_map_data[pos] = "LAND"
				# 注意：這裡呼叫 update_all_coasts() 會統一繪製，不用在這裡重複 emit 視覺訊號
	
	# ... 後續的海洋之心與侵蝕邏輯保持不變 ...
	var heart_pos = Vector2i(35, -1)
	var ocean_heart_core = CellData.new(CellType.OCEAN_HEART, 99999)
	for x in range(heart_pos.x, heart_pos.x + 3):
		for y in range(heart_pos.y, heart_pos.y + 3):
			var pos = Vector2i(x, y)
			var grid_cell = CellData.new(CellType.OCEAN_HEART, 0, heart_pos)
			grid_cell.core_data = ocean_heart_core
			grid_data[pos] = grid_cell
			EventManager.simple_map_data[pos] = "OCEAN_HEART"
		
	update_all_coasts()
	selection_tilemap.clear()
	
	erosion_timer = Timer.new()
	erosion_timer.wait_time = erosion_interval
	erosion_timer.autostart = true
	erosion_timer.timeout.connect(_on_erosion_timer_timeout)
	add_child(erosion_timer)
	
	EventManager.command_damage_land.connect(damage_land)
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
	EventManager.on_cell_selected.emit(current_selected_pos,info)

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
	var new_types: Dictionary = {}
	for pos in grid_data.keys():
		var data = grid_data[pos]
		if data.type == CellType.LAND or data.type == CellType.COAST:
			new_types[pos] = CellType.LAND

	for pos in new_types.keys():
		for dir in NEIGHBORS:
			var neighbor = pos + dir
			if not new_types.has(neighbor) and not _is_solid_non_land(neighbor):
				new_types[pos] = CellType.COAST
				break

	for pos in new_types.keys():
		grid_data[pos].type = new_types[pos]
		EventManager.simple_map_data[pos] = CellType.keys()[new_types[pos]]

	# 最後統一呼叫視覺更新
	for pos in grid_data.keys():
		_set_visual_tile(pos, grid_data[pos].type)

func _is_solid_non_land(pos: Vector2i) -> bool:
	if not grid_data.has(pos): return false
	var t = grid_data[pos].type
	return t == CellType.VOLCANO or t == CellType.OCEAN_HEART
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
	
	var info = {
		"type": target_data.type,
		"hp": target_data.current_hp,
		"max_hp": target_data.max_hp,
		"level": target_data.level if "level" in target_data else 1
		}
	EventManager.on_cell_data_changed.emit(pos, info)
	
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

func _get_land_mask(pos: Vector2i) -> int:
	var mask = 0
	if _is_solid(pos + Vector2i.UP): mask += 1
	if _is_solid(pos + Vector2i.RIGHT): mask += 2
	if _is_solid(pos + Vector2i.DOWN): mask += 4
	if _is_solid(pos + Vector2i.LEFT): mask += 8
	return mask

func _is_solid(pos: Vector2i) -> bool:
	if not grid_data.has(pos): return false
	var t = grid_data[pos].type
	return t == CellType.LAND or t == CellType.COAST or t == CellType.VOLCANO or t == CellType.OCEAN_HEART

func _set_visual_tile(pos: Vector2i, type: CellType):
	if type == CellType.SEA:
		tilemap.set_cell(pos, -1, Vector2i(-1, -1))
		return
		
	var data = grid_data[pos]
	var offset = pos - data.origin_pos # 算出相對位置 (0,0), (1,0), (0,1)...
	
	match type:
		CellType.VOLCANO:
			# 假設火山圖塊從 Atlas (0, 2) 開始，往右往下排
			var base_atlas = Vector2i(0, 0) 
			tilemap.set_cell(pos, 3, base_atlas + offset)
			
		CellType.OCEAN_HEART:
			# 假設海洋之心圖塊從 Atlas (0, 4) 開始，往右往下排
			var base_atlas = Vector2i(0, 0)
			tilemap.set_cell(pos, 4, base_atlas + offset)
			
		CellType.LAND, CellType.COAST:
			# 原本的 Bitmask 邏輯保持不變
			var mask = _get_land_mask(pos)
			var atlas_coord = Vector2i(mask % 4, mask / 4)
			tilemap.set_cell(pos, TILE_SOURCE_ID, atlas_coord)
func _unhandled_input(event):
	if event is InputEventMouseButton and event.pressed:
		var grid_pos = tilemap.local_to_map(get_global_mouse_position())
		
		if event.button_index == MOUSE_BUTTON_LEFT:
			if grid_data.has(grid_pos):
				current_selected_pos = grid_pos 
				
				var data = grid_data[grid_pos]
				var target = data.core_data if data.core_data else data
				
				var info = {
					"type": data.type,
					"hp": target.current_hp,
					"max_hp": target.max_hp,
					"level": target.level if "level" in target else 1
				}
				
				# 🌟 修正：這裡要傳兩個參數 (pos, info)
				EventManager.on_cell_selected.emit(grid_pos, info)
				
			else:
				build_land(grid_pos)
		
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			current_selected_pos = Vector2i(-10000, -10000) 
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
