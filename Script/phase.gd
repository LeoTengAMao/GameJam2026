extends Node

@export var phase1_seconds : float = 10.0
@export var phase2_seconds : float = 20.0
@export var phase3_seconds : float = 30.0

var start_time : int = 0

func _ready() -> void:
	start_time = Time.get_ticks_msec()

func getPhase() -> int:
	var due_time_msec = Time.get_ticks_msec() - start_time
	
	if due_time_msec > phase3_seconds * 1000: return 4
	if due_time_msec > phase2_seconds * 1000: return 3
	if due_time_msec > phase1_seconds * 1000: return 2
	return 1
