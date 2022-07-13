extends Node2D


var _server: TcpListener
var _client: TcpClient


func _ready() -> void:
    _handle_server()
    _handle_client()


func _handle_server() -> void:
    _server = TcpListener.new(5000)
    _server.start()

    var client: TcpClient = await _server.accept()
    print("S> client connected")

    client.send_line("<0>'e' n=Server</0>")
    print("S> line sent")

    await get_tree().create_timer(1).timeout
    client.disconnect_from_host()


func _handle_client() -> void:
    _client = TcpClient.new()
    _client.timeout = 1
    _client.connect_to_host("127.0.0.1", 5000)

    await _client.connected
    print("C> connected")

    _client.send_line("<0>'e'</0>")

    var line = await _client.recv_line()
    while line != "":
        print("C> '%s'" % line.replace('\n', ''))
        line = await _client.recv_line()

    await _client.disconnected
    print("C> disconnected")

func _process(_delta: float) -> void:
    if _client != null:
        _client.poll()

    if _server != null:
        _server.poll()
