extends Node2D
## Missão da baleia (Pacote 3): ela sobe ao lado da ilha com 4 crustáceos coloridos nas costas.
## Encostar a borda da mesma cor em cada um limpa ele (o main.gd confere as batidas).
## Limpou os 4: jato d'água e prêmio. Se o tempo acaba, ela só mergulha (não machuca).

var state := "rise"     # rise · up · jet · dive
var st := 0.0           # tempo no estado atual
var t := 0.0
var left := 30.0        # segundos até ela mergulhar
var facing := 1.0       # 1 = cabeça para a direita
var spots: Array = []   # {"off": Vector2 (local), "elem": int, "clean": bool, "pop": float}
var nudge_cd := 0.0     # espera entre os avisos de "cor errada"

const L := 380.0        # comprimento
const W := 120.0        # largura


func setup(colors: Array) -> void:
	spots.clear()
	for i in colors.size():
		var x := (i - (colors.size() - 1) * 0.5) * G.TILE * 0.95
		spots.append({"off": Vector2(x, 0), "elem": colors[i], "clean": false, "pop": 0.0})


func set_state(s: String) -> void:
	state = s
	st = 0.0


func spot_world(i: int) -> Vector2:
	return to_global(spots[i]["off"])


func cleaned() -> int:
	return spots.filter(func(s): return s["clean"]).size()


func _process(delta: float) -> void:
	t += delta
	st += delta
	nudge_cd = max(0.0, nudge_cd - delta)
	for s in spots:
		s["pop"] = max(0.0, s["pop"] - delta)
	match state:
		"rise":
			modulate.a = clamp(st / 1.2, 0.0, 1.0)
			if st >= 1.2:
				set_state("up")
		"jet":
			if st >= 2.2:
				set_state("dive")
		"dive":
			modulate.a = clamp(1.0 - st / 1.5, 0.0, 1.0)
			scale = Vector2.ONE * (1.0 - st * 0.08)
			if st >= 1.5:
				queue_free()
	queue_redraw()


func _draw() -> void:
	var body := Color("4f7fb3")
	var dark := Color("1f3d63")
	var belly := Color("9cc4e8")
	var bob := sin(t * 1.4) * 3.0
	var f := facing
	# espuma em volta
	draw_set_transform(Vector2(0, bob), 0, Vector2(1, 0.42))
	draw_circle(Vector2.ZERO, L * 0.58 + sin(t * 2.0) * 4.0, Color(1, 1, 1, 0.22))
	draw_set_transform(Vector2(0, bob), 0, Vector2.ONE)
	# cauda (lado oposto à cabeça), balançando
	var tail := Vector2(-f * L * 0.5, sin(t * 2.0) * 6.0)
	for s in [-1.0, 1.0]:
		G.outlined_poly(self, PackedVector2Array([tail + Vector2(f * 14, 0), tail + Vector2(-f * L * 0.13, s * L * 0.15),
			tail + Vector2(-f * L * 0.17, s * L * 0.1), tail + Vector2(-f * L * 0.05, 0)]), body, dark, 5)
	# nadadeiras
	for s in [-1.0, 1.0]:
		var b := Vector2(f * L * 0.12, s * W * 0.4)
		G.outlined_poly(self, PackedVector2Array([b, b + Vector2(-f * L * 0.16, s * W * 0.55), b + Vector2(-f * L * 0.04, s * W * 0.25)]), body, dark, 4)
	# corpo (gota alongada vista de cima)
	var pts := PackedVector2Array()
	var n := 28
	for i in n:
		var a := TAU * i / n
		var x := cos(a)
		var w := W * 0.5 * (1.0 - 0.45 * maxf(0.0, -x * f))  # mais fina perto da cauda
		pts.append(Vector2(x * L * 0.5, sin(a) * w))
	G.outlined_poly(self, pts, body, dark, 6)
	draw_set_transform(Vector2(f * L * 0.1, bob), 0, Vector2(1, 0.35))
	draw_circle(Vector2.ZERO, L * 0.22, Color(belly, 0.35))
	draw_set_transform(Vector2(0, bob), 0, Vector2.ONE)
	# olhinhos e respiradouro
	for s in [-1.0, 1.0]:
		var e := Vector2(f * L * 0.36, s * W * 0.3)
		G.outlined_circle(self, e, 9, Color.WHITE, dark, 3)
		draw_circle(e + Vector2(f * 2, 0), 4.5, Color("1d2b4a"))
	var hole := Vector2(f * L * 0.27, 0)
	draw_circle(hole, 7, dark)
	# crustáceos coloridos nas costas
	for s in spots:
		var p: Vector2 = s["off"]
		var k: float = s["pop"] / 0.5
		if s["clean"]:
			if k > 0.0:
				draw_arc(p, 30 * (1.0 - k) + 10, 0, TAU, 20, Color(1, 1, 1, k), 4, true)
			else:
				draw_circle(p + Vector2(0, -4), 4, Color(1, 1, 1, 0.5))
			continue
		var e: int = s["elem"]
		var wob := sin(t * 5.0 + p.x) * 2.0
		draw_circle(p + Vector2(0, 4), 25, Color(0, 0, 0, 0.18))
		G.outlined_circle(self, p, 22 + wob, G.ELEM[e], G.ELEM_DARK[e], 4)
		for j in 5:
			var a := TAU * j / 5.0 + 0.3
			draw_line(p + Vector2.from_angle(a) * 8, p + Vector2.from_angle(a) * (20 + wob), G.ELEM_DARK[e], 2)
		G.draw_symbol(self, e, p, 9, G.ELEM[e].lightened(0.45), G.ELEM_DARK[e], 2)
	# relógio: quanto falta para ela mergulhar
	if state == "up":
		var c := Vector2(0, -W * 0.5 - 34)
		var frac: float = clamp(left / 30.0, 0.0, 1.0)
		draw_circle(c, 18, Color(0, 0, 0, 0.3))
		draw_arc(c, 15, -PI / 2, -PI / 2 + TAU * frac, 24, Color("ff6b6b") if left < 8.0 else Color.WHITE, 5, true)
		draw_string(G.font, c + Vector2(-30, 7), "%d/%d" % [cleaned(), spots.size()], HORIZONTAL_ALIGNMENT_CENTER, 60, 16, Color.WHITE)
	# jato d'água
	if state == "jet":
		var h: float = min(st * 260.0, 160.0) * (1.0 if st < 1.6 else max(0.0, 1.0 - (st - 1.6) / 0.6))
		for i in 14:
			var u := float(i) / 13.0
			var a := -PI / 2 + (u - 0.5) * 1.2
			var r := h * (0.6 + 0.4 * sin(u * PI))
			var tip := hole + Vector2.from_angle(a) * r
			draw_line(hole, tip, Color(0.85, 0.97, 1.0, 0.7), 6, true)
			draw_circle(tip, 7, Color(1, 1, 1, 0.85))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
