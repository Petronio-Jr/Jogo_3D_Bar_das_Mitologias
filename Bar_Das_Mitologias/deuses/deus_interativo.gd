extends Node3D

# Anexe este script ao nó raiz de cada deus (Anubis, Hefesto, Odin).
# Ele só pode ser escolhido pela mira enquanto o controlador permitir
# (durante a habilidade do Anubis); nesse momento ele ganha um contorno branco ao ser mirado.

signal selecionado(nome_jogador: String)

# Nome do jogador correspondente a este deus: Anubis, Hefesto ou Odin
# (precisa ser igual ao nome usado em iniciar_jogo() no controlador)
@export var nome_jogador: String = "Anubis"
# Folga (em metros) somada à malha ao testar o raio da mira (malhas animadas pedem folga maior)
@export var margem_mira: float = 0.15
# Contorno ao mirar no deus
@export var cor_linha: Color = Color(1.0, 1.0, 1.0)
# Espessura do contorno em pixels (constante na tela, não depende do tamanho do modelo)
@export var largura_linha: float = 3.0

# Contorno por "casco invertido": a malha é redesenhada um pouco maior, só com as faces de
# trás, em branco. Sobra uma linha em volta da silhueta.
const SHADER_LINHA: String = """
shader_type spatial;
render_mode unshaded, cull_front;

uniform vec4 cor_linha : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float largura_px = 3.0;

void vertex() {
	vec4 pos_clip = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	vec3 normal_clip = mat3(PROJECTION_MATRIX) * (mat3(MODELVIEW_MATRIX) * NORMAL);
	vec2 dir = normal_clip.xy;
	if (length(dir) > 0.0001) {
		dir = normalize(dir);
		pos_clip.xy += dir / VIEWPORT_SIZE * pos_clip.w * largura_px * 2.0;
	}
	POSITION = pos_clip;
}

void fragment() {
	ALBEDO = cor_linha.rgb;
}
"""

var _malhas: Array = []
var _material_linha: ShaderMaterial

func _ready() -> void:
	add_to_group("deuses")
	_malhas = find_children("*", "MeshInstance3D", true, false)
	var este: Node = self
	if este is MeshInstance3D:
		_malhas.append(este)
	
	var shader := Shader.new()
	shader.code = SHADER_LINHA
	_material_linha = ShaderMaterial.new()
	_material_linha.shader = shader
	_material_linha.set_shader_parameter("cor_linha", cor_linha)
	_material_linha.set_shader_parameter("largura_px", largura_linha)

# Liga/desliga a possibilidade de escolher este deus pela mira
func set_selecionavel(ativo: bool) -> void:
	if ativo:
		add_to_group("deuses_selecionaveis")
	else:
		remove_from_group("deuses_selecionaveis")
		definir_hover(false)

# Chamado pelo controlador quando o dot entra/sai do deus
func definir_hover(ativo: bool) -> void:
	for m in _malhas:
		if is_instance_valid(m):
			m.material_overlay = _material_linha if ativo else null

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
