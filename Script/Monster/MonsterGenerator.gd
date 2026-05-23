extends Node
class_name MonsterGenerator

## 每隔幾秒生成一次石頭
@export var spawn_interval: float = 2.0

## 拖入你的 RockPool 節點 (型態為 Node 或特定類別)
@export var monster_pool: Node

@export var map_manager: Node

var time_accumulator: float = 0.0

func _ready() -> void:
	time_accumulator = 0.0

var rocks: Dictionary = {}

func _process(delta: float) -> void:
	time_accumulator += delta
	if time_accumulator >= spawn_interval:
		time_accumulator -= spawn_interval
		_on_timer_tick()


func _on_timer_tick() -> void:
	_spawn_one_monster()

func _spawn_one_monster() -> void:
	# 在 GDScript 中，可以直接用 Autoload 的全域名稱 GenerateManager
	# 如果沒有值，GDScript 的方法通常會回傳 null
	var pos = Vector2i(35, 0)# map_manager.get_ocean_side_land_position()
	monster_pool.spawn_monster_by_grid_pos(pos)
