class_name MarbleAudio
extends Node

## §53 — three collision samples, pitch and volume driven by impact speed.
##
## ponytail: samples are synthesised at startup instead of shipped as .wav
## files. Three decaying blips are ~40 lines of maths and zero binary assets to
## license, name or lose. Swap in real recordings when there is an audio pass.

const RATE := 44100

var _light: AudioStreamWAV
var _mid: AudioStreamWAV
var _hard: AudioStreamWAV
var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	_light = _blip(2400.0, 0.030, 0.15)
	_mid = _blip(1250.0, 0.055, 0.40)
	_hard = _blip(680.0, 0.090, 0.75)
	# A small voice pool: a cluster break fires many contacts in one frame.
	for i in 12:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)


## Exponentially decaying sine with a noise transient — reads as a hard
## little object striking another hard little object.
func _blip(freq: float, dur: float, noise_mix: float) -> AudioStreamWAV:
	var n := int(RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(freq)
	for i in n:
		var t := float(i) / RATE
		var env: float = exp(-t / (dur * 0.28))
		var tone: float = sin(TAU * freq * t)
		# The noise burst only lives in the first few milliseconds (the "tick").
		var transient: float = exp(-t / 0.0025) * rng.randfn(0.0, 1.0) * noise_mix
		var v: float = clampf((tone * (1.0 - noise_mix * 0.5) + transient) * env, -1.0, 1.0)
		var s := int(v * 30000.0)
		data.encode_s16(i * 2, s)

	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w


## §53 — pitch and volume scale with collision velocity.
func impact(speed: float, is_wall: bool = false) -> void:
	if speed < 0.12:
		return
	var s: float = clampf(speed / 4.5, 0.0, 1.0)
	var stream := _light if s < 0.25 else (_mid if s < 0.6 else _hard)

	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = stream
	# Lighter taps ring higher; spread keeps a cluster from sounding like one note.
	p.pitch_scale = clampf(1.35 - s * 0.45, 0.6, 1.6) * randf_range(0.94, 1.06)
	if is_wall:
		p.pitch_scale *= 0.82
	p.volume_db = linear_to_db(clampf(0.18 + s * 0.82, 0.0, 1.0))
	p.play()


func sink() -> void:
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _mid
	p.pitch_scale = 0.55
	p.volume_db = linear_to_db(0.7)
	p.play()
