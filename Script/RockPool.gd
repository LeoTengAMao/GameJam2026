# RockPool.gd
extends Node2D
class_name RockPool

@export var rock_scene: PackedScene # 拖入 Rock.tscn

var _rock_pool: ObjectPool

func _ready() -> void:
	_init_pool()

func _init_pool() -> void:
	_rock_pool = ObjectPool.new(
		# factory_method: 匿名函式建立與綁定
		func():
			var rock = rock_scene.instantiate() as Rock
			# 當石頭發出 collected 訊號時，自動還給池子
			rock.collected.connect(func(r): _rock_pool.return_item(r))
			add_child(rock)
			return rock,
		
		# on_get:
		func(rock: Rock):
			rock.visible = true
			rock.set_process(true)
			rock.input_pickable = true,
		
		# on_return:
		func(rock: Rock):
			rock.visible = false
			rock.set_process(false)
			rock.input_pickable = false,
			
		10 # initial_capacity
	)

# 當你想在地圖上生成石頭時
func spawn_rock(position: Vector2) -> void:
	var rock = _rock_pool.get_item() as Rock
	rock.initialize(position)
