extends Node
class_name CooldownRockGenerator

## 每隔幾秒生成一次石頭
@export var spawn_interval: float = 2.0

## 拖入你的 RockPool 節點 (型態為 Node 或特定類別)
@export var rock_pool: Node

## 最小冷卻上限（防呆：總不能讓冷卻變成 0 秒，不然電腦會因為無限生成而卡死）
@export var min_spawn_interval: float = 0.2

var time_accumulator: float = 0.0

func _ready() -> void:
	# 新增：在初始化時，監聽火山升級的訊號
	EventManager.volcano_upgraded.connect(_on_volcano_upgraded)
	GenerateManager.on_cancel_area.connect(_on_remove_area_rock)
	time_accumulator = 0.0

var rocks: Dictionary = {}

func _process(delta: float) -> void:
	time_accumulator += delta
	if time_accumulator >= spawn_interval:
		time_accumulator -= spawn_interval
		_on_timer_tick()


func _on_timer_tick() -> void:
	_spawn_n_rock()

func _on_remove_area_rock(area: GenerateArea) -> void:
	if area == null:
		return
	# 如果找不到這個 area，就回傳一個空陣列 []，for 迴圈就不會崩潰
	var area_rocks = rocks.get(area, [])
	print("hihihi", area_rocks)
	for rock in area_rocks:
		if rock != null:
			rock.destroy()
	# 清理防漏
	if rocks.has(area):
		rocks.erase(area)

func _spawn_n_rock() -> void:
	for area in GenerateManager._areas:
		var spawn_global_pos = GenerateManager.get_spawn_global_position(area)
		var rock = rock_pool.spawn_rock(spawn_global_pos)
		
		if rocks.get(area) == null:
			rocks[area] = []
		rocks[area].append(rock)

func _spawn_one_rock() -> void:
	# 在 GDScript 中，可以直接用 Autoload 的全域名稱 GenerateManager
	# 如果沒有值，GDScript 的方法通常會回傳 null
	var area = GenerateManager.get_pick_area()
	var spawn_global_pos = GenerateManager.get_spawn_global_position(area)
	
	var rock;
	# 檢查是否成功取得位置（不為 null），且防呆檢查 rock_pool 是否存在
	if spawn_global_pos != null and rock_pool != null:
		# 如果 rock_pool 是 GDScript，直接呼叫方法即可
		rock = rock_pool.spawn_rock(spawn_global_pos)
		
	if rocks.get(area) == null:
		rocks[area] = []
	rocks[area].append(rock)
		
func set_interval(time: float) -> void:
	spawn_interval = clampf(time, min_spawn_interval, 10.0)
	print("⏳ 石頭生成速度已調整！當前每隔 ", spawn_interval, " 秒掉落一顆石頭")

func _on_volcano_upgraded(level: int, _cur_hp: int, _max_hp: int) -> void:
	# 公式：每次升級，就把生成間隔減少 0.3 秒（你可以自己調數值）
	# 等級 1: 2.0秒
	# 等級 2: 1.7秒
	# 等級 3: 1.4秒 ... 依此類推
	var new_interval = 2.0 - (level - 1) * 0.5
	
	# 呼叫你原本寫好的設定函式
	set_interval(new_interval)
