extends Node
class_name SkillManager

# 抓住爸爸 (MapManager) 以便讀取地圖資料
@onready var map: MapManager = get_parent()
@export var CD : PackedScene

func _ready():
	# 由 SkillManager 來監聽升級訊號，分擔 MapManager 的工作
	EventManager.upgrade_requested.connect(_on_upgrade_requested)

func _on_upgrade_requested(target_type: String, upgrade_id: String):
	if map.current_selected_pos == Vector2i(-10000, -10000): return
	
	if target_type == "volcano":
		var volcano_core = map.grid_data[Vector2i(0,0)].core_data
		
		# === 🌋 處理火山的各種技能 ===
		if upgrade_id == "heal_all" and ResourceManager.spend_stones(100):
			_skill_heal_all_land()
		
		elif upgrade_id == "random_land" and ResourceManager.spend_stones(150):
			_skill_random_build_land()
				
		elif upgrade_id == "defense_up" and ResourceManager.spend_stones(200):
			_skill_global_defense_up()
				
		elif upgrade_id == "prod_speed" and ResourceManager.spend_stones(50):
			volcano_core.level += 1 
			
			# 🌟 火山核心資料庫升級完後，立刻廣播！(把新等級、新血量傳出去)
			EventManager.volcano_upgraded.emit(volcano_core.level, volcano_core.current_hp, volcano_core.max_hp)
			
			print("🌋 產石等級提升至 ", volcano_core.level)
			
		# 呼叫爸爸的函式更新 UI
		map._refresh_side_panel()

# --- 🌟 神級技能實作區 ---

func _skill_heal_all_land():
	print("✨ 施放：大地治癒！所有土地恢復滿血！")
	for pos in map.grid_data.keys():
		var cell = map.grid_data[pos]
		if cell.type == map.CellType.LAND or cell.type == map.CellType.COAST:
			cell.current_hp = cell.max_hp

func _skill_global_defense_up():
	print("🛡️ 施放：堅固岩層！所有土地最大血量 +50！")
	for pos in map.grid_data.keys():
		var cell = map.grid_data[pos]
		if cell.type == map.CellType.LAND or cell.type == map.CellType.COAST:
			cell.max_hp += 50
			cell.current_hp += 50

func _skill_random_build_land():
	print("🎲 施放：板塊構造！尋找適合的海洋造陸...")
	var possible_seas = []
	for pos in map.grid_data.keys():
		for dir in map.NEIGHBORS:
			var target_pos = pos + dir
			if not map.grid_data.has(target_pos):
				possible_seas.append(target_pos)
	
	if possible_seas.size() > 0:
		var lucky_pos = possible_seas.pick_random()
		map.grid_data[lucky_pos] = map.CellData.new(map.CellType.LAND, 100)
		EventManager.simple_map_data[lucky_pos] = "LAND"
		map.update_all_coasts()
		EventManager.on_create_land.emit(Vector2(lucky_pos * 128) + Vector2(128/2, 128/2))
		print("✅ 成功在座標 ", lucky_pos, " 隨機生成了一塊土地！")
	else:
		print("⚠️ 沒有空間可以造陸了！")
