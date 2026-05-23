extends Node2D
class_name Monster

const CELL_SIZE := 128
const ORIGIN_OFFSET := Vector2(64, 64)
const INVALID_TARGET := Vector2i(-999, -999)

signal collected

@onready var sprite: Sprite2D = $Sprite2D

# =========================
# TYPE
# =========================
enum MonsterType {
	OCTOPUS,
	STARFISH
}
var type: MonsterType
var texture_map = {
	MonsterType.OCTOPUS: preload("res://Assests/Monster/oct.png"),
	MonsterType.STARFISH: preload("res://Assests/Monster/star.png")
}

# =========================
# STATE MACHINE
# =========================
enum State {
	SEARCH,
	MOVE,
	ATTACK
}
var state: State = State.SEARCH

# =========================
# STATS
# =========================
var hp: int
var attack_damage: int
var speed: float
var grid_pos: Vector2i
var target: Vector2i = INVALID_TARGET

# =========================
# MOVEMENT CONTROL
# =========================
var move_cooldown: float = 0.0
var path: Array[Vector2i] = []

# =========================
# ATTACK CONTROL
# =========================
var attack_cooldown: float = 0.0
var attack_interval: float

# =========================
# INIT
# =========================
func initialize(monster_type: MonsterType, pos: Vector2i, hp_value: int, atk: int, spd: float, atk_speed: float):
	type = monster_type
	sprite.texture = texture_map[type]
	hp = hp_value
	attack_damage = atk
	speed = spd
	attack_interval = 1.0 / max(atk_speed, 0.01)
	grid_pos = pos
	global_position = Vector2(grid_pos) * CELL_SIZE + ORIGIN_OFFSET
	state = State.SEARCH
	move_cooldown = 0.0
	attack_cooldown = 0.0
	path = []

# =========================
# MAIN LOOP
# =========================
func _process(delta):
	match state:
		State.SEARCH:
			_handle_search()
		State.MOVE:
			_handle_move(delta)
		State.ATTACK:
			_handle_attack(delta)

# =========================
# SEARCH
# =========================
func _handle_search():
	target = _find_nearest_land()
	if target == INVALID_TARGET:
		return
	path = []
	state = State.MOVE

func _find_nearest_land() -> Vector2i:
	var lands = EventManager.simple_map_data.keys()
	if lands.is_empty():
		return INVALID_TARGET
	var best = lands[0]
	var best_dist = INF
	for p in lands:
		var d = grid_pos.distance_to(p)
		if d < best_dist:
			best_dist = d
			best = p
	return best

# =========================
# PATHFINDING
# =========================
func _find_path_to(t: Vector2i) -> Array[Vector2i]:
	var queue: Array[Vector2i] = [grid_pos]
	var came_from: Dictionary = {}
	came_from[grid_pos] = grid_pos
	var directions = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

	while not queue.is_empty():
		var current = queue.pop_front()
		if current == t:
			var result: Array[Vector2i] = []
			var c = t
			while c != grid_pos:
				result.push_front(c)
				c = came_from[c]
			return result
		for dir in directions:
			var next = current + dir
			if came_from.has(next):
				continue
			if abs(next.x) > 20 or abs(next.y) > 20:
				continue
			came_from[next] = current
			queue.append(next)

	return []

# =========================
# MOVE
# =========================
func _handle_move(delta):
	target = _find_nearest_land()

	if target == INVALID_TARGET:
		state = State.SEARCH
		return

	if grid_pos == target:
		path = []
		state = State.ATTACK
		attack_cooldown = 0.0
		return

	if path.is_empty() or path.back() != target:
		path = _find_path_to(target)

	if path.is_empty():
		state = State.SEARCH
		return

	move_cooldown -= delta
	if move_cooldown > 0:
		return

	var next_step = path.front()
	path.pop_front()
	grid_pos = next_step
	global_position = Vector2(grid_pos) * CELL_SIZE + ORIGIN_OFFSET
	move_cooldown = 1.0 / max(speed, 0.1)

# =========================
# ATTACK
# =========================
func _handle_attack(delta):
	attack_cooldown -= delta
	if attack_cooldown > 0:
		return

	if EventManager.simple_map_data.has(grid_pos):
		EventManager.command_damage_land.emit(grid_pos, attack_damage)
		
		attack_cooldown = attack_interval
	else:
		state = State.SEARCH
