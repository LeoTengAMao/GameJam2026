extends Node2D
class_name Monster

const CELL_SIZE := 128
const ORIGIN_OFFSET := Vector2(64, 64)
const INVALID_TARGET := Vector2i(-999, -999)
const OCTOPUS_RANGE := 5
const SEARCH_INTERVAL := 0.5  # 每 0.5 秒才重新找目標一次
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
var generation: int = 0

# 火山（中間四格）
const VOLCANO_CELLS := [
	Vector2i(0, 0), Vector2i(1, 0),
	Vector2i(0, 1), Vector2i(1, 1)
]

var scale_map = {
	MonsterType.JELLYFISH: Vector2(5.0, 5.0),
	MonsterType.OCTOPUS: Vector2(1.0, 1.0),   # adjust these values
	MonsterType.STARFISH: Vector2(1.0, 1.0)
}

# 海洋之心（不攻擊，但可穿越）
const OCEAN_HEART_CELLS := [
	Vector2i(35, -1), Vector2i(35, 0), Vector2i(35, 1),
	Vector2i(36, -1), Vector2i(36, 0), Vector2i(36, 1),
	Vector2i(37, -1), Vector2i(37, 0), Vector2i(37, 1)
]

signal collected
signal on_generate


# =========================
# 全局佔位管理
# =========================
static var reserved_cells: Dictionary = {}

func _ready():
	# 這裡保證 sprite 絕對已經準備好了！
	
	sprite.play(animation_map[type])
	sprite.scale = scale_map[type]

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

