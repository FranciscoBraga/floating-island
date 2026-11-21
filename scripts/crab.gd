extends Node2D
## Bichos de fora da ilha que usam a regra da cor (Pacote 2):
## - "caranguejo": nada até a ilha; borda da cor dele = é jogado longe; outra cor = gruda e a peça perde vida.
## - "siri": passa devagar numa ilhota com uma plaquinha colorida; borda daquela cor = dá a Bolha do siri.
## - "tubarao": barbatana que cruza o mar em linha; se alcança a ilha, arranca 1 peça (Pacote 4).
## O main.gd decide as batidas; aqui ficam o movimento depois da batida e o desenho.

var kind := "caranguejo"
var elem := 0            # cor do caranguejo / da plaquinha do siri
var state := "swim"      # swim · stuck · flung · fall (caranguejo) | swim · bye · dive (siri) | warn · swim · passed · flee (tubarão)
var route := 0.0         # tubarão que puxa a fila: comprimento da linha tracejada do aviso
var vel := Vector2.ZERO
var speed := 100.0
var t := 0.0             # tempo de vida (animação)
var st := 0.0            # tempo no estado atual
var cell := Vector2i.ZERO  # peça onde o caranguejo grudou
var dir := Vector2i.ZERO   # lado da peça onde grudou
var stuck_left := 0.0


func set_state(s: String) -> void:
	state = s
	st = 0.0


## Jogado longe (cor certa, bolha ou soco).
func fling(away: Vector2) -> void:
	set_state("flung")
	vel = away.normalized() * 520.0


func stick(c: Vector2i, d: Vector2i, secs: float) -> void:
	set_state("stuck")
	cell = c
	dir = d
	stuck_left = secs
	vel = Vector2.ZERO


## Solta da peça e afunda.
func fall() -> void:
	set_state("fall")
	vel = Vector2.from_angle(rotation - PI / 2.0) * -60.0


func done() -> bool:
	return state in ["flung", "fall", "bye", "dive", "flee"]


## Tubarão assustado (bolha, estrela ou coco): vira e vai embora.
func flee(away: Vector2) -> void:
	set_state("flee")
	vel = away.normalized() * 260.0


func _process(delta: float) -> void:
	t += delta
	st += delta
	if state != "stuck" and state != "warn":
		position += vel * delta
	match state:
		"swim":
			if kind == "caranguejo":
				rotation = lerp_angle(rotation, vel.angle() + PI / 2.0, 1.0 - exp(-delta * 6.0))
		"flung":
			rotation += delta * 14.0
			vel = vel.lerp(Vector2.ZERO, delta * 1.2)
			scale = Vector2.ONE * (1.0 + sin(min(st, 0.6) / 0.6 * PI) * 0.5)
			modulate.a = clamp(1.4 - st, 0.0, 1.0)
		"flee":
			modulate.a = clamp(1.5 - st, 0.0, 1.0)
		"fall", "dive":
			scale = Vector2.ONE * max(0.0, 1.0 - st / 1.2)
			modulate.a = clamp(1.0 - st / 1.2, 0.0, 1.0)
		"bye":
			vel = vel.lerp(vel.normalized() * 80.0, delta)
			modulate.a = clamp(3.0 - st * 0.8, 0.0, 1.0)
	if done() and modulate.a <= 0.01:
		queue_free()
	queue_redraw()


func _draw() -> void:
	if kind == "siri":
		_draw_siri()
	elif kind == "tubarao":
		if state == "warn" and route > 0.0:
			# linha tracejada vermelha mostrando a rota
			var d := vel.normalized()
			var blink := 0.55 + 0.45 * sin(t * 12.0)
			draw_dashed_line(d * 40.0, d * route, Color(1, 0.25, 0.2, 0.75 * blink), 6, 22, true)
		G.draw_fin(self, Vector2.ZERO, vel.angle(), 52.0, state == "warn", t)
	else:
		G.draw_crab(self, Vector2.ZERO, 26.0, elem, t, state == "stuck")


func _draw_siri() -> void:
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	var bob := sin(t * 2.2) * 3.0
	if state == "dive":
		bob += st * 30.0
	# ilhota de areia
	draw_circle(Vector2(0, 10), 50 + sin(t * 2.0) * 2.0, Color(1, 1, 1, 0.28))
	G.outlined_circle(self, Vector2(0, 10), 40, G.SAND, G.SAND_DARK, 5)
	draw_circle(Vector2(-12, 2), 7, Color(1, 1, 1, 0.25))
	# plaquinha com a cor (ele segura com a garra da direita)
	var wave := sin(t * 9.0) * 0.5 if state == "bye" else sin(t * 2.0) * 0.08
	var sp := Vector2(26, -18 + bob)
	var top := sp + Vector2(0, -38).rotated(wave)
	draw_line(sp, top, Color("6e3a10"), 5)
	draw_set_transform(top, wave, Vector2.ONE)
	G.rounded_box(self, Rect2(Vector2(-22, -30), Vector2(44, 34)), G.ELEM[elem], G.ELEM_DARK[elem], 4, 8)
	G.draw_symbol(self, elem, Vector2(0, -13), 10, G.ELEM[elem].lightened(0.45), G.ELEM_DARK[elem], 2)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	# siri vermelho sentado na ilhota
	G.draw_crab(self, Vector2(-4, 4 + bob), 30.0, -1, t * 0.5, false)
	if state == "dive" and st < 0.8:
		draw_string(G.font, Vector2(-30, -60), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color.WHITE)
