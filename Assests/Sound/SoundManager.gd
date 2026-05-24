extends AudioStreamPlayer

# 這裡可以預載入你的 BGM 音樂檔
var Phase1 = preload("res://Assests/BGM/Phase1.mp3")
var Phase2 = preload("res://Assests/BGM/Phase2.mp3")
var Phase3 = preload("res://Assests/BGM/Phase3.mp3")
var current_phase = -1
func _ready():
	volume_db = -5.0
	if EventManager.has_signal("game_over"):
		EventManager.game_over.connect(_stop_music)

func set_volume(db: float) -> void:
	volume_db = db

func _stop_music():
	stop()
	current_phase = -1 # 重置階段，防止恢復遊戲時出錯
	print("🔇 遊戲結束，音樂已停止")

# 方便外部隨時切換音樂的函式
func play_new_bgm(new_stream: AudioStream):
	stream = new_stream
	play()

func play_bgm_for_phase(phase: int):
	# 如果階段沒變，就不需要重播
	if current_phase == phase:
		return
	
	current_phase = phase
	var next_stream = null
	
	match phase:
		1: next_stream = Phase1
		2: next_stream = Phase2
		3: next_stream = Phase3
		
	if next_stream:
		stream = next_stream
		play()
		print("🎵 切換到階段 ", phase, " 的音樂")
