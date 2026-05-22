extends Node

# 定義 UI 專用訊號：當滑鼠懸停的地塊改變時發射
# 傳遞參數：是否指著有效土地、地形名稱、目前血量、最大血量
signal on_cell_hovered(is_hovering: bool, type_name: String, current_hp: int, max_hp: int)
