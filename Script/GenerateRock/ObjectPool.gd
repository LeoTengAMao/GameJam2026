# ObjectPool.gd
class_name ObjectPool

var _pool: Array = []
var _factory_method: Callable
var _on_get: Callable
var _on_return: Callable
var _total: int = 0;
var _limit: int

# 唯讀屬性：目前池子裡閒置的物件數量
var count_inactive: int:
	get: return _pool.size()

# 初始化物件池 (等同於 C# 的建構子)
func _init(factory_method: Callable, on_get: Callable = Callable(), on_return: Callable = Callable(), initial_capacity: int = 0, limit: int = -1) -> void:
	if factory_method.is_null():
		push_error("factory_method 不能為空！")
		return
		
	_factory_method = factory_method
	_on_get = on_get
	_on_return = on_return
	_limit = limit

	# 預熱 (Pre-warm)
	for i in range(initial_capacity):
		_pool.append(_factory_method.call())

# 借出一個物件
func get_item() -> Variant:
	var item: Variant = null
	
	# 1. 循環嘗試直到取出一個有效的物件，或者池空了
	while _pool.size() > 0:
		var candidate = _pool.pop_back()
		if is_instance_valid(candidate):
			item = candidate
			break
		else:
			# 遇到無效物件，直接忽略並繼續迴圈找下一個
			_total -= 1 # 這邊要減回去，因為有一個物件無效了
			continue
	
	# 2. 如果池裡沒有有效的物件，則從工廠生成
	if item == null:
		if _limit > 0 and _total >= _limit: 
			return null
		item = _factory_method.call()
		_total += 1
		print("total: ", _total)
		
	# 3. 只有在確定 item 有效時才執行回呼
	if item != null and not _on_get.is_null():
		_on_get.call(item)
		
	return item

# 歸還一個物件
func return_item(item: Variant) -> void:
	if not _on_return.is_null():
		_on_return.call(item)
	_pool.append(item)
