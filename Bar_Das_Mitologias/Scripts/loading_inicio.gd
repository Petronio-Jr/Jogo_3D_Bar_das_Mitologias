class_name LoadingInicio
extends CanvasLayer
## Tela de loading curtinha no início do jogo: fundo preto, "Carregando..." e uma barra fina.
## Segura o personagem parado até terminar e some com um fade.
## Uso: LoadingInicio.mostrar(get_tree().current_scene, 1.5, jogador)

var _duracao: float = 1.5
var _jogador: Node
var _fundo: ColorRect
var _texto: Label
var _barra: ColorRect
var _tempo: float = 0.0
var _saindo: bool = false

static func mostrar(pai: Node, duracao: float = 1.5, jogador: Node = null) -> LoadingInicio:
	var l := LoadingInicio.new()
	l._duracao = maxf(duracao, 0.1)
	l._jogador = jogador
	if pai == null:
		pai = (Engine.get_main_loop() as SceneTree).root
	pai.add_child(l)
	return l

func _ready() -> void:
	layer = 128
	add_to_group("loading_inicio")   # o menu de pausa não abre durante o loading
	process_mode = Node.PROCESS_MODE_ALWAYS
	if _jogador != null:
		_jogador.process_mode = Node.PROCESS_MODE_DISABLED   # parado durante o loading

	_fundo = ColorRect.new()
	_fundo.color = Color.BLACK
	_fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_fundo)

	_texto = Label.new()
	_texto.text = "Carregando"
	_texto.add_theme_font_size_override("font_size", 22)
	_texto.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_texto.anchor_left = 0.0
	_texto.anchor_right = 1.0
	_texto.offset_left = 0.0
	_texto.offset_right = 0.0
	_texto.offset_top = -110.0
	_texto.offset_bottom = -70.0
	_texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_fundo.add_child(_texto)

	# Barra fina embaixo
	var trilho := ColorRect.new()
	trilho.color = Color(1, 1, 1, 0.15)
	trilho.anchor_left = 0.3
	trilho.anchor_right = 0.7
	trilho.anchor_top = 1.0
	trilho.anchor_bottom = 1.0
	trilho.offset_top = -60.0
	trilho.offset_bottom = -56.0
	_fundo.add_child(trilho)
	_barra = ColorRect.new()
	_barra.color = Color(1, 1, 1, 0.85)
	_barra.set_anchors_preset(Control.PRESET_FULL_RECT)
	_barra.anchor_right = 0.0
	trilho.add_child(_barra)

func _process(delta: float) -> void:
	if _saindo:
		return
	_tempo += delta
	var p: float = clampf(_tempo / _duracao, 0.0, 1.0)
	_barra.anchor_right = p * p * (3.0 - 2.0 * p)
	_texto.text = "Carregando" + ".".repeat(int(_tempo * 3.0) % 4)
	if p >= 1.0:
		_terminar()

func _terminar() -> void:
	_saindo = true
	if _jogador != null and is_instance_valid(_jogador):
		_jogador.process_mode = Node.PROCESS_MODE_INHERIT
	var tw := create_tween()
	tw.tween_property(_fundo, "modulate:a", 0.0, 0.4)
	await tw.finished
	queue_free()
