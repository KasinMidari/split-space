extends Node

const SFX_RATE  := 22050.0
const BGM_RATE  := 11025.0
const BPM       := 120.0
const BGM_BEATS := 8

const DB_PATH := "res://assets/audio/audio_db.tres"

# ── Audio DB ──────────────────────────────────────────────────────────────────
var _db: AudioDatabase = null

# ── BGM player ────────────────────────────────────────────────────────────────
var _bgm_node: AudioStreamPlayer
var _bgm_gen:  AudioStreamGenerator
var _bgm_pb:   AudioStreamGeneratorPlayback
var _bgm_buf:  PackedVector2Array
var _bgm_pos:  int = 0
var _bgm_use_file: bool = false
var _bgm_current_id: String = ""

# ── Ducking BGM khi phát stinger thắng/thua ───────────────────────────────────
const DUCK_DB        := -16.0   # mức hạ âm lượng nhạc nền khi duck
const DUCK_FADE_DOWN := 0.15    # thời gian hạ nhỏ (giây)
const DUCK_HOLD      := 1.0     # giữ nhỏ trong lúc SFX chạy (giây)
const DUCK_FADE_UP   := 1.6     # thời gian to dần trở lại (giây)
var _duck_tween: Tween = null

# ── SFX player (procedural) ───────────────────────────────────────────────────
var _sfx_node: AudioStreamPlayer
var _sfx_gen:  AudioStreamGenerator
var _sfx_pb:   AudioStreamGeneratorPlayback

# Pool AudioStreamPlayer để phát nhiều SFX file cùng lúc
var _sfx_pool: Array[AudioStreamPlayer] = []
const SFX_POOL_SIZE := 8

func _ready() -> void:
	# Nhạc/âm thanh vẫn chạy khi game bị pause (vd: mở Settings).
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_db()

	# ── SFX procedural player ─────────────────────────────────────────
	_sfx_gen              = AudioStreamGenerator.new()
	_sfx_gen.mix_rate     = SFX_RATE
	_sfx_gen.buffer_length = 0.15
	_sfx_node             = AudioStreamPlayer.new()
	_sfx_node.stream      = _sfx_gen
	add_child(_sfx_node)
	_sfx_node.play()

	# ── SFX file pool ─────────────────────────────────────────────────
	for i in range(SFX_POOL_SIZE):
		var p := AudioStreamPlayer.new()
		add_child(p)
		_sfx_pool.append(p)

	# ── BGM player ────────────────────────────────────────────────────
	_bgm_node = AudioStreamPlayer.new()
	add_child(_bgm_node)

	var s := get_node_or_null("/root/Settings") as Settings
	if s:
		s.changed.connect(_apply_settings)

	# Phát BGM mặc định (id "main"), fallback procedural nếu file chưa có
	_start_default_bgm()
	_apply_settings()
	call_deferred("_init_playbacks")

	get_tree().root.files_dropped.connect(_on_files_dropped)

# ─────────────────────────────────────────────────────────────────────────────
# DB API
# ─────────────────────────────────────────────────────────────────────────────

func _load_db() -> void:
	if ResourceLoader.exists(DB_PATH):
		_db = load(DB_PATH) as AudioDatabase
	if _db == null:
		_db = AudioDatabase.new()

# Đăng ký thêm entry lúc runtime (không ghi vào file .tres)
func register_bgm(id: StringName, stream: AudioStream, loop: bool = true, vol_db: float = 0.0) -> void:
	var entry       := AudioEntry.new()
	entry.id        = id
	entry.type      = AudioEntry.Type.BGM
	entry.stream    = stream
	entry.loop      = loop
	entry.volume_db = vol_db
	_db.entries.append(entry)

func register_sfx(id: StringName, stream: AudioStream, vol_db: float = 0.0) -> void:
	var entry       := AudioEntry.new()
	entry.id        = id
	entry.type      = AudioEntry.Type.SFX
	entry.stream    = stream
	entry.volume_db = vol_db
	_db.entries.append(entry)

# Lấy AudioEntry theo loại và ID
func get_bgm_entry(id: StringName) -> AudioEntry:
	return _db.get_bgm(id)

func get_sfx_entry(id: StringName) -> AudioEntry:
	return _db.get_sfx(id)

# ─────────────────────────────────────────────────────────────────────────────
# BGM API
# ─────────────────────────────────────────────────────────────────────────────

