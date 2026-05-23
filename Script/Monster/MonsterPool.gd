extends Node2D
class_name MonsterPool

@export var monster_scene: PackedScene # 拖入 Rock.tscn

var _monster_pool: ObjectPool

func _ready() -> void:
	_init_pool()

func _init_pool() -> void:
	_monster_pool = ObjectPool.new(
		# factory_method: 匿名函式建立與綁定
		func():
			var monster = monster_scene.instantiate() as Monster
			# 當石頭發出 collected 訊號時，自動還給池子
			monster.collected.connect(func(r): _monster_pool.return_item(r))
			add_child(monster)
			return monster,
		
		# on_get:
		func(monster: Monster):
			monster.visible = true,
			
		# on_return:
		func(monster: Monster):
			monster.visible = false,
			
		10 # initial_capacity
	)

# 當你想在地圖上生成石頭時
func spawn_monster(position: Vector2) -> void:
	var target_grid_pos := Vector2i(position / 128.0)
	pick_random_monster(target_grid_pos)

func spawn_monster_by_grid_pos(position: Vector2) -> void:
	pick_random_monster(position)
	
func pick_random_monster(position: Vector2) -> void:
	var monster = _monster_pool.get_item() as Monster
	add_child(monster)
	
	var hp_value = 1
	var atk = 1
	var spd = 1
	
	# 3. 呼叫初始化：直接傳入整數 0，或是用 類別名.列舉名 傳入（最安全）
	monster.initialize(Monster.MonsterType.OCTOPUS, position, hp_value, atk, spd)
