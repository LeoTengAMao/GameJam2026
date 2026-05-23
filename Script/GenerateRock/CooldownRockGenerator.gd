extends Node
class_name CooldownRockGenerator

## 每隔幾秒生成一次石頭
@export var spawn_interval: float = 2.0

## 拖入你的 RockPool 節點 (型態為 Node 或特定類別)
@export var rock_pool: Node

var time_accumulator: float = 0.0


func _process(delta: float) -> void:
	time_accumulator += delta
	if time_accumulator >= spawn_interval:
		time_accumulator -= spawn_interval
		_on_timer_tick()


func _on_timer_tick() -> void:
	_spawn_one_rock()


func _spawn_one_rock() -> void:
	# 在 GDScript 中，可以直接用 Autoload 的全域名稱 GenerateManager
	# 如果沒有值，GDScript 的方法通常會回傳 null
	var spawn_global_pos = GenerateManager.get_random_spawn_global_position()
	
	# 檢查是否成功取得位置（不為 null），且防呆檢查 rock_pool 是否存在
	if spawn_global_pos != null and rock_pool != null:
		# 如果 rock_pool 是 GDScript，直接呼叫方法即可
		rock_pool.spawn_rock(spawn_global_pos)
