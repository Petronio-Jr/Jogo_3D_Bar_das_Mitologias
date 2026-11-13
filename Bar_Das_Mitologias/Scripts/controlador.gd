class_name ControladorJogo
extends Node3D
## Orquestrador da partida. A lógica específica está nos módulos abaixo.

# Emitido quando o jogador escolhe o deus que vai comprar cartas (nome do jogador)
signal deus_escolhido(nome: String)

# --- Módulos (criados no _ready) ---
var mira: MiraJogo
var visual: VisualMesa
var pilha: PilhaMesa
var regras: RegrasJogo
var acoes_humano: AcoesHumano
var cerebro_ia: CerebroIA
var habilidade: HabilidadeAnubis
var balanca: BalancaAnubis
var poder_odin: PoderOdin
var poder: PoderBaralho
var uno: AvisoUno
var embriaguez: Embriaguez

# --- Estado da partida ---
var baralho: Baralho
var jogadores: Array[Jogador] = []
var indice_jogador_atual: int = 0
var jogo_ativo: bool = false # Começa falso até sentar na cadeira
var numero_turno_atual: int = 1

# --- Sistema de Melhor de 3 ---
var vitorias_jogadores: Dictionary = {}
var ultimo_vencedor_nome: String = ""
@export var objetivo_vitorias: int = 2

# --- Configuração geral / IA ---
@export var tempo_resposta_ia: float = 1.5
# false = cartas dos deuses viradas para baixo; true = viradas para cima
@export var mostrar_cartas_ia: bool = false

# --- Carta voando da mão do deus até a mesa ---
@export var atraso_voo_carta: float = 0.5     # segundos após o início da animação do deus
@export var duracao_voo_carta: float = 0.6
@export var altura_saida_carta: float = 0.15  # quanto a carta sobe antes de ir ao centro

# --- Pilha de cartas jogadas no centro da mesa ---
@export var cartas_na_pilha: int = 4           # quantas cartas ficam visíveis
@export var escala_carta_pilha: float = 1.8     # TAMANHO FINAL da carta na mesa (1.0 = igual à da mão)
@export var distancia_vertical_pilha: float = 0.012    # altura entre uma carta e a de cima (m); aumente se ainda se sobrescreverem
@export var distancia_horizontal_pilha: float = 0.06   # afastamento lateral entre as cartas da pilha (m); 0 = empilhadas retas
@export var desvio_max_pilha: float = 0.02     # deslocamento aleatório extra (m)
@export var giro_max_pilha: float = 20.0       # giro aleatório (graus)

# --- Configuração da mira (dot) ---
@export var alcance_mira: float = 10.0
@export var dot_mira: CanvasItem
@export var criar_dot_se_nao_achar: bool = true
@export var debug_mira: bool = false

# --- Habilidade especial do Anubis ---
@export var rodadas_para_habilidade: int = 1
@export_range(0.0, 1.0, 0.05) var chance_habilidade_anubis: float = 0.5
@export var cartas_jogador_compra: int = 4
@export var cartas_deus_compra: int = 2
var animacao_habilidade: String = "Habilidade"
var testar_habilidade: bool = false

# --- Poder do jogador (baralho_poder) ---
# Se ficar vazio, o nó "baralho_poder" é procurado automaticamente na cena.
@export var baralho_poder: Node3D
@export var turnos_recarga_poder: int = 5
@export var eixo_virada_poder: Vector3 = Vector3.RIGHT  # eixo LOCAL em que o baralho de poder gira (tente RIGHT, FORWARD ou UP)
@export var duracao_virada_poder: float = 0.5
@export var altura_virada_poder: float = 0.1            # quanto levanta no meio do giro
@export var duracao_poder: float = 5.0   # segundos com as cartas dos deuses reveladas

# --- Cerveja (embriaguez) ---
# Se ficar vazio, o nó é procurado pelo nome ("cerveja"/"beer").
@export var cerveja: Node3D
@export var limite_bebidas: int = 10            # nesta dose a tela escurece
@export var forca_tontura_base: float = 1.0
@export var aumento_forca_por_dose: float = 0.35
@export var duracao_tontura_base: float = 10.0
@export var duracao_extra_por_dose: float = 2.0
@export var tempo_fechar_olho: float = 4.0      # tempo até a tela ficar preta
@export var reabrir_apos_apagar: bool = true
@export var tempo_olho_fechado: float = 5.0     # tempo preto antes de reabrir

