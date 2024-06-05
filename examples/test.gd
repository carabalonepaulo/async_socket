extends Node2D


var _server: AsyncSocket.TcpListener
var _client: AsyncSocket.TcpClient


func _ready() -> void:
	_handle_server()
	_handle_client()


func _handle_server() -> void:
	_server = AsyncSocket.TcpListener.new('0.0.0.0', 5000)
	_server.client_connected.connect(func(client: AsyncSocket.TcpClient) -> void:
		print('S> client connected')
		var expected := 'hello world'.to_ascii_buffer()
		print('S> expecting message')
		var result := await client.recv(expected.size()) as Array
		if result[0] != OK:
			print('S> failed to receive data from client')
			return
		print('S> message received: %s' % (result[1] as PackedByteArray).get_string_from_ascii())
		_client.send(result[1])
		print('S> server response sent')
		print('S> waiting 1s before disconnecting client')
		await get_tree().create_timer(1).timeout
		_client.disconnect_from_host())
	_server.client_disconnected.connect(func() -> void:
		print('S> client disconnected')
		_server.stop())
	_server.start()


func _handle_client() -> void:
	_client = AsyncSocket.TcpClient.new()
	_client.connected.connect(func() -> void:
		print('C> connected')
		var message := 'hello world'.to_ascii_buffer()
		print('C> waiting 1s before sending message')
		await get_tree().create_timer(1).timeout
		if _client.send(message) != OK:
			print('C> failed to send hello')
			return
		print('C> message sent')
		print('C> expecting response')
		var result := await _client.recv(message.size()) as Array
		if result[0] != OK:
			print('C> failed to receive hello response from server')
			return
		print('C> got response: %s' % (result[1] as PackedByteArray).get_string_from_ascii()))
	_client.disconnected.connect(func() -> void:
		print('C> disconnected'))
	await _client.connect_to_host('127.0.0.1', 5000)


func _process(_delta: float) -> void:
	if _client != null:
		_client.poll()

	if _server != null:
		_server.poll()
