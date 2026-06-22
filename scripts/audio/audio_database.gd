class_name AudioDatabase
extends Resource

# ── BGM IDs ───────────────────────────────────────────────────────────────────
const BGM_MAIN  := &"main"
const BGM_MENU  := &"menu"

# ── SFX IDs ───────────────────────────────────────────────────────────────────
const SFX_CLICK      := &"click"
const SFX_CUT        := &"cut"
const SFX_BIG_CUT    := &"big_cut"
const SFX_DIE        := &"die"
const SFX_WIN        := &"win"
const SFX_LOSE       := &"lose"
const SFX_ITEM       := &"item"
const SFX_FREEZE     := &"freeze"
const SFX_ENEMY_DIE  := &"enemy_die"

# ── Entries ───────────────────────────────────────────────────────────────────
@export var entries: Array[AudioEntry] = []

func get_bgm(id: StringName) -> AudioEntry:
	for e in entries:
		if e.id == id and e.type == AudioEntry.Type.BGM:
			return e
	return null

func get_sfx(id: StringName) -> AudioEntry:
	for e in entries:
		if e.id == id and e.type == AudioEntry.Type.SFX:
			return e
	return null
