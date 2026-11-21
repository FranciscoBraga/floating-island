extends Control
## Interface: corações, pontos, combo, avisos, controles de toque, menu e fim de jogo.

var main: Node
var mode := "menu"
var paused := false
var t := 0.0
var combo_pop := 0.0
var last_combo := 0

var lbl_score: Label
var lbl_size: Label
var lbl_world: Label
var lbl_combo: Label
var lbl_banner: Label
var lbl_sub: Label
var lbl_title: Label
var lbl_center: Label
var lbl_info: Label
var lbl_current: Label
var banner_t := 0.0

var spin_touches := {}   # índice do dedo -> lado (-1 esquerda, 1 direita)

var options_open := false
var album_open := false   # tela do álbum (coleção), aberta pelo menu
var drag_slider := ""    # canal de áudio sendo arrastado no painel de opções
var drag_index := -1


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	var ink := Color("1d2b4a")
	lbl_score = _label(44, Color("fff3c4"), ink, 12, HORIZONTAL_ALIGNMENT_RIGHT)
	lbl_size = _label(26, Color.WHITE, ink, 9, HORIZONTAL_ALIGNMENT_LEFT)
	lbl_world = _label(22, Color("d6f6ff"), ink, 8, HORIZONTAL_ALIGNMENT_RIGHT)
	lbl_combo = _label(56, Color("ffe066"), Color("8a4b00"), 14, HORIZONTAL_ALIGNMENT_CENTER)
	lbl_banner = _label(50, Color("fff3c4"), Color("1d4f8c"), 14, HORIZONTAL_ALIGNMENT_CENTER)
	lbl_sub = _label(26, Color.WHITE, ink, 9, HORIZONTAL_ALIGNMENT_CENTER)
	lbl_title = _label(84, Color("fff3c4"), Color("1d4f8c"), 20, HORIZONTAL_ALIGNMENT_CENTER)
	lbl_center = _label(34, Color.WHITE, ink, 10, HORIZONTAL_ALIGNMENT_CENTER)
	lbl_info = _label(30, Color("4a3418"), Color(0, 0, 0, 0), 0, HORIZONTAL_ALIGNMENT_CENTER)
	lbl_current = _label(32, Color.WHITE, Color("17788f"), 10, HORIZONTAL_ALIGNMENT_CENTER)
	lbl_info.label_settings.shadow_size = 0
	lbl_info.label_settings.shadow_color = Color(0, 0, 0, 0)
	for l in [lbl_title, lbl_banner, lbl_sub, lbl_center, lbl_info]:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _label(size: int, color: Color, outline: Color, osize: int, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.label_settings = G.label_settings(size, color, outline, osize)
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


# ---------- trocas de tela ----------

func show_menu() -> void:
	mode = "menu"
	t = 0.0


func show_play() -> void:
	mode = "play"
	paused = false


func show_game_over(_reason: String, _record: bool) -> void:
	mode = "over"
	t = 0.0


func set_paused(p: bool) -> void:
	paused = p


func banner(title: String, sub: String) -> void:
	lbl_banner.text = title
	lbl_sub.text = sub
	banner_t = 3.2


# ---------- atualização ----------

func _process(delta: float) -> void:
	t += delta
	banner_t = max(0.0, banner_t - delta)
	var vp := get_viewport_rect().size
	size = vp
	var playing: bool = mode == "play"

	lbl_score.visible = playing
	lbl_size.visible = playing
	lbl_world.visible = playing
	lbl_score.text = _fmt(main.score)
	_place(lbl_score, Vector2(vp.x - 424, 18), Vector2(400, 54))
	lbl_world.text = "Mundo %d · %s" % [main.world_idx + 1, G.WORLDS[main.world_idx]["name"]]
	_place(lbl_world, Vector2(vp.x - 424, 70), Vector2(400, 30))
	var n: int = main.island.cells.size()
	lbl_size.text = "Ilha: %d %s" % [n, "peça" if n == 1 else "peças"]
	_place(lbl_size, Vector2(22, 72), Vector2(400, 34))

	var mult: int = main.combo_mult()
	if main.combo != last_combo:
		if main.combo > last_combo:
			combo_pop = 1.0
		last_combo = main.combo
	combo_pop = max(0.0, combo_pop - delta * 4.0)
	lbl_combo.visible = playing and mult > 1
	lbl_combo.text = "×%d" % mult
	_place(lbl_combo, Vector2(vp.x * 0.5 - 120, 110), Vector2(240, 70))
	lbl_combo.pivot_offset = lbl_combo.size * 0.5
	lbl_combo.scale = Vector2.ONE * (1.0 + combo_pop * 0.35)

	var bshow: bool = banner_t > 0.0 and mode == "play"
	lbl_banner.visible = bshow
	lbl_sub.visible = bshow
	if bshow:
		var a: float = clamp(banner_t / 0.4, 0.0, 1.0) * clamp((3.2 - banner_t) / 0.25, 0.0, 1.0)
		lbl_banner.modulate.a = a
		lbl_sub.modulate.a = a
		_place(lbl_banner, Vector2(30, vp.y * 0.24), Vector2(vp.x - 60, 120))
		_place(lbl_sub, Vector2(40, vp.y * 0.24 + 112), Vector2(vp.x - 80, 70))

	lbl_current.visible = playing and (main.current_warn > 0.0 or main.current_left > 0.0)
	lbl_current.text = "Corrente!"
	_place(lbl_current, Vector2(vp.x * 0.5 - 150, vp.y - 200), Vector2(300, 44))

	lbl_title.visible = mode == "menu" and not options_open and not album_open
	lbl_center.visible = (mode != "play" or paused) and not options_open and not album_open
	lbl_info.visible = mode == "over"
	match mode:
		"menu":
			lbl_title.text = "Ilha Flutuante"
			_place(lbl_title, Vector2(20, 20), Vector2(vp.x - 40, 130))
			lbl_center.text = "Toque para jogar" if fmod(t, 1.2) < 0.85 else ""
			_place(lbl_center, Vector2(20, vp.y - 100), Vector2(vp.x - 40, 60))
		"over":
			lbl_center.text = main.death_reason
			_place(lbl_center, Vector2(vp.x * 0.5 - 260, vp.y * 0.5 - 225), Vector2(520, 90))
			lbl_info.text = "Pontos: %s\nMaior ilha: %d peças\nMelhor combo: %d\nTempo: %s\n\nRecorde: %s" % [
				_fmt(main.score), main.max_size, main.best_combo, _time(main.game_time), _fmt(main.best_score)]
			_place(lbl_info, Vector2(vp.x * 0.5 - 240, vp.y * 0.5 - 160), Vector2(480, 290))
		_:
			if paused:
				lbl_center.text = "Pausado\ntoque para continuar"
				_place(lbl_center, Vector2(20, vp.y * 0.42), Vector2(vp.x - 40, 120))
	if options_open:
		# o painel de opções fica por cima de tudo: esconde os textos soltos
		for l in [lbl_combo, lbl_banner, lbl_sub, lbl_current]:
			l.visible = false
	queue_redraw()


func _place(l: Label, pos: Vector2, sz: Vector2) -> void:
	l.position = pos
	l.size = sz


func _fmt(n: int) -> String:
	var s := str(n)
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "." + out
	return out


func _time(sec: float) -> String:
	return "%d:%02d" % [int(sec) / 60, int(sec) % 60]


# ---------- toques ----------

## Centro de cada ícone de poder (fileira embaixo, no meio da tela).
func _power_slot(vp: Vector2, i: int) -> Vector2:
	# 4 poderes das cores + o 5º espaço (especial) um pouco mais afastado
	var gap := 108.0
	var x := (i - 2.0) * gap + (14.0 if i == 4 else 0.0)
	return Vector2(vp.x * 0.5 + x, vp.y - 82)


func _pause_button(vp: Vector2) -> Vector2:
	return Vector2(vp.x - 52, 132)


## Engrenagem: ao lado do pause no jogo, no canto de cima na tela inicial.
func _options_button(vp: Vector2) -> Vector2:
	if mode == "play":
		return Vector2(vp.x - 116, 132)
	return Vector2(vp.x - 52, 52)


func _options_panel(vp: Vector2) -> Rect2:
	var sz := Vector2(min(600.0, vp.x - 40), 430)
	return Rect2(vp * 0.5 - sz * 0.5, sz)


func _slider_rect(vp: Vector2, i: int) -> Rect2:
	var p := _options_panel(vp)
	return Rect2(p.position.x + 190, p.position.y + 118 + i * 82, p.size.x - 300, 28)


## Botões do painel: [id, texto, cor, cor escura].
func _option_buttons() -> Array:
	var list := [["continuar", "Continuar" if mode == "play" else "Voltar", Color("5cc85a"), Color("23722f")]]
	if mode == "play":
		list.append(["menu", "Menu inicial", Color("f0a33a"), Color("8a5200")])
	if main.can_quit():
		list.append(["sair", "Sair do jogo", Color("e8505b"), Color("7a1420")])
	return list


func _option_button_rect(vp: Vector2, i: int, n: int) -> Rect2:
	var p := _options_panel(vp)
	var gap := 16.0
	var w := (p.size.x - 60 - gap * (n - 1)) / n
	return Rect2(p.position.x + 30 + i * (w + gap), p.end.y - 120, w, 80)


func _slider_value_at(vp: Vector2, i: int, x: float) -> float:
	var r := _slider_rect(vp, i)
	return clamp((x - r.position.x) / r.size.x, 0.0, 1.0)


const SLIDERS := [["Musica", "Música"], ["Efeitos", "Efeitos"]]


## Toques dentro do painel de opções. Sempre consome o toque.
func _options_touch(e: InputEventScreenTouch, vp: Vector2) -> void:
	if not e.pressed:
		if e.index == drag_index:
			if drag_slider == "Efeitos":
				main.sfx.play("click")
			drag_slider = ""
			drag_index = -1
		return
	for i in SLIDERS.size():
		var hit := _slider_rect(vp, i).grow_individual(14, 22, 14, 22)
		if hit.has_point(e.position):
			drag_slider = SLIDERS[i][0]
			drag_index = e.index
			main.sfx.set_volume(drag_slider, _slider_value_at(vp, i, e.position.x))
			return
		# ícone do alto-falante: liga/desliga o som do canal
		var spk := Vector2(_slider_rect(vp, i).end.x + 52, _slider_rect(vp, i).get_center().y)
		if e.position.distance_to(spk) < 30:
			var bus: String = SLIDERS[i][0]
			main.sfx.set_volume(bus, 0.0 if main.sfx.get_volume(bus) > 0.0 else 0.8)
			main.sfx.play("click")
			return
	var btns := _option_buttons()
	for i in btns.size():
		if _option_button_rect(vp, i, btns.size()).has_point(e.position):
			match btns[i][0]:
				"continuar": main.close_options()
				"menu": main.quit_to_menu()
				"sair": main.quit_game()
			return
	if not _options_panel(vp).has_point(e.position):
		main.close_options()


func _play_again_rect(vp: Vector2) -> Rect2:
	return Rect2(vp.x * 0.5 - 170, vp.y * 0.5 + 150, 340, 90)


## Jogo: tocar numa peça da ilha guia o Tobé; tocar no resto da tela gira e
## move a ilha para aquele lado (metade esquerda ↺ e para a esquerda, direita ↻ e para a direita).
func _input(event: InputEvent) -> void:
	var vp := get_viewport_rect().size
	if album_open:
		if event is InputEventScreenTouch and event.pressed:
			_album_touch(event.position, vp)
		if event is InputEventScreenTouch or event is InputEventScreenDrag:
			accept_event()
		return
	if options_open:
		if event is InputEventScreenTouch:
			_options_touch(event, vp)
			accept_event()
		elif event is InputEventScreenDrag and event.index == drag_index and drag_slider != "":
			var i := 0 if drag_slider == "Musica" else 1
			main.sfx.set_volume(drag_slider, _slider_value_at(vp, i, event.position.x))
			accept_event()
		return
	if event is InputEventScreenTouch:
		var e := event as InputEventScreenTouch
		if e.pressed:
			if mode != "over" and e.position.distance_to(_options_button(vp)) < 40:
				for idx in spin_touches:
					main.spin_release(spin_touches[idx])
				spin_touches.clear()
				main.open_options()
				accept_event()
				return
			if mode == "menu" and _album_button(vp).has_point(e.position):
				album_open = true
				main.sfx.play("click", 1.2)
				accept_event()
				return
			if mode == "menu":
				main.start_game()
				accept_event()
				return
			if mode == "over":
				if t > 0.8 and _play_again_rect(vp).has_point(e.position):
					main.start_game()
				accept_event()
				return
			if paused:
				main.toggle_pause()
				accept_event()
				return
			var hit_power := -1
			for i in G.POWERS.size() + 1:
				if e.position.distance_to(_power_slot(vp, i)) < 46:
					hit_power = i
			if e.position.distance_to(_pause_button(vp)) < 40:
				main.toggle_pause()
			elif hit_power == G.POWERS.size():
				main.activate_special()
			elif hit_power >= 0:
				main.activate_power(G.POWERS[hit_power])
			elif main.tap_incoming(e.position):
				pass
			elif not main.tap_island(e.position):
				var dir := -1 if e.position.x < vp.x * 0.5 else 1
				spin_touches[e.index] = dir
				main.spin_press(dir)
			accept_event()
		elif spin_touches.has(e.index):
			var dir: int = spin_touches[e.index]
			spin_touches.erase(e.index)
			if not spin_touches.values().has(dir):
				main.spin_release(dir)
			accept_event()


# ---------- desenho ----------

func _draw() -> void:
	var vp := size
	if mode == "play":
		_draw_markers(vp)
		_draw_hearts()
		_draw_challenge()
		_draw_pause(vp)
		_draw_powers(vp)
		if main.current_warn > 0.0 or main.current_left > 0.0:
			_draw_current(vp)
		if paused:
			draw_rect(Rect2(Vector2.ZERO, vp), Color(0.05, 0.1, 0.2, 0.55))
	elif mode == "menu":
		_draw_menu(vp)
		if album_open:
			_draw_album(vp)
	elif mode == "over":
		_draw_over(vp)
	if mode != "over" and not album_open:
		_draw_options_button(vp)
	if options_open:
		_draw_options(vp)


func _draw_options_button(vp: Vector2) -> void:
	var c := _options_button(vp)
	G.outlined_circle(self, c, 26, Color(1, 1, 1, 0.22), Color(1, 1, 1, 0.55), 4)
	# engrenagem: 8 dentes + anel
	var pts := PackedVector2Array()
	for k in 32:
		var a := TAU * k / 32.0
		var r := 15.0 if (k / 2) % 2 == 0 else 11.0
		pts.append(c + Vector2.from_angle(a) * r)
	draw_colored_polygon(pts, Color.WHITE)
	draw_circle(c, 5, Color(0.25, 0.45, 0.6))


func _draw_speaker(c: Vector2, on: bool, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([c + Vector2(-16, -6), c + Vector2(-8, -6), c + Vector2(2, -15),
		c + Vector2(2, 15), c + Vector2(-8, 6), c + Vector2(-16, 6)]), col)
	if on:
		draw_arc(c + Vector2(4, 0), 8, -PI / 3, PI / 3, 10, col, 3, true)
		draw_arc(c + Vector2(4, 0), 15, -PI / 3, PI / 3, 12, col, 3, true)
	else:
		draw_line(c + Vector2(7, -7), c + Vector2(19, 7), Color("e8505b"), 4)
		draw_line(c + Vector2(19, -7), c + Vector2(7, 7), Color("e8505b"), 4)


func _draw_options(vp: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.05, 0.1, 0.2, 0.6))
	var p := _options_panel(vp)
	var ink := Color("4a3418")
	G.rounded_box(self, p.grow(8), Color("8a5a2b"), Color(0, 0, 0, 0), 0, 44)
	G.rounded_box(self, p, Color("fff3e0"), Color("c08f4c"), 8, 36)
	draw_string(G.font, Vector2(p.position.x, p.position.y + 66), "Opções", HORIZONTAL_ALIGNMENT_CENTER, p.size.x, 44, Color("1d4f8c"))
	for i in SLIDERS.size():
		var bus: String = SLIDERS[i][0]
		var v: float = main.sfx.get_volume(bus)
		var r := _slider_rect(vp, i)
		draw_string(G.font, Vector2(p.position.x + 34, r.get_center().y + 10), SLIDERS[i][1], HORIZONTAL_ALIGNMENT_LEFT, 150, 28, ink)
		G.rounded_box(self, r, Color(0, 0, 0, 0.15), Color("c08f4c"), 3, 14)
		if v > 0.0:
			G.rounded_box(self, Rect2(r.position + Vector2(3, 3), Vector2(max(22.0, (r.size.x - 6) * v), r.size.y - 6)), Color("4fb3d9"), Color(0, 0, 0, 0), 0, 11)
		var knob := Vector2(r.position.x + r.size.x * v, r.get_center().y)
		G.outlined_circle(self, knob, 20 if drag_slider == bus else 17, Color.WHITE, Color("1d4f8c"), 4)
		draw_string(G.font, Vector2(r.position.x, r.end.y + 26), "%d%%" % roundi(v * 100.0), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 18, Color(ink, 0.7))
		_draw_speaker(Vector2(r.end.x + 52, r.get_center().y), v > 0.0, ink)
	var btns := _option_buttons()
	for i in btns.size():
		var b := _option_button_rect(vp, i, btns.size())
		G.rounded_box(self, b.grow(5), btns[i][3], Color(0, 0, 0, 0), 0, 30)
		G.rounded_box(self, b, btns[i][2], btns[i][2].lightened(0.3), 4, 26)
		draw_string(G.font, Vector2(b.position.x, b.get_center().y + 10), btns[i][1], HORIZONTAL_ALIGNMENT_CENTER, b.size.x, 26, Color.WHITE)


