class_name MenuPausa
extends CanvasLayer
## Menu de pausa: ESC abre. Retomar, Opções e Sair do jogo.
## É criado pelo controlador (MenuPausa.instalar(self)) e escuta o ESC sozinho.
## Não abre enquanto o menu inicial ou a tela de loading estiverem na tela.

var _raiz: Control
var _opcoes_abertas: bool = false
var _botao_retomar: Button

static func instalar(pai: Node) -> MenuPausa:
	var m := MenuPausa.new()
	pai.add_child(m)
	return m

func _ready() -> void:
	layer = 150
	process_mode = Node.PROCESS_MODE_ALWAYS   # continua funcionando com o jogo pausado
	_construir()
	_raiz.visible = false

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
		return
	if _opcoes_abertas:
		return   # o ESC fecha o menu de opções, não este
	get_viewport().set_input_as_handled()
	if _raiz.visible:
		_retomar()
	elif _pode_abrir():
		_abrir()

func _pode_abrir() -> bool:
	var arvore := get_tree()
	return arvore.get_first_node_in_group("menu_inicial") == null \
		and arvore.get_first_node_in_group("loading_inicio") == null

func _abrir() -> void:
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_raiz.visible = true
	Som.sfx("ui_click")
	_botao_retomar.grab_focus()

func _retomar() -> void:
	_raiz.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Som.sfx("ui_click")

func _opcoes() -> void:
	Som.sfx("ui_click")
	_opcoes_abertas = true
	var m := MenuOpcoes.abrir(self)
	m.fechado.connect(func():
		_opcoes_abertas = false
		_botao_retomar.grab_focus())

func _sair() -> void:
	Som.sfx("ui_click")
	get_tree().paused = false
	get_tree().quit()

# ---------------------------------------------------------------- UI

func _construir() -> void:
	_raiz = Control.new()
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_raiz)

	var fundo := ColorRect.new()
	fundo.color = Color(0, 0, 0, 0.65)
	fundo.mouse_filter = Control.MOUSE_FILTER_STOP
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.add_child(fundo)

	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.add_child(centro)

	var painel := PanelContainer.new()
	painel.custom_minimum_size = Vector2(420, 0)
	var tema := Theme.new()
	tema.default_font_size = 22
	painel.theme = tema
	centro.add_child(painel)

	var margem := MarginContainer.new()
	for lado in ["left", "right", "top", "bottom"]:
		margem.add_theme_constant_override("margin_" + lado, 28)
	painel.add_child(margem)

	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 14)
	margem.add_child(coluna)

	var titulo := Label.new()
	titulo.text = "Pausado"
	titulo.add_theme_font_size_override("font_size", 38)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coluna.add_child(titulo)

	_botao_retomar = _botao("Retomar", _retomar, coluna)
	_botao("Opções", _opcoes, coluna)
	_botao("Sair do jogo", _sair, coluna)

func _botao(texto: String, acao: Callable, pai: Container) -> Button:
	var b := Button.new()
	b.text = texto
	b.custom_minimum_size = Vector2(0, 50)
	b.mouse_entered.connect(func(): Som.sfx("ui_hover"))
	b.pressed.connect(acao)
	pai.add_child(b)
	return b
