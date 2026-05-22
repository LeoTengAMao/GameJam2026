extends Node2D
class_name MapManager

# 定義地塊狀態
enum CellType { SEA, LAND, COAST }

# 內部類別：每塊土地的專屬資料表
class CellData:
	var type: CellType
	var current_hp: int
	var max_hp: int
	var level: int
	# 未來可以擴充：var building_type, var defense_value 等等

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

func _ready():
	# 假設火山在 (0, 0)
	var center = Vector2i(0, 0)
	
	# 生成 3x3 土地
	for x in range(-1, 2):
		for y in range(-1, 2):
			var pos = center + Vector2i(x, y)
			# 初始給予 100 血量
			grid_data[pos] = CellData.new(CellType.LAND, 100)
	
	# 計算並更新海岸線狀態與視覺
	update_all_coasts()
	print("3x3 初始地圖生成完畢！") # 加入這行
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

# 遍歷所有土地，重新計算誰靠海
func update_all_coasts():
	for pos in grid_data.keys():
		var data: CellData = grid_data[pos]
		
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
	data.current_hp -= amount
	
	print("土地 ", pos, " 受到傷害，剩餘血量: ", data.current_hp)
	
	# 血量歸零，土地沉沒
	if data.current_hp <= 0:
		_destroy_land(pos)

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
		CellType.LAND:
			# 將原本的 0 改成你剛剛看到的 Source 數字 (這裡以 1 為例)
			tilemap.set_cell(pos, 1, Vector2i(0, 0)) 
		CellType.COAST:
			# 這裡也改成相同的數字
			tilemap.set_cell(pos, 1, Vector2i(1, 0))

# 處理玩家的輸入事件
func _unhandled_input(event: InputEvent) -> void:
	# 偵測是否按下「滑鼠左鍵」
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		
		# 1. 取得滑鼠在遊戲世界中的實際座標
		var mouse_global_pos = get_global_mouse_position()
		
		# 2. 透過 TileMapLayer 將世界座標轉換為網格 (Grid) 座標
		var grid_pos = tilemap.local_to_map(mouse_global_pos)
		
		# 3. 呼叫造陸函式 (目前先不判斷是否有足夠的石頭，先測試功能)
		# 限制只能蓋在現有土地的旁邊 (不能憑空在遠處造陸)
		if _is_adjacent_to_land(grid_pos):
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
