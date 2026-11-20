extends Area3D
## Cadeira do jogo principal. Não some depois de usada: ao fim da série o personagem levanta
## e dá para sentar de novo.

@export var mensagem_interacao: String = "Pressione E para dessafiar os deuses"
var jogador_na_area: bool = false
var _aviso: AvisoTela

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_aviso = AvisoTela.criar(self)

func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		jogador_na_area = true

func _on_body_exited(body: Node3D) -> void:
	if body is CharacterBody3D:
		jogador_na_area = false

## Sentar: começa a partida (se não há uma) ou volta a ela (se você levantou no meio).
func _pode_sentar() -> bool:
	var c := get_tree().get_first_node_in_group("controlador_jogo") as ControladorJogo
	if c == null or c.em_transicao_cadeira:
		return false
	if c.jogo_ativo:
		return c.levantado
	var t := get_tree().get_first_node_in_group("controlador_tutorial") as ControladorTutorial
	return t == null or not t.em_andamento

func _process(_delta: float) -> void:
	if jogador_na_area and _pode_sentar():
		var c := get_tree().get_first_node_in_group("controlador_jogo") as ControladorJogo
		_aviso.mostrar("Pressione E para voltar ao jogo" if c != null and c.jogo_ativo else mensagem_interacao)
	else:
		_aviso.esconder()

func _input(event: InputEvent) -> void:
	if jogador_na_area and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		if _pode_sentar():
			acionar_cadeira()

func acionar_cadeira() -> void:
	_aviso.esconder()
	var controlador := get_tree().get_first_node_in_group("controlador_jogo") as ControladorJogo
	if controlador == null:
		return
	if controlador.jogo_ativo:
		controlador.voltar_a_sentar()
	else:
		controlador.iniciar_jogo_por_interacao()
