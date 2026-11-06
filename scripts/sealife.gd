extends Node2D
## Vida embaixo d'água: sombras de tubarões, baleias e cardumes passando sob o mar.
## Os cardumes podem soltar um peixe que pula na ilha (main.gd cuida do pulo).

var creatures: Array = []   # {"kind", "pos", "vel", "t", "size", "cd", "fish": Array}
var view := Rect2(-640, -360, 1280, 720)
var focus := Vector2.ZERO   # posição da ilha (os cardumes nascem perto da faixa dela)
var night := 0.0
var _filled := false

const WANT := {"tubarao": 2, "baleia": 1, "cardume": 3}


func _process(delta: float) -> void:
	for c in creatures:
		c["t"] += delta
		c["cd"] = max(0.0, c["cd"] - delta)
		c["pos"] += c["vel"] * delta
		if c["kind"] == "cardume":
			# o cardume muda de rumo devagar, como se procurasse comida
			c["vel"] = c["vel"].rotated(sin(c["t"] * 0.4 + c["size"] * 7.0) * 0.12 * delta)
	var far := view.grow(max(view.size.x, view.size.y) * 0.6)
	creatures = creatures.filter(func(c): return far.has_point(c["pos"]))
	for kind in WANT:
		var n := creatures.filter(func(c): return c["kind"] == kind).size()
		for i in WANT[kind] - n:
			if kind == "baleia" and _filled and randf() > delta * 0.15:
				continue  # baleia é rara: demora para aparecer de novo
			_spawn(kind, not _filled)
	_filled = true
	queue_redraw()


func _spawn(kind: String, inside: bool) -> void:
	var c := {"kind": kind, "t": randf() * 10.0, "cd": 0.0, "size": randf_range(0.85, 1.2)}
	var speed: float = {"tubarao": 70.0, "baleia": 32.0, "cardume": 38.0}[kind]
	var pos: Vector2
	var dir: Vector2
	if inside:
		pos = view.position + Vector2(randf(), randf()) * view.size
		dir = Vector2.RIGHT.rotated(randf() * TAU)
	else:
		# nasce fora da tela e atravessa
		var side := randi() % 4
		var m := 260.0
		match side:
			0: pos = Vector2(randf_range(view.position.x, view.end.x), view.position.y - m)
			1: pos = Vector2(view.end.x + m, randf_range(view.position.y, view.end.y))
			2: pos = Vector2(randf_range(view.position.x, view.end.x), view.end.y + m)
			_: pos = Vector2(view.position.x - m, randf_range(view.position.y, view.end.y))
		var aim := view.get_center() + Vector2(randf_range(-0.3, 0.3) * view.size.x, randf_range(-0.3, 0.3) * view.size.y)
		if kind == "cardume":
			aim.y = focus.y + randf_range(-140.0, 140.0)  # passa perto da ilha
		dir = (aim - pos).normalized()
	c["pos"] = pos
	c["vel"] = dir * speed * randf_range(0.8, 1.2)
	if kind == "cardume":
		var fish := []
		for i in randi_range(12, 18):
			fish.append({"off": Vector2(randf_range(-70, 70), randf_range(-38, 38)), "ph": randf() * TAU})
		c["fish"] = fish
	creatures.append(c)


## Cardumes perto de um ponto do mundo (para o peixe pular na ilha).
func school_near(p: Vector2, dist: float) -> Dictionary:
	for c in creatures:
		if c["kind"] == "cardume" and c["cd"] <= 0.0 and c["pos"].distance_to(p) < dist:
			return c
	return {}


# ---------- desenho das sombras ----------

func _tint(alpha: float) -> Color:
	return Color(0.02, 0.13, 0.24, 1.0).lerp(Color(0.0, 0.03, 0.08, 1.0), night) * Color(1, 1, 1, alpha)


## Corpo alongado visto de cima (nariz em +x), com a cauda balançando.
func _body(L: float, W: float, t: float, wag: float, nose: float) -> PackedVector2Array:
	var top := PackedVector2Array()
	var bot := PackedVector2Array()
	var n := 14
	for i in n + 1:
		var u := float(i) / n                     # 0 = nariz, 1 = cauda
		var x := L * 0.5 - u * L
		var w := W * pow(sin(PI * clamp(u * 0.92 + 0.04, 0.0, 1.0)), nose) * (1.0 - u * 0.55)
		var y := sin(t * 5.0 - u * 3.0) * wag * u * u
		top.append(Vector2(x, y - w))
		bot.append(Vector2(x, y + w))
	bot.reverse()
	top.append_array(bot)
	return top


## Sombra feita no Gemini (máscara branca, cabeça para a direita), pintada com a cor do fundo.
func _draw_tex(tx: Texture2D, pos: Vector2, ang: float, length: float, col: Color, t: float, wag: float) -> void:
	var sz := tx.get_size()
	var k := length / sz.x
	draw_set_transform(pos, ang + sin(t * 5.0) * wag, Vector2(k, k * (1.0 + sin(t * 5.0 + 1.0) * 0.03)))
	draw_texture_rect(tx, Rect2(-sz * 0.5, sz), false, col)


