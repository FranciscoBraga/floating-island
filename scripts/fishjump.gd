extends Node2D
## Peixe pulando do cardume até uma peça da ilha. Ao cair vira o item "peixe".

signal landed(cell: Vector2i)

var from := Vector2.ZERO
var cell := Vector2i.ZERO
var island: Node2D
var t := 0.0
const DUR := 0.85


func _process(delta: float) -> void:
	t += delta
	if t >= DUR:
		landed.emit(cell)
		queue_free()
		return
	queue_redraw()


func _point(k: float) -> Vector2:
	var to: Vector2 = island.cell_to_world(Vector2(cell))
	return from.lerp(to, k) + Vector2(0, -sin(k * PI) * 160.0)


func _draw() -> void:
	var k := t / DUR
	var p := _point(k)
	var ahead := _point(min(1.0, k + 0.05))
	draw_set_transform(p, (ahead - p).angle(), Vector2.ONE * (1.0 + sin(k * PI) * 0.3))
	G.draw_fish(self, Vector2.ZERO, 20.0)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
