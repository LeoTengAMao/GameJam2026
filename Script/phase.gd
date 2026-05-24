extends Node

# 設定為累積總秒數
@export var phase1_threshold : float = 120.0  # 2 分鐘
@export var phase2_threshold : float = 240.0  # 4 分鐘
@export var phase3_threshold : float = 360.0  # 6 分鐘

var start_time : int = 0

func _ready() -> void:
	start_time = Time.get_ticks_msec()

func getPhase() -> int:
	var elapsed_seconds = (Time.get_ticks_msec() - start_time) / 1000.0
	
	if elapsed_seconds > phase3_threshold: return 4
	if elapsed_seconds > phase2_threshold: return 3
	if elapsed_seconds > phase1_threshold: return 2
	return 1