func _tail_y(t: float, wag: float) -> float:
	return sin(t * 5.0 - 3.0) * wag


func _draw_shark(c: Dictionary) -> void:
	var L: float = 170.0 * c["size"]
	var t: float = c["t"] * 1.6
	var col := _tint(0.26)
	var tx := G.tex("sombra_tubarao")
	if tx:
		_draw_tex(tx, c["pos"], c["vel"].angle(), L, col, t, 0.06)
		return
	draw_set_transform(c["pos"], c["vel"].angle(), Vector2.ONE)
	# nadadeiras peitorais
	for s in [-1.0, 1.0]:
		draw_colored_polygon(PackedVector2Array([Vector2(L * 0.12, s * L * 0.06), Vector2(-L * 0.12, s * L * 0.26),
			Vector2(-L * 0.04, s * L * 0.07)]), col)
	draw_colored_polygon(_body(L, L * 0.1, t, L * 0.07, 0.7), col)
	# cauda em meia-lua
	var ty := _tail_y(t, L * 0.07)
	var tb := Vector2(-L * 0.5, ty)
	draw_colored_polygon(PackedVector2Array([tb + Vector2(6, 0), tb + Vector2(-L * 0.16, -L * 0.15),
		tb + Vector2(-L * 0.08, 0), tb + Vector2(-L * 0.16, L * 0.15)]), col)


func _draw_whale(c: Dictionary) -> void:
	var L: float = 420.0 * c["size"]
	var t: float = c["t"] * 0.7
	var col := _tint(0.17)
	var tx := G.tex("sombra_baleia")
	if tx:
		_draw_tex(tx, c["pos"], c["vel"].angle(), L, col, t, 0.03)
		return
	draw_set_transform(c["pos"], c["vel"].angle(), Vector2.ONE)
	for s in [-1.0, 1.0]:
		var fl: float = sin(t * 2.0) * 0.15 * s
		var base := Vector2(L * 0.12, s * L * 0.1)
		draw_colored_polygon(PackedVector2Array([base, base + Vector2(-L * 0.2, s * L * 0.22).rotated(fl),
			base + Vector2(-L * 0.26, s * L * 0.2).rotated(fl), base + Vector2(-L * 0.1, 0)]), col)
	draw_colored_polygon(_body(L, L * 0.14, t, L * 0.04, 0.45), col)
	var ty := _tail_y(t, L * 0.04)
	var tb := Vector2(-L * 0.5, ty)
	for s in [-1.0, 1.0]:
		draw_colored_polygon(PackedVector2Array([tb + Vector2(10, 0), tb + Vector2(-L * 0.06, s * L * 0.15),
			tb + Vector2(-L * 0.14, s * L * 0.13), tb + Vector2(-L * 0.04, 0)]), col)


func _draw_school(c: Dictionary) -> void:
	var col := _tint(0.3)
	var ang: float = c["vel"].angle()
	var swirl: float = sin(c["t"] * 0.6) * 0.25
	for f in c["fish"]:
		var off: Vector2 = f["off"].rotated(swirl) + Vector2(sin(c["t"] * 1.3 + f["ph"]) * 8.0, cos(c["t"] * 1.1 + f["ph"]) * 5.0)
		var p: Vector2 = c["pos"] + off.rotated(ang)
		var ftx := G.tex("sombra_peixe")
		if ftx:
			_draw_tex(ftx, p, ang, 28.0, col, c["t"] * 1.6 + f["ph"], 0.2)
			continue
		draw_set_transform(p, ang + sin(c["t"] * 8.0 + f["ph"]) * 0.25, Vector2.ONE)
		draw_colored_polygon(PackedVector2Array([Vector2(12, 0), Vector2(4, -5), Vector2(-7, -3), Vector2(-14, -6),
			Vector2(-11, 0), Vector2(-14, 6), Vector2(-7, 3), Vector2(4, 5)]), col)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	# brilho de bolhinhas indica que dá para pegar peixe aqui
	if c["cd"] <= 0.0:
		for i in 3:
			var bt := fmod(c["t"] * 0.8 + i * 0.33, 1.0)
			var bp: Vector2 = c["pos"] + Vector2((i - 1) * 26, 10 - bt * 30)
			draw_arc(bp, 3 + bt * 4, 0, TAU, 10, Color(1, 1, 1, 0.45 * (1.0 - bt)), 2, true)


func _draw() -> void:
	# baleias primeiro (mais fundas), depois tubarões e cardumes
	for kind in ["baleia", "tubarao", "cardume"]:
		for c in creatures:
			if c["kind"] != kind:
				continue
			match kind:
				"baleia": _draw_whale(c)
				"tubarao": _draw_shark(c)
				_: _draw_school(c)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
