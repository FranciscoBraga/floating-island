extends Node
## Efeitos sonoros sintetizados na hora (não precisam de arquivos).
## Cada elemento toca uma nota do mesmo acorde (Dó maior com sétima).

const RATE := 22050
const NOTES := [523.25, 659.25, 783.99, 987.77]

var streams := {}
var players: Array[AudioStreamPlayer] = []
var next_player := 0
var music: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 10:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		players.append(p)
	for i in 4:
		streams["elem%d" % i] = _tone([NOTES[i], NOTES[i] * 2.0], 0.35, 0.0, 0.5)
	streams["gold"] = _arp([NOTES[0], NOTES[1], NOTES[2], NOTES[0] * 2.0], 0.07)
	streams["bump"] = _thump(130.0, 55.0, 0.22)
	streams["item"] = _arp([1318.5, 1760.0], 0.06)
	streams["hurt"] = _sweep(600.0, 180.0, 0.3, true)
	streams["roar"] = _growl(0.45)
	streams["wave"] = _arp([NOTES[0], NOTES[1], NOTES[2], NOTES[3], NOTES[0] * 2.0], 0.05)
	streams["sink"] = _sweep(320.0, 90.0, 0.5, false)
	streams["over"] = _arp([523.25, 392.0, 329.6, 261.6], 0.16)
	streams["start"] = _arp([392.0, 523.25, 659.25, 783.99], 0.08)
	streams["click"] = _tone([880.0], 0.06, 0.0, 0.3)
	streams["whoosh"] = _noise_sweep(0.5)
	_start_music()


func play(key: String, pitch := 1.0, volume_db := 0.0) -> void:
	if not streams.has(key):
		return
	var p := players[next_player]
	next_player = (next_player + 1) % players.size()
	p.stream = streams[key]
	p.pitch_scale = pitch
	p.volume_db = volume_db
	p.play()


func _start_music() -> void:
	# Usa a música do Suno se existir em assets/music (tema.mp3 ou tema.ogg).
	for path in ["res://assets/music/tema.ogg", "res://assets/music/tema.mp3"]:
		if ResourceLoader.exists(path):
			var stream = load(path)
			if stream is AudioStreamMP3 or stream is AudioStreamOggVorbis:
				stream.loop = true
			music = AudioStreamPlayer.new()
			music.stream = stream
			music.volume_db = -10.0
			add_child(music)
			music.play()
			return


func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		var v := int(clamp(samples[i], -1.0, 1.0) * 32000.0)
		data.encode_s16(i * 2, v)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w


func _tone(freqs: Array, dur: float, attack: float, amp: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / RATE
		var env: float = exp(-t * 9.0) * min(1.0, t / max(attack, 0.004))
		var v := 0.0
		for k in freqs.size():
			v += sin(TAU * freqs[k] * t) / float(k + 1)
		s[i] = v * env * amp
	return _wav(s)


func _arp(freqs: Array, step: float) -> AudioStreamWAV:
	var dur := step * freqs.size() + 0.3
	var n := int(dur * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / RATE
		var v := 0.0
		for k in freqs.size():
			var t0 := t - k * step
			if t0 >= 0.0:
				v += (sin(TAU * freqs[k] * t0) + 0.3 * sin(TAU * freqs[k] * 2.0 * t0)) * exp(-t0 * 10.0) * min(1.0, t0 / 0.004)
		s[i] = v * 0.32
	return _wav(s)


func _thump(f0: float, f1: float, dur: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / RATE
		var f: float = lerp(f0, f1, t / dur)
		ph += TAU * f / RATE
		s[i] = (sin(ph) * 0.8 + randf_range(-0.25, 0.25) * exp(-t * 40.0)) * exp(-t * 14.0)
	return _wav(s)


func _sweep(f0: float, f1: float, dur: float, square: bool) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / RATE
		ph += TAU * lerp(f0, f1, t / dur) / RATE
		var v := sin(ph)
		if square:
			v = sign(v) * 0.5 + v * 0.5
		s[i] = v * 0.35 * (1.0 - t / dur)
	return _wav(s)


func _growl(dur: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / RATE
		ph += TAU * (85.0 + sin(t * 40.0) * 15.0) / RATE
		var env: float = min(1.0, t / 0.05) * (1.0 - t / dur)
		s[i] = (sin(ph) * 0.6 + sin(ph * 2.03) * 0.3 + randf_range(-0.2, 0.2)) * env * 0.6
	return _wav(s)


func _noise_sweep(dur: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var last := 0.0
	for i in n:
		var t := float(i) / RATE
		var k: float = 0.05 + 0.4 * sin(PI * t / dur)
		last = lerp(last, randf_range(-1.0, 1.0), k)
		s[i] = last * sin(PI * t / dur) * 0.35
	return _wav(s)