func _draw_hearts() -> void:
	for i in 5:
		var pos := Vector2(42 + i * 50, 42)
		if i < main.hearts:
			var beat := 1.0 + (sin(t * 10.0) * 0.08 if main.hearts == 1 else 0.0)
			G.outlined_poly(self, G.heart_points(pos, 19 * beat), Color("ff4d6d"), Color("9e1030"), 4)
			draw_circle(pos + Vector2(-7, -6), 4, Color(1, 1, 1, 0.7))
		elif i < 3:
			G.outlined_poly(self, G.heart_points(pos, 17), Color(0, 0, 0, 0.25), Color(1, 1, 1, 0.5), 3)
	var x: float = 42.0 + max(3, main.hearts) * 50.0
	if main.island.shield:
		G.draw_item(self, "escudo", Vector2(x, 42), 18)
		x += 46
	if main.anchor_t > 0.0:
		G.draw_item(self, "ancora", Vector2(x, 42), 18)
		draw_arc(Vector2(x, 42), 26, -PI / 2, -PI / 2 + TAU * main.anchor_t / 10.0, 24, Color.WHITE, 4, true)
		x += 52
	if main.island.tobe and main.island.tobe.food_t > 0.0:
		G.draw_item(self, "comida", Vector2(x, 42), 18)


