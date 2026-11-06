extends Node2D
## A ilha do jogador: grade de peças, centro de giro, encaixe por cor,
## afundamento e o desenho de tudo que está sobre ela.

const Actor = preload("res://scripts/actor.gd")

var cells := {}        # Vector2i -> {"elem": cor do encaixe (-1 = ilha inicial), "edges": [4 cores], "born": float}
var items := {}        # Vector2i -> String
var pivot := Vector2.ZERO
var spin_dir := 0          # -1/1 enquanto o jogador segura, 0 solto
var spin_hold := 0.0       # há quanto tempo está segurando
var ang_vel := 0.0         # velocidade do giro (rad/s, com sinal)
var spin_cap := 0.0        # velocidade que o giro atingiu segurando (usada para terminar o giro)
var move_vel := 0.0        # velocidade de lado da ilha (px/s, com sinal)
var settle_k := 0          # passo de 90° onde a ilha vai parar
var settling := false
var game_time := 0.0
var sea_color := Color("38c6d9")
var tobe: Actor
var monsters: Array = []
var preview := {}      # {"slot": Vector2i, "ok": bool}
var rings: Array = []  # ondas elementais: {"pos": Vector2, "elem": int, "t": float}
var shield := false
var powers_on := {}        # poderes ligados (para desenhar): {"ima": bool, "soco": bool, "conserto": bool}


func reset() -> void:
	cells.clear()
	items.clear()
	monsters.clear()
	rings.clear()
	preview = {}
	pivot = Vector2.ZERO
	spin_dir = 0
	settling = false
	settle_k = 0
	ang_vel = 0.0
	move_vel = 0.0
	rotation = 0.0
	position = Vector2.ZERO
	cells[Vector2i.ZERO] = {"elem": -1, "edges": G.HOME_EDGE.duplicate(), "born": game_time}
	tobe = Actor.new()
	tobe.kind = "tobe"
	tobe.speed = 2.6


# ---------- coordenadas ----------

func cell_to_local(c: Vector2) -> Vector2:
	return (c - pivot) * G.TILE


func world_to_cell(p: Vector2) -> Vector2:
	return to_local(p) / G.TILE + pivot


func cell_to_world(c: Vector2) -> Vector2:
	return to_global(cell_to_local(c))


func radius_cells() -> float:
	var r := 0.0
	for c in cells:
		r = max(r, (Vector2(c) - pivot).length())
	return r


# ---------- regras ----------

func edge_color(c: Vector2i, d: Vector2i) -> int:
	return cells[c]["edges"][G.dir_index(d)]


func exposed_colors() -> Array:
	var out := []
	for c in cells:
		for d in G.DIRS:
			if not cells.has(c + d):
				var col := edge_color(c, d)
				if not out.has(col):
					out.append(col)
	return out


# ---------- giro ----------

func spin_press(dir: int) -> void:
	if spin_dir == dir:
		return
	spin_dir = dir
	spin_hold = 0.0
	spin_cap = G.SPIN_MIN
	# o toque conta a partir de onde a ilha ia parar (toques rápidos somam passos)
	if not settling:
		settle_k = roundi(rotation / G.SPIN_STEP)
	settling = false


func spin_release(dir: int) -> void:
	if spin_dir != dir:
		return
	spin_dir = 0
	var k := rotation / G.SPIN_STEP
	# termina o giro no próximo passo de 90° no sentido do toque (pelo menos 1 passo)
	if dir > 0:
		settle_k = maxi(ceili(k - 0.001), settle_k + 1)
	else:
		settle_k = mini(floori(k + 0.001), settle_k - 1)
	settling = true


## Um toque instantâneo (usado pelo robô de teste).
func tap_rotate(dir: int) -> void:
	spin_press(dir)
	spin_release(dir)


func is_spinning() -> bool:
	return spin_dir != 0 or settling


## Giro "oficial" para as regras de cor: o passo de 90° mais perto.
func snap_rot() -> float:
	return roundf(rotation / G.SPIN_STEP) * G.SPIN_STEP


