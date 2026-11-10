class_name PilhaMesa
extends RefCounted
## Pilha de cartas jogadas no centro da mesa. Cada carta jogada (pelo jogador ou
## pelos deuses) voa até o centro e fica na mesa, levemente deslocada e girada
## para dar efeito de pilha. Só as últimas `cartas_na_pilha` ficam visíveis.

const CARTA_UI_3D_SCENE = preload("res://Interagiveis/carta_ui_3d.tscn")

var ctrl: ControladorJogo
var cartas: Array[Node3D] = []

var _ref: Transform3D = Transform3D.IDENTITY   # onde a pilha fica (malha da CartaMesa)
var _pronta: bool = false
var _seq: int = 0   # contador de cartas jogadas (define o "slot" lateral de cada uma)

func _init(controlador: ControladorJogo) -> void:
	ctrl = controlador
	var mesa := ctrl.visual.carta_mesa as Node3D
	if mesa == null:
		push_warning("[Pilha] Nó 'Cenário/CartaMesa' não encontrado: a pilha usa essa posição como centro.")
		return
	var malha := mesa.get_node_or_null("Mesh") as Node3D
	_ref = malha.global_transform if malha != null else mesa.global_transform
	mesa.visible = false   # a carta única do centro é substituída pela pilha
	_pronta = true

## Escala de referência: a da mão do jogador (a mesma para todas as cartas na mesa).
func _escala_base() -> Vector3:
	if ctrl.container_mao_3d != null:
		return (ctrl.container_mao_3d as Node3D).global_transform.basis.get_scale()
	return Vector3.ONE

func limpar() -> void:
	_seq = 0
	for c in cartas:
		if is_instance_valid(c):
			c.queue_free()
	cartas.clear()

## Primeira carta da ronda: já aparece no centro, sem voo.
func colocar_inicial(carta: Carta) -> void:
	limpar()
	jogar(carta, Transform3D(Basis.IDENTITY.scaled(_escala_base()), _ref.origin), true)

## Joga a carta: nasce em `origem` (global), sobe um pouco, vai ao centro e fica
## na pilha. Devolve o Tween do voo (null se for instantâneo) para quem quiser esperar.
func jogar(carta: Carta, origem: Transform3D, instantaneo: bool = false) -> Tween:
	if not _pronta:
		return null

	var no: Node3D = CARTA_UI_3D_SCENE.instantiate()
	ctrl.add_child(no)
	no.setup(carta, 0)
	no.global_transform = origem

	# Pilha cheia: a mais antiga sai e as outras descem uma camada
	while cartas.size() >= maxi(ctrl.cartas_na_pilha, 1):
		var velha: Node3D = cartas.pop_front()
		if is_instance_valid(velha):
			velha.queue_free()
		for c in cartas:
			if is_instance_valid(c):
				ctrl.create_tween().tween_property(c, "global_position:y", c.global_position.y - ctrl.distancia_vertical_pilha, 0.15)

	var camada: int = cartas.size()
	cartas.append(no)

	# Destino: orientação do Mesh da CartaMesa, com um desvio aleatório
	var malha_local: Transform3D = Transform3D.IDENTITY
	var malha_carta = no.get("mesh_instance")
	if malha_carta != null:
		malha_local = (malha_carta as Node3D).transform

	var escala0: Vector3 = origem.basis.get_scale()
	# Tamanho final igual para todas as cartas, de qualquer jogador: a escala da mão
	# de origem (ex.: deus com modelo maior) só vale para o início do voo.
	var escala: Vector3 = _escala_base() * ctrl.escala_carta_pilha
	var base_q: Quaternion = _quat_deitada_para_cima()
	var yaw: float = deg_to_rad(randf_range(-ctrl.giro_max_pilha, ctrl.giro_max_pilha))
	var q1: Quaternion = Quaternion(Vector3.UP, yaw) * base_q
	var j: float = ctrl.desvio_max_pilha
	# Cada carta usa um "slot" lateral diferente, para não ficarem uma sobre a outra
	var n: int = maxi(ctrl.cartas_na_pilha, 1)
	var slot: int = _seq % n
	_seq += 1
	var direita: Vector3 = _eixos_mesa()[1]
	var lateral: float = (slot - (n - 1) / 2.0) * ctrl.distancia_horizontal_pilha
	var alvo_malha: Vector3 = _ref.origin \
		+ direita * lateral \
		+ Vector3(randf_range(-j, j), 0.0, randf_range(-j, j)) \
		+ Vector3.UP * camada * ctrl.distancia_vertical_pilha
	var p1: Vector3 = alvo_malha - Basis(q1).scaled(escala) * malha_local.origin

	if instantaneo:
		no.global_transform = Transform3D(Basis(q1).scaled(escala), p1)
		return null

	var p0: Vector3 = origem.origin
	var q0: Quaternion = origem.basis.orthonormalized().get_rotation_quaternion()
	var tw: Tween = ctrl.create_tween()
	tw.tween_method(func(t: float): _mover(no, t, p0, q0, escala0, escala, p1, q1), 0.0, 1.0, maxf(ctrl.duracao_voo_carta, 0.01))
	return tw

## Rotação que deita a carta com a FRENTE (+Z da carta, onde ficam o número e a cor)
## para cima e o topo do texto apontando para longe do jogador (lê-se de pé).
func _quat_deitada_para_cima() -> Quaternion:
	var eixos: Array = _eixos_mesa()
	return Basis(eixos[1], eixos[0], Vector3.UP).get_rotation_quaternion()

## [topo, direita]: "topo" aponta para longe do jogador; "direita" é a direita dele.
func _eixos_mesa() -> Array:
	var topo: Vector3 = Vector3(0, 0, -1)
	var cam := ctrl.camera_jogador
	if cam != null:
		topo = _ref.origin - cam.global_position
		topo.y = 0.0
		if topo.length() < 0.001:
			topo = Vector3(0, 0, -1)
		topo = topo.normalized()
	return [topo, topo.cross(Vector3.UP).normalized()]

## t de 0 a 1: primeiro sobe um pouco acima da mão, depois vai ao centro girando.
func _mover(no: Node3D, t: float, p0: Vector3, q0: Quaternion, esc0: Vector3, esc1: Vector3, p1: Vector3, q1: Quaternion) -> void:
	if not is_instance_valid(no):
		return
	const FASE_SUBIDA: float = 0.3
	var topo: Vector3 = p0 + Vector3.UP * ctrl.altura_saida_carta
	var pos: Vector3
	var q: Quaternion
	if t < FASE_SUBIDA:
		var k: float = t / FASE_SUBIDA
		k = 1.0 - (1.0 - k) * (1.0 - k)
		pos = p0.lerp(topo, k)
		q = q0
	else:
		var k: float = (t - FASE_SUBIDA) / (1.0 - FASE_SUBIDA)
		k = k * k * (3.0 - 2.0 * k)
		pos = topo.lerp(p1, k)
		q = q0.slerp(q1, k)
	var e: float = t * t * (3.0 - 2.0 * t)
	no.global_transform = Transform3D(Basis(q).scaled(esc0.lerp(esc1, e)), pos)
