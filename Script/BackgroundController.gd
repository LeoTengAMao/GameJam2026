extends ColorRect

func _ready():
	# 初始化時更新一次
	update_background_mode()
	# 監聽設定變更訊號
	EventManager.settings_changed.connect(update_background_mode)

func update_background_mode():
	var mat = material as ShaderMaterial
	if not mat: return
	
	if EventManager.is_gentle_mode:
		# 🌊 溫和模式：停止流動、顏色變深沉、飽和度降低
		mat.set_shader_parameter("wave_speed", 0.0)      # 停止海浪流動
		mat.set_shader_parameter("deep_water", Color(0.08, 0.35, 0.6, 0.8))
		mat.set_shader_parameter("shallow_water", Color(0.15, 0.6, 0.8, 0.8))
		mat.set_shader_parameter("foam_color", Color(0.9, 0.95, 1.0, 0.8))
	else:
		# 🌊 原樣模式：恢復動態與鮮豔色彩
		mat.set_shader_parameter("wave_speed", 0.01)     # 恢復流速
		mat.set_shader_parameter("deep_water", Color(0.08, 0.35, 0.6, 1.0))
		mat.set_shader_parameter("shallow_water", Color(0.15, 0.6, 0.8, 1.0))
		mat.set_shader_parameter("foam_color", Color(0.9, 0.95, 1.0, 1.0))