## Desafio do Tobé: cartão embaixo do tamanho da ilha, com o prêmio, o texto e o progresso.
func _draw_challenge() -> void:
	var c: Dictionary = main.challenge
	if c.is_empty():
		return
	var r := Rect2(16, 112, 330, 60)
	var fresh: float = clamp(1.0 - c["t"] / 0.6, 0.0, 1.0)
	G.rounded_box(self, r.grow(fresh * 6.0), Color(0.05, 0.15, 0.3, 0.45), Color(1, 0.95, 0.75, 0.7 + fresh * 0.3), 3, 16)
	G.draw_power(self, main.challenge_prize(), r.position + Vector2(32, 30), 21)
	var x := r.position.x + 62
	draw_string(G.font, Vector2(x, r.position.y + 24), main.challenge_text(), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 72, 19, Color.WHITE)
	var bar := Rect2(Vector2(x, r.position.y + 34), Vector2(r.size.x - 120, 14))
	var frac: float = clamp(float(c["n"]) / c["goal"], 0.0, 1.0)
	G.rounded_box(self, bar, Color(0, 0, 0, 0.35), Color(1, 1, 1, 0.5), 2, 7)
	if frac > 0.0:
		G.rounded_box(self, Rect2(bar.position + Vector2(2, 2), Vector2((bar.size.x - 4) * frac, bar.size.y - 4)), G.GOLD, Color(0, 0, 0, 0), 0, 5)
	draw_string(G.font, Vector2(bar.end.x + 8, bar.end.y), "%d/%d" % [min(c["n"], c["goal"]), c["goal"]], HORIZONTAL_ALIGNMENT_LEFT, 60, 18, Color("fff3c4"))