var animation_map = {
	MonsterType.JELLYFISH: "jellyfish",
	MonsterType.OCTOPUS: "octopus",
	MonsterType.STARFISH: "starfish"
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

# 水母路徑快取
var _cached_target: Vector2i = INVALID_TARGET
var _cached_nearest_land: Vector2i = INVALID_TARGET
var _search_cooldown: float = 0.0

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
	_cached_target = INVALID_TARGET
	_cached_nearest_land = INVALID_TARGET
	_search_cooldown = 0.0
	add_to_group("monsters")
	_reserve_cell(grid_pos)
	generation += 1
	
	if is_node_ready(): 
		_update_visuals()
	else:
		ready.connect(_update_visuals, CONNECT_ONE_SHOT)
		
	on_generate.emit()

func _update_visuals() -> void:
	if sprite:
		sprite.play(animation_map[type])
		sprite.scale = scale_map[type]

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
		var pi := Vector2i(int(p.x), int(p.y))
		if _is_volcano(pi) or _is_ocean_heart(pi):
			continue
		var d = grid_pos.distance_to(p)
		if d < best_dist:
			best_dist = d
			best = pi
	return best

# 節流版：每 SEARCH_INTERVAL 秒才重新掃地圖
func _find_nearest_land_cached(delta: float) -> Vector2i:
	_search_cooldown -= delta
	if _search_cooldown > 0.0:
		return _cached_nearest_land
	_search_cooldown = SEARCH_INTERVAL
	_cached_nearest_land = _find_nearest_land()
	return _cached_nearest_land

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
# A* 路徑（移除 occupied 陣列，改用全域字典 $O(1)$ 查詢）
# =========================
func _find_path_to(t: Vector2i) -> Array[Vector2i]:
	var open_set: Array[Vector2i] = [grid_pos]
	var came_from: Dictionary = {}
	var g_score: Dictionary = { grid_pos: 0.0 }
	var f_score: Dictionary = { grid_pos: _heuristic(grid_pos, t) }

	while not open_set.is_empty():
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
				
			# 🎯 核心優化：不要用迴圈陣列檢查！直接用 .has() 查詢全域靜態字典
			if next != t and Monster.reserved_cells.has(next):
				# 如果該格子登記的主人不是自己，那就代表它是障礙物，繞道！
				if Monster.reserved_cells[next] != self:
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
	state = State.MOVE  # 直接開始漂，不需要找目標

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
# 水母 MOVE（漂流版）
# =========================
func _handle_move_jellyfish(delta):
	move_cooldown -= delta
	if move_cooldown > 0:
		return

	if EventManager.simple_map_data.has(grid_pos) and not _is_ocean_heart(grid_pos):
		state = State.ATTACK
		attack_cooldown = 0.0
		return

	var toward_center_x = -sign(grid_pos.x) if grid_pos.x != 0 else 0
	var toward_center_y = -sign(grid_pos.y) if grid_pos.y != 0 else 0
	var wx = clamp(abs(grid_pos.x) / 10.0, 0.5, 3.0)
	var wy = clamp(abs(grid_pos.y) / 10.0, 0.5, 3.0)

	var weighted_dirs: Array[Vector2i] = []
	if toward_center_x != 0:
		for i in int(wx * 2):
			weighted_dirs.append(Vector2i(toward_center_x, 0))
	if toward_center_y != 0:
		for i in int(wy * 2):
			weighted_dirs.append(Vector2i(0, toward_center_y))
	weighted_dirs.append(Vector2i(1, 0))
	weighted_dirs.append(Vector2i(-1, 0))
	weighted_dirs.append(Vector2i(0, 1))
	weighted_dirs.append(Vector2i(0, -1))

	weighted_dirs.shuffle()

	for dir in weighted_dirs:
		var next = grid_pos + dir
		# 邊界檢查
		if next.x < -15 or next.x > 39 or next.y < -15 or next.y > 15:
			continue
		# 火山不能穿越
		if _is_volcano(next):
			continue
		# 其他怪物佔用
		if not _is_cell_free(next):
			continue
		_release_cell(grid_pos)
		grid_pos = next
		_reserve_cell(grid_pos)
		global_position = Vector2(grid_pos) * CELL_SIZE + ORIGIN_OFFSET
		break

	move_cooldown = 1.0 / max(speed, 0.1)

# =========================
# 章魚 MOVE（走到火山射程內就停）- 優化節流版
# =========================
func _handle_move_octopus(delta):
	# 1. 檢查是否已經有火山在射程內了，有的話立刻轉成攻擊，不用移動
	var in_range_target = _find_volcano_in_range(OCTOPUS_RANGE)
	if in_range_target != INVALID_TARGET:
		target = in_range_target
		path = []
		state = State.ATTACK
		attack_cooldown = 0.0
		return

	# 2. 移動冷卻計時
	move_cooldown -= delta
	if move_cooldown > 0:
		return

	# 3. 確保有目標火山
	target = _find_nearest_volcano()
	if target == INVALID_TARGET:
		state = State.SEARCH
		return

	# 🎯 最佳化 A：如果路徑是空的，才需要重新計算 A*（不需要每一步都重算）
	if path.is_empty():
		path = _find_path_to(target) # 拿掉 occupied 參數，改去內部查全域字典
		
		# 防呆：如果真的完全找不到路（例如路被填滿了），強迫休息一下再搜尋，避免死循環卡死 CPU
		if path.is_empty():
			move_cooldown = 0.5 
			return

	# 4. 準備跨出下一步
	var next_step = path.front()
	
	# 🎯 最佳化 B：防重疊檢查，直接查靜態字典（原本的 _is_cell_free 已經有查了）
	if not _is_cell_free(next_step):
		# 如果下一步突然被其他怪物捷足先登了，這一幀先停下不走，下一幀再重新評估
		return

	# 5. 安全步進更新
	_release_cell(grid_pos)
	path.pop_front()
	grid_pos = next_step
	_reserve_cell(grid_pos)
	
	# 同步世界座標
	global_position = Vector2(grid_pos) * CELL_SIZE + ORIGIN_OFFSET
	
	# 重設移動冷卻
	move_cooldown = 1.0 / max(speed, 0.1)

# =========================
# 海星 MOVE - 修正優化版（繞路型）
# =========================
func _handle_move_starfish(delta):
	if _is_adjacent_to_volcano(grid_pos):
		path = []
		state = State.ATTACK
		attack_cooldown = 0.0
		return

	move_cooldown -= delta
	if move_cooldown > 0:
		return

	# 如果路徑空了，重新尋找目標並計算 A*
	if path.is_empty():
		target = _find_best_volcano_adjacent()
		if target == INVALID_TARGET:
			return
		path = _find_path_to(target) # 已套用上一題的優化版（直查全域字典）
		
		if path.is_empty():
			state = State.SEARCH
			move_cooldown = 0.5 # 找不到路時強制休息，防 CPU 燒壞
			return

	# 檢查下一步
	var next_step = path.front()
	
	# 🎯 修正核心：如果下一步被其他怪物擋住了！
	if not _is_cell_free(next_step):
		path.clear() # 💥 立刻清空路徑！逼它在下一影格重新算一條「繞開擋路者」的新路
		move_cooldown = 0.2 # 稍微等待 0.2 秒再動，給前方怪物一點走開的時間，避免每幀狂算 A*
		return

	# 順利通行
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
	# 地塊還在 → 繼續攻擊
	if EventManager.simple_map_data.has(grid_pos):
		EventManager.command_damage_land.emit(grid_pos, attack_damage)
		attack_cooldown = attack_interval
	else:
		# 地塊消失 → 回到漂流
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

func take_damage(amount: int):
	hp -= amount
	
	# 可以加個閃爍特效或飄字
	sprite.modulate = Color(1, 0.5, 0.5) # 變紅
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(1, 1, 1), 0.2)
	
	if hp <= 0:
		_die()

