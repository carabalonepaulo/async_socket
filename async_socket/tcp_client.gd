class_name TcpClient
extends RefCounted


class ReceiveTask extends Object:
    signal ready(success, value)

    var elapsed_time: float:
        get: return (Time.get_ticks_msec() - _start_time) * 0.001
    var length: int

    var _start_time: int


    func _init(_length: int):
        length = _length
        _start_time = Time.get_ticks_msec()


    func can_handle(socket: StreamPeerTCP) -> bool:
        return socket.get_available_bytes() >= length


    func handle(socket: StreamPeerTCP) -> void:
        var data := socket.get_data(length)
        ready.emit(data[0], data[1])


signal connected(client)
signal disconnected(client)


var timeout: int = -1

var _connected: bool
var _socket: StreamPeerTCP
var _current_task: ReceiveTask


func _init(buffer_size := 4096):
    pass


func wrap_stream(stream: StreamPeerTCP) -> void:
    _socket = stream
    _connected = true


func connect_to_host(host: String, port: int) -> int:
    _socket = StreamPeerTCP.new()
    return _socket.connect_to_host(host, port)


func disconnect_from_host() -> void:
    if _socket == null:
        return

    if _current_task != null:
        if _current_task.can_handle(_socket):
            _current_task.handle(_socket)
        else:
            _current_task.ready.emit(FAILED, PackedByteArray())

        _current_task.free()
        _current_task = null

    _socket.disconnect_from_host()
    _socket = null
    _connected = false
    disconnected.emit(self)


func poll() -> void:
    if _socket == null:
        return

    _refresh_status()

    if not _connected:
        return

    if _current_task and _current_task.can_handle(_socket):
        _current_task.handle(_socket)
        _current_task.free()
        _current_task = null


func send(buff: PackedByteArray) -> int:
    return _socket.put_data(buff)


func recv(length: int) -> Array:
    _current_task = ReceiveTask.new(length)
    return await _current_task.ready as Array


func _refresh_status() -> void:
    if _socket.poll() != OK:
        disconnect_from_host()

    match _socket.get_status():
        StreamPeerTCP.STATUS_CONNECTED:
            if not _connected:
                _connected = true
                connected.emit(self)
        StreamPeerTCP.STATUS_ERROR, StreamPeerTCP.STATUS_NONE:
            disconnect_from_host()