func _draw_pause(vp: Vector2) -> void:
	var pb := _pause_button(vp)
	G.outlined_circle(self, pb, 26, Color(1, 1, 1, 0.22), Color(1, 1, 1, 0.55), 4)
	draw_rect(Rect2(pb + Vector2(-9, -10), Vector2(6, 20)), Color.WHITE)
	draw_rect(Rect2(pb + Vector2(3, -10), Vector2(6, 20)), Color.WHITE)


## Fileira de poderes: ícone + barrinha. Cheia = brilha e pode tocar; ligado = barra esvaziando.
func _draw_powers(vp: Vector2) -> void:
	for i in G.POWERS.size():
		var id: String = G.POWERS[i]
		var info: Dictionary = G.POWER_INFO[id]
		var c := _power_slot(vp, i)
		var charge: float = main.power_charge[id]
		var left: float = main.power_left[id]
		var active := left > 0.0
		var ready := charge >= 1.0 and not active
		var r := 30.0
		if ready:
			var pulse := 0.5 + 0.5 * sin(t * 7.0)
			draw_circle(c, r + 10 + pulse * 5, Color(info["color"], 0.25 + pulse * 0.2))
			r += pulse * 3.0
		if active:
			draw_arc(c, r + 9, 0, TAU, 32, Color(1, 1, 1, 0.8), 4, true)
		G.draw_power(self, id, c, r, not ready and not active)
		# barrinha
		var bar := Rect2(c + Vector2(-40, 40), Vector2(80, 14))
		var fill: float = (left / max(0.01, info["dur"])) if (active and info["dur"] > 0.0) else charge
		if active and info["dur"] <= 0.0:
			fill = left / 0.6
		G.rounded_box(self, bar, Color(0, 0, 0, 0.35), Color(1, 1, 1, 0.6), 2, 7)
		if fill > 0.0:
			var fr := Rect2(bar.position + Vector2(2, 2), Vector2((bar.size.x - 4) * clamp(fill, 0.0, 1.0), bar.size.y - 4))
			var fc: Color = info["color"].lightened(0.25) if (ready or active) else info["color"]
			G.rounded_box(self, fr, fc, Color(0, 0, 0, 0), 0, 5)
		draw_string(G.font, c + Vector2(-r - 4, -r + 6), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 1, 1, 0.8))
		# símbolo da cor que enche este poder
		var el: int = G.ELEM_POWER.find(id)
		G.draw_symbol(self, el, c + Vector2(r - 2, -r + 4), 9, G.ELEM[el], G.ELEM_DARK[el], 2)
	_draw_special(vp)