func _update_spin(delta: float) -> void:
	if spin_dir != 0:
		# segurando: giro e movimento aceleram aos poucos até o limite
		spin_hold += delta
		var k: float = clamp(spin_hold / G.HOLD_RAMP, 0.0, 1.0)
		spin_cap = lerp(G.SPIN_MIN, G.SPIN_MAX, k)
		ang_vel = move_toward(ang_vel, spin_dir * spin_cap, G.SPIN_ACCEL * delta)
		var want: float = spin_dir * lerp(G.MOVE_MIN, G.MOVE_MAX, k)
		move_vel = move_toward(move_vel, want, G.MOVE_ACCEL * delta)
	else:
		# solto: a ilha desliza e vai parando devagar
		move_vel *= exp(-G.MOVE_FRICTION * delta)
		if abs(move_vel) < 2.0:
			move_vel = 0.0
		if settling:
			# termina o giro desacelerando ao chegar no passo de 90°
			var rem := settle_k * G.SPIN_STEP - rotation
			var want: float = signf(rem) * clamp(abs(rem) * 6.0, 0.6, spin_cap)
			ang_vel = move_toward(ang_vel, want, G.SPIN_ACCEL * delta)
	var target := settle_k * G.SPIN_STEP
	var before := target - rotation
	rotation += ang_vel * delta
	position.x += move_vel * delta
	if settling:
		var after := target - rotation
		# chegou (ou cruzou o ponto neste quadro): encaixa no passo certo
		if abs(after) < 0.003 or signf(after) != signf(before):
			rotation = target
			ang_vel = 0.0
			settling = false


## O centro de giro fica no meio exato das peças, para a ilha girar no lugar
## (sem balançar para os lados). As regras de cor usam a grade da própria ilha,
## então o centro não precisa cair numa peça.
func recompute_pivot() -> void:
	if cells.is_empty():
		return
	var sum := Vector2.ZERO
	for c in cells:
		sum += Vector2(c)
	var np := sum / cells.size()
	if not np.is_equal_approx(pivot):
		# move o nó junto para as peças continuarem no mesmo lugar da tela
		position += ((np - pivot) * G.TILE).rotated(rotation)
		pivot = np


func find_contact(q: Vector2, reach := 0.96) -> Dictionary:
	var best := Vector2i.ZERO
	var found := false
	var bd := 99.0
	for c in cells:
		var d: Vector2 = q - Vector2(c)
		if max(abs(d.x), abs(d.y)) < reach:
			var l := d.length()
			if l < bd:
				bd = l
				best = c
				found = true
	if not found:
		return {}
	var dv: Vector2 = q - Vector2(best)
	var dir := Vector2i(int(signf(dv.x)), 0) if abs(dv.x) >= abs(dv.y) else Vector2i(0, int(signf(dv.y)))
	if dir == Vector2i.ZERO:
		dir = Vector2i(0, -1)
	var slot: Vector2i = best + dir
	if cells.has(slot):
		slot = nearest_empty_slot(q)
	return {"cell": best, "slot": slot}


func nearest_empty_slot(q: Vector2) -> Vector2i:
	var best := Vector2i.ZERO
	var bd := 1e9
	for c in cells:
		for d in G.DIRS:
			var s: Vector2i = c + d
			if not cells.has(s):
				var l := (Vector2(s) - q).length_squared()
				if l < bd:
					bd = l
					best = s
	return best


## Cor do lado da ilha que chega virado para a direção local d da ilha.
func inc_edge(inc, d: Vector2i) -> int:
	var w := Vector2(d).rotated(snap_rot() - inc.rotation)
	return inc.edges[G.dir_from_vec(w)]


## Cores da ilha que chega já no sistema da ilha (para guardar na peça nova).
func local_edges(inc) -> Array:
	var out := []
	for d in G.DIRS:
		out.append(inc_edge(inc, d))
	return out


## Encaixe vale se algum lado da ilha que chega encostar numa borda da mesma cor
## (a dúvida favorece o jogador). Devolve a cor do encaixe, ou -1 se não casou.
func slot_color(slot: Vector2i, inc) -> int:
	for d in G.DIRS:
		var nb: Vector2i = slot + d
		if cells.has(nb):
			var ic := edge_color(nb, -d)
			if inc.wild or inc_edge(inc, d) == ic:
				return ic
	return -1


func add_cell(slot: Vector2i, elem: int, edges: Array) -> void:
	cells[slot] = {"elem": elem, "edges": edges, "born": game_time}
	recompute_pivot()


func age(c: Vector2i) -> float:
	return game_time - float(cells[c]["born"])


func remaining(c: Vector2i) -> float:
	return G.PIECE_LIFE - age(c)


