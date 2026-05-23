extends Camera2D
class_name MapCamera

# === 🎯 鏡頭移動參數 ===
@export var speed: float = 1200.0          # 移動速度
@export var margin_trigger: float = 20.0  # 滑鼠邊緣觸發距離

# === 🧱 世界邊界參數 ===
@export var min_grid: Vector2i = Vector2i(-20, -20)
@export var max_grid: Vector2i = Vector2i(40, 20)
const TILE_SIZE: float = 128.0

# === 🔍 縮放 (Zoom) 參數 ===
@export var zoom_speed: float = 10.0      # 縮放變化的流暢速度 (數值越高越快)
@export var min_zoom: float = 0.2         # 🔍 縮放上限：拉到最遠 (畫面變小，看大局，最小設為 0.5 倍)
@export var max_zoom: float = 1.0         # 🔍 縮放下限：拉到最近 (畫面變大，看細節，最大設為 2.0 倍)

var target_zoom: float = 0.3              # 目標縮放值 (滾輪滾動時改變它)

# 儲存計算完的像素極限值，用來防止座標溢出
var min_pos: Vector2
var max_pos: Vector2

func _ready() -> void:
	# 1. 設置 Godot 畫面渲染的 limit 鎖
	limit_left = int(min_grid.x * TILE_SIZE)
	limit_top = int(min_grid.y * TILE_SIZE)
	limit_right = int(max_grid.x * TILE_SIZE)
	limit_bottom = int(max_grid.y * TILE_SIZE)
	
	# 2. 🌟 紀錄物理坐標的邊界極限（扣除視窗大小的一半，防止視角邊緣漂移）
	# 為了精準計算，我們把邊界轉成 Vector2 方便後面 clamp
	min_pos = Vector2(limit_left, limit_top)
	max_pos = Vector2(limit_right, limit_bottom)
# 🌟 透過 _unhandled_input 捕捉滑鼠滾輪事件
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		# 向上滾動滾輪 -> 放大 (Zoom In)
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			target_zoom += 0.03
			
		# 向下滾動滾輪 -> 縮小 (Zoom Out)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			target_zoom -= 0.03
			
		# 鎖死上下限值
		target_zoom = clampf(target_zoom, min_zoom, max_zoom)

func _physics_process(delta: float) -> void:
	var move_vec = Vector2.ZERO
	var current_zoom = lerpf(zoom.x, target_zoom, zoom_speed * delta)
	zoom = Vector2(current_zoom, current_zoom)
	
	# 🟢 1. 鍵盤控制 (WASD)
	if Input.is_key_pressed(KEY_D):
		move_vec.x += 1
	if Input.is_key_pressed(KEY_A):
		move_vec.x -= 1
	if Input.is_key_pressed(KEY_S):
		move_vec.y += 1
	if Input.is_key_pressed(KEY_W):
		move_vec.y -= 1
		
	# 🔵 2. 滑鼠邊緣偵測
	var mouse_pos = get_viewport().get_mouse_position()
	var screen_size = get_viewport().get_visible_rect().size
	
	if mouse_pos.x >= screen_size.x - margin_trigger:
		move_vec.x += 1
	elif mouse_pos.x <= margin_trigger:
		move_vec.x -= 1
		
	if mouse_pos.y >= screen_size.y - margin_trigger:
		move_vec.y += 1
	elif mouse_pos.y <= margin_trigger:
		move_vec.y -= 1
		
	# 🟡 3. 執行移動
	if move_vec != Vector2.ZERO:
		global_position += move_vec.normalized() * speed * delta
		
		# 🌟 終極大絕招：強迫下一幀的物理坐標「同步」為被邊界卡住後的實際位置！
		# 這樣不管怎麼撞牆，物理坐標跟畫面永遠貼齊，反方向絕對秒回頭
		force_update_scroll() # 強迫攝影機這幀立刻對齊邊界
		global_position = get_screen_center_position()