## 5º espaço: poder especial (vazio, guardado e brilhando, ou ligado esvaziando).
func _draw_special(vp: Vector2) -> void:
	var c := _power_slot(vp, G.POWERS.size())
	var id: String = main.special
	var r := 30.0
	if id == "":
		draw_arc(c, r, 0, TAU, 28, Color(1, 1, 1, 0.35), 3, true)
		draw_string(G.font, c + Vector2(-r, 9), "?", HORIZONTAL_ALIGNMENT_CENTER, r * 2, 26, Color(1, 1, 1, 0.4))
		return
	var info: Dictionary = G.SPECIAL_INFO[id]
	var active: bool = main.special_left > 0.0
	if not active:
		var pulse := 0.5 + 0.5 * sin(t * 7.0)
		draw_circle(c, r + 10 + pulse * 5, Color(info["color"], 0.3 + pulse * 0.2))
		r += pulse * 3.0
	else:
		draw_arc(c, r + 9, 0, TAU, 32, Color(1, 1, 1, 0.8), 4, true)
	G.draw_power(self, id, c, r)
	var bar := Rect2(c + Vector2(-40, 40), Vector2(80, 14))
	var fill: float = main.special_left / info["dur"] if active else 1.0
	G.rounded_box(self, bar, Color(0, 0, 0, 0.35), Color(1, 1, 1, 0.6), 2, 7)
	G.rounded_box(self, Rect2(bar.position + Vector2(2, 2), Vector2((bar.size.x - 4) * fill, bar.size.y - 4)), info["color"].lightened(0.25), Color(0, 0, 0, 0), 0, 5)
	draw_string(G.font, c + Vector2(-r - 4, -r + 6), "5", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 1, 1, 0.8))