## Peça rachada (prestes a afundar): o Tobé não anda por cima dela.
func is_unsafe(c: Vector2i) -> bool:
	return remaining(c) < G.UNSAFE_LEFT


# ---------- caminhos ----------

## Caminhos pela ilha. Com avoid_unsafe, as peças rachadas ficam de fora
## (só a peça de partida pode ser rachada, para o Tobé conseguir sair dela).
func bfs(from: Vector2i, avoid_unsafe := false) -> Dictionary:
	var dist := {from: 0}
	var parent := {}
	var q: Array[Vector2i] = [from]
	var i := 0
	while i < q.size():
		var c: Vector2i = q[i]
		i += 1
		for d in G.DIRS:
			var n: Vector2i = c + d
			if cells.has(n) and not dist.has(n) and not (avoid_unsafe and is_unsafe(n)):
				dist[n] = dist[c] + 1
				parent[n] = c
				q.append(n)
	return {"dist": dist, "parent": parent}


func path_from(info: Dictionary, from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if not info["dist"].has(to):
		return out
	var c := to
	while c != from:
		out.push_front(c)
		c = info["parent"][c]
	out.push_front(from)
	return out


func set_destination(a: Actor, dest: Vector2i, info: Dictionary = {}, avoid_unsafe := false) -> void:
	var start: Vector2i = a.path[0] if a.path.size() > 0 else a.cell()
	if not cells.has(start):
		start = a.cell()
	if not cells.has(start):
		a.path.clear()
		return
	if info.is_empty() or not info["dist"].has(start) or info["dist"][start] != 0:
		info = bfs(start, avoid_unsafe)
	a.target = dest
	a.path = path_from(info, start, dest)


func step_actor(a: Actor, delta: float, spd: float) -> void:
	a.anim += delta
	while a.path.size() > 0 and not cells.has(a.path[0]):
		a.path.clear()
	if a.path.is_empty():
		a.moving = false
		return
	var goal := Vector2(a.path[0])
	var to := goal - a.cpos
	var stepd := spd * delta
	if to.length() <= stepd:
		a.cpos = goal
		a.path.pop_front()
	else:
		a.cpos += to.normalized() * stepd
	a.moving = to.length() > 0.02
	var wdir := to.rotated(rotation)
	if abs(wdir.x) > 0.05:
		a.facing = signf(wdir.x)


# ---------- desenho ----------

func _process(delta: float) -> void:
	_update_spin(delta)
	for r in rings:
		r["t"] += delta
	rings = rings.filter(func(r): return r["t"] < 0.9)
	queue_redraw()


func _cell_rect(c: Vector2i, grow: float) -> Rect2:
	var center := cell_to_local(Vector2(c))
	var h := G.TILE * 0.5 + grow
	return Rect2(center - Vector2(h, h), Vector2(h, h) * 2.0)


func _sink_k(c: Vector2i) -> float:
	return clamp((age(c) - (G.PIECE_LIFE - 10.0)) / 10.0, 0.0, 1.0)


func _draw() -> void:
	var t := game_time
	# espuma em volta da ilha
	for c in cells:
		var wob := sin(t * 2.0 + c.x * 1.3 + c.y * 0.7) * 3.0
		G.rounded_box(self, _cell_rect(c, 14.0 + wob), Color(1, 1, 1, 0.28), Color(0, 0, 0, 0), 0, 26)
	# contorno grosso da areia (cor escura da própria areia)
	for c in cells:
		var k := _sink_k(c)
		G.rounded_box(self, _cell_rect(c, 6.0 - k * 12.0), sand_dark_for(k), Color(0, 0, 0, 0), 0, 18)
	# areia
	for c in cells:
		var k := _sink_k(c)
		G.rounded_box(self, _cell_rect(c, 0.5 - k * 12.0), G.SAND.lerp(sea_color, k * 0.6), Color(0, 0, 0, 0), 0, 14)
	# grama (estendida até as vizinhas para parecer uma ilha só)
	for c in cells:
		var k := _sink_k(c)
		var r := _cell_rect(c, -12.0 - k * 10.0)
		for d in G.DIRS:
			if cells.has(c + d):
				var g := 12.0
				if d.x < 0: r = r.grow_side(SIDE_LEFT, g)
				if d.x > 0: r = r.grow_side(SIDE_RIGHT, g)
				if d.y < 0: r = r.grow_side(SIDE_TOP, g)
				if d.y > 0: r = r.grow_side(SIDE_BOTTOM, g)
		G.rounded_box(self, r, G.GRASS.lerp(sea_color, k * 0.6), G.GRASS_DARK, 0, 16)
	# tufos de grama e flores
	for c in cells:
		var center := cell_to_local(Vector2(c))
		var hsh := absi(c.x * 73856093 ^ c.y * 19349663)
		var off := Vector2((hsh % 30) - 15, ((hsh / 30) % 30) - 15)
		draw_circle(center + off, 5, G.GRASS_DARK.lightened(0.15))
		draw_circle(center + off + Vector2(7, 3), 4, G.GRASS_DARK.lightened(0.25))
		if hsh % 3 == 0:
			draw_circle(center - off * 0.8, 4, Color("fff3c4"))
			draw_circle(center - off * 0.8, 2, Color("ff9e5e"))
	# faixas coloridas nas bordas expostas
	for c in cells:
		var center := cell_to_local(Vector2(c))
		var k := _sink_k(c)
		var e: int = cells[c]["elem"]
		for d in G.DIRS:
			if cells.has(c + d):
				continue
			G.draw_edge_band(self, center, d, G.TILE * 0.5 - 2.0 - k * 12.0, edge_color(c, d))
		if e >= 0:
			G.draw_symbol(self, e, center + Vector2(0, 2), 11, G.ELEM[e].lightened(0.25), G.ELEM_DARK[e], 3)
		else:
			G.outlined_circle(self, center, 9, Color("fff3c4"), G.SAND_DARK, 3)
	# rachaduras e água subindo nas peças velhas
	for c in cells:
		var a := age(c)
		if a < G.CRACK_AT:
			continue
		var center := cell_to_local(Vector2(c))
		var p := (a - G.CRACK_AT) / (G.PIECE_LIFE - G.CRACK_AT)
		var crack := Color(0.35, 0.22, 0.1, 0.4 + p * 0.5)
		var pts := PackedVector2Array([center + Vector2(-22, -18), center + Vector2(-8, -6), center + Vector2(-14, 6),
			center + Vector2(2, 14), center + Vector2(-2, 24)])
		draw_polyline(pts, crack, 3, true)
		if p > 0.4:
			draw_polyline(PackedVector2Array([center + Vector2(20, -22), center + Vector2(8, -8), center + Vector2(18, 4)]), crack, 3, true)
		var k := _sink_k(c)
		if k > 0.0:
			for i in 3:
				var bt := fmod(t * 1.5 + i * 0.33, 1.0)
				draw_arc(center + Vector2((i - 1) * 16, 10 - bt * 30), 3 + bt * 4, 0, TAU, 10, Color(1, 1, 1, 0.8 * (1.0 - bt)), 2, true)
	# prévia do encaixe (lado de contato ao vivo)
	if not preview.is_empty():
		var pr := _cell_rect(preview["slot"], -4.0)
		var pulse := 0.5 + 0.5 * sin(t * 14.0)
		var col: Color = Color("7dff8a") if preview["ok"] else Color("ff6b6b")
		G.rounded_box(self, pr, Color(col, 0.18 + 0.12 * pulse), Color(col, 0.9), 4, 14)
	# destino que o jogador tocou para o Tobé
	if tobe and tobe.has_manual and cells.has(tobe.manual):
		var mc := cell_to_local(Vector2(tobe.manual))
		var pr2 := 0.5 + 0.5 * sin(t * 8.0)
		draw_arc(mc, 22 + pr2 * 6, 0, TAU, 32, Color(1, 1, 1, 0.9), 4, true)
		draw_arc(mc, 10, 0, TAU, 20, Color(1, 1, 1, 0.6), 3, true)
	# magnetismo: anéis vermelhos e azuis girando em volta da ilha, puxando para dentro
	if powers_on.get("ima", false):
		var rad := (radius_cells() + 1.3) * G.TILE
		for i in 12:
			var a0 := t * 0.8 + i * TAU / 12.0
			var colm := Color("e8413a") if i % 2 == 0 else Color("4da3ff")
			draw_arc(Vector2.ZERO, rad, a0, a0 + TAU / 24.0, 8, Color(colm, 0.75), 6, true)
		for i in 6:
			var k := fmod(t * 0.9 + i / 6.0, 1.0)
			var ang := i * TAU / 6.0 + 0.4
			var p := Vector2.RIGHT.rotated(ang) * rad * (1.6 - k * 0.6)
			draw_circle(p, 5 * (1.0 - k) + 2, Color(0.8, 0.9, 1.0, 0.7 * (1.0 - k)))
	# ondas elementais
	for r in rings:
		var rp: float = r["t"] / 0.9
		var col: Color = r["color"] if r.has("color") else G.ELEM[r["elem"]]
		draw_arc(cell_to_local(r["pos"]), 30 + rp * G.TILE * 5.0, 0, TAU, 48, Color(col, 1.0 - rp), 10.0 * (1.0 - rp) + 2, true)
	# itens (sempre em pé)
	for c in items:
		var lp := cell_to_local(Vector2(c))
		draw_set_transform(lp, -rotation, Vector2.ONE)
		_shadow(Vector2(0, 16), 16)
		G.draw_item(self, items[c], Vector2(0, -6 + sin(t * 3.0 + c.x) * 4.0), 20)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	# personagens, ordenados pela altura na tela
	var actors: Array = monsters.duplicate()
	if tobe:
		actors.append(tobe)
	actors.sort_custom(func(x, y): return cell_to_local(x.cpos).rotated(rotation).y < cell_to_local(y.cpos).rotated(rotation).y)
	for a in actors:
		var lp := cell_to_local(a.cpos)
		draw_set_transform(lp, -rotation, Vector2.ONE)
		if a.kind == "tobe":
			_draw_tobe(a, t)
		else:
			_shadow(Vector2(0, 20), 22)
			var hop: float = -abs(sin(a.anim * 10.0)) * 5.0 if a.moving else 0.0
			G.draw_monster(self, a.kind, Vector2(0, 8 + hop), G.TILE * 0.42, a.weak, a.anim)
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)


