extends Node2D
## Ilha que chega flutuando: 4 cores, uma por lado (ou dourada), e às vezes um item ou monstro.

var edges := [0, 1, 2, 3]  # cor de cada lado: cima, direita, baixo, esquerda
var wild := false
var cargo := ""        # "", "item" ou "monster"
var kind := ""         # tipo do item ou do monstro
var weak := 0          # ponto fraco do monstro
var vel := Vector2.ZERO
var bounce_t := 0.0
var age := 0.0
var drifting := false  # peça solta à deriva (sem colisão, some aos poucos)
var sea_color := Color("38c6d9")


func _process(delta: float) -> void:
	age += delta
	position += vel * delta
	bounce_t = max(0.0, bounce_t - delta)
	if bounce_t > 0.0:
		vel = vel.lerp(vel.normalized() * 110.0, delta * 1.5)
	rotation = sin(age * 1.6 + edges[0]) * 0.06
	if drifting:
		modulate.a = max(0.0, 1.0 - age / 4.0)
		scale = Vector2.ONE * (1.0 - age / 8.0)
		if age > 4.0:
			queue_free()
	queue_redraw()


## Cor do lado virado para um ponto do mundo (ex.: a ilha do jogador).
func facing_edge(target: Vector2) -> int:
	return edges[G.dir_from_vec((target - position).rotated(-rotation))]


func _draw() -> void:
	var h := G.TILE * 0.5
	var wob := sin(age * 2.5) * 3.0
	G.rounded_box(self, Rect2(Vector2(-h, -h) - Vector2(14 + wob, 14 + wob), Vector2(h, h) * 2 + Vector2(28 + wob * 2, 28 + wob * 2)), Color(1, 1, 1, 0.25), Color(0, 0, 0, 0), 0, 26)
	G.rounded_box(self, Rect2(Vector2(-h - 6, -h - 6), Vector2(h * 2 + 12, h * 2 + 12)), G.SAND_DARK, Color(0, 0, 0, 0), 0, 18)
	G.rounded_box(self, Rect2(Vector2(-h - 1, -h - 1), Vector2(h * 2 + 2, h * 2 + 2)), G.SAND, Color(0, 0, 0, 0), 0, 15)
	G.rounded_box(self, Rect2(Vector2(-h + 14, -h + 14), Vector2(h * 2 - 28, h * 2 - 28)), G.GRASS, G.GRASS_DARK, 3, 10)
	for i in 4:
		G.draw_edge_band(self, Vector2.ZERO, G.DIRS[i], h - 2.0, edges[i], wild)
	if wild:
		G.draw_symbol(self, -1, Vector2.ZERO, 14, G.GOLD, G.GOLD_DARK, 3)
	draw_set_transform(Vector2.ZERO, -rotation, Vector2.ONE)
	if cargo == "item":
		G.draw_item(self, kind, Vector2(0, -12 + sin(age * 3.0) * 4.0), 20)
	elif cargo == "monster":
		G.draw_monster(self, kind, Vector2(0, 2), G.TILE * 0.4, weak, age)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
