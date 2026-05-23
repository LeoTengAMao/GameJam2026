extends Node

# 定義 UI 專用訊號：當滑鼠懸停的地塊改變時發射
# 傳遞參數：是否指著有效土地、地形名稱、目前血量、最大血量
signal on_cell_hovered(is_hovering: bool, type_name: String, current_hp: int, max_hp: int)

# 新增：給隊員接的接口（當玩家收集到石頭時發射）
signal stone_collected(amount: int)

signal on_create_land(pos: Vector2)

signal on_destory_land(pos: Vector2)

# 新增：當石頭數量改變時，用來通知 UI 更新畫面的訊號
signal stone_count_changed(new_amount: int)

# 原本只有 type，現在加上 upgrade_id 告訴系統具體買了哪一招
signal upgrade_requested(target_type: String, upgrade_id: String)

# 新增：當升級成功後，通知大家目前的等級與數值
signal volcano_upgraded(level: int, current_hp: int, max_hp: int)

# 建立一個公開的精簡版地圖，格式為 { Vector2i(x,y) : "LAND" }
var simple_map_data: Dictionary = {}

# 參數只傳座標跟字串
signal land_updated(pos: Vector2i, type_name: String)

# 任何系統想對土地造成傷害，發射這個訊號
signal command_damage_land(pos: Vector2i, damage_amount: int)

# 任何系統想強制摧毀某塊地，發射這個訊號
signal command_destroy_land(pos: Vector2i)

signal on_cell_selected(data: Dictionary)

signal close_ui_requested

var is_heart_surrounded: bool = false
signal game_won
signal game_over