## Avisos nas bordas da tela para ilhas que ainda vão entrar.
func _draw_markers(vp: Vector2) -> void:
	if vp.x < 300.0 or vp.y < 300.0:
		return  # primeiro quadro: a HUD ainda não tem tamanho
	var cam: Camera2D = main.cam
	var cen := cam.get_screen_center_position()
	var z := cam.zoom.x
	var m := 48.0
	var inner := Rect2(Vector2(m, m + 90), vp - Vector2(m * 2, m * 2 + 90 + 150))
	for inc in main.incoming_root.get_children():
		if inc.drifting:
			continue
		var sp: Vector2 = (inc.position - cen) * z + vp * 0.5
		if Rect2(Vector2.ZERO, vp).grow(-10).has_point(sp):
			continue
		var cp := Vector2(clamp(sp.x, inner.position.x, inner.end.x), clamp(sp.y, inner.position.y, inner.end.y))
		var dist := sp.distance_to(cp)
		if dist > 700:
			continue
		var alpha: float = clamp(1.2 - dist / 700.0, 0.25, 1.0)
		var dir := (sp - cp).normalized()
		# mostra a cor do lado que vai encostar na ilha
		var fe: int = inc.facing_edge(main.island.position)
		var col: Color = G.GOLD if inc.wild else G.ELEM[fe]
		var dark: Color = G.GOLD_DARK if inc.wild else G.ELEM_DARK[fe]
		var pulse := 1.0 + sin(t * 8.0) * 0.06
		var tip := cp + dir * 40
		draw_colored_polygon(PackedVector2Array([tip, cp + dir.orthogonal() * 16 + dir * 22, cp - dir.orthogonal() * 16 + dir * 22]), Color(dark, alpha))
		G.outlined_circle(self, cp, 26 * pulse, Color(col, alpha), Color(dark, alpha), 5)
		if inc.wild:
			G.draw_symbol(self, -1, cp, 13, Color(1, 1, 1, alpha), Color(dark, alpha), 2)
		else:
			G.draw_symbol(self, fe, cp, 12, Color(1, 1, 1, alpha), Color(dark, alpha), 2)
		if inc.cargo == "monster":
			G.outlined_circle(self, cp + Vector2(20, -20), 12, Color("ff4d4d"), Color("7a0f0f"), 3)
			draw_string(G.font, cp + Vector2(16, -13), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
		elif inc.cargo == "item":
			G.draw_item(self, inc.kind, cp + Vector2(22, -20), 10)


func _draw_current(vp: Vector2) -> void:
	var c := Vector2(vp.x * 0.5, vp.y - 240)
	var d: Vector2 = main.current_dir
	var a := 0.6 + 0.4 * sin(t * 10.0)
	for i in 3:
		var p := c + d * (i - 1) * 46 + d * fmod(t * 60.0, 46.0)
		var pts := PackedVector2Array([p + d * 26, p - d * 10 + d.orthogonal() * 22, p - d * 10 - d.orthogonal() * 22])
		G.outlined_poly(self, pts, Color(1, 1, 1, a), Color("17788f"), 4)


func _draw_menu(vp: Vector2) -> void:
	var tx := G.tex("tobe")
	if tx:
		var s := 1.25 + sin(t * 2.0) * 0.03
		var sz := tx.get_size() * s
		var tr := Rect2(Vector2(vp.x * 0.22 - sz.x * 0.5, 175 + sin(t * 2.4) * 10.0), sz)
		draw_texture_rect(tx, tr, false)
		if main.outfit != "":
			G.draw_outfit(self, main.outfit, tr)
	var p := Rect2(vp.x * 0.5 + 90, 160, min(540.0, vp.x * 0.5 - 110), 340)
	G.rounded_box(self, p, Color(1, 0.97, 0.88, 0.92), Color("c08f4c"), 6, 30)
	var lines := ["Toque à esquerda/direita: gira e anda.", "Segurar acelera (com limite).",
		"Encoste bordas da mesma cor.", "As peças afundam em 60 segundos!",
		"Toque na ilha para guiar o Tobé.", "Cada cor enche um poder: toque no ícone.", "Teclado: setas giram · 1-5 poderes."]
	for i in lines.size():
		draw_string(G.font, Vector2(p.position.x + 30, p.position.y + 42 + i * 41), lines[i], HORIZONTAL_ALIGNMENT_LEFT, p.size.x - 40, 22, Color("4a3418"))
	_draw_album_button(vp)
	if main.best_score > 0:
		draw_string(G.font, Vector2(p.position.x, p.end.y + 40), "Recorde: %s pontos · ilha de %d" % [_fmt(main.best_score), main.best_size], HORIZONTAL_ALIGNMENT_CENTER, p.size.x, 24, Color.WHITE)


func _draw_over(vp: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.05, 0.1, 0.2, 0.5))
	var k: float = clamp(t / 0.35, 0.0, 1.0)
	var ease_k := 1.0 - pow(1.0 - k, 3.0)
	var panel := Rect2(vp.x * 0.5 - 280, vp.y * 0.5 - 250 + (1.0 - ease_k) * 200.0, 560, 520)
	G.rounded_box(self, panel.grow(8), Color("8a5a2b"), Color(0, 0, 0, 0), 0, 44)
	G.rounded_box(self, panel, Color("fff3e0"), Color("c08f4c"), 8, 36)
	var b := _play_again_rect(vp)
	var pulse := 1.0 + sin(t * 5.0) * 0.03
	var br := Rect2(b.get_center() - b.size * 0.5 * pulse, b.size * pulse)
	G.rounded_box(self, br.grow(6), Color("23722f"), Color(0, 0, 0, 0), 0, 34)
	G.rounded_box(self, br, Color("5cc85a"), Color("8fe08a"), 4, 30)
	draw_string(G.font, Vector2(br.position.x, br.get_center().y + 13), "Jogar de novo", HORIZONTAL_ALIGNMENT_CENTER, br.size.x, 36, Color.WHITE)
	if main.score >= main.best_score and main.score > 0:
		var star_c := Vector2(panel.get_center().x, panel.position.y - 48)
		G.draw_symbol(self, -1, star_c, 48 + sin(t * 6.0) * 4.0, G.GOLD, G.GOLD_DARK, 6)
		G.rounded_box(self, Rect2(star_c + Vector2(-110, 34), Vector2(220, 40)), G.GOLD, G.GOLD_DARK, 4, 20)
		draw_string(G.font, star_c + Vector2(-110, 62), "Novo recorde!", HORIZONTAL_ALIGNMENT_CENTER, 220, 24, Color("6b4a00"))


