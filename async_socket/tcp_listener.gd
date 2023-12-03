class_name TcpListener
extends RefCounted


const Slab := preload('res://async_socket/slab.gd')


class AcceptEvent extends Object:
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
var _clients: Slab


func _init(port: int, max_clients := 4096):
    _port = port
    _socket = TCPServer.new()
    _clients = Slab.new(max_clients)


func start() -> void:
    _running = true
    _socket.listen(_port)


func stop() -> void:
    _running = true
    _socket.stop()


func poll() -> void:
    if _current_event != null and _current_event.can_handle(_socket):
        _current_event.handle(_socket)
        _current_event.free()
        _current_event = null

    var client: TcpClient
    for i in (_clients.highest_index + 1):
        client = _clients.get_item(i)
        if client != null:
            client.poll()


func accept() -> TcpClient:
    _current_event = AcceptEvent.new()
    var client :=  await _current_event.ready as TcpClient

    var index := _clients.insert(client)
    client.set_meta('id', index)

    client.disconnected.connect(_on_client_disconnected)
    client_connected.emit(client)

    return client


func _on_client_disconnected(client: TcpClient) -> void:
    var id := client.get_meta('id') as int
    _clients.remove(id)
    client_disconnected.emit(client)
