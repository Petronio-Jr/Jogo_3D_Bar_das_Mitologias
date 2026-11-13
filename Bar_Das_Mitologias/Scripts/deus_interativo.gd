extends Node3D

# Anexe este script ao nó raiz de cada deus (Anubis, Hefesto, Odin).
# Ele só pode ser escolhido pela mira enquanto o controlador permitir
# (durante a habilidade do Anubis). Nesse momento:
#  - cada deus ganha uma plaquinha flutuando acima da cabeça: "[2] Hefesto" (o número é a tecla);
#  - ao mirar nele, a plaquinha cresce, fica dourada com setas (▼ Hefesto ▼) e um
#    HOLOFOTE cai do alto sobre o deus (combina com a sala às escuras da habilidade).

signal selecionado(nome_jogador: String)

# Nome do jogador correspondente a este deus: Anubis, Hefesto ou Odin
# (precisa ser igual ao nome usado em iniciar_jogo() no controlador)
@export var nome_jogador: String = "Anubis"
# Folga (em metros) somada à malha ao testar o raio da mira (malhas animadas pedem folga maior)
@export var margem_mira: float = 0.15

@export_group("Destaque ao mirar")
@export var cor_destaque: Color = Color(1.0, 0.85, 0.3)     # cor da plaquinha e do holofote
@export var cor_plaquinha: Color = Color(1, 1, 1, 0.85)     # plaquinha quando NÃO está mirado
@export var altura_plaquinha: float = 0.4          # distância acima da cabeça (m)
@export var tamanho_plaquinha: float = 0.006       # tamanho do texto no mundo (pixel_size do Label3D)
@export var escala_plaquinha_hover: float = 1.35
@export var luz_energia: float = 10.0
@export var luz_altura: float = 3.5                # altura do holofote acima da cabeça (m)
@export var luz_angulo: float = 26.0               # abertura do cone (graus)

var _malhas: Array = []
var _marcador: Label3D
var _luz: SpotLight3D
var _tween_luz: Tween
var _tween_marcador: Tween
var _selecionavel: bool = false
var _hover: bool = false
var _numero: int = 0
var _tempo: float = 0.0
var _base_marcador: Vector3 = Vector3.ZERO

func _ready() -> void:
	add_to_group("deuses")
	_malhas = find_children("*", "MeshInstance3D", true, false)
	var este: Node = self
	if este is MeshInstance3D:
		_malhas.append(este)
	_criar_marcador()
	_criar_luz()

# --- Nós do destaque (criados por código, não precisa mexer na cena) ---

func _criar_marcador() -> void:
	_marcador = Label3D.new()
	_marcador.font_size = 64
	_marcador.pixel_size = tamanho_plaquinha
	_marcador.outline_size = 24
	_marcador.outline_modulate = Color(0.05, 0.0, 0.0, 1.0)
	_marcador.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_marcador.no_depth_test = true      # aparece mesmo atrás de cartas/mesa
	_marcador.fixed_size = false
	_marcador.top_level = true          # não herda giro/escala do modelo do deus
	_marcador.visible = false
	add_child(_marcador)

func _criar_luz() -> void:
	_luz = SpotLight3D.new()
	_luz.top_level = true
	_luz.light_color = cor_destaque
	_luz.light_energy = 0.0
	_luz.spot_angle = luz_angulo
	_luz.spot_angle_attenuation = 0.7
	_luz.shadow_enabled = false
	_luz.visible = false
	add_child(_luz)

# Topo (cabeça) e centro do deus no mundo, somando as malhas visíveis
func _caixa_global() -> AABB:
	var caixa := AABB()
	var primeiro: bool = true
	for m in _malhas:
		if not is_instance_valid(m) or m.mesh == null or not m.is_visible_in_tree():
			continue
		var c: AABB = (m as MeshInstance3D).global_transform * (m as MeshInstance3D).get_aabb()
		if primeiro:
			caixa = c
			primeiro = false
		else:
			caixa = caixa.merge(c)
	if primeiro:
		caixa = AABB(global_position - Vector3(0.5, 0.0, 0.5), Vector3(1.0, 2.0, 1.0))
	return caixa

