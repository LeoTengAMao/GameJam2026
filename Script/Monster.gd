extends Node2D
class_name Monster

const CELL_SIZE := 128
const ORIGIN_OFFSET := Vector2(64, 64)
const INVALID_TARGET := Vector2i(-999, -999)
const OCTOPUS_RANGE := 5
var generation: int = 0

# 火山（中間四格）
const VOLCANO_CELLS := [
	Vector2i(0, 0), Vector2i(1, 0),
	Vector2i(0, 1), Vector2i(1, 1)
]

# 海洋之心（不攻擊，但可穿越）
const OCEAN_HEART_CELLS := [
	Vector2i(35, -1), Vector2i(35, 0), Vector2i(35, 1),
	Vector2i(36, -1), Vector2i(36, 0), Vector2i(36, 1),
	Vector2i(37, -1), Vector2i(37, 0), Vector2i(37, 1)
]

signal collected
signal on_generate

@onready var sprite: Sprite2D = $Sprite2D

# =========================
# 全局佔位管理
# =========================
static var reserved_cells: Dictionary = {}

func _reserve_cell(pos: Vector2i):
	reserved_cells[pos] = self

func _release_cell(pos: Vector2i):
	if reserved_cells.get(pos) == self:
		reserved_cells.erase(pos)

func _is_cell_free(pos: Vector2i) -> bool:
	if reserved_cells.has(pos):
		return reserved_cells[pos] == self
	return true

