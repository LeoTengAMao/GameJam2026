extends Node2D
class_name Boss

const CELL_SIZE := 128
const ORIGIN_OFFSET := Vector2(64, 64)
const INVALID_TARGET := Vector2i(-999, -999)

# Boss occupies a 3x3 footprint relative to its anchor (top-left cell)
const FOOTPRINT := [
	Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0),
	Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1),
	Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2)
]

const VOLCANO_CELLS := [
	Vector2i(0, 0), Vector2i(1, 0),
	Vector2i(0, 1), Vector2i(1, 1)
]

signal on_death

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

# =========================
# STATS
# =========================
var hp: int = 500
var attack_damage: int = 10
var volcano_damage: int = 15
var speed: float = 0.3
var grid_pos: Vector2i          # anchor = top-left cell of the 3x3

# =========================
# TIMERS
# =========================
var move_cooldown: float = 0.0
var land_attack_cooldown: float = 0.0
var volcano_attack_cooldown: float = 0.0

const LAND_ATTACK_INTERVAL  := 1.5   # destroy random land every 1.5s
const VOLCANO_ATTACK_INTERVAL := 3.0  # hit volcano every 3s
const LAND_ATTACK_RADIUS    := 6      # how far it can randomly destroy land

# =========================
# STATE
# =========================
enum State { MOVE, ATTACK }
var state: State = State.MOVE
var path: Array[Vector2i] = []

# reuse Monster's reserved_cells for collision avoidance
# (Boss writes its own cells into the same dictionary)

func _ready():
	sprite.play("idle")
	sprite.scale = Vector2(3.0,3.0)
	sprite.animation_finished.connect(func():
		if sprite.animation == "attack":
			sprite.play("idle")
	)
	
	
func initialize(pos: Vector2i):
	grid_pos = pos
	_update_position()
	_reserve_footprint()
	add_to_group("bosses")
	state = State.MOVE

func _exit_tree():
	_release_footprint()

# =========================
# FOOTPRINT HELPERS
# =========================
func _footprint_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for offset in FOOTPRINT:
		cells.append(grid_pos + offset)
	return cells

func _reserve_footprint():
	for cell in _footprint_cells():
		Monster.reserved_cells[cell] = self

func _release_footprint():
	for cell in _footprint_cells():
		if Monster.reserved_cells.get(cell) == self:
			Monster.reserved_cells.erase(cell)

func _update_position():
	# Sprite is centered on the middle cell (1,1) of the 3x3
	var center = grid_pos + Vector2i(1, 1)
	global_position = Vector2(center) * CELL_SIZE + ORIGIN_OFFSET

func _is_footprint_free(anchor: Vector2i) -> bool:
	for offset in FOOTPRINT:
		var cell = anchor + offset
		if Monster.reserved_cells.has(cell) and Monster.reserved_cells[cell] != self:
			return false
	return true

# =========================
# MAIN LOOP
# =========================
func _process(delta):
	# 無論在 MOVE 還是 ATTACK，都維持攻擊能力
	match state:
		State.MOVE:
			_handle_move(delta)
			_handle_attack(delta) # 🌟 把攻擊檢查也放進來，讓他移動時也能攻擊
		State.ATTACK:
			_handle_attack(delta)

# =========================
# MOVE — walk toward volcano, switch to ATTACK when adjacent
# =========================
func _handle_move(delta):
	if _is_near_volcano():
		state = State.ATTACK
		return

	move_cooldown -= delta
	if move_cooldown > 0:
		return

	var target = _best_anchor_near_volcano()
	if target == INVALID_TARGET:
		return

	path = _find_path_to(target)
	if path.is_empty():
		return

	var next_anchor = path.front()
	if not _is_footprint_free(next_anchor):
		return

	_release_footprint()
	path.pop_front()
	grid_pos = next_anchor
	_reserve_footprint()
	_update_position()
	move_cooldown = 1.0 / max(speed, 0.1)

