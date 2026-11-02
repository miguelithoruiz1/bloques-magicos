extends Control
## Minimap — mapa en vivo de la 3.0, dibujado DESDE los
## datos de nuestro terreno (no es una imagen ajena ni una
## copia del mapa de otro juego): por cada columna visible
## se toma la superficie (terrain_height + get_block) y el
## color del bloque. Norte arriba, jugador en el centro.
## Presupuesto fijo: 41×41 celdas, refresco máximo 2 veces
## por segundo y solo si el jugador se movió 2+ celdas.

class_name Minimap

const CELLS := 41
const CELL_PX := 5
const MINIMAP_PX := CELLS * CELL_PX

var _world: VoxelWorldGenerator = null
var _last_cell := Vector2i(99999, 99999)
var _last_time := 0.0


func setup(world: VoxelWorldGenerator) -> void:
	_world = world
	queue_redraw()


func update_view(player_pos: Vector3, time_now: float) -> void:
	var cell := Vector2i(floori(player_pos.x), floori(player_pos.z))
	if cell == _last_cell and time_now - _last_time < 0.5:
		return
	_last_cell = cell
	_last_time = time_now
	queue_redraw()


func _draw() -> void:
	# Fondo.
	draw_rect(Rect2(Vector2.ZERO, Vector2(MINIMAP_PX, MINIMAP_PX)), Color(0.0, 0.0, 0.0, 0.6))
	if _world == null:
		return
	var half: int = CELLS / 2
	for dx in range(-half, half + 1):
		for dz in range(-half, half + 1):
			var wx: int = _last_cell.x + dx
			var wz: int = _last_cell.y + dz
			var h: int = _world.terrain_height(wx, wz)
			var block: int = _world.get_block(Vector3i(wx, h, wz))
			var color: Color = VoxelWorldGenerator.block_color(block)
			draw_rect(
				Rect2(Vector2(float(dx + half) * CELL_PX, float(dz + half) * CELL_PX),
					Vector2(CELL_PX, CELL_PX)),
				color)
	# Jugador: punto amarillo en el centro + flecha norte.
	var center: float = float(half) * CELL_PX
	draw_rect(Rect2(Vector2(center - 2.0, center - 2.0), Vector2(9.0, 9.0)), Color(1.0, 0.9, 0.2))
	draw_colored_polygon(PackedVector2Array([
		Vector2(center + 2.5, 2.0), Vector2(center - 2.5, 2.0),
		Vector2(center + 2.5, 12.0)]), Color.WHITE)
