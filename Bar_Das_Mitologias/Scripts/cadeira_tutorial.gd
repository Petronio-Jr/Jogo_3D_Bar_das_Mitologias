extends Area3D
## Cadeira do TUTORIAL (só este script: ponha num Area3D com um CollisionShape3D perto da cadeira).
## Ao apertar E dentro da área, o personagem anda até a mesa do tutorial, senta e começa o X1.
## Diferente da cadeira do jogo principal, ela NÃO some: depois do tutorial dá para sentar de novo.

@export var controlador: ControladorTutorial   # vazio = procura o nó do grupo "controlador_tutorial"
@export var mensagem_interacao: String = "Pressione E para enfrentar Shiva"
@export var tecla: Key = KEY_E
@export var ah_puch: Node   # vazio = procura o nó do grupo "ah_puch"; a cadeira só libera depois de falar com ele

var _dentro: bool = false
var _aviso: AvisoTela

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

func _process(_delta: float) -> void:
	if _dentro and _pode_iniciar():
		var c: ControladorTutorial = _achar_controlador()
		_aviso.mostrar("Pressione E para voltar ao jogo" if c != null and c.em_andamento else mensagem_interacao)
	else:
		_aviso.esconder()

func _input(event: InputEvent) -> void:
	if not _dentro or not (event is InputEventKey and event.pressed and not event.echo and event.keycode == tecla):
		return
	if not _pode_iniciar():
		return
	get_viewport().set_input_as_handled()
	_aviso.esconder()
	var c: ControladorTutorial = _achar_controlador()
	if c.em_andamento:
		c.voltar_a_sentar()    # você levantou no meio do tutorial: continua de onde parou
	else:
		c.iniciar_jogo_por_interacao()

func _achar_controlador() -> ControladorTutorial:
	if controlador != null:
		return controlador
	return get_tree().get_first_node_in_group("controlador_tutorial") as ControladorTutorial

## Não deixa começar sem controlador, com o tutorial já rolando ou no meio do jogo principal.
func _pode_iniciar() -> bool:
	var c: ControladorTutorial = _achar_controlador()
	if c == null or c.em_transicao_cadeira:
		return false
	if c.em_andamento:
		return c.levantado
	var ah: Node = ah_puch if ah_puch != null else get_tree().get_first_node_in_group("ah_puch")
	if ah != null and not bool(ah.get("conversou_antes")):
		return false
	var principal := get_tree().get_first_node_in_group("controlador_jogo") as ControladorJogo
	return principal == null or not principal.jogo_ativo
