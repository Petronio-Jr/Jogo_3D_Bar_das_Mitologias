extends Node3D
 
signal carta_clicada(indice)
signal carta_jogada_com_cor(indice, cor_escolhida)
 
@onready var mesh_instance: MeshInstance3D = $Mesh
@onready var label_texto: Label3D = $TextoValor
@onready var label_texto2: Label3D = $TextoValor2
@onready var label_texto3: Label3D = $TextoValor3
@onready var area_3d: Area3D = $Area3D
 
@onready var menu_cores_3d: Node3D = $MenuCores3D
@onready var quadrado_vermelho: Node3D = $MenuCores3D/QuadradoVermelho
@onready var quadrado_azul: Node3D = $MenuCores3D/QuadradoAzul
@onready var quadrado_amarelo: Node3D = $MenuCores3D/QuadradoAmarelo
@onready var quadrado_verde: Node3D = $MenuCores3D/QuadradoVerde
 
# Deslocamento (local) aplicado SÓ aos visuais quando a mira está sobre a carta.
# A Area3D (hitbox) fica parada, por isso o hover não faz a mira "perder" a carta
# nem pular para a vizinha (era isso que causava o flicker).
@export var deslocamento_hover: Vector3 = Vector3(0, 0.05, 0.05)
@export var duracao_hover: float = 0.12
# Folga (em metros) somada à malha da carta ao testar o raio da mira
@export var margem_mira: float = 0.004
# Aparência da carta virada para baixo (mãos dos deuses).
# Se quiser o verso do UNO, arraste a textura para "Textura Verso".
@export var cor_verso: Color = Color(0.07, 0.07, 0.07)
@export var textura_verso: Texture2D
# Distância (em pixels) do centro da tela para considerar um quadrado de cor "mirado"
@export var raio_selecao_cor: float = 45.0
 
# Duração (s) do giro quando o poder do baralho vira as cartas dos deuses
@export var duracao_virada: float = 0.35

var indice_na_mao: int = -1
var _tem_verso: bool = false      # true se esta carta foi virada para baixo (mostrar_verso)
var _revelada: bool = false       # true enquanto o poder mantém a carta virada para o jogador
var _rot_y_antes: float = 0.0
var _tween_virada: Tween
var posicao_base: Vector3 
var tween: Tween
var carta_dados_atual: Carta
 
var pos_base_quadrados: Dictionary = {}
var escala_base_quadrados: Dictionary = {}
 
# Visuais que sobem no hover e suas posições originais
var _bases_visuais: Dictionary = {}
 
# 0.0 = repouso, 1.0 = totalmente em hover (animado pelo tween)
var hover_t: float = 0.0:
	set(valor):
		hover_t = valor
		_aplicar_hover()
 
const CORES_CARTA = {
	Carta.Cor.VERMELHA: Color(0.85, 0.15, 0.15),
	Carta.Cor.AZUL: Color(0.15, 0.45, 0.85),
	Carta.Cor.AMARELA: Color(0.95, 0.75, 0.1),
	Carta.Cor.VERDE: Color(0.15, 0.75, 0.25),
	Carta.Cor.PRETA: Color(0.1, 0.1, 0.1)
}
 
func _ready():
	_guardar_posicoes_visuais()
	if menu_cores_3d:
		menu_cores_3d.visible = false
		_guardar_posicoes_quadrados()
 
func _guardar_posicoes_visuais() -> void:
	for n in [mesh_instance, label_texto, label_texto2, label_texto3, menu_cores_3d]:
		if n:
			_bases_visuais[n] = n.position
 
func _aplicar_hover() -> void:
	for n in _bases_visuais.keys():
		if n and is_instance_valid(n):
			n.position = _bases_visuais[n] + deslocamento_hover * hover_t
 
# Hover dos quadrados de cor enquanto o menu do coringa está aberto
func _process(_delta: float) -> void:
	if menu_cores_3d and menu_cores_3d.visible:
		var alvo = _quadrado_sob_mira()
		for node in pos_base_quadrados.keys():
			if node and is_instance_valid(node):
				var base: Vector3 = escala_base_quadrados.get(node, Vector3.ONE)
				node.scale = base * (1.25 if (not alvo.is_empty() and alvo["no"] == node) else 1.0)
 
