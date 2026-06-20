class_name AudioEntry
extends Resource

enum Type { BGM, SFX }

@export var id: StringName        # Tên ID để gọi, ví dụ: "main", "cut"
@export var type: Type = Type.BGM
@export var stream: AudioStream
@export var loop: bool = false
@export var volume_db: float = 0.0
