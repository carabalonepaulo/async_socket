# Asynchronous Socket
Single-threaded async socket support for Godot 4.2!

## TcpClient
- `static from_stream(stream: StreamPeerTCP) -> AsyncSocket.TcpClient` - Wrap a `StreamPeerTCP`.
- `connect_to_host(host: String, port: int) -> Error` - `async` Open a connection and return an error code.
- `disconnect_from_host()` - `async` Disconnect from the host asynchronously; you can wait for it.
- `poll()` - Refresh connection status and attempt to receive data if requested and available.
- `send(buffer: PackedByteArray) -> Error` - Attempt to send `buffer`, in case of failure, the connection is terminated and an error code is returned.
- `recv(length: int) -> Array[OK|FAILED, PackedByteArray?]` - `async` Coroutine that yields when that amount of bytes is ready to be read. Returns [OK, PackedByteArray] or [FAILED]. In casse of failure the connection is terminated.

## TcpListener
- `start()` - Start listening.
- `stop()` - Stop listening.
- `poll()` - Accept pending connections and poll all connected clients.

## Examples:
### Server
```gdscript
func _handle_server() -> void:
    _server = AsyncSocket.TcpListener.new('0.0.0.0', 5000, 512)
    _server.client_connected.connect(func(client: AsyncSocket.TcpClient) -> void:
        print('S> client connected')
        var expected := 'hello world'.to_ascii_buffer()
        print('S> expecting message')
        var result := await client.recv(expected.size()) as Array
        if result[0] != OK:
            print('S> failed to receive data from client')
            return
        print('S> message received: %s' % (result[1] as PackedByteArray).get_string_from_ascii())
        client.send(result[1])
        print('S> server response sent')
        print('S> waiting 1s before disconnecting client')
        await get_tree().create_timer(1).timeout
        client.disconnect_from_host())
    _server.client_disconnected.connect(func() -> void:
        print('S> client disconnected')
        _server.stop())
    _server.start()
```

### Client
```gdscript
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
```


## Important Note

As it operates on the main thread, the poll/dispatch is tied to the FPS. If your client runs at 30 FPS, it can only handle 30 tasks (or receive 30 packets).

The most effective solution is to run the server/client on a separate thread. However, this requires a secure means of interaction. One practical option is to use a ConcurrentQueue, where events (e.g., [CLIENT_CONNECTED, id]) can be enqueued from the background thread and dequeued on the main thread.
