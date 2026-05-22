# GenerateManager.gd
extends Node

# 注意：此腳本請在 Godot 的 Project Settings -> Autoload 中註冊，名稱設為 "GenerateManager"
# 註冊後，它會自動變成全域單例，不需要再手動寫 C# 的 Instance。

var _areas: Array[GenerateArea] = []

# 供 GenerateArea 呼叫的註冊方法
func register_area(area: GenerateArea) -> void:
	if not _areas.has(area):
		_areas.append(area)

# 依照面積權重，隨機挑選一個 Area
func _pick_area_by_weight() -> GenerateArea:
	if _areas.size() == 0:
		return null

	# 1. 計算所有區域的總面積
	var total_area: float = 0.0
	for area in _areas:
		total_area += area.area_size

	# 2. 在 0 ~ 總面積 之間搖一個隨機數
	var random_weight = randf_range(0.0, total_area)

	# 3. 遍歷區域，看隨機數落在哪個區間
	var current_weight_sum: float = 0.0
	for area in _areas:
		current_weight_sum += area.area_size
		if random_weight <= current_weight_sum:
			return area # 抽中這個區域！

	return _areas[-1] # 防呆

# 核心觸發：依照權重隨機在地圖上的某個 Area 的某個點生成位置
# 備註：GDScript 沒有 Vector2? 這種 Nullable 型別，若沒抽中一律回傳 null，所以回傳型別宣告為 Variant
func get_random_spawn_global_position() -> Variant:
	var selected_area = _pick_area_by_weight()
	if selected_area == null:
		push_warning("沒有任何註冊的 GenerateArea！")
		return null

	# 取得該 Area 內部的隨機相對座標
	var local_pos = selected_area.get_random_local_position()

	# 將相對座標轉換為 Godot 的世界全域座標 (GlobalPosition)
	return selected_area.to_global(local_pos)
