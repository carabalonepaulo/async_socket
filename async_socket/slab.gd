extends RefCounted


var highest_index: int:
    get: return _highest_index

var _items: Array
var _highest_index: int
var _capacity: int
var _available_indices: Array


func _init(capacity := 1024):
    _capacity = capacity
    clear()


func get_item(index: int) -> Variant:
    return _items[index]


func insert(value: Variant) -> int:
    var index := _get_next_index()
    _items[index] = value
    return index


func remove(index: int) -> Variant:
    var value = _items[index]
    _available_indices.push_back(index)
    return value


func clear() -> void:
    _items = []
    _items.resize(_capacity)
    _highest_index = -1
    _available_indices = []


func _get_next_index() -> int:
    if _available_indices.size() > 0:
        return _available_indices.pop_back()
    _highest_index += 1
    return _highest_index
