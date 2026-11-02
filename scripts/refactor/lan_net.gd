extends Node
## LanNet — multijugador LAN (documento §8): UDP puerto
## 27016, descubrimiento por broadcast, 1-7 jugadores,
## topología en estrella (el anfitrión retransmite).
## ReliableLink mínimo propio: paquetes fiables con
## secuencia, ack y reenvío cada 0.1 s (máx. 10 intentos);
## el estado de posición va sin fiabilidad (10/s, el
## siguiente corrige al anterior). Los paquetes son JSON
## pequeños; la foto del mundo se envía en trozos de 50
## bloques al entrar.
##
## Transporte separable: la lógica (descubrimiento,
## join, fiabilidad, retransmisión) no toca sockets; el
## backend UDP real es fino (llamadas estándar de
## PacketPeerUDP) y el backend en memoria permite probar
## el protocolo en headless, donde esta VM cuelga
## cualquier listen() UDP. Verificación en 2
## dispositivos reales pendiente del usuario.
##
## Limitación honesta v1: al entrar solo se sincronizan
## los bloques modificados del anfitrión.

class_name LanNet

signal host_found(ip: String, host_name: String)
signal join_accepted(player_id: int, seed: int, biome: String)
signal join_rejected(reason: String)
signal peer_joined(player_id: int, peer_name: String)
signal peer_left(player_id: int)
signal peer_state(player_id: int, state: Dictionary)
signal block_received(cell: Vector3i, block_id: int)
signal snapshot_received(blocks: Array, done: bool)

const PORT := 27016
const MAGIC := "BLOQUES3"
const MAX_PLAYERS := 7
const RESEND_INTERVAL := 0.1
const MAX_RETRIES := 10


## Backend UDP real (llamadas estándar de Godot).
class UdpTransport extends RefCounted:
	var _udp := PacketPeerUDP.new()

	func listen(port: int) -> void:
		_udp.listen(port)

	func close() -> void:
		_udp.close()

	func send(to_key: String, bytes: PackedByteArray) -> void:
		var parts := to_key.split(":")
		if parts.size() != 2:
			return
		_udp.set_dest_address(parts[0], int(parts[1]))
		_udp.put_packet(bytes)

	func broadcast(bytes: PackedByteArray) -> void:
		_udp.set_broadcast_enabled(true)
		for dest in ["255.255.255.255", "127.0.0.1"]:
			_udp.set_dest_address(dest, PORT)
			_udp.put_packet(bytes)

	func poll() -> Array[Dictionary]:
		var out: Array[Dictionary] = []
		while _udp.get_available_packet_count() > 0:
			var data := _udp.get_packet()
			out.append({"from": _udp.get_packet_ip() + ":" + str(_udp.get_packet_port()), "bytes": data})
		return out


## Backend en memoria para tests: misma interfaz, sin
## sockets. Los transportes comparten un registro
## estático por dirección "127.0.0.1:puerto".
class MemoryTransport extends RefCounted:
	static var _registry := {}
	static var _next_ephemeral := 60000

	var _addr := ""
	var _inbox: Array[Dictionary] = []

	func listen(port: int) -> void:
		if port == 0:
			port = _next_ephemeral
			_next_ephemeral += 1
		_addr = "127.0.0.1:" + str(port)
		_registry[_addr] = self

	func close() -> void:
		_registry.erase(_addr)
		_addr = ""

	func send(to_key: String, bytes: PackedByteArray) -> void:
		var target: MemoryTransport = _registry.get(to_key, null)
		if target != null:
			target._inbox.append({"from": _addr, "bytes": bytes})

	func broadcast(bytes: PackedByteArray) -> void:
		for key in _registry.keys():
			if str(key).ends_with(":" + str(PORT)):
				send(str(key), bytes)

	func poll() -> Array[Dictionary]:
		var out := _inbox
		_inbox = []
		return out


