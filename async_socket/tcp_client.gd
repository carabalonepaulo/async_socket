class_name TcpClient
extends RefCounted


class Task extends RefCounted:
    signal ready(value)

    var elapsed_time: float:
        get: return (Time.get_ticks_msec() - _start_time) * 0.001

    var _start_time: int


    func _init():
        _start_time = Time.get_ticks_msec()


    func can_handle(_buffer: CircularBuffer) -> bool:
        return false


    func handle(_buffer: CircularBuffer) -> bool:
        return false


class ReceiveLineTask extends Task:
    var _index: int = -1


    func can_handle(buffer: CircularBuffer) -> bool:
        _index = buffer.find_virtual_index(LF)
        return _index != -1


    func handle(buffer: CircularBuffer) -> bool:
        var data := buffer.read(_index + 1)
        if data[0] != OK:
            return false

        ready.emit(data[1].get_string_from_ascii())
        return true


class ReceiveTask extends Task:
    var length: int


    func _init(_length: int):
        super()
        length = _length


    func can_handle(buffer: CircularBuffer) -> bool:
        return buffer.available_to_read >= length


    func handle(buffer: CircularBuffer) -> bool:
        var data := buffer.read(length)
        if data[0] != OK:
            return false

        ready.emit(data[1])
        return true


signal connected(client)
signal disconnected(client)

const LF := 10

var timeout: int = -1

var _connected: bool
var _socket: StreamPeerTCP
var _buffer: CircularBuffer
var _tasks: Queue


func _init(buffer_size := 4096):
    _buffer = CircularBuffer.new(buffer_size)
    _tasks = Queue.new()


func wrap_stream(stream: StreamPeerTCP) -> void:
    _socket = stream
    _connected = true


func connect_to_host(host: String, port: int) -> int:
    _socket = StreamPeerTCP.new()
    return _socket.connect_to_host(host, port)


func disconnect_from_host() -> void:
    if _socket == null:
        return

    _release_pending_tasks()
    _socket.disconnect_from_host()
    _socket = null
    _connected = false
    _buffer.clear()
    disconnected.emit(self)


func poll() -> void:
    if _socket == null:
        return

    _refresh_status()

    if not _connected:
        return

    _try_receive()
    _try_handle_task()


func send(buff: PackedByteArray) -> int:
    return _socket.put_data(buff)


func send_line(text: String) -> int:
    return send((text + "\n").to_ascii_buffer())


func recv(length: int) -> PackedByteArray:
    var task := ReceiveTask.new(length)
    _tasks.enqueue(task)
    return await task.ready


func recv_line() -> String:
    var task := ReceiveLineTask.new()
    _tasks.enqueue(task)
    return await task.ready


func _refresh_status() -> void:
    if _socket.poll() != OK:
        disconnect_from_host()

    match _socket.get_status():
        StreamPeerTCP.STATUS_CONNECTED:
            if not _connected:
                _connected = true
                connected.emit(self)
        StreamPeerTCP.STATUS_ERROR, StreamPeerTCP.STATUS_NONE:
            disconnect_from_host()


func _try_receive() -> void:
    var available := _socket.get_available_bytes()
    if available <= 0:
        return

    var data := _socket.get_data(available)
    if data[0] != OK:
        disconnect_from_host()
        return

    if _buffer.write(data[1]) != OK:
        push_error("Buffer is full, can't write any more data.")
        disconnect_from_host()


func _try_handle_task() -> void:
    if _tasks.size == 0:
        return

    var task: Task = _tasks.peek_first()
#    if timeout > 0 and task.elapsed_time > timeout:
#        disconnect_from_host()
#        return

    if task.can_handle(_buffer):
        if task.handle(_buffer):
            _tasks.dequeue()


func _release_pending_tasks() -> void:
    if _tasks.size == 0:
        return

    var task: Task = _tasks.dequeue()
    while task != null:
        task.ready.emit("" if task is ReceiveLineTask else PackedByteArray())
        task = _tasks.dequeue()
