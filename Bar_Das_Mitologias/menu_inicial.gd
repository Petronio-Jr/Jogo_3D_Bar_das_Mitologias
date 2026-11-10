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

@export_group("Balanço da câmera do menu")
@export var balanco_camera: bool = true
@export var amplitude_balanco_graus: float = 2.0
@export var velocidade_balanco: float = 0.25

@onready var botao_jogar: Button = %BotaoJogar
@onready var botao_sair: Button = %BotaoSair

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

	botao_jogar.pressed.connect(_on_jogar)
	botao_sair.pressed.connect(_on_sair)
	botao_jogar.grab_focus()

	# Espera o resto do jogo terminar o _ready (câmera, HUD, mira) para então assumir
	await get_tree().process_frame
	await get_tree().process_frame
	_preparar_menu()
	_pronto = true
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
	botao_sair.disabled = true

	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, duracao_fade)
	await tw.finished

	for hud in _huds_escondidas:
		if is_instance_valid(hud):
			hud.visible = true
	if jogador != null:
		jogador.process_mode = Node.PROCESS_MODE_INHERIT
	if camera_jogador != null:
		camera_jogador.make_current()
		if camera_jogador.has_method("iniciar_pre_aquecimento"):
			camera_jogador.iniciar_pre_aquecimento()   # tela preta própria + fade de saída
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# Remove o menu (e o CanvasLayer que o contém, se houver)
	var raiz: Node = get_parent() if get_parent() is CanvasLayer else self
	raiz.queue_free()

func _on_sair() -> void:
	if _iniciando:
		return
	_iniciando = true
	get_tree().quit()

func _criar_fade() -> void:
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 1)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