# --- Poder do Odin (troca de baralho) ---
@export var rodadas_para_poder_odin: int = 6
@export var duracao_troca_odin: float = 0.9        # voo de cada carta (s)
@export var atraso_entre_cartas_troca: float = 0.07 # cascata entre as cartas (s)
@export var altura_arco_troca_odin: float = 0.35   # quanto as cartas sobem no meio do voo (m)
var testar_poder_odin: bool = false                # true = Odin checa em TODA vez dele (teste)

# --- Balança da habilidade ---
@export var altura_queda_balanca: float = 4.0
@export var duracao_descida_balanca: float = 3.0
@export var anim_balanca_castigo: String = "BaixarEsquerda"
@export var anim_balanca_sorte: String = "BaixarDireita"
@export_range(0.0, 1.0, 0.05) var chance_balanca_castigo: float = 0.5

# --- Animação de sentar na mesa ---
@export_group("Animação de sentar")
@export var duracao_sentar: float = 1.8          # 0 = sem animação (troca direto de câmera)
@export var balanco_passos: float = 0.02         # sobe e desce da câmera enquanto "anda" até a cadeira (m)
@export var queda_ao_sentar: float = 0.04        # afundada rápida no fim, quando "senta" (m)

# --- Combos e aviso de UNO ---
@export_group("Combos e UNO")
@export var cartas_minimas_apos_combo: int = 2       # combo nunca deixa menos que isso na mão (2 = não zera nem fica com UNO)
@export_range(0.0, 1.0, 0.05) var chance_combo_ia: float = 0.5   # chance de um deus combar quando puder
@export var intervalo_combo: float = 0.18            # tempo entre uma carta e outra do combo (s)
@export var altura_aviso_uno: float = 0.8            # altura do "UNO!" acima da pilha (m)
@export var tamanho_aviso_uno: float = 2.2            # escala da escrita "UNO!"

# --- Nós da cena ---
@onready var anim_anubis: AnimationPlayer = $"Cenário/deuses/anubis/AnimationPlayer2"
@onready var container_mao_3d = $PosicaoMaoHumano
@onready var baralho_visual: Node3D = $Baralho_mesa
@onready var camera_jogador: Camera3D = $Camera3D
@onready var jogador_andando: Node = get_node_or_null("Jogador") # personagem que anda pelo mapa

#========================================================================
#--- CICLO DE VIDA / INPUT ---
#========================================================================

func _ready() -> void:
	# O mouse começa capturado para andar e olhar ao redor no mapa 3D
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	add_to_group("controlador_jogo")
	MenuPausa.instalar(self)   # ESC abre o menu de pausa (Retomar / Opções / Sair)

	mira = MiraJogo.new(self)
	visual = VisualMesa.new(self)
	pilha = PilhaMesa.new(self)
	regras = RegrasJogo.new(self)
	acoes_humano = AcoesHumano.new(self)
	cerebro_ia = CerebroIA.new(self)
	habilidade = HabilidadeAnubis.new(self)
	balanca = BalancaAnubis.new(self)
	poder_odin = PoderOdin.new(self)
	poder = PoderBaralho.new(self)
	embriaguez = Embriaguez.new(self)
	uno = AvisoUno.new(self)

	mira.localizar_dot()
	balanca.preparar()

	if container_mao_3d and container_mao_3d.has_signal("carta_clicada"):
		container_mao_3d.carta_clicada.connect(acoes_humano.on_carta_jogada)
	if container_mao_3d and container_mao_3d.has_signal("carta_jogada_com_cor"):
		container_mao_3d.carta_jogada_com_cor.connect(acoes_humano.on_carta_jogada_com_cor)

# Função chamada pelo script da cadeira quando o jogador interage
func iniciar_jogo_por_interacao() -> void:
	print("[Controlador] Jogador sentou-se na cadeira. A iniciar o jogo de cartas...")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	embriaguez.resetar()   # contagem de bebidas começa junto com o jogo
	Som.partida()          # música de jogo + pagode mais baixinho

	# "Congela" o personagem que andava e faz a câmera caminhar até a cadeira e sentar
	if jogador_andando != null:
		jogador_andando.process_mode = Node.PROCESS_MODE_DISABLED
	await _animar_sentar()
	camera_jogador.make_current()

	jogo_ativo = true
	iniciar_jogo()

