class_name TcpListener
extends RefCounted


class AcceptTask extends Object:
    signal ready(success, value)

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
        ready.emit(OK, client)


signal client_connected(client)
signal client_disconnected(client)

var _socket: TCPServer
var _port: int
var _current_task: AcceptTask
var _running: bool
var _clients: Array


func _init(port: int):
    _port = port
    _socket = TCPServer.new()
    _clients = []


func start() -> void:
    _running = true
    _socket.listen(_port)


func stop() -> void:
    _running = true
    _socket.stop()

    if _current_task != null:
        _current_task.ready.emit(FAILED)


func poll() -> void:
    if _current_task != null and _current_task.can_handle(_socket):
        _current_task.handle(_socket)
        _current_task.free()
        _current_task = null

    for client in _clients:
        client.poll()


func accept() -> Array:
    _current_task = AcceptTask.new()

    var result :=  await _current_task.ready as Array
    if result[0] != OK:
        return [FAILED]

    var client := result[1] as TcpClient
    _clients.push_back(client)

    client.disconnected.connect(_on_client_disconnected)
    client_connected.emit(client)

    return [OK, client]


func _on_client_disconnected(client: TcpClient) -> void:
    var idx := _clients.find(client)
    var last_idx := _clients.size() - 1

    var temp = _clients[last_idx]
    _clients[last_idx] = _clients[idx]
    _clients[idx] = temp

    client_disconnected.emit(client)


func _poll_client(client: TcpClient) -> void:
    client.poll()
