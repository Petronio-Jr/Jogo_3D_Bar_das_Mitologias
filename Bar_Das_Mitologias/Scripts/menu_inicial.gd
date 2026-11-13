extends Control
## Menu inicial por cima do cenário do jogo.
## O menu fica DENTRO da cena do jogo (num CanvasLayer). Enquanto ele está aberto:
##  - uma câmera de menu mostra o cenário (com um balanço bem leve);
##  - o personagem fica parado e a HUD do jogo fica escondida.
## Ao apertar "Jogar": fade para preto, a câmera do jogador assume e o menu some.

@export var camera_menu: Camera3D        # câmera que enquadra o cenário atrás do menu
@export var jogador: Node3D              # o personagem que anda (CharacterBody3D "Jogador")
@export var camera_jogador: Camera3D     # a câmera dele (camera_andar)
@export var duracao_fade: float = 0.6
@export var duracao_loading: float = 1.5   # loading curto depois de apertar "Jogar"

@export_group("Balanço da câmera do menu")
@export var balanco_camera: bool = true
@export var amplitude_balanco_graus: float = 2.0
@export var velocidade_balanco: float = 0.25

@onready var botao_jogar: Button = %BotaoJogar
@onready var botao_sair: Button = %BotaoSair

var botao_opcoes: Button   # criado por código, entre Jogar e Sair

var _fade: ColorRect
var _tempo: float = 0.0
var _rot_base: Vector3 = Vector3.ZERO
var _huds_escondidas: Array[CanvasLayer] = []
var _iniciando: bool = false
var _pronto: bool = false

# Avisa a camera_andar (antes de qualquer _ready) que existe um menu
func _enter_tree() -> void:
	add_to_group("menu_inicial")

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_criar_fade()   # começa preto, enquanto a cena termina de carregar

	Configuracoes.aplicar_tudo()   # aplica as opções salvas (volumes, tela cheia, etc.)
	botao_opcoes = _criar_botao_opcoes()

	botao_jogar.pressed.connect(_on_jogar)
	botao_opcoes.pressed.connect(_on_opcoes)
	botao_sair.pressed.connect(_on_sair)
	for b in [botao_jogar, botao_opcoes, botao_sair]:
		b.mouse_entered.connect(_som_hover)
		b.focus_entered.connect(_som_hover)
	botao_jogar.grab_focus()

	# Espera o resto do jogo terminar o _ready (câmera, HUD, mira) para então assumir
	await get_tree().process_frame
	await get_tree().process_frame
	_preparar_menu()
	_pronto = true
	Som.musica("musica_menu", 1.0)   # música do menu
	create_tween().tween_property(_fade, "color:a", 0.0, duracao_fade)

func _preparar_menu() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if camera_menu != null:
		camera_menu.make_current()
		_rot_base = camera_menu.rotation
	else:
		push_warning("[Menu] 'Camera Menu' não definida: usando a câmera do jogador parada.")

	# Personagem parado (sem andar nem girar a câmera) enquanto o menu está aberto
	if jogador != null:
		jogador.process_mode = Node.PROCESS_MODE_DISABLED

	# Esconde a HUD do jogo (turno, mira...) que fica em CanvasLayers do controlador
	var controlador := get_tree().get_first_node_in_group("controlador_jogo")
	if controlador != null:
		for c in controlador.get_children():
			if c is CanvasLayer and c.visible and c != get_parent() and not c.is_ancestor_of(self):
				c.visible = false
				_huds_escondidas.append(c)

func _process(delta: float) -> void:
	if not balanco_camera or camera_menu == null or not _pronto or _iniciando:
		return
	_tempo += delta * velocidade_balanco * TAU
	var a: float = deg_to_rad(amplitude_balanco_graus)
	camera_menu.rotation = _rot_base + Vector3(sin(_tempo * 0.7) * a * 0.5, sin(_tempo) * a, 0.0)

func _on_jogar() -> void:
	if _iniciando or not _pronto:
		return
	_iniciando = true
	botao_jogar.disabled = true
	botao_opcoes.disabled = true
	botao_sair.disabled = true
	Som.sfx("ui_click")
	Som.musica_parar(duracao_fade + 0.4)   # a música do menu some junto com o fade...
	Som.pagode_passeio()                   # ...e o pagode começa baixinho ao fundo

	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, duracao_fade)
	await tw.finished

	for hud in _huds_escondidas:
		if is_instance_valid(hud):
			hud.visible = true
	if camera_jogador != null:
		camera_jogador.make_current()
	# Loading já cobre a tela (preta) antes do menu sumir; ele libera o personagem no fim
	LoadingInicio.mostrar(get_tree().current_scene, duracao_loading, jogador)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# Remove o menu (e o CanvasLayer que o contém, se houver)
	var raiz: Node = get_parent() if get_parent() is CanvasLayer else self
	raiz.queue_free()

func _on_sair() -> void:
	if _iniciando:
		return
	_iniciando = true
	Som.sfx("ui_click")
	get_tree().quit()

## Cria o botão "Opções" copiando o estilo do botão Sair e põe ele logo abaixo do Jogar.
func _criar_botao_opcoes() -> Button:
	var b: Button = botao_sair.duplicate() as Button
	b.unique_name_in_owner = false
	b.name = "BotaoOpcoes"
	b.text = "Opções"
	b.disabled = false
	for c in b.pressed.get_connections():          # a cópia não pode herdar a ação de "Sair"
		b.pressed.disconnect(c.callable)
	var pai: Node = botao_jogar.get_parent()
	pai.add_child(b)
	if pai is Container:
		pai.move_child(b, botao_jogar.get_index() + 1)
	else:
		# sem container: encaixa entre os dois, empurrando o Sair para baixo
		b.position = botao_sair.position
		botao_sair.position.y += botao_sair.size.y + 12.0
	return b

func _on_opcoes() -> void:
	if _iniciando or not _pronto:
		return
	Som.sfx("ui_click")
	var m := MenuOpcoes.abrir(self)
	m.fechado.connect(func(): botao_opcoes.grab_focus())

func _som_hover() -> void:
	if _pronto and not _iniciando:
		Som.sfx("ui_hover")

func _criar_fade() -> void:
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 1)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
