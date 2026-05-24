extends Node # 🌟 建議改為繼承 Node，因為你不需要這個管理器本身去「播放音樂」

# 音效庫
var sfx_library = {
	"laser": preload("res://Assests/Sound/ahmed_abdulaal-laser-312360.mp3"),
	"laugh": preload("res://Assests/Sound/laugh.mp3"),
	"place": preload("res://Assests/Sound/place.mp3"),
	"throwrock": preload("res://Assests/Sound/throwrock.mp3"),
	"golem": preload("res://Assests/Sound/golem.mp3"),
	"Blaser": preload("res://Assests/Sound/BigLaser.mp3"),
	"Bigheal": preload("res://Assests/Sound/heal.mp3"),
	"DU": preload("res://Assests/Sound/Defenseup.mp3"),
	"Holy": preload("res://Assests/Sound/Holy.mp3"),
}

# 🌟 改名為 play_sfx，避免與 AudioStreamPlayer 的內建 play() 衝突
func play_sfx(sfx_name: String):
	if not sfx_library.has(sfx_name): 
		print("找不到音效: ", sfx_name)
		return
	
	# 動態產生獨立播放器，播完即丟
	var player = AudioStreamPlayer.new()
	player.stream = sfx_library[sfx_name]
	player.bus = "SFX" 
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)