## Câmera temporária: sai de onde o jogador está, anda até a mesa, desce e "senta".
func _animar_sentar() -> void:
	var origem: Camera3D = get_viewport().get_camera_3d()
	if duracao_sentar <= 0.0 or origem == null or origem == camera_jogador:
		return
	var t0: Transform3D = origem.global_transform
	var t1: Transform3D = camera_jogador.global_transform
	var q0: Quaternion = t0.basis.orthonormalized().get_rotation_quaternion()
	var q1: Quaternion = t1.basis.orthonormalized().get_rotation_quaternion()

	var cam := Camera3D.new()
	cam.near = origem.near
	cam.far = origem.far
	cam.cull_mask = origem.cull_mask
	cam.environment = origem.environment
	cam.attributes = origem.attributes
	add_child(cam)
	cam.global_transform = t0
	cam.fov = origem.fov
	cam.make_current()

	# Sons: passos até a cadeira e o arrastar da cadeira perto do fim
	for k in [0.08, 0.34, 0.60]:
		Som.sfx("passo", -6.0, 0.15, duracao_sentar * k)
	Som.sfx("cadeira", 0.0, 0.0, duracao_sentar * 0.62)

	var tw: Tween = create_tween()
	tw.tween_method(func(k: float): _quadro_sentar(cam, k, t0.origin, t1.origin, q0, q1, origem.fov, camera_jogador.fov), 0.0, 1.0, duracao_sentar)
	await tw.finished

	camera_jogador.make_current()
	cam.queue_free()

func _quadro_sentar(cam: Camera3D, k: float, p0: Vector3, p1: Vector3, q0: Quaternion, q1: Quaternion, fov0: float, fov1: float) -> void:
	if not is_instance_valid(cam):
		return
	var e: float = k * k * (3.0 - 2.0 * k)                 # suaviza o movimento horizontal e o giro
	var ky: float = clampf((k - 0.35) / 0.65, 0.0, 1.0)    # a descida só começa depois de chegar perto
	ky = ky * ky * (3.0 - 2.0 * ky)
	var pos := Vector3(lerpf(p0.x, p1.x, e), lerpf(p0.y, p1.y, ky), lerpf(p0.z, p1.z, e))
	pos.y += sin(k * TAU * 3.0) * balanco_passos * (1.0 - k)                        # balanço dos passos
	pos.y -= sin(clampf((k - 0.8) / 0.2, 0.0, 1.0) * PI) * queda_ao_sentar          # "plof" ao sentar
	cam.global_transform = Transform3D(Basis(q0.slerp(q1, e)), pos)
	cam.fov = lerpf(fov0, fov1, e)

func vez_do_jogador() -> bool:
	return jogo_ativo and not jogadores.is_empty() and jogadores[indice_jogador_atual].eh_o_player

func _process(_delta: float) -> void:
	if not jogo_ativo or jogadores.is_empty():
		return
	mira.atualizar_foco()

func _input(event: InputEvent) -> void:
	if not jogo_ativo:
		return

	if habilidade.escolhendo_deus and event is InputEventKey and event.pressed and not event.echo:
		habilidade.tratar_tecla(event)
		return

	if habilidade.evento_em_andamento and not habilidade.escolhendo_deus:
		return

	# Botão direito: marca/desmarca cartas para o combo
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			mira.selecionar_carta()
		return

	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return

	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return

	var minha_vez: bool = vez_do_jogador()
	if minha_vez and _clique_no_menu_de_cores():
		return
	mira.interagir(minha_vez)

func _clique_no_menu_de_cores() -> bool:
	for carta_vis in container_mao_3d.get_children():
		if carta_vis.has_method("verificar_clique_menu_cores") and carta_vis.verificar_clique_menu_cores():
			return true
	return false

#========================================================================
#--- INICIALIZAÇÃO E MELHOR DE 3 ---
#========================================================================

func iniciar_jogo() -> void:
	Som.sfx("carta_embaralhar")
	visual.mostrar_hud()   # indicador de turno e contagem aparecem só quando o jogo inicia
	baralho = Baralho.new()
	poder.resetar()   # o jogador recebe o poder no 1º turno
	_criar_jogadores()
	_distribuir_cartas()
	_virar_primeira_carta()
	_definir_primeiro_jogador()

	mira.carta_em_foco = -1
	visual.atualizar_mao_humano(jogadores[0], 1)
	visual.atualizar_maos_ia()
	visual.atualizar_indicador_turno()

	# Se quem começa for uma IA, executa o turno dela automaticamente logo no início
	if not jogadores[indice_jogador_atual].eh_o_player and jogo_ativo:
		proximo_turno()

