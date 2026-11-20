extends Area3D
## JUKEBOX: troca o pagode de FUNDO (o do jogo, não o do rádio).
##
## MONTAGEM: um Area3D com um CollisionShape3D perto da jukebox e este script.
## Dentro da área, ao apertar E (ou o botão ESQUERDO do mouse), toca OUTRA música da pasta
## audio/pagode/ (sorteada, diferente da atual). Ela toca do começo até o fim (aí a playlist segue
## sozinha) ou até você trocar de novo. O texto embaixo da tela mostra o nome da faixa.

@export var mensagem_interacao: String = "Pressione E para trocar a música"
@export var tecla: Key = KEY_E
@export var clique_esquerdo_tambem: bool = true
@export var som_troca: String = "jukebox_troca"      # res://audio/sfx/
@export var volume_som_db: float = -6.0
@export var tempo_mostrando_faixa: float = 4.0       # quanto tempo o nome da faixa fica na tela após trocar (s)

signal musica_trocada(nome: String)

var _dentro: bool = false
var _aviso: AvisoTela
var _faixa: String = ""
var _mostrar_ate_ms: int = 0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_aviso = AvisoTela.criar(self)

func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		_dentro = true

func _on_body_exited(body: Node3D) -> void:
	if body is CharacterBody3D:
		_dentro = false
		_aviso.esconder()

func _process(_delta: float) -> void:
	if not _dentro or _sentado_jogando():
		_aviso.esconder()
		return
	var texto: String = mensagem_interacao
	if _faixa != "" and Time.get_ticks_msec() < _mostrar_ate_ms:
		texto += "\n♪ " + _faixa
	_aviso.mostrar(texto)

func _input(event: InputEvent) -> void:
	if not _dentro or _sentado_jogando():
		return
	var apertou: bool = false
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == tecla:
		apertou = true
	elif clique_esquerdo_tambem and event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		apertou = true
	if apertou:
		get_viewport().set_input_as_handled()
		trocar()

func trocar() -> void:
	Som.sfx(som_troca, volume_som_db)
	_faixa = Som.pagode_trocar()
	_mostrar_ate_ms = Time.get_ticks_msec() + int(tempo_mostrando_faixa * 1000.0)
	musica_trocada.emit(_faixa)

## Sentado jogando (partida ou tutorial em andamento e o personagem NÃO levantou): o E/clique é do jogo.
func _sentado_jogando() -> bool:
	for c in get_tree().get_nodes_in_group("controlador_jogo"):
		if bool(c.get("jogo_ativo")) and not bool(c.get("levantado")):
			return true
	for c in get_tree().get_nodes_in_group("controlador_tutorial"):
		if bool(c.get("em_andamento")) and not bool(c.get("levantado")):
			return true
	return false
