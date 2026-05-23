extends Node2D
class_name GenerateAreaPool

@export var area_scene: PackedScene # 拖入 Rock.tscn

var _area_pool: ObjectPool

var _active_areas: Dictionary = {}

func _ready() -> void:
	_init_pool()

func _init_pool() -> void:
	_area_pool = ObjectPool.new(
		# factory_method: 匿名函式建立與綁定
		func():
			var area = area_scene.instantiate() as GenerateArea
			area.visible = false;
			# 當石頭發出 collected 訊號時，自動還給池子
			area.collected.connect(func(r): _area_pool.return_item(r))
			add_child(area)
			return area,
		
		# on_get:
		func(area: GenerateArea):
			area.visible = true,
			
		# on_return:
		func(area: GenerateArea):
			area.visible = false,
			
		10 # initial_capacity
	)
	EventManager.on_create_land.connect(spawn_area)
	EventManager.on_destory_land.connect(destory_area_by_pos)

# 當你想在地圖上生成石頭時
func spawn_area(position: Vector2) -> void:
	var area = _area_pool.get_item() as GenerateArea
	area.initialize(position)
	area.enable()
	_active_areas[Vector2i(position)] = area
	
func destory_area_by_pos(pos) -> void:
	var key = Vector2i(int(pos.x), int(pos.y)) if pos is Vector2 else pos
	if not _active_areas.has(key):
		return
	var area = _active_areas[key]
	_active_areas.erase(key)
	area.disable()
	_area_pool.return_item(area)
