class_name AudioManager
extends Node

const SFX_RATE := 22050.0
const BGM_RATE := 11025.0
const BPM      := 120.0      # beats per minute
const BGM_BEATS := 8         # 8 quarter notes → 4-second loop

var _sfx_node: AudioStreamPlayer
var _sfx_gen:  AudioStreamGenerator
var _sfx_pb:   AudioStreamGeneratorPlayback

var _bgm_node: AudioStreamPlayer
var _bgm_gen:  AudioStreamGenerator
var _bgm_pb:   AudioStreamGeneratorPlayback
var _bgm_buf:  PackedVector2Array
var _bgm_pos:  int = 0

func _ready() -> void:
	# ── SFX player ────────────────────────────────────────────────────
	_sfx_gen = AudioStreamGenerator.new()
	_sfx_gen.mix_rate = SFX_RATE
	_sfx_gen.buffer_length = 0.15
	_sfx_node = AudioStreamPlayer.new()
	_sfx_node.stream = _sfx_gen
	add_child(_sfx_node)
	_sfx_node.play()

	# ── BGM player ────────────────────────────────────────────────────
	_bgm_gen = AudioStreamGenerator.new()
	_bgm_gen.mix_rate = BGM_RATE
	_bgm_gen.buffer_length = 0.4
	_bgm_node = AudioStreamPlayer.new()
	_bgm_node.stream = _bgm_gen
	add_child(_bgm_node)
	_bgm_node.play()
	_bgm_buf = _gen_bgm()

	var s := get_node_or_null("/root/Settings") as Settings
	if s:
		s.changed.connect(_apply_settings)
	_apply_settings()

	# get_stream_playback() cần ít nhất 1 frame sau play() mới không null
	call_deferred("_init_playbacks")

func _init_playbacks() -> void:
	_sfx_pb = _sfx_node.get_stream_playback()
	_bgm_pb = _bgm_node.get_stream_playback()

func _apply_settings() -> void:
	var s := get_node_or_null("/root/Settings") as Settings
	_sfx_node.volume_db = s.get_sfx_db()   if s else -6.0
	_bgm_node.volume_db = s.get_music_db() if s else -10.0

# Stream BGM loop continuously
func _process(_dt: float) -> void:
	if _sfx_pb == null:
		_sfx_pb = _sfx_node.get_stream_playback()
	if _bgm_pb == null:
		_bgm_pb = _bgm_node.get_stream_playback()
	if _bgm_pb == null or _bgm_buf.is_empty():
		return
	var avail := _bgm_pb.get_frames_available()
	if avail <= 0:
		return
	var n := _bgm_buf.size()
	var chunk := PackedVector2Array()
	chunk.resize(avail)
	for i in range(avail):
		chunk[i] = _bgm_buf[_bgm_pos]
		_bgm_pos = (_bgm_pos + 1) % n
	_bgm_pb.push_buffer(chunk)

# ── SFX public API ─────────────────────────────────────────────────────

func play_cut() -> void:
	_sfx_note(660.0, 0.06, 0.55, 0)

func play_big_cut() -> void:
	_sfx_note(880.0,  0.07, 0.65, 0)
	await get_tree().create_timer(0.06).timeout
	_sfx_note(1100.0, 0.08, 0.60, 0)
	await get_tree().create_timer(0.06).timeout
	_sfx_note(1320.0, 0.10, 0.55, 0)

func play_die() -> void:
	var freqs := [420.0, 350.0, 280.0, 180.0]
	for f in freqs:
		_sfx_note(f, 0.09, 0.70, 3)
		await get_tree().create_timer(0.08).timeout

func play_win() -> void:
	var freqs := [523.0, 659.0, 784.0, 1047.0, 1319.0]
	for f in freqs:
		_sfx_note(f, 0.10, 0.60, 0)
		await get_tree().create_timer(0.09).timeout

func play_lose() -> void:
	var freqs := [392.0, 349.0, 311.0, 261.0]
	for f in freqs:
		_sfx_note(f, 0.13, 0.70, 1)
		await get_tree().create_timer(0.12).timeout

func play_item() -> void:
	_sfx_note(1047.0, 0.07, 0.50, 2)
	await get_tree().create_timer(0.06).timeout
	_sfx_note(1319.0, 0.09, 0.50, 2)

func play_freeze() -> void:
	for i in range(5):
		_sfx_note(700.0 + i * 120.0, 0.07, 0.38, 2)
		await get_tree().create_timer(0.04).timeout

func play_enemy_die() -> void:
	_sfx_note(320.0, 0.05, 0.60, 3)
	await get_tree().create_timer(0.04).timeout
	_sfx_note(190.0, 0.09, 0.50, 3)

# ── SFX internals ──────────────────────────────────────────────────────
# wave: 0=square  1=sine  2=triangle  3=sawtooth

