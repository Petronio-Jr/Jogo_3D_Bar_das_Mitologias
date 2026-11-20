extends Node3D
 
signal carta_clicada(indice: int)
signal carta_jogada_com_cor(indice: int, cor_escolhida: int)
 
const CARTA_UI_3D_SCENE = preload("res://Interagiveis/carta_ui_3d.tscn")
 
@export var espacamento_x: float = 0.2   
@export var sobreposicao_z: float = 0.01  
 
# false = cartas viradas para baixo (usado nas mãos dos deuses)
@export var mostrar_frente: bool = true

# --- Configurações da Animação de Surgimento ---
@export var duracao_surgimento: float = 0.4
@export var offset_surgimento_y: float = -0.5

# --- Cores do Verso para cada Deus ---
@export var cores_verso_deuses: Dictionary = {
	"Anubis": Color(0.578, 0.452, 0.0, 1.0),   # Vermelho
	"Hefesto": Color(0.453, 0.062, 0.038, 1.0),  # Laranja
	"Odin": Color(0.08, 0.243, 0.648, 1.0)      # Azul
}
@export var cor_verso_padrao: Color = Color(0.07, 0.07, 0.07)
 
var cartas_visuais: Array = []
var _fim_animacao_ms: int = 0   # até quando a animação de surgimento ainda está rolando

# true = cartas viradas para o jogador (poder do baralho). Recriações da mão
# durante o poder já nascem viradas.
var revelada: bool = false

# Vira (ou desvira) todas as cartas desta mão
func revelar(ativo: bool, animar: bool = true) -> void:
	revelada = ativo
	for c in cartas_visuais:
		if is_instance_valid(c) and c.has_method("virar_frente"):
			c.virar_frente(ativo, animar)
 
func atualizar_mao(humano: Jogador, modo_animacao: int = 0, qtd_novas: int = 1) -> void:
	# Guarda onde cada carta antiga estava e se ainda estava subindo: se a mão for refeita no meio
	# da animação (ex.: outra atualização logo depois de recomeçar), as cartas CONTINUAM subindo
	# a partir de onde estavam, em vez de aparecerem paradas no lugar final.
	var animando: bool = Time.get_ticks_msec() < _fim_animacao_ms
	var posicoes_antigas: Array[Vector3] = []
	for c in cartas_visuais:
		posicoes_antigas.append((c as Node3D).position if is_instance_valid(c) else Vector3.ZERO)

	# Remove as antigas na hora (sem esperar o queue_free): os índices não se misturam
	for child in get_children():
		remove_child(child)
		child.queue_free()
	cartas_visuais.clear()

	var total: int = humano.mao.size()
	if total == 0:
		_fim_animacao_ms = 0
		return

	var centro: float = (total - 1) / 2.0
	var cor_deus: Color = cores_verso_deuses.get(humano.nome, cor_verso_padrao)   # cor do verso deste deus
	var fim_ms: int = 0

	for i in range(total):
		var nova_carta = CARTA_UI_3D_SCENE.instantiate()
		add_child(nova_carta)
		cartas_visuais.append(nova_carta)

		nova_carta.setup(humano.mao[i], i)
		if not mostrar_frente and nova_carta.has_method("mostrar_verso"):
			nova_carta.mostrar_verso()
			var no_verso = nova_carta.get_node_or_null("Mesh/Verso")
			if no_verso and no_verso is MeshInstance3D:
				var mat := StandardMaterial3D.new()
				mat.albedo_color = cor_deus
				no_verso.set_surface_override_material(0, mat)

		nova_carta.carta_clicada.connect(func(idx): carta_clicada.emit(idx))
		nova_carta.carta_jogada_com_cor.connect(func(idx, cor): carta_jogada_com_cor.emit(idx, cor))

		var offset: float = i - centro
		var pos_final := Vector3(offset * espacamento_x, 0.0, i * sobreposicao_z)
		nova_carta.rotation = Vector3.ZERO
		if revelada and nova_carta.has_method("virar_frente"):
			nova_carta.virar_frente(true, false)

		var animar: bool = false
		var pos_inicio: Vector3 = pos_final + Vector3(0.0, offset_surgimento_y, 0.0)
		var atraso: float = 0.0
		var duracao: float = duracao_surgimento
		if modo_animacao == 1:
			animar = true   # anima a mão toda (início)
			atraso = i * 0.08
		elif modo_animacao == 2 and i >= (total - qtd_novas):
			animar = true   # anima só as últimas N cartas compradas
			atraso = (i - (total - qtd_novas)) * 0.08
		elif animando and i < posicoes_antigas.size() and posicoes_antigas[i].distance_to(pos_final) > 0.005:
			animar = true   # mão refeita no meio da subida: continua de onde estava
			pos_inicio = posicoes_antigas[i]
			duracao = minf(duracao_surgimento, 0.25)

		if animar:
			nova_carta.position = pos_inicio
			# O tween fica na própria carta: se ela for removida, ele morre junto (sem erros)
			var tween: Tween = nova_carta.create_tween()
			tween.tween_property(nova_carta, "position", pos_final, duracao)\
				.set_delay(atraso)\
				.set_trans(Tween.TRANS_BACK)\
				.set_ease(Tween.EASE_OUT)
			fim_ms = maxi(fim_ms, Time.get_ticks_msec() + int((atraso + duracao) * 1000.0))
		else:
			nova_carta.position = pos_final
	_fim_animacao_ms = fim_ms

# Devolve o nó visual pelo índice da mão (não depende da ordem de get_child,
# que pode divergir enquanto os nós antigos aguardam queue_free)
func obter_carta_visual(indice: int) -> Node3D:
	if indice >= 0 and indice < cartas_visuais.size() and is_instance_valid(cartas_visuais[indice]):
		return cartas_visuais[indice]
	return null
 
# Destaca apenas a carta que está sob a mira (-1 = nenhuma)
# Testa o raio da mira contra a malha de cada carta e devolve a mais próxima
# da câmera: {"indice": int (-1 se nenhuma), "dist": float}
func testar_raio(origem: Vector3, direcao: Vector3) -> Dictionary:
	var melhor: Dictionary = {"indice": -1, "dist": INF}
	for i in range(cartas_visuais.size()):
		var carta_visual = cartas_visuais[i]
		if not is_instance_valid(carta_visual) or not carta_visual.has_method("distancia_do_raio"):
			continue
		var d: float = carta_visual.distancia_do_raio(origem, direcao)
		if d < melhor["dist"]:
			melhor = {"indice": i, "dist": d}
	return melhor
 
func definir_foco(indice: int) -> void:
	for i in range(cartas_visuais.size()):
		var carta_visual = cartas_visuais[i]
		if is_instance_valid(carta_visual) and carta_visual.has_method("definir_hover"):
			carta_visual.definir_hover(i == indice)