# =========================
# ATTACK — randomly destroy land + damage volcano
# =========================
func _handle_attack(delta):
	# 刪除原本的距離判斷，Boss 不再需要靠近火山才攻擊
	# if not _is_near_volcano():
	# 	state = State.MOVE
	# 	return

	# Random land destruction
	land_attack_cooldown -= delta
	if land_attack_cooldown <= 0:
		_do_land_attack()
		land_attack_cooldown = LAND_ATTACK_INTERVAL
		# 檢查是否在播放攻擊動畫，避免動畫不斷被中斷
		if sprite.animation != "attack":
			sprite.play("attack")

	# Volcano damage (現在 Boss 在地圖任何地方都可以對火山造成威脅)
	volcano_attack_cooldown -= delta
	if volcano_attack_cooldown <= 0:
		_do_volcano_attack()
		volcano_attack_cooldown = VOLCANO_ATTACK_INTERVAL
		if sprite.animation != "attack":
			sprite.play("attack")

func _do_land_attack():
	var lands = EventManager.simple_map_data.keys()
	if lands.is_empty():
		return
	# Gather candidates within radius
	var candidates: Array = []
	for p in lands:
		var pi := Vector2i(int(p.x), int(p.y))
		var center = grid_pos + Vector2i(1, 1)
		if center.distance_to(pi) <= LAND_ATTACK_RADIUS:
			candidates.append(pi)
	if candidates.is_empty():
		# fallback: pick any land
		candidates = lands.map(func(p): return Vector2i(int(p.x), int(p.y)))
	if candidates.is_empty():
		return	
	
	var pick: Vector2i = candidates[randi() % candidates.size()]
	EventManager.command_damage_land.emit(pick, attack_damage)

func _do_volcano_attack():
	# Hit all volcano cells (or pick a random one — your choice)
	for cell in VOLCANO_CELLS:
		EventManager.command_damage_land.emit(cell, volcano_damage)

# =========================
# PROXIMITY CHECK
# =========================
func _is_near_volcano() -> bool:
	var center = grid_pos + Vector2i(1, 1)
	for cell in VOLCANO_CELLS:
		if center.distance_to(cell) <= 4:
			return true
	return false

# =========================
# PATHFINDING — anchor-based A*
# =========================
func _best_anchor_near_volcano() -> Vector2i:
	# Find the anchor position that puts the boss closest to the volcano
	var best = INVALID_TARGET
	var best_dist = INF
	for cell in VOLCANO_CELLS:
		# Try anchors that would place the center near this volcano cell
		for dx in range(-3, 4):
			for dy in range(-3, 4):
				var candidate = cell + Vector2i(dx - 1, dy - 1)  # center offset
				if not _is_footprint_free(candidate):
					continue
				var dist = float((grid_pos + Vector2i(1,1)).distance_to(cell))
				if dist < best_dist:
					best_dist = dist
					best = candidate
	return best

func _find_path_to(t: Vector2i) -> Array[Vector2i]:
	var start = grid_pos
	var open_set: Array[Vector2i] = [start]
	var came_from: Dictionary = {}
	var g_score: Dictionary = { start: 0.0 }
	var f_score: Dictionary = { start: _heuristic(start, t) }

	while not open_set.is_empty():
		var current = open_set[0]
		for node in open_set:
			if f_score.get(node, INF) < f_score.get(current, INF):
				current = node

		if current == t:
			var result: Array[Vector2i] = []
			var c = t
			while c != start:
				result.push_front(c)
				c = came_from[c]
			return result

		open_set.erase(current)

		var directions = [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
		for dir in directions:
			var next = current + dir
			if abs(next.x) > 50 or abs(next.y) > 50:
				continue
			if not _is_footprint_free(next) and next != t:
				continue
			var tg = g_score.get(current, INF) + 1.0
			if tg < g_score.get(next, INF):
				came_from[next] = current
				g_score[next] = tg
				f_score[next] = tg + _heuristic(next, t)
				if next not in open_set:
					open_set.append(next)
	return []

func _heuristic(a: Vector2i, b: Vector2i) -> float:
	return abs(a.x - b.x) + abs(a.y - b.y)

# =========================
# DAMAGE / DEATH
# =========================
func take_damage(amount: int):
	hp -= amount
	sprite.modulate = Color(1, 0.3, 0.3)
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(1, 1, 1), 0.3)
	if hp <= 0:
		_die()

func _die():
	_release_footprint()
	on_death.emit()
	queue_free()
