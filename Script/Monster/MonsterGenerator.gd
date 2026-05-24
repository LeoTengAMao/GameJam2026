extends Node
class_name MonsterGenerator

## 每隔幾秒生成一次石頭
@export var spawn_interval: float = 2.0

@export var jellyfishWeight : int
@export var starfishWeight : int
@export var octopusWeight : int

## 拖入你的 RockPool 節點 (型態為 Node 或特定類別)
@export var monster_pool: MonsterPool

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
	print(Phase.getPhase())
	if Phase.getPhase() > 1:
		_spawn_one_monster()

func get_random_type() -> Monster.MonsterType:
	var total = starfishWeight + jellyfishWeight + octopusWeight
	if total == 0: 
		return Monster.MonsterType.JELLYFISH
	
	var chance = randi() % total
	print("總權重: ", total, " | 隨機點: ", chance)
	
	if chance < starfishWeight:
		return Monster.MonsterType.STARFISH
	chance -= starfishWeight
	
	if chance < jellyfishWeight:
		return Monster.MonsterType.JELLYFISH
	chance -= jellyfishWeight
	
	return Monster.MonsterType.OCTOPUS
	
func _spawn_one_monster() -> void:
	# 在 GDScript 中，可以直接用 Autoload 的全域名稱 GenerateManager
	# 如果沒有值，GDScript 的方法通常會回傳 null
	var pos = Vector2i(35, 0)# map_manager.get_ocean_side_land_position()
	
	monster_pool.spawn_monster_by_grid_pos(pos, get_random_type(), 1, 1, 1, 1)