# Phát BGM theo id (ví dụ: AudioManager.play_bgm("main"))
func play_bgm(id: StringName) -> void:
	if _bgm_current_id == id and _bgm_node.playing and _bgm_use_file:
		return
	var entry := get_bgm_entry(id)
	if entry == null or entry.stream == null:
		push_warning("[AudioManager] BGM id '" + id + "' không có trong DB")
		return
	if entry.stream is AudioStreamOggVorbis:
		(entry.stream as AudioStreamOggVorbis).loop = entry.loop
	_bgm_node.stop()
	_bgm_node.stream    = entry.stream
	_bgm_node.volume_db = entry.volume_db if entry.volume_db != 0.0 else _bgm_node.volume_db
	_bgm_node.play()
	_bgm_use_file   = true
	_bgm_current_id = id
	_bgm_pb         = null
	_apply_settings()

func stop_bgm() -> void:
	_bgm_node.stop()
	_bgm_current_id = ""

# Âm lượng nhạc nền chuẩn theo Settings (mức để khôi phục sau khi duck).
func _bgm_base_db() -> float:
	var s := get_node_or_null("/root/Settings") as Settings
	return s.get_music_db() if s else -10.0

# Hạ nhỏ nhạc nền, giữ một lúc rồi to dần trở lại (dùng cho stinger thắng/thua).
func duck_bgm(hold: float = DUCK_HOLD) -> void:
	if _bgm_node == null:
		return
	var base := _bgm_base_db()
	if _duck_tween != null and _duck_tween.is_valid():
		_duck_tween.kill()
	_duck_tween = create_tween()
	_duck_tween.tween_property(_bgm_node, "volume_db", base + DUCK_DB, DUCK_FADE_DOWN)
	_duck_tween.tween_interval(hold)
	_duck_tween.tween_property(_bgm_node, "volume_db", base, DUCK_FADE_UP)

func _start_default_bgm() -> void:
	var entry := get_bgm_entry(AudioDatabase.BGM_MAIN)
	if entry != null and entry.stream != null:
		play_bgm(AudioDatabase.BGM_MAIN)
		return
	# Fallback: nhạc procedural
	_bgm_gen               = AudioStreamGenerator.new()
	_bgm_gen.mix_rate      = BGM_RATE
	_bgm_gen.buffer_length = 0.4
	_bgm_node.stream       = _bgm_gen
	_bgm_node.play()
	_bgm_buf               = _gen_bgm()
	_bgm_use_file          = false
	call_deferred("_export_bgm_wav")

# ─────────────────────────────────────────────────────────────────────────────
# SFX API (file-based)
# ─────────────────────────────────────────────────────────────────────────────

# Phát SFX theo id (ví dụ: AudioManager.play_sfx("cut"))
func play_sfx(id: StringName) -> void:
	var entry := get_sfx_entry(id)
	if entry == null or entry.stream == null:
		return
	var player := _get_free_sfx_player()
	if player == null:
		return
	player.stream    = entry.stream
	player.volume_db = entry.volume_db if entry.volume_db != 0.0 else _sfx_node.volume_db
	player.play()

func _get_free_sfx_player() -> AudioStreamPlayer:
	for p in _sfx_pool:
		if not p.playing:
			return p
	return _sfx_pool[0]  # fallback: dùng lại player đầu tiên

# ─────────────────────────────────────────────────────────────────────────────
# Drag-and-drop thay BGM
# ─────────────────────────────────────────────────────────────────────────────

func _on_files_dropped(files: PackedStringArray) -> void:
	for src in files:
		var ext := src.get_extension().to_lower()
		if ext not in ["ogg", "mp3", "wav"]:
			continue
		var dest_dir := ProjectSettings.globalize_path("res://assets/audio/bgm/")
		DirAccess.make_dir_recursive_absolute(dest_dir)
		for old_ext in ["ogg", "mp3", "wav"]:
			var old = dest_dir + "main." + old_ext
			if FileAccess.file_exists(old):
				DirAccess.remove_absolute(old)
		var dest := dest_dir + "main." + ext
		if DirAccess.copy_absolute(src, dest) != OK:
			push_warning("[AudioManager] Không thể sao chép: " + src)
			return
		# Tạo AudioEntry mới và ghi vào DB runtime
		var bytes  := FileAccess.get_file_as_bytes(dest)
		var stream: AudioStream
		match ext:
			"ogg": stream = AudioStreamOggVorbis.load_from_buffer(bytes)
			"mp3": var mp3 := AudioStreamMP3.new(); mp3.data = bytes; stream = mp3
			"wav":
				var wav := AudioStreamWAV.new()
				if bytes.size() > 44:
					wav.format     = AudioStreamWAV.FORMAT_16_BITS
					wav.stereo     = true
					wav.mix_rate   = 44100
					wav.loop_mode  = AudioStreamWAV.LOOP_FORWARD
					wav.data       = bytes.slice(44)
					stream         = wav
		if stream:
			register_bgm(AudioDatabase.BGM_MAIN, stream, true)
			_bgm_use_file   = false
			_bgm_current_id = &""
			play_bgm(AudioDatabase.BGM_MAIN)
			print("[AudioManager] BGM 'main' đã được thay bằng: ", src)
		return

