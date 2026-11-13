class_name MostradorFps
extends CanvasLayer
## Contador de FPS no canto da tela (ligado nas opções de gráficos).

var _rotulo: Label

func _init() -> void:
	name = "MostradorFps"
	layer = 300

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rotulo = Label.new()
	_rotulo.position = Vector2(14, 8)
	_rotulo.add_theme_font_size_override("font_size", 18)
	_rotulo.add_theme_color_override("font_color", Color(1, 1, 0.6))
	_rotulo.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_rotulo.add_theme_constant_override("outline_size", 4)
	add_child(_rotulo)

func _process(_delta: float) -> void:
	_rotulo.text = "%d FPS" % Engine.get_frames_per_second()
