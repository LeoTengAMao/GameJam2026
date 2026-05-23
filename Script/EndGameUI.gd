extends CanvasLayer

@onready var color_rect = $ColorRect
@onready var title_label = $CenterContainer/PanelContainer/VBoxContainer/TitleLabel
@onready var desc_label = $CenterContainer/PanelContainer/VBoxContainer/DescLabel
@onready var restart_btn = $CenterContainer/PanelContainer/VBoxContainer/RestartBtn

func _ready() -> void:
	# 遊戲剛開始時，結算畫面必須是隱藏的
	hide()
	
	# 綁定按鈕點擊事件
	restart_btn.pressed.connect(_on_restart_pressed)
	
	# 🔌 監聽終局廣播
	EventManager.game_won.connect(show_win_screen)
	EventManager.game_over.connect(show_lose_screen)

# 🏆 顯示勝利畫面
func show_win_screen() -> void:
	title_label.text = "🎉 偉大的勝利！"
	title_label.add_theme_color_override("font_color", Color(1, 0.8, 0)) # 變成金色
	desc_label.text = "火山大爆炸摧毀了海洋之心！\n你的島嶼永遠安全了！"
	
	_play_popup_animation()

# 💀 顯示失敗畫面
func show_lose_screen() -> void:
	title_label.text = "💀 遊戲結束"
	title_label.add_theme_color_override("font_color", Color(1, 0.2, 0.2)) # 變成紅色
	desc_label.text = "火山核心被海水無情吞噬...\n世界沉入了海底。"
	
	_play_popup_animation()

# UI 彈出動畫與暫停遊戲
func _play_popup_animation() -> void:
	show()
	
	# 讓背景變暗、面板從小變大的彈出動畫
	color_rect.modulate.a = 0
	# $CenterContainer.scale = Vector2(0.5, 0.5)
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(color_rect, "modulate:a", 1.0, 0.5)
	tween.tween_property($CenterContainer, "scale", Vector2(1, 1), 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# 暫停整個遊戲（包含石頭掉落、海怪移動、侵蝕倒數都會停止！）
	get_tree().paused = true

# 🔄 重新開始遊戲
func _on_restart_pressed() -> void:
	# 1. 解除暫停狀態
	get_tree().paused = false
	
	# 2. 非常重要：清空 EventManager 裡的全域變數與資料！
	# 否則重新開始後，系統會以為海洋之心還是被包圍的，或是地圖資料殘留
	EventManager.is_heart_surrounded = false
	EventManager.simple_map_data.clear()
	
	# 3. 重新載入當前場景 (等同於 F5 刷新)
	get_tree().reload_current_scene()
