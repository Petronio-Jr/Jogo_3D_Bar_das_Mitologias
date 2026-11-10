class_name PoderBaralho
extends RefCounted
## Poder do jogador: o "baralho_poder" da mesa.
## - O jogador recebe o poder no 1º turno da ronda (já nasce disponível).
## - Ao clicar no baralho_poder, VIRA as cartas de todos os deuses (frente + número)
##   por `duracao_poder` segundos (5 s); depois elas voltam para baixo.
## - Depois de usar, precisa esperar `turnos_recarga_poder` turnos para usar de novo.

var ctrl: ControladorJogo

var no: Node3D
var recarga_restante: int = 0   # 0 = pronto para usar
var revelando: bool = false     # true = mãos dos deuses viradas para cima
var _id_ativacao: int = 0

# Virada do baralho de poder (a carta gira 180° ao ativar e desgira ao acabar)
var _q_base: Quaternion = Quaternion.IDENTITY
var _pos_base: Vector3 = Vector3.ZERO
var _angulo_virada: float = 0.0
var _tween_virada: Tween


func _init(controlador: ControladorJogo) -> void:
	ctrl = controlador
	_localizar()

func _localizar() -> void:
	no = ctrl.baralho_poder
	if no == null:
		for n in ctrl.find_children("*", "Node3D", true, false):
			if String(n.name).to_lower().replace("_", "") == "baralhopoder":
				no = n
				break
	if no == null:
		push_warning("[Poder] Nó 'baralho_poder' não encontrado. Arraste-o para a propriedade 'Baralho Poder' do Controlador.")
		return
	_q_base = no.quaternion
	_pos_base = no.position

# --- Ciclo de vida ---

## Nova ronda: o jogador recebe o poder já disponível (1º turno).
func resetar() -> void:
	recarga_restante = 0
	_id_ativacao += 1   # cancela o timer de uma revelação em andamento
	if revelando:
		revelando = false
		_aplicar_revelacao(false, false)
	_virar(false, false)
	definir_hover(false)

## Chamado no início de cada turno do jogador (a partir do 2º).
func registrar_turno() -> void:
	if recarga_restante > 0:
		recarga_restante -= 1
	ctrl.visual.atualizar_indicador_turno()

# --- Uso ---

func pode_ativar() -> bool:
	return ctrl.vez_do_jogador() \
		and not ctrl.habilidade.evento_em_andamento \
		and not ctrl.habilidade.escolhendo_deus \
		and recarga_restante == 0 \
		and not revelando

func ativar() -> void:
	if not pode_ativar():
		if recarga_restante > 0 and ctrl.vez_do_jogador():
			Som.sfx("poder_recarga")
			ctrl.visual.mensagem("Poder em recarga: %d turno(s)." % recarga_restante)
		return
	revelando = true
	recarga_restante = ctrl.turnos_recarga_poder
	_id_ativacao += 1
	var id: int = _id_ativacao
	Som.sfx("poder_ativar")
	_aplicar_revelacao(true)   # vira as cartas de todos os deuses
	_virar(true)               # o baralho de poder vira para o outro lado
	ctrl.visual.mensagem("Poder ativado! Cartas reveladas por %d segundos." % int(ctrl.duracao_poder))
	_pulsar()

	await ctrl.get_tree().create_timer(ctrl.duracao_poder).timeout
	if id == _id_ativacao and revelando:
		revelando = false
		Som.sfx("poder_fim")
		_aplicar_revelacao(false)   # as cartas voltam para baixo
		_virar(false)               # o baralho de poder desvira
		if ctrl.jogo_ativo and not ctrl.jogadores.is_empty():
			ctrl.visual.atualizar_indicador_turno()

## Gira o baralho de poder 180° em torno de `eixo_virada_poder` (eixo local),
## levantando um pouco no meio do giro. ativo=false desvira.
func _virar(ativo: bool, animar: bool = true) -> void:
	if no == null or not is_instance_valid(no):
		return
	if _tween_virada != null and _tween_virada.is_valid():
		_tween_virada.kill()
	var alvo: float = PI if ativo else 0.0
	if not animar:
		_aplicar_virada(alvo)
		return
	_tween_virada = no.create_tween()
	_tween_virada.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween_virada.tween_method(_aplicar_virada, _angulo_virada, alvo, maxf(ctrl.duracao_virada_poder, 0.01))

func _aplicar_virada(angulo: float) -> void:
	if no == null or not is_instance_valid(no):
		return
	_angulo_virada = angulo
	var eixo: Vector3 = ctrl.eixo_virada_poder
	if eixo.length() < 0.001:
		eixo = Vector3.RIGHT
	no.quaternion = _q_base * Quaternion(eixo.normalized(), angulo)
	var arco: float = sin(clampf(angulo / PI, 0.0, 1.0) * PI) * ctrl.altura_virada_poder
	no.position = _pos_base + Vector3.UP * arco

func _aplicar_revelacao(ativo: bool, animar: bool = true) -> void:
	for container in ctrl.visual.maos_ia.values():
		if container != null and is_instance_valid(container) and container.has_method("revelar"):
			container.revelar(ativo, animar)

func texto_status() -> String:
	if revelando:
		return "Poder ativo!"
	if recarga_restante <= 0:
		return "Poder pronto! Clique no baralho de poder"
	return "Poder disponível em %d turno(s)" % recarga_restante

# --- Interação pela mira ---

## Distância do raio da mira até o objeto (INF = não acertou).
func distancia_do_raio(origem: Vector3, direcao: Vector3) -> float:
	if no == null or not is_instance_valid(no) or not no.is_visible_in_tree():
		return INF
	var melhor: float = INF
	var malhas: Array = []
	if no is MeshInstance3D:
		malhas.append(no)
	malhas.append_array(no.find_children("*", "MeshInstance3D", true, false))
	for m in malhas:
		var mi: MeshInstance3D = m
		if mi.mesh == null or not mi.is_visible_in_tree():
			continue
		var inv: Transform3D = mi.global_transform.affine_inverse()
		var acerto = mi.get_aabb().intersects_ray(inv * origem, (inv.basis * direcao).normalized())
		if acerto != null:
			var ponto: Vector3 = mi.global_transform * (acerto as Vector3)
			melhor = minf(melhor, origem.distance_to(ponto))
	return melhor

func definir_hover(ativo: bool) -> void:
	EfeitoInchar.hover(no, ativo)

func _pulsar() -> void:
	EfeitoInchar.pulsar(no)