func _criar_jogadores() -> void:
	jogadores.clear()
	jogadores.append(Jogador.new("Humano", true))
	jogadores.append(Jogador.new("Anubis", false))
	jogadores.append(Jogador.new("Hefesto", false))
	jogadores.append(Jogador.new("Odin", false))

	# Inicializa contador de vitórias se ainda não existir
	for j in jogadores:
		if not vitorias_jogadores.has(j.nome):
			vitorias_jogadores[j.nome] = 0

func _distribuir_cartas() -> void:
	for j in jogadores:
		for i in range(7):
			j.adicionar_carta(baralho.puxar())

func _virar_primeira_carta() -> void:
	var primeira_carta = baralho.puxar()
	while primeira_carta.cor == Carta.Cor.PRETA:
		baralho.cartas_baralho.push_front(primeira_carta)
		primeira_carta = baralho.puxar()
	baralho.descartar(primeira_carta)
	visual.atualizar_carta_mesa()

# O vencedor anterior é o primeiro a jogar na nova ronda
func _definir_primeiro_jogador() -> void:
	if ultimo_vencedor_nome == "":
		indice_jogador_atual = 0
		return
	for i in range(jogadores.size()):
		if jogadores[i].nome == ultimo_vencedor_nome:
			indice_jogador_atual = i
			break

func verificar_fim_partida(vencedor: Jogador) -> void:
	vitorias_jogadores[vencedor.nome] += 1
	ultimo_vencedor_nome = vencedor.nome
	uno.limpar()
	print("[Partida] Vencedor da ronda: ", vencedor.nome, " | Placar: ", vitorias_jogadores)

	if vitorias_jogadores[vencedor.nome] >= objetivo_vitorias:
		jogo_ativo = false
		Som.sfx("vitoria_serie" if vencedor.eh_o_player else "derrota")
		visual.mensagem(vencedor.nome + " venceu a série (Melhor de 3)! Pressione ESC.")
		print("[Série] O jogador ", vencedor.nome, " venceu a melhor de 3!")
	else:
		Som.sfx("vitoria_ronda" if vencedor.eh_o_player else "derrota")
		visual.mensagem(vencedor.nome + " venceu esta ronda! A reiniciar...")
		await get_tree().create_timer(2.5, false).timeout
		reiniciar_ronda()

func reiniciar_ronda() -> void:
	regras.resetar_ronda()
	habilidade.resetar_ronda()
	poder_odin.resetar_ronda()
	numero_turno_atual = 1
	jogo_ativo = true
	iniciar_jogo()

#========================================================================
#--- FLUXO DE TURNOS ---
#========================================================================

func proximo_turno() -> void:
	if not jogo_ativo:
		return
	_avancar_vez()

	while not jogadores[indice_jogador_atual].eh_o_player and jogo_ativo:
		await cerebro_ia.processar_turno(jogadores[indice_jogador_atual])
		if jogo_ativo:
			_avancar_vez()

	if jogo_ativo:
		habilidade.registrar_rodada()
		poder_odin.registrar_rodada()
		poder.registrar_turno()
		visual.atualizar_mao_player()
		Som.sfx("turno_jogador", -6.0)   # "ding": voltou a vez do jogador

# Passa a vez (respeitando bloqueio), gira a carta da mesa e aplica compra acumulada
func _avancar_vez() -> void:
	for i in range(regras.passos_para_avancar):
		avancar_indice_jogador()
	visual.girar_carta_mesa(regras.passos_para_avancar)
	regras.passos_para_avancar = 1
	visual.atualizar_indicador_turno()
	regras.processar_compra_cartas(jogadores[indice_jogador_atual])

func avancar_indice_jogador() -> void:
	indice_jogador_atual = (indice_jogador_atual + regras.sentido) % jogadores.size()
	if indice_jogador_atual < 0:
		indice_jogador_atual = jogadores.size() - 1
	# Um turno novo começa toda vez que a vez passa pelo jogador (jogando ou sendo pulado)
	if jogadores[indice_jogador_atual].eh_o_player:
		numero_turno_atual += 1