func _die():
	_release_cell(grid_pos) # 釋放佔用的網格
	# 如果你有掉落物或是要加錢，可以在這裡寫 (例如: ResourceManager.add_stones(5))
	queue_free() # 刪除怪物節點

# =========================
# 子彈
# =========================
class Bullet extends Node2D:
	var target_pos: Vector2
	var damage: int
	var speed: float = 400.0
	var owner_monster: Monster = null
	var owner_generation: int = -1

	var trail: Array[Vector2] = []
	const TRAIL_LENGTH = 10

	# 隨機裝飾粒子（初始化時固定，不每幀重算）
	var ink_particles: Array[Dictionary] = []
	const PARTICLE_COUNT = 6

	func initialize(from: Vector2, to: Vector2, dmg: int, owner: Monster):
		global_position = from
		target_pos = to
		damage = dmg
		owner_monster = owner
		owner_generation = owner.generation
		_init_particles()

	func _init_particles():
		ink_particles.clear()
		var rng = RandomNumberGenerator.new()
		rng.randomize()
		for i in PARTICLE_COUNT:
			ink_particles.append({
				# 圍繞核心的隨機偏移
				"offset": Vector2(rng.randf_range(-12.0, 12.0), rng.randf_range(-12.0, 12.0)),
				"radius": rng.randf_range(1.5, 4.0),
				# 低明度隨機顏色：深紫、深藍、深綠、深紅
				"color": Color(
					rng.randf_range(0.0, 0.25),
					rng.randf_range(0.0, 0.2),
					rng.randf_range(0.0, 0.3),
					rng.randf_range(0.4, 0.8)
				)
			})

	func _is_owner_alive() -> bool:
		if not is_instance_valid(owner_monster):
			return false
		if not owner_monster.visible:
			return false
		return owner_monster.generation == owner_generation

	func _process(delta):
		if not _is_owner_alive():
			queue_free()
			return

		trail.push_back(Vector2.ZERO)
		if trail.size() > TRAIL_LENGTH:
			trail.pop_front()

		var direction = target_pos - global_position
		if direction.length() <= speed * delta:
			global_position = target_pos
			_on_hit()
		else:
			var move = direction.normalized() * speed * delta
			global_position += move
			for i in trail.size():
				trail[i] -= move

		queue_redraw()

	func _draw():
		var dir = (target_pos - global_position).normalized()
		if dir == Vector2.ZERO:
			dir = Vector2(1, 0)

		# 墨汁拖尾：黑色為主，越舊越細越透明
		for i in trail.size():
			var t = float(i) / float(TRAIL_LENGTH)
			var radius = lerp(15.0, 5.0, t)
			var alpha = lerp(0.0, 0.7, t)
			draw_circle(trail[i], radius, Color(0.05, 0.05, 0.08, alpha))

		# 拖尾側邊墨點（不規則感）
		for i in range(0, trail.size(), 2):
			var t = float(i) / float(TRAIL_LENGTH)
			var splat_offset = Vector2(trail[i].y, -trail[i].x).normalized() * randf_range(2.0, 5.0)
			draw_circle(trail[i] + splat_offset, lerp(0.3, 2.0, t), Color(0.08, 0.04, 0.1, t * 0.4))
			draw_circle(trail[i] - splat_offset, lerp(0.3, 1.5, t), Color(0.05, 0.02, 0.08, t * 0.3))

		# 低明度裝飾粒子（固定偏移，隨子彈旋轉）
		for p in ink_particles:
			draw_circle(p["offset"], p["radius"], p["color"])

		# 墨汁暈染外層
		draw_circle(Vector2.ZERO, 11.0, Color(0.06, 0.02, 0.1, 0.35))

		# 墨汁中層
		draw_circle(Vector2.ZERO, 7.0, Color(0.04, 0.04, 0.06, 0.85))

		# 核心
		draw_circle(Vector2.ZERO, 4.0, Color(0.08, 0.02, 0.12, 1.0))

		# 方向性墨汁尾跡（粗）
		var tail_end = -dir * 16.0
		draw_line(Vector2.ZERO, tail_end, Color(0.05, 0.02, 0.08, 0.5), 4.0, true)
		# 細高亮線（讓尾跡有層次）
		draw_line(Vector2.ZERO, tail_end * 0.5, Color(0.15, 0.08, 0.2, 0.6), 1.5, true)

	func _on_hit():
		if not _is_owner_alive():
			queue_free()
			return
		EventManager.command_damage_land.emit(Vector2i(0, 0), damage)
		queue_free()
		
	
