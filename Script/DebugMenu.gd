extends CanvasLayer

func _ready():
	# 預設隱藏
	hide()

func _input(event):
	# 直接檢查按鍵事件，這樣最直覺
	if event.is_action_pressed("ui_text_completion") or (event is InputEventKey and event.pressed and event.keycode == KEY_F1):
		# 切換可見度
		visible = !visible
		
		# 根據可見度來決定要不要暫停遊戲
		get_tree().paused = visible 
		
		
# --- 按鈕邏輯 ---

func _on_btn_add_stones_pressed():
	ResourceManager.add_stones(500)
	print("Debug: 加了 500 顆石頭")

func _on_btn_win_pressed():
	EventManager.game_won.emit()
	print("Debug: 強制觸發勝利")

func _on_btn_loss_pressed():
	EventManager.game_over.emit()
	print("Debug: 強制觸發失敗")

func _on_btn_toggle_erosion_pressed():
	# 抓取 MapManager 的計時器來關閉或開啟侵蝕
	var map = get_tree().root.find_child("MapManager", true, false)
	if map and map.erosion_timer:
		map.erosion_timer.paused = !map.erosion_timer.paused
		print("Debug: 侵蝕機制切換為 ", !map.erosion_timer.paused)
