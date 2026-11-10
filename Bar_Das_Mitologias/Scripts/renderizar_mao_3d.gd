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
	# Limpa as cartas antigas
	for child in get_children():
		child.queue_free()
	cartas_visuais.clear()

	var total = humano.mao.size()
	if total == 0:
		return

	var centro = (total - 1) / 2.0
	
	# Descobre a cor do verso com base no nome do deus atual (ou usa a padrão)
	var cor_deus = cores_verso_deuses.get(humano.nome, cor_verso_padrao)

	for i in range(total):
		var carta_dados = humano.mao[i]
		var nova_carta = CARTA_UI_3D_SCENE.instantiate()
		
		add_child(nova_carta)
		cartas_visuais.append(nova_carta)
		
		nova_carta.setup(carta_dados, i)
		if not mostrar_frente and nova_carta.has_method("mostrar_verso"):
			nova_carta.mostrar_verso()
			
			# Altera a cor do mesh Verso específico deste deus
			var no_verso = nova_carta.get_node_or_null("Mesh/Verso")
			if no_verso and no_verso is MeshInstance3D:
				var mat = StandardMaterial3D.new()
				mat.albedo_color = cor_deus
				no_verso.set_surface_override_material(0, mat)

		nova_carta.carta_clicada.connect(func(idx): carta_clicada.emit(idx))
		nova_carta.carta_jogada_com_cor.connect(func(idx, cor): carta_jogada_com_cor.emit(idx, cor))

		# Cálculo da posição final na mão
		var offset = i - centro
		var pos_final = Vector3(offset * espacamento_x, 0.0, i * sobreposicao_z)
		nova_carta.rotation = Vector3.ZERO
		if revelada and nova_carta.has_method("virar_frente"):
			nova_carta.virar_frente(true, false)

		# Define se esta carta deve subir com animação
		var animar = false
		if modo_animacao == 1:
			animar = true # Anima a mão toda (início)
		elif modo_animacao == 2 and i >= (total - qtd_novas):
			animar = true # Anima apenas as últimas N cartas compradas

		if animar:
			# Define a posição inicial rebaixada (abaixo da mesa)
			var pos_inicio = pos_final + Vector3(0.0, offset_surgimento_y, 0.0)
			nova_carta.position = pos_inicio

			# Calcula um pequeno atraso em cascata para cada carta nova
			var indice_relativo = i - (total - qtd_novas) if modo_animacao == 2 else i
			var atraso = indice_relativo * 0.08

			var tween = create_tween()
			tween.tween_property(nova_carta, "position", pos_final, duracao_surgimento)\
				.set_delay(atraso)\
				.set_trans(Tween.TRANS_BACK)\
				.set_ease(Tween.EASE_OUT)
		else:
			nova_carta.position = pos_final

# Detecta a carta através do raio disparado pelo centro da câmera
func obter_indice_carta_por_collider(collider: Node) -> int:
	if collider == null:
		return -1
	for i in range(cartas_visuais.size()):
		var carta_visual = cartas_visuais[i]
		if not is_instance_valid(carta_visual):
			continue
		if carta_visual == collider or carta_visual.is_ancestor_of(collider):
			return i
	return -1
 
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