func _lista_quadrados() -> Array:
	return [
		{ "no": quadrado_vermelho, "cor": Carta.Cor.VERMELHA },
		{ "no": quadrado_azul, "cor": Carta.Cor.AZUL },
		{ "no": quadrado_amarelo, "cor": Carta.Cor.AMARELA },
		{ "no": quadrado_verde, "cor": Carta.Cor.VERDE }
	]
 
func _guardar_posicoes_quadrados():
	for q in _lista_quadrados():
		var node = q["no"]
		if node:
			pos_base_quadrados[node] = node.position
			escala_base_quadrados[node] = node.scale
 
func setup(carta_dado: Carta, index: int):
	indice_na_mao = index
	carta_dados_atual = carta_dado
	atualizar_visual(carta_dado)
	if menu_cores_3d:
		menu_cores_3d.visible = false
		resetar_hover_quadrados()
 
# Distância da origem do raio até a face da carta (INF se o raio não acerta).
# Usa a malha visível na posição de repouso (sem o deslocamento do hover),
# então a área de mira não "foge" do dot quando a carta sobe.
func distancia_do_raio(origem: Vector3, direcao: Vector3) -> float:
	if mesh_instance == null or mesh_instance.mesh == null:
		return INF
	var base: Vector3 = _bases_visuais.get(mesh_instance, mesh_instance.position)
	var t: Transform3D = global_transform * Transform3D(mesh_instance.transform.basis, base)
	var inv: Transform3D = t.affine_inverse()
	var caixa: AABB = mesh_instance.get_aabb().grow(margem_mira)
	var hit = caixa.intersects_ray(inv * origem, inv.basis * direcao)
	if hit == null:
		return INF
	return origem.distance_to(t * (hit as Vector3))
 
# Vira a carta para baixo: esconde os textos e pinta com a cor/textura do verso.
# Chamar depois de setup().
func mostrar_verso() -> void:
	_tem_verso = true
	for rotulo in [label_texto, label_texto2, label_texto3]:
		if rotulo:
			rotulo.visible = false
	if menu_cores_3d:
		menu_cores_3d.visible = false
	if mesh_instance:
		var mat_original = mesh_instance.get_surface_override_material(0)
		var mat: StandardMaterial3D = mat_original.duplicate() if mat_original else StandardMaterial3D.new()
		mat.albedo_color = Color.WHITE if textura_verso != null else cor_verso
		mat.albedo_texture = textura_verso
		# Visível dos dois lados: o jogador enxerga o verso das cartas do outro lado da mesa
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mesh_instance.set_surface_override_material(0, mat)
 
# Vira a carta para o jogador ver a frente (cor + número) ou volta ao verso.
# Se a frente já estiver voltada para a câmera, só mostra os textos, sem girar.
func virar_frente(ativo: bool, animar: bool = true) -> void:
	if ativo == _revelada:
		return
	_revelada = ativo
	if _tween_virada and _tween_virada.is_running():
		_tween_virada.kill()

	var alvo_y: float = _rot_y_antes
	if ativo:
		_rot_y_antes = rotation.y
		alvo_y = _rot_y_antes + (PI if _frente_esta_de_costas() else 0.0)

	if not animar:
		rotation.y = alvo_y
		_aplicar_aparencia(ativo)
		return

	_tween_virada = create_tween()
	_tween_virada.set_trans(Tween.TRANS_CUBIC)
	_tween_virada.set_ease(Tween.EASE_IN_OUT)
	_tween_virada.tween_property(self, "rotation:y", alvo_y, duracao_virada)
	# Troca textos/cores no meio do giro, quando a carta está "de lado"
	_tween_virada.parallel().tween_callback(func():
		if _revelada == ativo:
			_aplicar_aparencia(ativo)
	).set_delay(duracao_virada * 0.5)

func _frente_esta_de_costas() -> bool:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return false
	var frente: Vector3 = global_transform.basis.z.normalized()
	return frente.dot(cam.global_position - global_position) < 0.0

