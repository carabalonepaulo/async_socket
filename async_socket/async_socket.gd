class_name AsyncSocket
extends Object
## The AsyncSocket namespace provides asynchronous, single-threaded TCP networking functionality.


class TcpClient extends RefCounted:
    signal connected
    signal disconnected


    var _stream: StreamPeerTCP
    var _connected: bool
    var _expecting := -1
    var _internal: Internal


    ## Create a TcpClient from a StreamPeerTCP.
    static func from_stream(stream: StreamPeerTCP) -> TcpClient:
        stream.set_no_delay(true)

        var client := TcpClient.new()
        client._stream = stream
        client._connected = true
        return client


    func _init():
        _stream = StreamPeerTCP.new()
        _internal = Internal.new()


    ## Connects to a host at the specified address and port.
    ## [codeblock]
    ## var client := AsyncSocket.TcpClient.new()
    ## if await client.connect_to_host('127.0.0.1', 5000) != OK:
    ##     print('failed to connect')
    ## [/codeblock]
    func connect_to_host(host: String, port: int) -> Error:
        var result := _stream.connect_to_host(host, port)
        if result == OK:
            await connected
            _stream.set_no_delay(true)
        return result


    ## Disconnects from the host.
    ## [codeblock]await client.disconnect_from_host()[/codeblock]
    func disconnect_from_host() -> void:
        _stream.disconnect_from_host()
        await disconnected


    ## Sends a buffer of data to the connected host.
    func send(buf: PackedByteArray) -> Error:
        var result := _stream.put_partial_data(buf)
        if result[0] != OK:
            disconnect_from_host()
        return result[0]


    ## Receives data from the connected host.
    ## [codeblock]await client.recv(10)[/codeblock]
    func recv(size: int) -> Array:
        # Calling client.recv multiple times without await.
        if _expecting != -1:
            return [FAILED]

        _expecting = size
        return [OK, await _internal.done]


    ## Polls the TCP stream for updates on connection status and received data.
    func poll() -> void:
        _stream.poll()
        var status := _stream.get_status()

        match status:
            StreamPeerTCP.Status.STATUS_CONNECTED:
                if not _connected:
                    _connected = true
                    connected.emit()
                if _expecting != -1 and _stream.get_available_bytes() >= _expecting:
                    var result := _stream.get_partial_data(_expecting)
                    if result[0] != OK:
                        disconnect_from_host()
                        return

                    _expecting = -1
                    _internal.done.emit(result[1])
            StreamPeerTCP.Status.STATUS_NONE, StreamPeerTCP.Status.STATUS_ERROR:
                if _connected:
                    _connected = false
                    disconnected.emit()


class TcpListener extends RefCounted:
    signal client_connected(client: TcpClient)
    signal client_disconnected(client: TcpClient)


    var _listener: TCPServer
    var _host: String
    var _port: int
    var _clients: Array


    func _init(host: String, port: int, cap: int) -> void:
        _host = host
        _port = port
        _listener = TCPServer.new()
        _clients = []
        _clients.resize(cap)


    ## Starts listening for incoming TCP connections on the specified host and port.
    func start() -> Error:
        return _listener.listen(_port, _host)


    ## Stops listening for incoming TCP connections.
    func stop() -> void:
        _listener.stop()


    func poll() -> void:
        if _listener.is_connection_available():
            _accept_conn()

        for i in _clients.size():
            if _clients[i] != null:
                _clients[i].poll()


    func _accept_conn() -> void:
        var stream := _listener.take_connection()
        var idx := _clients.find(null)
        if idx == -1:
            stream.disconnect_from_host()
            return

        var client := TcpClient.from_stream(stream)
        client.disconnected.connect(func() -> void:
            _clients[idx] = null
            client_disconnected.emit(client))

        _clients[idx] = client
        client_connected.emit(client)


class Internal extends Object:
    signal done(something: Variant)