func _posicionar() -> void:
	var caixa: AABB = _caixa_global()
	var centro: Vector3 = caixa.get_center()
	var topo_y: float = caixa.position.y + caixa.size.y
	_base_marcador = Vector3(centro.x, topo_y + altura_plaquinha, centro.z)
	_marcador.global_position = _base_marcador
	_luz.global_position = Vector3(centro.x, topo_y + luz_altura, centro.z)
	_luz.rotation_degrees = Vector3(-90.0, 0.0, 0.0)      # aponta para baixo
	_luz.spot_range = luz_altura + caixa.size.y + 1.0

func _process(delta: float) -> void:
	if not _selecionavel:
		return
	_tempo += delta
	# a plaquinha "boia" de leve (mais rápido quando mirado)
	var vel: float = 5.0 if _hover else 2.5
	_marcador.global_position = _base_marcador + Vector3.UP * sin(_tempo * vel) * 0.03

func _texto(mirado: bool) -> String:
	if mirado:
		return "▼ %s ▼" % nome_jogador
	return "[%d] %s" % [_numero, nome_jogador] if _numero > 0 else nome_jogador

# Liga/desliga a possibilidade de escolher este deus pela mira.
# `numero` = tecla que também o escolhe (1, 2, 3...); 0 = não mostra.
func set_selecionavel(ativo: bool, numero: int = 0) -> void:
	_selecionavel = ativo
	_numero = numero
	if ativo:
		add_to_group("deuses_selecionaveis")
		_posicionar()
		_hover = false
		_aplicar_estilo(false, false)
		_marcador.scale = Vector3.ZERO
		_marcador.visible = true
		if _tween_marcador != null and _tween_marcador.is_valid():
			_tween_marcador.kill()
		_tween_marcador = create_tween()
		_tween_marcador.tween_property(_marcador, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		remove_from_group("deuses_selecionaveis")
		_hover = false
		_marcador.visible = false
		_acender_luz(false)

# Chamado pelo controlador quando o dot entra/sai do deus
func definir_hover(ativo: bool) -> void:
	if ativo == _hover or (ativo and not _selecionavel):
		return
	_hover = ativo
	if not _selecionavel:
		return
	_aplicar_estilo(ativo, true)
	_acender_luz(ativo)
	if ativo:
		Som.sfx("ui_hover")

func _aplicar_estilo(mirado: bool, animar: bool) -> void:
	_marcador.text = _texto(mirado)
	_marcador.modulate = cor_destaque if mirado else cor_plaquinha
	var alvo: Vector3 = Vector3.ONE * (escala_plaquinha_hover if mirado else 1.0)
	if animar and _marcador.visible:
		if _tween_marcador != null and _tween_marcador.is_valid():
			_tween_marcador.kill()
		_tween_marcador = create_tween()
		_tween_marcador.tween_property(_marcador, "scale", alvo, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		_marcador.scale = alvo

func _acender_luz(ligar: bool) -> void:
	if _tween_luz != null and _tween_luz.is_valid():
		_tween_luz.kill()
	_tween_luz = create_tween()
	if ligar:
		_luz.visible = true
		_tween_luz.tween_property(_luz, "light_energy", luz_energia, 0.25)
	else:
		_tween_luz.tween_property(_luz, "light_energy", 0.0, 0.2)
		_tween_luz.tween_callback(func(): _luz.visible = false)

# Chamado pelo controlador quando o jogador clica no deus
func interagir_por_mira() -> void:
	selecionado.emit(nome_jogador)

# Distância da origem do raio até o deus (INF se o raio não acerta)
func distancia_do_raio(origem: Vector3, direcao: Vector3) -> float:
	var melhor: float = INF
	for m in _malhas:
		if not is_instance_valid(m) or m.mesh == null or not m.is_visible_in_tree():
			continue
		var t: Transform3D = m.global_transform
		var inv: Transform3D = t.affine_inverse()
		var caixa: AABB = m.get_aabb().grow(margem_mira)
		var hit = caixa.intersects_ray(inv * origem, inv.basis * direcao)
		if hit != null:
			melhor = minf(melhor, origem.distance_to(t * (hit as Vector3)))
	return melhor