func sand_dark_for(k: float) -> Color:
	return G.SAND_DARK.lerp(sea_color.darkened(0.3), k)


func _shadow(pos: Vector2, r: float) -> void:
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		pts.append(pos + Vector2(cos(a) * r, sin(a) * r * 0.38))
	draw_colored_polygon(pts, Color(0, 0, 0, 0.18))


func _draw_tobe(a: Actor, t: float) -> void:
	_shadow(Vector2(0, 22), 20)
	if a.invuln > 0.0 and fmod(a.invuln, 0.2) < 0.1:
		return
	var hop: float = -abs(sin(a.anim * 12.0)) * 7.0 if a.moving else 0.0
	var breathe := 1.0 + sin(t * 3.0) * 0.03
	var tx := G.tex("tobe")
	if tx:
		var sz := tx.get_size()
		var k := G.TILE * 0.95 / sz.y
		var size := Vector2(sz.x * k * a.facing / breathe, sz.y * k * breathe)
		var pos := Vector2(-size.x * 0.5, 22 - abs(size.y) + hop)
		draw_texture_rect(tx, Rect2(pos, size), false)
	else:
		G.outlined_circle(self, Vector2(0, hop), 22, Color("9bd27a"), Color("3f7f2c"), 6)
	if shield:
		draw_arc(Vector2(0, -8 + hop), 36, 0, TAU, 32, Color(0.5, 0.85, 1.0, 0.7), 4, true)
	# poderes ligados aparecem em cima da cabeça do Tobé
	if powers_on.get("soco", false):
		draw_arc(Vector2(0, -8 + hop), 40 + sin(t * 12.0) * 3.0, 0, TAU, 32, Color(1.0, 0.6, 0.2, 0.8), 5, true)
		G.draw_power(self, "soco", Vector2(30, -66 + hop + sin(t * 10.0) * 4.0), 15)
	if powers_on.get("conserto", false):
		G.draw_power(self, "conserto", Vector2(-30, -66 + hop), 15)
	if a.stun > 0.0:
		for i in 3:
			var ang := t * 6.0 + i * TAU / 3.0
			G.draw_symbol(self, -1, Vector2(cos(ang) * 20, -52 + sin(ang) * 6), 7, Color("ffe066"), Color("b8860b"), 2)
	elif a.fleeing:
		G.rounded_box(self, Rect2(Vector2(-10, -78 + hop), Vector2(20, 26)), Color.WHITE, Color("c0392b"), 3, 8)
		draw_string(ThemeDB.fallback_font, Vector2(-4, -58 + hop), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("c0392b"))