# ─────────────────────────────────────────────────────────────────────────────
# Export procedural BGM → file WAV (để người dùng tham khảo / chỉnh sửa)
# ─────────────────────────────────────────────────────────────────────────────

func _export_bgm_wav() -> void:
	if _bgm_buf.is_empty():
		return
	var path := ProjectSettings.globalize_path("res://assets/audio/bgm/main.wav")
	if FileAccess.file_exists(path):
		return
	var f := FileAccess.open(path, FileAccess.WRITE)
	if not f:
		return
	var num_samples := _bgm_buf.size()
	var data_size   := num_samples * 4
	f.store_buffer("RIFF".to_ascii_buffer())
	f.store_32(36 + data_size)
	f.store_buffer("WAVE".to_ascii_buffer())
	f.store_buffer("fmt ".to_ascii_buffer())
	f.store_32(16)
	f.store_16(1); f.store_16(2)
	f.store_32(int(BGM_RATE))
	f.store_32(int(BGM_RATE) * 4)
	f.store_16(4); f.store_16(16)
	f.store_buffer("data".to_ascii_buffer())
	f.store_32(data_size)
	for s in _bgm_buf:
		f.store_16(int(clampf(s.x, -1.0, 1.0) * 32767.0))
		f.store_16(int(clampf(s.y, -1.0, 1.0) * 32767.0))
	f.close()
	print("[AudioManager] BGM exported: ", path)

# ─────────────────────────────────────────────────────────────────────────────
# Internals
# ─────────────────────────────────────────────────────────────────────────────

func _init_playbacks() -> void:
	_sfx_pb = _sfx_node.get_stream_playback()
	if not _bgm_use_file:
		_bgm_pb = _bgm_node.get_stream_playback()

func _apply_settings() -> void:
	var s := get_node_or_null("/root/Settings") as Settings
	var sfx_db  := s.get_sfx_db()   if s else -6.0
	var bgm_db  := s.get_music_db() if s else -10.0
	_sfx_node.volume_db = sfx_db
	_bgm_node.volume_db = bgm_db
	for p in _sfx_pool:
		p.volume_db = sfx_db

func _process(_dt: float) -> void:
	if _bgm_use_file:
		if not _bgm_node.playing and not _bgm_current_id.is_empty():
			play_bgm(_bgm_current_id)
		if _sfx_pb == null:
			_sfx_pb = _sfx_node.get_stream_playback()
		return

	# Procedural BGM stream
	if _sfx_pb == null:
		_sfx_pb = _sfx_node.get_stream_playback()
	if _bgm_pb == null:
		_bgm_pb = _bgm_node.get_stream_playback()
	if _bgm_pb == null or _bgm_buf.is_empty():
		return
	var avail := _bgm_pb.get_frames_available()
	if avail <= 0:
		return
	var n     := _bgm_buf.size()
	var chunk := PackedVector2Array()
	chunk.resize(avail)
	for i in range(avail):
		chunk[i] = _bgm_buf[_bgm_pos]
		_bgm_pos = (_bgm_pos + 1) % n
	_bgm_pb.push_buffer(chunk)

# ── SFX procedural (fallback khi không có file) ───────────────────────────────

func play_click() -> void:
	if get_sfx_entry(AudioDatabase.SFX_CLICK): play_sfx(AudioDatabase.SFX_CLICK); return
	_sfx_note(1200.0, 0.03, 0.40, 0)

func play_cut() -> void:
	if get_sfx_entry(AudioDatabase.SFX_CUT): play_sfx(AudioDatabase.SFX_CUT); return
	_sfx_note(660.0, 0.06, 0.55, 0)

func play_big_cut() -> void:
	if get_sfx_entry(AudioDatabase.SFX_BIG_CUT): play_sfx(AudioDatabase.SFX_BIG_CUT); return
	_sfx_note(880.0,  0.07, 0.65, 0)
	await get_tree().create_timer(0.06).timeout
	_sfx_note(1100.0, 0.08, 0.60, 0)
	await get_tree().create_timer(0.06).timeout
	_sfx_note(1320.0, 0.10, 0.55, 0)

func play_die() -> void:
	if get_sfx_entry(AudioDatabase.SFX_DIE): play_sfx(AudioDatabase.SFX_DIE); return
	for f in [420.0, 350.0, 280.0, 180.0]:
		_sfx_note(f, 0.09, 0.70, 3)
		await get_tree().create_timer(0.08).timeout

