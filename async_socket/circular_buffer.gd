class_name CircularBuffer
extends RefCounted


var buffer: PackedByteArray:
    get: return _buffer
var available_to_write: int:
    get: return _available_to_write
var available_to_read: int:
    get: return _available_to_read
var read_cursor: int:
    get: return _read_cursor
var write_cursor: int:
    get: return _write_cursor

var _buffer: PackedByteArray
var _write_cursor: int
var _read_cursor: int
var _available_to_write: int
var _available_to_read: int


func _init(capacity := 4096):
    _buffer = PackedByteArray()
    _buffer.resize(capacity)
    _buffer.fill(0)
    _available_to_write = capacity


func can_write(length: int) -> bool:
    return _available_to_write >= length


func can_read(length: int) -> bool:
    return _available_to_read >= length


func write(buff: PackedByteArray) -> int:
    if not can_write(buff.size()):
        return FAILED

    if _write_cursor + buff.size() >= _buffer.size():
        var first_chunk_len := _buffer.size() - _write_cursor
        var second_chunk_len := buff.size() - first_chunk_len

        _copy(buff, 0, _buffer, _write_cursor, first_chunk_len)
        _advance_writer(first_chunk_len)
        _write_cursor = 0

        _copy(buff, first_chunk_len, _buffer, _write_cursor, second_chunk_len)
        _advance_writer(second_chunk_len)

        return OK

    _copy(buff, 0, _buffer, _write_cursor, buff.size())
    _advance_writer(buff.size())
    return OK


func read(length: int) -> Array:
    if not can_read(length):
        return [FAILED]
    return [OK, _raw_read(length)]


func clear() -> void:
    _buffer.fill(0)
    _write_cursor = 0
    _read_cursor = 0
    _available_to_write = _buffer.size()
    _available_to_read = 0


func find_virtual_index(value: int) -> int:
    var virtual_index := -1
    var found := false

    for i in _available_to_read:
        virtual_index += 1
        if peek(virtual_index) == value:
            found = true
            break

    return virtual_index if found else -1


func peek(virtual_index: int = 0) -> int:
    virtual_index += _read_cursor
    if virtual_index >= _buffer.size():
        return _buffer[virtual_index - _buffer.size()]
    return _buffer[virtual_index]


func _raw_read(length: int) -> PackedByteArray:
    var result := PackedByteArray()
    result.resize(length)

    if _read_cursor + length >= _buffer.size():
        var first_chunk_len := _buffer.size() - _read_cursor
        var second_chunk_len := length - first_chunk_len

        _copy(_buffer, _read_cursor, result, 0, first_chunk_len)
        _advance_reader(first_chunk_len)
        _read_cursor = 0

        _copy(_buffer, _read_cursor, result, first_chunk_len, second_chunk_len)
        _advance_reader(second_chunk_len)
    else:
        _copy(_buffer, _read_cursor, result, 0, length)
        _advance_reader(length)

    return result


func _copy(from: PackedByteArray, from_pos: int, to: PackedByteArray, to_pos: int, length: int) -> void:
    for i in length:
        to[to_pos + i] = from[from_pos + i]


func _advance_writer(length: int) -> void:
    _write_cursor += length
    _available_to_read += length
    _available_to_write -= length


func _advance_reader(length: int) -> void:
    _read_cursor += length
    _available_to_read -= length
    _available_to_write += length