# =========================
# TYPE
# =========================
enum MonsterType {
	JELLYFISH,
	OCTOPUS,
	STARFISH
}
var type: MonsterType
var texture_map = {
	MonsterType.JELLYFISH: preload("res://Assests/Monster/jellyfish.png"),
	MonsterType.OCTOPUS:   preload("res://Assests/Monster/oct.png"),
	MonsterType.STARFISH:  preload("res://Assests/Monster/star.png")
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
	add_to_group("monsters")
	_reserve_cell(grid_pos)
	generation += 1  # 每次重新啟用，世代遞增
	on_generate.emit()

func _exit_tree():
	_release_cell(grid_pos)

# =========================
# 共用工具
# =========================
func _is_volcano(pos: Vector2i) -> bool:
	return pos in VOLCANO_CELLS

func _is_ocean_heart(pos: Vector2i) -> bool:
	return pos in OCEAN_HEART_CELLS

func _get_occupied_cells() -> Array[Vector2i]:
	var occupied: Array[Vector2i] = []
	for pos in reserved_cells.keys():
		if reserved_cells[pos] != self:
			occupied.append(pos)
	return occupied

func _get_volcano_adjacent_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var directions = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for cell in VOLCANO_CELLS:
		for dir in directions:
			var neighbor = cell + dir
			if not _is_volcano(neighbor) and neighbor not in result:
				result.append(neighbor)
	return result

func _is_adjacent_to_volcano(pos: Vector2i) -> bool:
	var directions = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for dir in directions:
		if _is_volcano(pos + dir):
			return true
	return false

func _find_nearest_land() -> Vector2i:
	var lands = EventManager.simple_map_data.keys()
	if lands.is_empty():
		return INVALID_TARGET
	var best = INVALID_TARGET
	var best_dist = INF
	for p in lands:
		if _is_volcano(p) or _is_ocean_heart(p):
			continue
		var d = grid_pos.distance_to(p)
		if d < best_dist:
			best_dist = d
			best = p
	return best

func _find_nearest_volcano() -> Vector2i:
	var best = INVALID_TARGET
	var best_dist = INF
	for cell in VOLCANO_CELLS:
		var d = grid_pos.distance_to(cell)
		if d < best_dist:
			best_dist = d
			best = cell
	return best

func _find_volcano_in_range(range_cells: int) -> Vector2i:
	var best = INVALID_TARGET
	var best_dist = INF
	for cell in VOLCANO_CELLS:
		var d = grid_pos.distance_to(cell)
		if d <= range_cells and d < best_dist:
			best_dist = d
			best = cell
	return best

func _find_best_volcano_adjacent() -> Vector2i:
	var candidates = _get_volcano_adjacent_cells()
	var occupied = _get_occupied_cells()
	var best = INVALID_TARGET
	var best_dist = INF
	for pos in candidates:
		if pos in occupied:
			continue
		var d = grid_pos.distance_to(pos)
		if d < best_dist:
			best_dist = d
			best = pos
	return best

# =========================
# A* 路徑
# =========================
func _find_path_to(t: Vector2i, occupied: Array[Vector2i] = []) -> Array[Vector2i]:
	var open_set: Array[Vector2i] = [grid_pos]
	var came_from: Dictionary = {}
	var g_score: Dictionary = { grid_pos: 0.0 }
	var f_score: Dictionary = { grid_pos: _heuristic(grid_pos, t) }

	while not open_set.is_empty():
		# 找 f_score 最小的節點
		var current = open_set[0]
		for node in open_set:
			if f_score.get(node, INF) < f_score.get(current, INF):
				current = node

		if current == t:
			var result: Array[Vector2i] = []
			var c = t
			while c != grid_pos:
				result.push_front(c)
				c = came_from[c]
			return result

		open_set.erase(current)

		var directions = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
		for dir in directions:
			var next = current + dir
			if _is_volcano(next) and next != t:
				continue
			if next != t and next in occupied:
				continue
			if abs(next.x) > 50 or abs(next.y) > 50:
				continue

			var tentative_g = g_score.get(current, INF) + 1.0
			if tentative_g < g_score.get(next, INF):
				came_from[next] = current
				g_score[next] = tentative_g
				f_score[next] = tentative_g + _heuristic(next, t)
				if next not in open_set:
					open_set.append(next)

	return []

func _heuristic(a: Vector2i, b: Vector2i) -> float:
	# Manhattan distance，格子移動不走斜線所以最準確
	return abs(a.x - b.x) + abs(a.y - b.y)

# =========================
# MAIN LOOP
# =========================
func _process(delta):
	match state:
		State.SEARCH:
			match type:
				MonsterType.JELLYFISH:
					_handle_search_jellyfish()
				MonsterType.OCTOPUS:
					_handle_search_octopus()
				MonsterType.STARFISH:
					_handle_search_starfish()
		State.MOVE:
			match type:
				MonsterType.JELLYFISH:
					_handle_move_jellyfish(delta)
				MonsterType.OCTOPUS:
					_handle_move_octopus(delta)
				MonsterType.STARFISH:
					_handle_move_starfish(delta)
		State.ATTACK:
			_handle_attack(delta)

# =========================
# 水母 SEARCH
# =========================
func _handle_search_jellyfish():
	target = _find_nearest_land()
	if target == INVALID_TARGET:
		return
	path = []
	state = State.MOVE

# =========================
# 章魚 SEARCH
# =========================
func _handle_search_octopus():
	var in_range_target = _find_volcano_in_range(OCTOPUS_RANGE)
	if in_range_target != INVALID_TARGET:
		target = in_range_target
		state = State.ATTACK
		attack_cooldown = 0.0
		return
	target = _find_nearest_volcano()
	if target == INVALID_TARGET:
		return
	path = []
	state = State.MOVE

# =========================
# 海星 SEARCH
# =========================
func _handle_search_starfish():
	target = _find_best_volcano_adjacent()
	if target == INVALID_TARGET:
		return
	path = []
	state = State.MOVE

# =========================
# 水母 MOVE
# =========================
func _handle_move_jellyfish(delta):
	target = _find_nearest_land()

	if target == INVALID_TARGET:
		state = State.SEARCH
		return

	if grid_pos == target:
		path = []
		state = State.ATTACK
		attack_cooldown = 0.0
		return

	move_cooldown -= delta
	if move_cooldown > 0:
		return

	var occupied = _get_occupied_cells()
	path = _find_path_to(target, occupied)

	if path.is_empty():
		return

	var next_step = path.front()
	if not _is_cell_free(next_step):
		return

	_release_cell(grid_pos)
	path.pop_front()
	grid_pos = next_step
	_reserve_cell(grid_pos)
	global_position = Vector2(grid_pos) * CELL_SIZE + ORIGIN_OFFSET
	move_cooldown = 1.0 / max(speed, 0.1)


# =========================
# 章魚 MOVE（走到火山射程內就停）
# =========================
func _handle_move_octopus(delta):
	var in_range_target = _find_volcano_in_range(OCTOPUS_RANGE)
	if in_range_target != INVALID_TARGET:
		target = in_range_target
		path = []
		state = State.ATTACK
		attack_cooldown = 0.0
		return

	target = _find_nearest_volcano()
	if target == INVALID_TARGET:
		state = State.SEARCH
		return

	move_cooldown -= delta
	if move_cooldown > 0:
		return

	var occupied = _get_occupied_cells()
	path = _find_path_to(target, occupied)

	if path.is_empty():
		return

	var next_step = path.front()
	if not _is_cell_free(next_step):
		return

	_release_cell(grid_pos)
	path.pop_front()
	grid_pos = next_step
	_reserve_cell(grid_pos)
	global_position = Vector2(grid_pos) * CELL_SIZE + ORIGIN_OFFSET
	move_cooldown = 1.0 / max(speed, 0.1)

# =========================
# 海星 MOVE
# =========================
func _handle_move_starfish(delta):
	if _is_adjacent_to_volcano(grid_pos):
		path = []
		state = State.ATTACK
		attack_cooldown = 0.0
		return

	var occupied = _get_occupied_cells()

	if target == INVALID_TARGET or target in occupied:
		target = _find_best_volcano_adjacent()

	if target == INVALID_TARGET:
		return

	if grid_pos == target:
		path = []
		state = State.ATTACK
		attack_cooldown = 0.0
		return

	move_cooldown -= delta
	if move_cooldown > 0:
		return

	path = _find_path_to(target, occupied)

	if path.is_empty():
		state = State.SEARCH
		return

	var next_step = path.front()
	if not _is_cell_free(next_step):
		return

	_release_cell(grid_pos)
	path.pop_front()
	grid_pos = next_step
	_reserve_cell(grid_pos)
	global_position = Vector2(grid_pos) * CELL_SIZE + ORIGIN_OFFSET
	move_cooldown = 1.0 / max(speed, 0.1)

# =========================
# ATTACK
# =========================
func _handle_attack(delta):
	attack_cooldown -= delta
	if attack_cooldown > 0:
		return

	match type:
		MonsterType.JELLYFISH:
			_attack_jellyfish()
		MonsterType.OCTOPUS:
			_attack_octopus_ranged()
		MonsterType.STARFISH:
			_attack_starfish()

func _attack_jellyfish():
	if EventManager.simple_map_data.has(grid_pos):
		EventManager.command_damage_land.emit(grid_pos, attack_damage)
		attack_cooldown = attack_interval
	else:
		state = State.SEARCH

func _attack_octopus_ranged():
	target = _find_volcano_in_range(OCTOPUS_RANGE)
	if target == INVALID_TARGET:
		state = State.SEARCH
		return
	var bullet = Bullet.new()
	get_parent().add_child(bullet)
	bullet.initialize(
		global_position,
		Vector2(target) * CELL_SIZE + ORIGIN_OFFSET,
		attack_damage,
		self
	)
	attack_cooldown = attack_interval

func _attack_starfish():
	var directions = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var attacked = false
	for dir in directions:
		var neighbor = grid_pos + dir
		if _is_volcano(neighbor):
			EventManager.command_damage_land.emit(neighbor, attack_damage)
			attacked = true
	if attacked:
		attack_cooldown = attack_interval
	else:
		state = State.SEARCH

# =========================
# 子彈
# =========================
# Bullet (在 Monster.gd 內)
class Bullet extends Node2D:
	var target_pos: Vector2
	var damage: int
	var speed: float = 300.0
	var owner_monster: Monster = null
	var owner_generation: int = -1  # 記住發射當下的世代

	func initialize(from: Vector2, to: Vector2, dmg: int, owner: Monster):
		global_position = from
		target_pos = to
		damage = dmg
		owner_monster = owner
		owner_generation = owner.generation  # 快照當下世代

	func _is_owner_alive() -> bool:
		if not is_instance_valid(owner_monster):
			return false
		if not owner_monster.visible:
			return false
		return owner_monster.generation == owner_generation  # 世代不符就視為已死

	func _process(delta):
		if not _is_owner_alive():
			queue_free()
			return
		var direction = target_pos - global_position
		if direction.length() <= speed * delta:
			global_position = target_pos
			_on_hit()
		else:
			global_position += direction.normalized() * speed * delta

	func _draw():
		draw_circle(Vector2.ZERO, 6, Color.BLACK)

	func _on_hit():
		if not _is_owner_alive():
			queue_free()
			return
		EventManager.command_damage_land.emit(Vector2i(0, 0), damage)
		queue_free()
