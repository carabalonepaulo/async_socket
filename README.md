# Asynchronous Socket
Single-threaded async socket support for Godot 4.2!

## TcpClient
- `wrap_stream(stream: StreamPeerTCP)` - Upgrade a `StreamPeerTCP` to a async `TcpClient`.
- `connect_to_host(host: String, port: int) -> Error` - Open a connection (just like the normal one).
- `disconnect_from_host()` - Yep, just like the other one.
- `poll()` - It will refresh the connection status and receive data into the internal buffer.
- `send(buffer: PackedByteArray) -> Error` - The same as `put_data` from `StreamPeer`
- `recv(length: int) -> Array` - Coroutine that yields when that amount of bytes is ready to be read. Returns [OK, PackedByteArray] or [FAILED].

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

    var result := await _server.accept() as Array
    if result[0] != OK:
        push_error('Failed to accept connection.')
        # TcpListener.accept can only fail if the server forcefully shuts down
        # while an AcceptTask is still pending. So we can safely return here.
        return

    var client := result[1] as TcpClient
    print('S> client connected')

    var buff := 'hello world'.to_ascii_buffer()
    print('S> %d bytes sent!' % buff.size())
    client.send(buff)

    await get_tree().create_timer(1).timeout
    client.disconnect_from_host()
```

### Client
```gdscript
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
```


## Important Note

As it operates on the main thread, the poll/dispatch is linked to the FPS. If your client runs at 30 FPS, it can only handle 30 tasks (or receive 30 packets).

The most effective solution is to run the server/client on a separate thread. However, this requires a secure means of interaction. One practical option is to use a ConcurrentQueue, where events (e.g., [CLIENT_CONNECTED, id]) can be enqueued from the background thread and dequeued on the main thread.
