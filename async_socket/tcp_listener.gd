class_name TcpListener
extends RefCounted


class UID extends RefCounted:
    var highest_index: int:
        get: return _highest_index

    var _available_indices: Array[int]
    var _highest_index := -1


    func _init():
        _available_indices = []


    func get_next() -> int:
        if _available_indices.size() > 0:
            return _available_indices.pop_back()
        _highest_index += 1
        return _highest_index


    func release(id: int) -> void:
        _available_indices.push_back(id)


class AcceptEvent extends RefCounted:
    signal ready(value)

    var elapsed_time: float:
        get: return (Time.get_ticks_msec() - _start_time) * 0.001

    var _start_time: int


    func _init():
        _start_time = Time.get_ticks_msec()


    func can_handle(socket: TCPServer) -> bool:
        return socket.is_connection_available()


    func handle(socket: TCPServer) -> void:
        var client_socket := socket.take_connection()
        var client := TcpClient.new()
        client.wrap_stream(client_socket)
        ready.emit(client)


signal client_connected(client)
signal client_disconnected(client)

var _socket: TCPServer
var _port: int
var _current_event: AcceptEvent
var _running: bool
var _uid: UID
var _clients: Array


func _init(port: int, max_clients := 4096):
    _port = port
    _socket = TCPServer.new()
    _uid = UID.new()
    _clients = []
    _clients.resize(max_clients)


func start() -> void:
    _running = true
    _socket.listen(_port)


func stop() -> void:
    _running = true
    _socket.stop()


func poll() -> void:
    if _current_event == null:
        return

    if _current_event.can_handle(_socket):
        _current_event.handle(_socket)

    for i in (_uid.highest_index + 1):
        if _clients[i] != null:
            _clients[i].poll()


func accept() -> TcpClient:
    _current_event = AcceptEvent.new()
    var client: TcpClient =  await _current_event.ready
    client.set_meta("id", _uid.get_next())
    client.disconnected.connect(_on_client_disconnected)
    client_connected.emit(client)
    return client


func _on_client_disconnected(client: TcpClient) -> void:
    var id: int = client.get_meta("id")
    _clients[id] = null
    _uid.release(id)
    client_disconnected.emit(client)

