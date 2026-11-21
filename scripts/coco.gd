extends Node2D
## Coco atirado pelo Tobé (poder Chuva de cocos): voa em arco até o alvo e avisa quando chega.

signal hit

var from := Vector2.ZERO
var aim: Callable      # devolve a posição atual do alvo (ele pode estar andando)
var t := 0.0
const DUR := 0.35


func _process(delta: float) -> void:
	t += delta
	if t >= DUR:
		hit.emit()
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k := t / DUR
	var to: Vector2 = aim.call()
	var p := from.lerp(to, k) + Vector2(0, -sin(k * PI) * 90.0)
	draw_set_transform(p, t * 20.0, Vector2.ONE)
	G.draw_coconut(self, Vector2.ZERO, 11)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