func play_win() -> void:
	duck_bgm()
	if get_sfx_entry(AudioDatabase.SFX_WIN): play_sfx(AudioDatabase.SFX_WIN); return
	for f in [523.0, 659.0, 784.0, 1047.0, 1319.0]:
		_sfx_note(f, 0.10, 0.60, 0)
		await get_tree().create_timer(0.09).timeout

func play_lose() -> void:
	duck_bgm()
	if get_sfx_entry(AudioDatabase.SFX_LOSE): play_sfx(AudioDatabase.SFX_LOSE); return
	for f in [392.0, 349.0, 311.0, 261.0]:
		_sfx_note(f, 0.13, 0.70, 1)
		await get_tree().create_timer(0.12).timeout

func play_item() -> void:
	if get_sfx_entry(AudioDatabase.SFX_ITEM): play_sfx(AudioDatabase.SFX_ITEM); return
	_sfx_note(1047.0, 0.07, 0.50, 2)
	await get_tree().create_timer(0.06).timeout
	_sfx_note(1319.0, 0.09, 0.50, 2)

func play_freeze() -> void:
	if get_sfx_entry(AudioDatabase.SFX_FREEZE): play_sfx(AudioDatabase.SFX_FREEZE); return
	for i in range(5):
		_sfx_note(700.0 + i * 120.0, 0.07, 0.38, 2)
		await get_tree().create_timer(0.04).timeout

func play_enemy_die() -> void:
	if get_sfx_entry(AudioDatabase.SFX_ENEMY_DIE): play_sfx(AudioDatabase.SFX_ENEMY_DIE); return
	_sfx_note(320.0, 0.05, 0.60, 3)
	await get_tree().create_timer(0.04).timeout
	_sfx_note(190.0, 0.09, 0.50, 3)

func _sfx_note(freq: float, dur: float, vol: float, wave: int) -> void:
	if _sfx_pb == null:
		return
	var frames := int(SFX_RATE * dur)
	var buf    := PackedVector2Array()
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
		0: return 1.0 if cy < 0.5 else -1.0
		1: return sin(TAU * freq * t)
		2: return 1.0 - 4.0 * absf(cy - 0.5) if cy < 0.5 else 4.0 * absf(cy - 0.5) - 1.0
		_: return 2.0 * cy - 1.0

# ── BGM generation ─────────────────────────────────────────────────────────────

func _gen_bgm() -> PackedVector2Array:
	var beat  := BGM_RATE * 60.0 / BPM
	var total := int(beat * BGM_BEATS)
	var buf   := PackedVector2Array()
	buf.resize(total)
	var mel := [329.63, 392.0, 440.0, 523.25, 440.0, 392.0, 329.63, 392.0]
	for i in range(BGM_BEATS):
		_bgm_mix(buf, int(i * beat), int(beat * 0.86), mel[i], 0, 0.20)
	var bas := [130.81, 110.0, 174.61, 196.0]
	for i in range(4):
		_bgm_mix(buf, int(i * beat * 2.0), int(beat * 1.88), bas[i], 1, 0.38)
	var arp := [
		[261.63, 329.63, 392.0,  261.63, 329.63, 392.0,  261.63, 329.63],
		[220.0,  261.63, 329.63, 220.0,  261.63, 329.63, 220.0,  261.63],
		[174.61, 220.0,  261.63, 174.61, 220.0,  261.63, 174.61, 220.0 ],
		[196.0,  246.94, 293.66, 196.0,  246.94, 293.66, 196.0,  246.94],
	]
	var eighth := beat * 0.5
	for bar in range(4):
		for n in range(8):
			_bgm_mix(buf, int(bar * beat * 2.0 + n * eighth), int(eighth * 0.65), arp[bar][n], 2, 0.11)
	for i in range(16):
		_bgm_noise(buf, int(i * eighth), int(eighth * 0.07), 0.07)
	for i in [0, 2, 4, 6]:
		_bgm_kick(buf, int(i * beat), int(beat * 0.28))
	var peak := 0.001
	for s in buf:
		if absf(s.x) > peak:
			peak = absf(s.x)
	var sc := 0.78 / peak
	for i in range(total):
		buf[i] = buf[i] * sc
	return buf

func _bgm_mix(buf: PackedVector2Array, start: int, dur: int, freq: float, wave: int, vol: float) -> void:
	var end := mini(start + dur, buf.size())
	for i in range(start, end):
		var t   := float(i - start) / BGM_RATE
		var env := 1.0 - float(i - start) / float(dur)
		env = env * env
		buf[i] = buf[i] + Vector2(_wave(freq, t, wave) * vol * env, _wave(freq, t, wave) * vol * env)

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
		var t    := float(i - start) / BGM_RATE
		var env  := 1.0 - frac
		var s    := sin(TAU * (80.0 - frac * 55.0) * t) * 0.50 * env * env
		buf[i] = buf[i] + Vector2(s, s)
