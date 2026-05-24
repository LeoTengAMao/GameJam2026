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


func _on_btn_next_phase_pressed() -> void:
	# 你的 Phase 系統是全域的嗎？如果是的話，可以直接修改
	# 這裡假設你的 Phase 系統是透過改變 start_time 來達成
	var phase_node = get_tree().root.find_child("Phase", true, false)
	if phase_node:
		# 透過減少 start_time 的數值，讓經過的時間變長，從而強制跳到下一階段
		# 假設 Phase 是根據 time 判斷，我們直接讓開始時間往前推 30 秒
		phase_node.start_time -= 30000*4 
		print("Debug: 強制跳轉階段，目前階段: ", Phase.getPhase())
	else:
		print("Debug: 找不到 Phase 節點")


func _on_btn_spawn_boss_pressed() -> void:
	# 尋找場景中的生成器
	var gen = get_tree().root.find_child("MonsterGenerator", true, false)
	if gen and gen.has_method("spawn_boss"):
		gen.spawn_boss()
		print("Debug: 強制召喚 Boss")
	else:
		print("Debug: 找不到 MonsterGenerator 節點")
