extends Node
class_name MonsterGenerator

## 每隔幾秒生成一次石頭
@export var spawn_interval: float = 2.0

@export var jellyfishWeight : int
@export var starfishWeight : int
@export var octopusWeight : int
@export var boss_scene: PackedScene
## 拖入你的 RockPool 節點 (型態為 Node 或特定類別)
@export var monster_pool: MonsterPool
@export var map_manager: Node

var isAdvancePhase : bool

var time_accumulator: float = 0.0

func _ready() -> void:
	time_accumulator = 0.0

var rocks: Dictionary = {}

var has_spawned_boss: bool = false


const BOSS_SCENE = preload("res://Tscn/Boss.tscn")

func spawn_boss():
	SFXManager.play_sfx("laugh")
	print("⚠️ 警告！巨型 Boss 出現了！")
	var boss_instance = BOSS_SCENE.instantiate()
	add_child(boss_instance) # 必須先加入場景
	
	# 決定 Boss 出生的位置 (例如在遠處的海上)
	var spawn_pos = Vector2i(15, -15) 
	boss_instance.initialize(spawn_pos)

func _process(delta: float) -> void:
	time_accumulator += delta
	if not isAdvancePhase and Phase.getPhase() == 3: 
		spawn_interval /= 2
		isAdvancePhase = true
	if time_accumulator >= spawn_interval:
		time_accumulator -= spawn_interval
		_on_timer_tick()
		
	var current_phase = Phase.getPhase()
	SoundManager.play_bgm_for_phase(current_phase)
		
	# 🌟 簡單觸發邏輯：如果遊戲時間達到 60 秒，召喚 Boss (只召喚一次)
	if map_manager.elapsed_time > 1.0 and not has_spawned_boss:		
		spawn_boss()
		has_spawned_boss = true


func _on_timer_tick() -> void:
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
