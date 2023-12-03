# Asynchronous Socket
Single thread async socket support for Godot 4.

## TcpClient
- `wrap_stream(stream: StreamPeerTCP)` - Upgrade a `StreamPeerTCP` to a async `TcpClient`.
- `connect_to_host(host: String, port: int) -> Error` - Open a connection (just like the normal one).
- `disconnect_from_host()` - Yep, just like the other one.
- `poll()` - It will refresh the connection status and receive data into the internal buffer.
- `send(buffer: PackedByteArray) -> Error` - The same as `put_data` from `StreamPeer`
- `recv(length: int) -> PackedByteArray` - Coroutine that yields when that amount of bytes is ready to be read.

## TcpListener
- `start()` - Start listening.
- `stop()` - Stop listening.
- `poll()` - Update all connected clients.
- `accept() -> TcpClient` - Couroutine that yields when a new connection is ready to be accepted.

## Examples:
### Server
```gdscript
func _handle_server() -> void:
    _server = TcpListener.new(5000)
    _server.start()

    var client: TcpClient = await _server.accept()
    print("S> client connected")

    var buff := "hello world".to_ascii_buffer()
    print("S> %d bytes sent!" % buff.size())
    client.send(buff)

    await get_tree().create_timer(1).timeout
    client.disconnect_from_host()
```

### Client
```gdscript
func _handle_client() -> void:
    _client = TcpClient.new()
    _client.timeout = 1
    _client.connect_to_host("127.0.0.1", 5000)

    await _client.connected
    print("C> connected")

    var expected := "hello world".to_ascii_buffer()
    var buff := await _client.recv(expected.size())

    print("C> %d bytes received: %s" % [buff.size(), buff.get_string_from_ascii()])

    await _client.disconnected
    print("C> disconnected")
```
