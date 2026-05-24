extends CanvasLayer
class_name PauseMenu

@export var title_scene_path: String = "res://Tscn/menu.tscn"

@onready var music_slider: HSlider = $Panel/VBox/MusicRow/MusicSlider
@onready var sfx_slider: HSlider = $Panel/VBox/SFXRow/SFXSlider


func _ready() -> void:
	hide()
	music_slider.min_value = -60.0
	music_slider.max_value = 0.0
	EventManager.music_db = -10.0
	music_slider.value = EventManager.music_db
	AudioServer.set_bus_volume_db(0, EventManager.music_db)

	var sfx_idx = AudioServer.get_bus_index("SFX")
	sfx_slider.min_value = -10.0
	sfx_slider.max_value = 10.0
	sfx_slider.value = EventManager.sfx_db
	if sfx_idx != -1:
		AudioServer.set_bus_volume_db(sfx_idx, EventManager.sfx_db)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		toggle_pause()

func toggle_pause() -> void:
	if get_tree().paused:
		_resume()
	else:
		_pause()

func _pause() -> void:
	get_tree().paused = true
	show()

func _resume() -> void:
	get_tree().paused = false
	hide()

func _on_resume_pressed() -> void:
	_resume()

func _on_restart_pressed() -> void:
	get_tree().paused = false
	_stop_all_audio()
	get_tree().reload_current_scene()

func _on_title_pressed() -> void:
	get_tree().paused = false
	_stop_all_audio()
	get_tree().change_scene_to_file(title_scene_path)

func _on_music_slider_changed(value: float) -> void:
	EventManager.music_db = value
	AudioServer.set_bus_volume_db(0, value)

func _on_sfx_slider_changed(value: float) -> void:
	EventManager.sfx_db = value
	var sfx_idx = AudioServer.get_bus_index("SFX")
	if sfx_idx == -1:
		push_warning("找不到 SFX bus，請確認 Audio 分頁有建立 SFX bus")
		return
	AudioServer.set_bus_volume_db(sfx_idx, value)

func _stop_all_audio() -> void:
	SoundManager.stop()
	SoundManager.current_phase = -1
	for player in get_tree().get_nodes_in_group("sfx_players"):
		player.stop()
		player.queue_free()