# ---------- álbum (coleção) ----------

func _album_button(vp: Vector2) -> Rect2:
	return Rect2(24, vp.y - 92, 220, 64)


func _album_panel(vp: Vector2) -> Rect2:
	var sz := Vector2(min(vp.x - 32, 900.0), min(vp.y - 32, 620.0))
	return Rect2((vp - sz) * 0.5, sz)


func _album_close(vp: Vector2) -> Vector2:
	var p := _album_panel(vp)
	return Vector2(p.end.x - 40, p.position.y + 40)


func _album_row(vp: Vector2, i: int) -> Rect2:
	var p := _album_panel(vp)
	var h := (p.size.y - 100) / G.ALBUM.size()
	return Rect2(p.position.x + 20, p.position.y + 84 + i * h, p.size.x - 40, h - 10)


func _album_outfit_rect(vp: Vector2, i: int) -> Rect2:
	var r := _album_row(vp, i)
	var w: float = min(190.0, r.size.x * 0.3)
	return Rect2(r.end.x - w - 8, r.position.y + 8, w, r.size.y - 16)


func _album_touch(pos: Vector2, vp: Vector2) -> void:
	if pos.distance_to(_album_close(vp)) < 34 or not _album_panel(vp).has_point(pos):
		album_open = false
		main.sfx.play("click", 0.9)
		return
	for i in G.ALBUM.size():
		var id: String = G.ALBUM[i]["outfit"]
		if _album_outfit_rect(vp, i).has_point(pos) and main.outfit_unlocked(id):
			main.set_outfit("" if main.outfit == id else id)
			main.sfx.play("item", 1.2)


