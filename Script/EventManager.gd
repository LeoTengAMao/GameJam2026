extends Node

# 定義 UI 專用訊號：當滑鼠懸停的地塊改變時發射
# 傳遞參數：是否指著有效土地、地形名稱、目前血量、最大血量
signal on_cell_hovered(is_hovering: bool, type_name: String, current_hp: int, max_hp: int)

# 新增：給隊員接的接口（當玩家收集到石頭時發射）
signal stone_collected(amount: int)

# 新增：當石頭數量改變時，用來通知 UI 更新畫面的訊號
signal stone_count_changed(new_amount: int)

# 新增：當玩家按下升級按鈕時發射 (參數：升級的類型，例如 "volcano")
signal upgrade_requested(type: String)

# 新增：當升級成功後，通知大家目前的等級與數值
signal volcano_upgraded(level: int, current_hp: int, max_hp: int)