var mode := "" # "", "host", "client"
var own_id := 0
var host_name := ""
var world_seed := 0
var world_biome := ""
var found_hosts := {} # ip -> nombre

var _transport: RefCounted = null
var _peers := {} # "ip:port" -> {id, name, last_seen}
var _next_id := 2
var _host_key := ""
var _seq := 0
var _pending := {} # seq -> {key, packet, last, retries}
var _seen_seq := {} # key -> último seq fiable visto
var _discover_timer := 0.0
var _state_timer := 0.0
var _send_state: Callable = Callable()


func set_transport(transport: RefCounted) -> void:
	_transport = transport


func _ensure_transport() -> void:
	if _transport == null:
		_transport = UdpTransport.new()


func is_active() -> bool:
	return mode != ""


## En partida de verdad (anfitrión, o cliente ya aceptado).
## Un cliente buscando aún no está en partida.
func is_in_game() -> bool:
	if mode == "host":
		return true
	if mode == "client":
		return own_id != 0
	return false


func _key(ip: String, port: int) -> String:
	return ip + ":" + str(port)


func _send(key: String, packet: Dictionary) -> void:
	_transport.send(key, JSON.stringify(packet).to_utf8_buffer())


func _send_reliable(key: String, type: String, data: Dictionary) -> void:
	_seq += 1
	var packet := {"t": type, "s": _seq, "d": data}
	_pending[_seq] = {"key": key, "packet": packet, "last": 0.0, "retries": 0}
	_send(key, packet)


func _send_ack(key: String, seq: int) -> void:
	_send(key, {"t": "ack", "a": seq})


func _broadcast_discovery() -> void:
	_transport.broadcast(JSON.stringify({"t": "hello", "d": {"magic": MAGIC}}).to_utf8_buffer())


func host_game(name: String, seed: int, biome: String) -> bool:
	leave()
	_ensure_transport()
	_transport.listen(PORT)
	mode = "host"
	own_id = 1
	host_name = name
	world_seed = seed
	world_biome = biome
	return true


func start_discovery() -> bool:
	leave()
	_ensure_transport()
	_transport.listen(0)
	mode = "client"
	_discover_timer = 0.0
	return true


func join_game(ip: String) -> void:
	if mode != "client":
		return
	_host_key = _key(ip, PORT)
	_send_reliable(_host_key, "join", {"name": host_name, "magic": MAGIC})


func leave() -> void:
	if _transport != null:
		_transport.close()
	mode = ""
	own_id = 0
	_peers.clear()
	_pending.clear()
	_seen_seq.clear()
	_host_key = ""


## Estado propio (posición/yaw) para retransmitir.
func set_state_sender(sender: Callable) -> void:
	_send_state = sender


func send_block(cell: Vector3i, block_id: int) -> void:
	var data := {"cell": [cell.x, cell.y, cell.z], "block": block_id}
	if mode == "host":
		for key in _peers.keys():
			_send_reliable(key, "block", data)
	elif mode == "client" and _host_key != "":
		_send_reliable(_host_key, "block", data)


func _relay_block(from_key: String, data: Dictionary) -> void:
	for key in _peers.keys():
		if key != from_key:
			_send_reliable(key, "block", data)


## Foto del mundo al que entra (trozos de 50 bloques).
func send_snapshot(player_id: int, blocks: Array) -> void:
	for key in _peers.keys():
		if int(_peers[key].get("id", 0)) == player_id:
			_send_snapshot(key, blocks)
			return


func _send_snapshot(to_key: String, blocks: Array) -> void:
	var i := 0
	while i < blocks.size():
		var chunk := blocks.slice(i, i + 50)
		_send_reliable(to_key, "snapshot", {"blocks": chunk, "done": i + 50 >= blocks.size()})
		i += 50
	if blocks.is_empty():
		_send_reliable(to_key, "snapshot", {"blocks": [], "done": true})


