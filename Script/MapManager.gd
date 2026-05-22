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
