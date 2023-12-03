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
    print('S> client connected')

    var buff := 'hello world'.to_ascii_buffer()
    print('S> %d bytes sent!' % buff.size())
    client.send(buff)

    await get_tree().create_timer(1).timeout
    client.disconnect_from_host()


func _handle_client() -> void:
    _client = TcpClient.new()
    _client.timeout = 1
    _client.connect_to_host('127.0.0.1', 5000)

    await _client.connected
    print('C> connected')

    var expected := 'hello world'.to_ascii_buffer()
    var result := await _client.recv(expected.size()) as Array

    if result[0] == OK:
        print('C> %d bytes received: %s' % [result[1].size(), result[1].get_string_from_ascii()])
    else:
        push_error('Failed to receive message.')

    await _client.disconnected
    print('C> disconnected')


func _process(_delta: float) -> void:
    if _client != null:
        _client.poll()

    if _server != null:
        _server.poll()