func _aplicar_aparencia(frente_visivel: bool) -> void:
	var no_verso: Node3D = get_node_or_null("Mesh/Verso") as Node3D
	if frente_visivel:
		for rotulo in [label_texto, label_texto2, label_texto3]:
			if rotulo:
				rotulo.visible = true
		if no_verso:
			no_verso.visible = false
		if _tem_verso and mesh_instance:
			atualizar_visual(carta_dados_atual)
			var mat := mesh_instance.get_surface_override_material(0) as StandardMaterial3D
			if mat:
				mat.albedo_texture = null
	else:
		if no_verso:
			no_verso.visible = true
		if _tem_verso:
			mostrar_verso()

func definir_posicao_base(pos: Vector3):
	position = pos
	posicao_base = pos
 
# Anima o destaque da carta (chamado quando a mira entra/sai dela).
# Só os visuais se movem; o nó raiz e a Area3D permanecem na posição base.
func definir_hover(ativo: bool) -> void:
	if tween and tween.is_running():
		tween.kill()
	tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "hover_t", 1.0 if ativo else 0.0, duracao_hover)
 
func atualizar_visual(carta_dado: Carta):
	if carta_dado == null:
		return
		
	if label_texto:
		label_texto.text = carta_dado.para_texto()
		label_texto2.text = carta_dado.para_texto()
		label_texto3.text = carta_dado.para_texto()
	
	if mesh_instance:
		var mat_original = mesh_instance.get_surface_override_material(0)
		var mat_unico: StandardMaterial3D = mat_original.duplicate() if mat_original else StandardMaterial3D.new()
		mat_unico.albedo_color = CORES_CARTA.get(carta_dado.cor, Color.WHITE)
		mesh_instance.set_surface_override_material(0, mat_unico)
 
# Função chamada pelo controlador quando o raycast acerta esta carta específica
func interagir_por_mira():
	if menu_cores_3d and menu_cores_3d.visible:
		return
		
	if carta_dados_atual and (carta_dados_atual.valor == Carta.Valor.MAIS_QUATRO or carta_dados_atual.valor == Carta.Valor.MUDAR_COR or carta_dados_atual.cor == Carta.Cor.PRETA):
		if menu_cores_3d:
			menu_cores_3d.visible = !menu_cores_3d.visible
	else:
		carta_clicada.emit(indice_na_mao)
 
# Devolve o quadrado de cor mais próximo do centro da tela (ou {} se nenhum)
func _quadrado_sob_mira() -> Dictionary:
	var camera = get_viewport().get_camera_3d()
	if not camera:
		return {}
	
	# Ponto da tela onde o dot está desenhado (o controlador sabe onde é)
	var centro_ecra: Vector2 = get_viewport().get_visible_rect().size / 2
	var controlador = get_tree().get_first_node_in_group("controlador_jogo")
	if controlador and controlador.has_method("obter_ponto_mira"):
		centro_ecra = controlador.obter_ponto_mira()
	var melhor: Dictionary = {}
	var menor_dist := raio_selecao_cor
	
	for q in _lista_quadrados():
		var node = q["no"]
		if node and is_instance_valid(node):
			var pos_3d = node.global_position
			if camera.is_position_behind(pos_3d):
				continue
			var dist = centro_ecra.distance_to(camera.unproject_position(pos_3d))
			if dist <= menor_dist:
				menor_dist = dist
				melhor = q
	return melhor
 
# Tratamento para seleção de cor do coringa usando o centro da tela
func verificar_clique_menu_cores() -> bool:
	if not menu_cores_3d or not menu_cores_3d.visible:
		return false
	
	var escolhido = _quadrado_sob_mira()
	
	menu_cores_3d.visible = false
	resetar_hover_quadrados()
	
	if not escolhido.is_empty():
		carta_jogada_com_cor.emit(indice_na_mao, escolhido["cor"])
	
	# Clique fora de qualquer quadrado apenas fecha o menu
	return true
 
func resetar_hover_quadrados():
	for node in pos_base_quadrados.keys():
		if node and is_instance_valid(node):
			node.position = pos_base_quadrados[node]
			node.scale = escala_base_quadrados.get(node, Vector3.ONE)
 