func _draw_album_button(vp: Vector2) -> void:
	var b := _album_button(vp)
	G.rounded_box(self, b.grow(5), Color("8a5a2b"), Color(0, 0, 0, 0), 0, 26)
	G.rounded_box(self, b, Color("fff3e0"), Color("c08f4c"), 4, 22)
	G.draw_shell(self, "concha_vieira", b.position + Vector2(38, 30), 20)
	var n: Vector2i = main.album_total()
	draw_string(G.font, Vector2(b.position.x + 64, b.position.y + 30), "Álbum", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color("4a3418"))
	draw_string(G.font, Vector2(b.position.x + 64, b.position.y + 54), "%d de %d" % [n.x, n.y], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("8a5a2b"))


func _draw_album(vp: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.05, 0.1, 0.2, 0.6))
	var p := _album_panel(vp)
	G.rounded_box(self, p.grow(8), Color("8a5a2b"), Color(0, 0, 0, 0), 0, 40)
	G.rounded_box(self, p, Color("fff3e0"), Color("c08f4c"), 6, 34)
	var ink := Color("4a3418")
	var n: Vector2i = main.album_total()
	draw_string(G.font, Vector2(p.position.x, p.position.y + 56), "Álbum do Tobé  ·  %d de %d" % [n.x, n.y], HORIZONTAL_ALIGNMENT_CENTER, p.size.x, 34, Color("1d4f8c"))
	var cc := _album_close(vp)
	G.outlined_circle(self, cc, 24, Color("ff6b6b"), Color("9e1030"), 4)
	draw_line(cc + Vector2(-9, -9), cc + Vector2(9, 9), Color.WHITE, 5)
	draw_line(cc + Vector2(9, -9), cc + Vector2(-9, 9), Color.WHITE, 5)
	for i in G.ALBUM.size():
		var page: Dictionary = G.ALBUM[i]
		var r := _album_row(vp, i)
		var done: bool = main.page_done(page)
		G.rounded_box(self, r, Color(1, 1, 1, 0.55) if not done else Color("fff6c8"), Color("e0c79a"), 3, 18)
		draw_string(G.font, r.position + Vector2(16, 28), page["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, ink)
		var orr := _album_outfit_rect(vp, i)
		var items: Array = page["items"]
		var avail: float = orr.position.x - r.position.x - 24
		var step: float = min(avail / items.size(), 92.0)
		var sr: float = clamp(min(step * 0.36, (r.size.y - 52) * 0.42), 12.0, 28.0)
		for k in items.size():
			var id: String = items[k]
			var c := Vector2(r.position.x + 16 + step * (k + 0.5), r.position.y + 36 + (r.size.y - 36) * 0.5)
			var cnt: int = main.album.get(id, 0)
			if cnt > 0:
				draw_circle(c, sr + 8, Color(1, 1, 1, 0.8))
				G.draw_album_item(self, id, c, sr)
				if cnt > 1:
					draw_string(G.font, c + Vector2(sr - 4, sr + 6), "×%d" % cnt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("8a5a2b"))
			else:
				draw_circle(c, sr + 8, Color(0.55, 0.45, 0.3, 0.18))
				draw_string(G.font, c + Vector2(-sr, 9), "?", HORIZONTAL_ALIGNMENT_CENTER, sr * 2, 26, Color(0.55, 0.45, 0.3, 0.6))
		# prêmio da página: visual do Tobé
		var oid: String = page["outfit"]
		var using: bool = main.outfit == oid
		G.rounded_box(self, orr, Color("5cc85a") if using else (Color("ffffff") if done else Color(0, 0, 0, 0.08)), Color("23722f") if using else Color("c08f4c"), 3, 14)
		draw_string(G.font, Vector2(orr.position.x + 4, orr.position.y + 20), G.OUTFITS[oid], HORIZONTAL_ALIGNMENT_CENTER, orr.size.x - 8, 15, Color.WHITE if using else ink)
		var tx := G.tex("tobe")
		var th: float = max(20.0, orr.size.y - 62)
		var tw: float = th * 0.76
		var trr := Rect2(Vector2(orr.get_center().x - tw * 0.5, orr.position.y + 36), Vector2(tw, th))
		if tx:
			draw_texture_rect(tx, trr, false, Color.WHITE if done else Color(0, 0, 0, 0.35))
		if done:
			G.draw_outfit(self, oid, trr)
		var label: String = ("Usando" if using else "Tocar para usar") if done else "Complete a página"
		draw_string(G.font, Vector2(orr.position.x, orr.end.y - 7), label, HORIZONTAL_ALIGNMENT_CENTER, orr.size.x, 14, Color.WHITE if using else ink)
