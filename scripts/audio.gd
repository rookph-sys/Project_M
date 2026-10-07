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
	_build_event_sounds()
	_build_aim_sounds()


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


# --------------------------------------------------------------- events ----
#
# §53-55. One synthesised cue per gameplay event, scaled by how much the event
# matters. Still no shipped audio files: these are a few lines of maths each
# and nothing to license or lose track of.

var _chime: AudioStreamWAV
var _thud: AudioStreamWAV
var _music: AudioStreamPlayer
var _music_bed: AudioStreamWAV


func _build_event_sounds() -> void:
	_chime = _blip(1760.0, 0.42, 0.04)     # bright, for a scoring event
	_thud = _blip(150.0, 0.30, 0.55)       # dull, for losing a marble


## A target leaves the ring or drops in a hole.
func score_event(pitch: float = 1.0) -> void:
	_play(_chime, 0.55 * pitch, 0.5)


## One of yours goes off the table.
func marble_lost() -> void:
	_play(_thud, 1.0, 0.55)


## Level cleared — a short rising arpeggio rather than a single note, so it
## reads as an ending and not just another hit.
func fanfare() -> void:
	for i in 4:
		var step := i
		get_tree().create_timer(0.09 * i).timeout.connect(func():
			_play(_chime, 0.5 * pow(1.26, step), 0.45))


func failure() -> void:
	for i in 2:
		var step := i
		get_tree().create_timer(0.14 * i).timeout.connect(func():
			_play(_thud, 1.0 * pow(0.84, step), 0.5))


func _play(stream: AudioStreamWAV, pitch: float, vol: float) -> void:
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = stream
	p.pitch_scale = clampf(pitch, 0.1, 4.0)
	p.volume_db = linear_to_db(clampf(vol, 0.0, 1.0))
	p.play()


## §54 — a quiet bed, ducked under every impact so it never competes.
func start_music(volume: float) -> void:
	if _music == null:
		_music_bed = _pad_loop()
		_music = AudioStreamPlayer.new()
		add_child(_music)
	_music.stream = _music_bed
	_music.volume_db = linear_to_db(clampf(volume, 0.0001, 1.0))
	_music.play()


func set_music_volume(volume: float) -> void:
	if _music:
		_music.volume_db = linear_to_db(clampf(volume, 0.0001, 1.0))


## Four stacked detuned sines over a slow amplitude drift — enough to read as
## atmosphere without being a tune anyone has to like.
func _pad_loop() -> AudioStreamWAV:
	var seconds := 8.0
	var n := int(RATE * seconds)
	var data := PackedByteArray()
	data.resize(n * 2)
	var roots := [110.0, 164.81, 220.0, 329.63]
	for i in n:
		var t := float(i) / RATE
		var v := 0.0
		for k in roots.size():
			var drift: float = 1.0 + 0.0008 * sin(TAU * (0.07 + 0.013 * k) * t)
			var swell: float = 0.5 + 0.5 * sin(TAU * (0.05 + 0.021 * k) * t)
			v += sin(TAU * roots[k] * drift * t) * swell / roots.size()
		# Taper the seam so the loop does not click.
		var edge: float = minf(1.0, minf(t, seconds - t) / 0.25)
		data.encode_s16(i * 2, int(clampf(v * edge, -1.0, 1.0) * 9000.0))

	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = n
	return w


# ------------------------------------------------------- aim and release ----

var _charge: AudioStreamPlayer
var _charge_tone: AudioStreamWAV
var _whoosh: AudioStreamWAV


func _build_aim_sounds() -> void:
	# A held tone whose pitch is driven by draw strength — the ear tracks a
	# rising pitch far better than a bar it has to look away from the table at.
	var n := int(RATE * 1.0)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / RATE
		var v: float = sin(TAU * 220.0 * t) * 0.6 + sin(TAU * 330.0 * t) * 0.25
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 7000.0))
	_charge_tone = AudioStreamWAV.new()
	_charge_tone.format = AudioStreamWAV.FORMAT_16_BITS
	_charge_tone.mix_rate = RATE
	_charge_tone.stereo = false
	_charge_tone.data = data
	_charge_tone.loop_mode = AudioStreamWAV.LOOP_FORWARD
	_charge_tone.loop_begin = 0
	_charge_tone.loop_end = n

	# Filtered noise sweep for the flick itself.
	var wn := int(RATE * 0.22)
	var wd := PackedByteArray()
	wd.resize(wn * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var last := 0.0
	for i in wn:
		var t := float(i) / RATE
		var env: float = exp(-t / 0.055)
		last = lerpf(last, rng.randfn(0.0, 1.0), 0.35)
		wd.encode_s16(i * 2, int(clampf(last * env, -1.0, 1.0) * 16000.0))
	_whoosh = AudioStreamWAV.new()
	_whoosh.format = AudioStreamWAV.FORMAT_16_BITS
	_whoosh.mix_rate = RATE
	_whoosh.stereo = false
	_whoosh.data = wd

	_charge = AudioStreamPlayer.new()
	_charge.stream = _charge_tone
	add_child(_charge)


## Called every frame while drawing back. `power` is 0..1.
func charge(power: float) -> void:
	if _charge == null:
		return
	if power <= 0.02:
		if _charge.playing:
			_charge.stop()
		return
	if not _charge.playing:
		_charge.play()
	_charge.pitch_scale = 0.75 + power * 1.25
	_charge.volume_db = linear_to_db(clampf(0.05 + power * 0.22, 0.0, 1.0))


func stop_charge() -> void:
	if _charge and _charge.playing:
		_charge.stop()


func release(power: float) -> void:
	stop_charge()
	_play(_whoosh, 0.8 + power * 0.7, 0.25 + power * 0.5)
