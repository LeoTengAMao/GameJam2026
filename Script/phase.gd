extends Node

@export var phase1_time : int;
@export var phase2_time : int;
@export var phase3_time : int;
	
func getPhase() -> int:
	if Time.get_ticks_usec() > phase3_time: return 4
	if Time.get_ticks_usec() > phase2_time: return 3
	if Time.get_ticks_usec() > phase1_time: return 2
	return 1
