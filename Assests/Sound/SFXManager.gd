extends AudioStreamPlayer # 繼承 Player，確保音樂持續播放

# 音效庫
var sfx_library = {
	"laser": preload("res://Assests/Sound/ahmed_abdulaal-laser-312360.mp3"),
	"laugh": preload("C:/Users/Administrator/Desktop/Git/GameJam2026/Assests/Sound/laugh.mp3")
}

func play(sfx_name: String):
	if not sfx_library.has(sfx_name): return
	
	# 動態產生獨立播放器，播完即丟
	var player = AudioStreamPlayer.new()
	player.stream = sfx_library[sfx_name]
	player.bus = "SFX" # 指定到 SFX 音軌
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)
