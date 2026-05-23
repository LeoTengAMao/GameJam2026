extends Node2D
class_name Monster
const CELL_SIZE := 128

@onready var sprite: Sprite2D = $Sprite2D

enum MonsterType {
	OCTOPUS,
	STARFISH
}
var type: MonsterType

enum State {
	SEARCH,
	MOVE,
	WAIT,
	ATTACK
}
var state: State



var texture_map = {
	MonsterType.OCTOPUS: preload("res://Assests/Monster/oct.png"),
	MonsterType.STARFISH: preload("res://Assests/Monster/star.png")
}

# ===== 狀態 =====
var hp: int
var attack_damage: int
var speed: int
var grid_pos: Vector2i

# ===== 初始化 =====
func initialize(monster_type: MonsterType, pos: Vector2i, hp_value: int, atk: int, spd: int):
	type = monster_type

	sprite.texture = texture_map[type]
	hp = hp_value
	attack_damage = atk
	speed = spd
	grid_pos = pos
	global_position = Vector2i(pos * CELL_SIZE) + Vector2i(64, 64)
	
	state = State.SEARCH
	
var timer := 0.0
var interval := 1.0

func _process(delta):
	timer += delta

	if timer >= interval:
		timer = 0.0
		step()
		
func step():
	grid_pos += Vector2i(1, 1)
	update_world()
	
func update_world():
	global_position = Vector2(grid_pos * CELL_SIZE) + Vector2(64, 64)
	
