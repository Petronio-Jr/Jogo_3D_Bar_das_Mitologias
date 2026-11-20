class_name AvisoTela
extends CanvasLayer
## Texto de interação na parte de baixo da tela ("Pressione E para ...").
## Usado pelas cadeiras e pelas portas. Crie com AvisoTela.criar(self) e use mostrar(texto)/esconder().

var _rotulo: Label

static func criar(pai: Node) -> AvisoTela:
	var a := AvisoTela.new()
	pai.add_child(a)
	return a

func _ready() -> void:
	layer = 90
	_rotulo = Label.new()
	_rotulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rotulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rotulo.add_theme_font_size_override("font_size", 24)
	_rotulo.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_rotulo.add_theme_constant_override("outline_size", 6)
	_rotulo.anchor_left = 0.5
	_rotulo.anchor_right = 0.5
	_rotulo.anchor_top = 1.0
	_rotulo.anchor_bottom = 1.0
	_rotulo.offset_left = -400.0
	_rotulo.offset_right = 400.0
	_rotulo.offset_top = -120.0
	_rotulo.offset_bottom = -70.0
	add_child(_rotulo)
	_rotulo.visible = false

func mostrar(texto: String) -> void:
	if _rotulo == null:
		return
	_rotulo.text = texto
	_rotulo.visible = true

func esconder() -> void:
	if _rotulo != null:
		_rotulo.visible = false
