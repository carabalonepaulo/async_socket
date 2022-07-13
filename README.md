# Asynchronous Socket
Single thread async socket support for Godot 4.

## TcpClient
- `wrap_stream(stream: StreamPeerTCP)` - Upgrade a `StreamPeerTCP` to a async `TcpClient`.
- `connect_to_host(host: String, port: int) -> Error` - Open a connection (just like the normal one).
- `disconnect_from_host()` - Yep, just like the other one.
- `poll()` - It will refresh the connection status and receive data into the internal buffer.
- `send(buffer: PackedByteArray) -> Error` - The same as `put_data` from `StreamPeer`
- `send_line(text: String) -> Error` - It will automatically append a LF at the end of the `text`.
- `recv(length: int) -> PackedByteArray` - Coroutine that yields when that amount of bytes is ready to be read.
- `recv_line() -> String` - Coroutine that yields when a new line is available to be read.

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

    client.send_line("<0>'e' n=Server</0>")
    print("S> line sent")

    await get_tree().create_timer(1).timeout
    client.disconnect_from_host()
```

### Client
```gdscript
func _handle_client() -> void:
    _client = TcpClient.new()
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
```