func _handle_packet(from_key: String, packet: Dictionary) -> void:
	var type := str(packet.get("t", ""))
	if type == "ack":
		_pending.erase(int(packet.get("a", 0)))
		return
	# Fiabilidad: ack + descarte de duplicados.
	if packet.has("s"):
		var seq := int(packet["s"])
		var last := int(_seen_seq.get(from_key, 0))
		if seq <= last:
			_send_ack(from_key, seq)
			return
		_seen_seq[from_key] = seq
		_send_ack(from_key, seq)
	match type:
		"hello":
			if mode == "host" and str(packet["d"].get("magic", "")) == MAGIC:
				_send(from_key, {"t": "host_info", "d": {"name": host_name, "players": _peers.size() + 1}})
		"host_info":
			if mode == "client":
				var ip := from_key.split(":")[0]
				found_hosts[ip] = str(packet["d"].get("name", ""))
				host_found.emit(ip, str(packet["d"].get("name", "")))
		"join":
			if mode == "host" and _peers.size() + 1 < MAX_PLAYERS:
				var pid := _next_id
				_next_id += 1
				_peers[from_key] = {"id": pid, "name": str(packet["d"].get("name", "")), "last_seen": 0.0}
				_send_reliable(from_key, "welcome", {"id": pid, "seed": world_seed, "biome": world_biome})
				peer_joined.emit(pid, str(packet["d"].get("name", "")))
			elif mode == "host":
				_send_reliable(from_key, "full", {})
		"full":
			if mode == "client":
				join_rejected.emit("Partida llena (7 jugadores).")
		"welcome":
			if mode == "client":
				own_id = int(packet["d"].get("id", 0))
				join_accepted.emit(own_id, int(packet["d"].get("seed", 0)), str(packet["d"].get("biome", "")))
		"state":
			var pid := int(packet["d"].get("id", 0))
			if pid != own_id:
				peer_state.emit(pid, packet["d"])
			if mode == "host":
				for key in _peers.keys():
					if key != from_key:
						_send(key, packet)
		"block":
			var c: Array = packet["d"].get("cell", [])
			if c.size() == 3:
				block_received.emit(Vector3i(int(c[0]), int(c[1]), int(c[2])), int(packet["d"].get("block", 0)))
			if mode == "host":
				_relay_block(from_key, packet["d"])
		"snapshot":
			var blocks: Array = packet["d"].get("blocks", [])
			snapshot_received.emit(blocks, bool(packet["d"].get("done", false)))


func _process(delta: float) -> void:
	if mode == "":
		return
	# Entrada.
	for item in _transport.poll():
		var text := (item["bytes"] as PackedByteArray).get_string_from_utf8()
		var packet: Dictionary = JSON.parse_string(text)
		if packet.is_empty():
			continue
		_handle_packet(str(item["from"]), packet)
	# Reenvíos fiables.
	for seq in _pending.keys():
		var item: Dictionary = _pending[seq]
		item["last"] = float(item.get("last", 0.0)) + delta
		if float(item["last"]) >= RESEND_INTERVAL:
			if int(item["retries"]) >= MAX_RETRIES:
				_pending.erase(seq)
				continue
			item["last"] = 0.0
			item["retries"] = int(item["retries"]) + 1
			_send(str(item["key"]), item["packet"])
	# Descubrimiento (cliente sin partida).
	if mode == "client" and own_id == 0:
		_discover_timer -= delta
		if _discover_timer <= 0.0:
			_discover_timer = 1.0
			_broadcast_discovery()
	# Estado propio 10/s.
	_state_timer -= delta
	if _state_timer <= 0.0:
		_state_timer = 0.1
		if _send_state.is_valid():
			var state: Dictionary = _send_state.call()
			if not state.is_empty():
				state["id"] = own_id
				if mode == "host":
					for key in _peers.keys():
						_send(key, {"t": "state", "d": state})
				elif mode == "client" and _host_key != "":
					_send(_host_key, {"t": "state", "d": state})