func _sfx_note(freq: float, dur: float, vol: float, wave: int) -> void:
	if _sfx_pb == null:
		return
	var frames := int(SFX_RATE * dur)
	var buf := PackedVector2Array()
	buf.resize(frames)
	for i in range(frames):
		var t   := float(i) / SFX_RATE
		var env := 1.0 - float(i) / float(frames)
		var s   := _wave(freq, t, wave) * vol * env * 0.35
		buf[i] = Vector2(s, s)
	_sfx_pb.push_buffer(buf)

func _wave(freq: float, t: float, wave: int) -> float:
	var cy := fmod(freq * t, 1.0)
	match wave:
		0: return 1.0 if cy < 0.5 else -1.0                          # square
		1: return sin(TAU * freq * t)                                 # sine
		2: return 1.0 - 4.0 * absf(cy - 0.5) if cy < 0.5 else \
				  4.0 * absf(cy - 0.5) - 1.0                         # triangle (no trig)
		_: return 2.0 * cy - 1.0                                     # sawtooth

# ── BGM generation (runs once at startup) ─────────────────────────────

func _gen_bgm() -> PackedVector2Array:
	var beat  := BGM_RATE * 60.0 / BPM       # samples per quarter note ≈ 5512
	var total := int(beat * BGM_BEATS)        # 44096 samples ≈ 4 seconds
	var buf   := PackedVector2Array()
	buf.resize(total)

	# --- Melody: square wave (quarter notes) ---
	# Chord progression C / Am / F / G
	var mel := [329.63, 392.0, 440.0, 523.25, 440.0, 392.0, 329.63, 392.0]
	for i in range(BGM_BEATS):
		_bgm_mix(buf, int(i * beat), int(beat * 0.86), mel[i], 0, 0.20)

	# --- Bass: sine (half notes, one per chord) ---
	var bas := [130.81, 110.0, 174.61, 196.0]
	for i in range(4):
		_bgm_mix(buf, int(i * beat * 2.0), int(beat * 1.88), bas[i], 1, 0.38)

	# --- Arpeggio: triangle (8th notes) ---
	var arp := [
		[261.63, 329.63, 392.0,  261.63, 329.63, 392.0,  261.63, 329.63],  # C
		[220.0,  261.63, 329.63, 220.0,  261.63, 329.63, 220.0,  261.63],  # Am
		[174.61, 220.0,  261.63, 174.61, 220.0,  261.63, 174.61, 220.0 ],  # F
		[196.0,  246.94, 293.66, 196.0,  246.94, 293.66, 196.0,  246.94],  # G
	]
	var eighth := beat * 0.5
	for bar in range(4):
		for n in range(8):
			_bgm_mix(buf, int(bar * beat * 2.0 + n * eighth),
					 int(eighth * 0.65), arp[bar][n], 2, 0.11)

	# --- Hi-hat: noise burst every 8th note ---
	for i in range(16):
		_bgm_noise(buf, int(i * eighth), int(eighth * 0.07), 0.07)

	# --- Kick: every bar (beats 1, 3, 5, 7) ---
	for i in [0, 2, 4, 6]:
		_bgm_kick(buf, int(i * beat), int(beat * 0.28))

	# Normalize
	var peak := 0.001
	for s in buf:
		if absf(s.x) > peak:
			peak = absf(s.x)
	var sc := 0.78 / peak
	for i in range(total):
		buf[i] = buf[i] * sc

	return buf

func _bgm_mix(buf: PackedVector2Array, start: int, dur: int,
			  freq: float, wave: int, vol: float) -> void:
	var end := mini(start + dur, buf.size())
	for i in range(start, end):
		var t   := float(i - start) / BGM_RATE
		var env := 1.0 - float(i - start) / float(dur)
		env = env * env
		var s := _wave(freq, t, wave) * vol * env
		buf[i] = buf[i] + Vector2(s, s)

func _bgm_noise(buf: PackedVector2Array, start: int, dur: int, vol: float) -> void:
	var end := mini(start + dur, buf.size())
	for i in range(start, end):
		var env := 1.0 - float(i - start) / float(dur)
		var s   := randf_range(-1.0, 1.0) * vol * env
		buf[i] = buf[i] + Vector2(s, s)

func _bgm_kick(buf: PackedVector2Array, start: int, dur: int) -> void:
	var end := mini(start + dur, buf.size())
	for i in range(start, end):
		var frac := float(i - start) / float(dur)
		var freq := 80.0 - frac * 55.0          # sweep 80 → 25 Hz
		var t    := float(i - start) / BGM_RATE
		var env  := 1.0 - frac
		var s    := sin(TAU * freq * t) * 0.50 * env * env
		buf[i] = buf[i] + Vector2(s, s)
