class_name TcpClient
extends RefCounted


class Event extends RefCounted:
    signal ready(value)

    var elapsed_time: float:
        get: return (Time.get_ticks_msec() - _start_time) * 0.001

    var _start_time: int


    func _init():
        _start_time = Time.get_ticks_msec()


    func can_handle(_buffer: CircularBuffer, _new_buffer: PackedByteArray) -> bool:
        return false


    func handle(_buffer: CircularBuffer) -> bool:
        return false


class ReadLineEvent extends Event:
    var _index: int = -1
    var _last_buffer_size := 0


    func can_handle(_buffer: CircularBuffer, new_buffer: PackedByteArray) -> bool:
        _last_buffer_size = new_buffer.size()
        _index = new_buffer.find(LF)
        return _index != -1


    func handle(buffer: CircularBuffer) -> bool:
        var data := buffer.read(buffer.available_to_read - _last_buffer_size + _index + 1)
        if data[0] != OK:
            return false

        ready.emit(data[1].get_string_from_ascii())
        return true


class ReadEvent extends Event:
    var length: int


    func _init(_length: int):
        super()
        length = _length


    func can_handle(buffer: CircularBuffer, new_buffer: PackedByteArray) -> bool:
        return buffer.available_to_read + new_buffer.size() < length


    func handle(buffer: CircularBuffer) -> bool:
        var data := buffer.read(length)
        if data[0] != OK:
            return false

        ready.emit(data[1])
        return true


signal connected(client: TcpClient)
signal disconnected(client: TcpClient)

const LF := 10

var is_connected: bool:
    get: return _connected
var read_timeout: int = 0

var _connected: bool
var _socket: StreamPeerTCP
var _buffer: CircularBuffer
var _current_event: Event


func _init(max_packet_size := 4096):
    _buffer = CircularBuffer.new(max_packet_size)
    _connected = false


func connect_to_host(host: String, port: int) -> void:
    if _socket != null:
        push_error("Socket is already connected.")
        return
    _socket = StreamPeerTCP.new()
    _socket.connect_to_host(host, port)


func disconnect_from_host() -> void:
    if _socket != null:
        _socket.disconnect_from_host()
        _socket = null


func wrap_stream(tcp_stream: StreamPeerTCP) -> void:
    _socket = tcp_stream
    _connected = true


func poll() -> void:
    if _socket == null:
        return

    if not _connected:
        _refresh_status()
        return

    if _socket.poll() != OK or _socket.get_status() != StreamPeerTCP.STATUS_CONNECTED:
        _dispose_client()
        return

    var available := _socket.get_available_bytes()
    var data := _socket.get_data(available)
    if data[0] != OK:
        _dispose_client()
        return

    if data[1].size() == 0:
        return

    if _buffer.write(data[1]) != OK:
        push_error("Too much data to write, buffer is too small.")
        _dispose_client()
        return

    if _current_event == null:
        return

    if read_timeout > 0 and _current_event.elapsed_time > read_timeout:
        _dispose_client()
        return

    if _current_event.can_handle(_buffer, data[1]):
        if _current_event.handle(_buffer):
            _current_event = null


func send(buff: PackedByteArray) -> void:
    if not _connected:
        push_error("Client is not connected.")
        return
    _socket.put_data(buff)


func send_string(text: String) -> void:
    send(text.to_ascii_buffer())


func send_line(line: String) -> void:
    send_string(line + LF)


func read_line() -> String:
    _current_event = ReadLineEvent.new()
    return await _current_event.ready


func read(length: int) -> PackedByteArray:
    _current_event = ReadEvent.new(length)
    return await _current_event.ready


func _refresh_status() -> void:
    if _socket.poll() != OK:
        _dispose_client()
        return

    if _socket.get_status() == StreamPeerTCP.STATUS_CONNECTED:
        _connected = true
        connected.emit(self)


func _dispose_client() -> void:
    if _socket == null:
        return

    _release_pending_event()
    _socket.disconnect_from_host()
    _socket = null
    _connected = false
    disconnected.emit(self)


func _release_pending_event() -> void:
    if _current_event == null:
        return

    var data := _buffer.read(_buffer.available_to_read)
    if _current_event is ReadEvent:
        _current_event.ready.emit(data[1] if data[0] == OK else PackedByteArray())
    else:
        _current_event.ready.emit(data[1].get_string_from_ascii() if data[0] == OK else "")
