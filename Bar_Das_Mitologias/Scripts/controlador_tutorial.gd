class_name ControladorTutorial
extends ControladorJogo
## TUTORIAL: um X1 contra UM deus, numa mesa própria em outra parte do mapa.
## É um segundo controlador de jogo: usa o mesmo motor (mãos 3D, pilha, mira, combos, UNO),
## só que com 2 jogadores e textos de ajuda. NADA é lido dos deuses/nós da mesa principal:
## o deus, a carta do centro e as mãos vêm todos de dentro deste nó (ou dos campos abaixo).
##
## MONTAGEM: um Node3D com este script e, dentro dele, os mesmos nós da mesa do jogo
## (PosicaoMaoHumano, Baralho_mesa, Camera3D, CartaMesa, baralho_poder), o deus desta mesa
## (com PosicaoMao e ContadorCartas dentro) e uma cadeira com cadeira_tutorial.gd.
## Arraste o deus para `No Deus` (e o AnimationPlayer dele para `Animador Deus`, se quiser).
##
## O tutorial só ensina o básico (comandos e cartas especiais). As habilidades NÃO são explicadas.
## Regras do X1: INVERTER funciona como bloqueio (quem jogou joga de novo). A habilidade do deus
## é própria do tutorial (passa uma carta dele para a sua mão) e independe do nome do deus.

signal tutorial_terminou(venceu: bool)

@export_group("Deus do tutorial")
@export var nome_deus: String = "Shiva"      
@export var no_deus: Node3D                      # modelo do deus DESTA mesa (com PosicaoMao e ContadorCartas)
@export var animador_deus: AnimationPlayer       # vazio = acha, dentro do deus, o que tiver JOGAR_CARTA
@export var carta_mesa_tutorial: Node3D          # vazio = nó "CartaMesa" desta mesa

@export_group("Ritmo")
@export var habilidade_do_deus_ativa: bool = true
@export var rodadas_ate_habilidade_deus: int = 7   # a habilidade do deus pode disparar a cada N rodadas
@export var tempo_explicacao: float = 7.0    # quanto cada explicação de carta fica na tela (s); depois voltam os comandos
@export var tempo_aviso_deus: float = 10.0   # o aviso do poder do deus fica fixo na tela por este tempo (nada o substitui)
@export var pausa_antes_habilidade_deus: float = 3.0   # tempo lendo o aviso antes da habilidade do deus começar (s)
@export var recarga_inicial_poder: int = 1   # o SEU poder carrega daqui a N turnos seus (1 = no próximo turno)
@export var pausa_ao_fim: float = 3.0        # tempo olhando o resultado antes de levantar (s)

@export_group("Textos (BBCode)")
@export var titulo_comandos: String = "COMANDOS"
@export_multiline var texto_comandos: String = \
	"[b]Jogar:[/b] botão [color=gold]ESQUERDO[/color] numa carta da mesma cor ou número da carta do centro.\n\n" \
	+ "[b]Combo:[/b] botão [color=gold]DIREITO[/color] em cartas de mesmo valor; depois ESQUERDO em uma delas.\n\n" \
	+ "[b]Comprar:[/b] botão [color=gold]ESQUERDO[/color] no [color=gold]baralho[/color] da mesa: você compra uma carta dele e passa a vez."

@export_group("Avisos dos poderes (BBCode) - não dizem o que o poder faz")
@export var titulo_poder: String = "SEU PODER"
@export_multiline var texto_poder: String = \
	"Você tem uma [b]habilidade especial[/b] deixada na mesa por outro deus: a [color=gold]carta preta[/color] na mesa.\n\n" \
	+ "Use-a com o botão [color=gold]ESQUERDO[/color] na sua vez. É possível dar zoom usando o scroll do mouse"
@export var texto_poder_pronto: String = "[color=lime]Disponível agora![/color]"
@export var texto_poder_recarga: String = "[color=orange]Recarregando: faltam {restante} turno(s).[/color]"
@export var titulo_deus: String = "PODER DO DEUS"
@export_multiline var texto_deus: String = \
	"Todo deus tem uma [b]habilidade especial[/b], assim como o sua.\n\n" \
	+ "Observe, aprenda e adapte-se a elas. [color=gold]Deuses são seres trapaceiros![/color]"

## Explicação de cada carta especial: aparece UMA vez, na hora em que a carta é jogada.
const EXPLICACOES: Dictionary = {
	Carta.Valor.MAIS_DOIS: ["CARTA +2", "O próximo compra 2. Se ele tiver outro +2, pode devolver e a soma aumenta."],
	Carta.Valor.MAIS_QUATRO: ["CARTA +4", "O próximo compra 4 e quem jogou escolhe a cor. Também pode ser devolvido com outro +2/+4."],
	Carta.Valor.BLOQUEIO: ["BLOQUEIO", "O adversário perde a vez e quem jogou joga de novo."],
	Carta.Valor.INVERTER: ["INVERTER", "No 1x1, inverter funciona como bloqueio: quem jogou joga de novo."],
	Carta.Valor.MUDAR_COR: ["CORINGA", "Vale sempre e quem jogou escolhe a cor."],
}

## true enquanto o jogador está sentado jogando o tutorial.
var em_andamento: bool = false
var hud: HudTutorial

var _sessao: int = 0   # muda a cada início/fim: cancela textos antigos
var _texto_id: int = 0 # identifica o texto que está na tela (para o timer não apagar um mais novo)
var _explicados: Array = []
var _avisou_poder: bool = false   # o aviso do SEU poder aparece só na 1ª vez
var _bloqueio_texto: bool = false  # true = aviso do deus na tela: outros textos esperam
var _avisou_deus: bool = false    # o aviso do poder do DEUS aparece só na 1ª vez
var _camera_andar: Camera3D = null


#========================================================================
#--- PEÇAS PRÓPRIAS DO TUTORIAL ---
#========================================================================

## Mesma VisualMesa do jogo, mas sem textos de turno/aviso na tela (o tutorial só usa o bloco lateral).
class VisualTutorial extends VisualMesa:
	func _init(controlador: ControladorJogo) -> void:
		super(controlador)

	func mensagem(_texto: String) -> void:
		pass

	func atualizar_indicador_turno() -> void:
		atualizar_todos_contadores_ia()
		if ctrl.uno != null:
			ctrl.uno.atualizar()

## Mesmas regras do jogo; avisa o tutorial quando uma carta é jogada (para explicar a carta especial).
class RegrasTutorial extends RegrasJogo:
	var ao_jogar: Callable

	func _init(controlador: ControladorJogo, aviso: Callable) -> void:
		super(controlador)
		ao_jogar = aviso

	func processar_efeito_carta(carta: Carta, tocar_som: bool = true) -> void:
		if carta.valor == Carta.Valor.INVERTER:
			passos_para_avancar += 1   # no X1, inverter = bloqueio (a vez volta para quem jogou)
			if tocar_som:
				Som.sfx("efeito_inverter", 0.0, 0.0, 0.45)
		else:
			super.processar_efeito_carta(carta, tocar_som)
		ao_jogar.call(carta)

## Habilidade do deus do X1: ergue uma carta dele, cria uma cópia ao lado, destrói a original
## e manda a cópia para a mão do jogador (a carta sai da mão dele e entra na sua).
## Não dispara com UNO (só 1 carta) e só a cada `rodadas_para_habilidade` rodadas.
class HabilidadeTutorial extends HabilidadeAnubis:
	const CARTA_UI_3D_SCENE = preload("res://Interagiveis/carta_ui_3d.tscn")
	const SOM_HABILIDADE: String = "habilidade_deus"   # res://audio/sfx/habilidade_deus.(ogg|mp3|wav)

	func _init(controlador: ControladorJogo) -> void:
		super(controlador)

	## Som próprio da habilidade (se o arquivo ainda não existir, cai no som de poder do jogo).
	func _som(nome_fallback: String = "poder_ativar") -> void:
		Som.sfx(SOM_HABILIDADE if Som.stream_sfx(SOM_HABILIDADE) != null else nome_fallback)

	func deve_ativar() -> bool:
		if rodadas_desde_checagem < ctrl.rodadas_para_habilidade:
			return false
		if ctrl.jogadores[1].mao.size() < 2:
			return false   # com UNO ele não pode
		rodadas_desde_checagem = 0
		return true

	func ativar() -> void:
		evento_em_andamento = true   # trava o jogador enquanto o aviso está na tela
		await (ctrl as ControladorTutorial).avisar_poder_do_deus()
		var deus: Jogador = ctrl.jogadores[1]
		var humano: Jogador = ctrl.jogadores[0]
		var indice: int = randi() % deus.mao.size()
		var carta: Carta = deus.mao[indice]
		var maos: Node3D = ctrl.visual.maos_ia.get(deus.nome) as Node3D
		var original: Node3D = null
		if maos != null and maos.has_method("obter_carta_visual"):
			original = maos.obter_carta_visual(indice)

		evento_em_andamento = true
		var copia: Node3D = null
		if original != null:
			AnimUtil.tocar_e_voltar_idle(ctrl.anim_anubis, ctrl.animacao_habilidade)
			copia = await _animar(deus, carta, original, maos)

		# Lógica: a carta sai da mão dele e entra na do jogador
		deus.remover_carta(indice)
		humano.adicionar_carta(carta)
		if copia != null and is_instance_valid(copia):
			copia.free()
		ctrl.visual.atualizar_mao_ia(deus)
		ctrl.visual.atualizar_mao_player()
		Som.sfx("carta_comprar", 0.0, 0.06)
		await ctrl.get_tree().create_timer(0.5, false).timeout
		evento_em_andamento = false
		ctrl.visual.atualizar_indicador_turno()

	## Erguer -> copiar ao lado -> destruir a original -> copia voa até a mão do jogador.
	## Devolve a cópia (já pousada no lugar da nova carta da mão do jogador).
	func _animar(deus: Jogador, carta: Carta, original: Node3D, maos: Node3D) -> Node3D:
		# 1) ergue
		var alto: Vector3 = original.global_position + Vector3.UP * 0.45
		_som()
		var tw: Tween = ctrl.create_tween()
		tw.tween_property(original, "global_position", alto, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		await tw.finished

		# 2) cópia ao lado (e vira para mostrar a frente)
		var copia: Node3D = CARTA_UI_3D_SCENE.instantiate()
		ctrl.add_child(copia)
		copia.call("setup", carta, 0)
		copia.global_transform = original.global_transform
		var de_frente: bool = bool(maos.get("mostrar_frente")) or bool(maos.get("revelada"))
		if not de_frente:
			_verso(copia, deus.nome, maos)
		var lado: Vector3 = ctrl.camera_jogador.global_transform.basis.x
		lado.y = 0.0
		lado = lado.normalized() * 0.32
		Som.sfx("carta_combo")
		var tw2: Tween = ctrl.create_tween()
		tw2.tween_property(copia, "global_position", alto + lado, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		if not de_frente:
			copia.call("virar_frente", true, true)
		await tw2.finished

		# 3) destrói a original
		Som.sfx("carta_invalida")
		var tw3: Tween = ctrl.create_tween()
		tw3.tween_property(original, "scale", Vector3.ZERO, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		await tw3.finished
		original.visible = false

		# 4) a cópia voa para a mão do jogador, no lugar da carta nova
		var mao_jogador: Node3D = ctrl.container_mao_3d as Node3D
		var total: int = ctrl.jogadores[0].mao.size() + 1
		var esp: float = float(mao_jogador.get("espacamento_x"))
		var sobre: float = float(mao_jogador.get("sobreposicao_z"))
		var slot: int = total - 1
		var destino: Transform3D = mao_jogador.global_transform * Transform3D(Basis.IDENTITY, Vector3((slot - (total - 1) / 2.0) * esp, 0.0, slot * sobre))
		var p0: Vector3 = copia.global_position
		var q0: Quaternion = copia.global_transform.basis.orthonormalized().get_rotation_quaternion()
		var e0: Vector3 = copia.global_transform.basis.get_scale()
		var p1: Vector3 = destino.origin
		var q1: Quaternion = destino.basis.orthonormalized().get_rotation_quaternion()
		var e1: Vector3 = destino.basis.get_scale()
		Som.sfx("carta_jogar", 0.0, 0.07)
		var tw4: Tween = ctrl.create_tween()
		tw4.tween_method(func(t: float): _mover(copia, t, p0, q0, e0, p1, q1, e1), 0.0, 1.0, 0.9)
		await tw4.finished
		return copia

	func _mover(no: Node3D, t: float, p0: Vector3, q0: Quaternion, e0: Vector3, p1: Vector3, q1: Quaternion, e1: Vector3) -> void:
		if not is_instance_valid(no):
			return
		var k: float = t * t * (3.0 - 2.0 * t)
		var pos: Vector3 = p0.lerp(p1, k) + Vector3.UP * sin(t * PI) * 0.3
		no.global_transform = Transform3D(Basis(q0.slerp(q1, k)).scaled(e0.lerp(e1, k)), pos)

	## Deixa a cópia virada para baixo, com a cor de verso do deus (igual à das cartas da mão dele).
	func _verso(no: Node3D, nome: String, maos: Node3D) -> void:
		no.call("mostrar_verso")
		var cor: Color = Color(0.07, 0.07, 0.07)
		var cores = maos.get("cores_verso_deuses")
		if cores is Dictionary and cores.has(nome):
			cor = cores[nome]
		var verso := no.get_node_or_null("Mesh/Verso") as MeshInstance3D
		if verso != null:
			var mat := StandardMaterial3D.new()
			mat.albedo_color = cor
			verso.set_surface_override_material(0, mat)

## O cérebro do jogo só usa a habilidade se o deus se chamar "Anubis"; aqui vale para qualquer deus do X1.
class CerebroTutorial extends CerebroIA:
	func _init(controlador: ControladorJogo) -> void:
		super(controlador)

	func processar_turno(ia: Jogador) -> void:
		if ctrl.habilidade.deve_ativar():
			await ctrl.habilidade.ativar()
		await super.processar_turno(ia)


#========================================================================
#--- CICLO DE VIDA ---
#========================================================================

func _ready() -> void:
	criar_dot_se_nao_achar = false          # usa a mira do jogo principal (ver _preparar_jogador)
	super._ready()
	remove_from_group("controlador_jogo")   # a cadeira/cartas do jogo principal não podem achar este
	add_to_group("controlador_tutorial")

	hud = HudTutorial.new()
	add_child(hud)
	_montar_mesa()
	_religar_poder_do_jogador()

	# Uma rodada decide. A habilidade do deus é a do tutorial; as do Anubis/Odin do jogo ficam desligadas.
	rodadas_para_habilidade = rodadas_ate_habilidade_deus if habilidade_do_deus_ativa else 999999
	rodadas_para_poder_odin = 999999

## O controlador do jogo procura a carta do centro e os deuses nos caminhos da mesa principal
## ("Cenário/..."). Aqui ligamos tudo aos nós deste tutorial.
func _montar_mesa() -> void:
	if no_deus == null:
		push_error("[Tutorial] Arraste o deus desta mesa para 'No Deus' no Controlador do tutorial.")

	var animador: AnimationPlayer = _achar_animador()
	anim_anubis = animador
	cerebro_ia = CerebroTutorial.new(self)
	cerebro_ia.animadores = {nome_deus: animador}
	habilidade = HabilidadeTutorial.new(self)
	regras = RegrasTutorial.new(self, _ao_carta_jogada)

	var v := VisualTutorial.new(self)
	v.carta_mesa = carta_mesa_tutorial if carta_mesa_tutorial != null else find_child("CartaMesa", true, false)
	v.contadores_ia = {nome_deus: _filho_do_deus("ContadorCartas")}
	v.maos_ia = {nome_deus: _filho_do_deus("PosicaoMao")}
	visual = v
	pilha = PilhaMesa.new(self)   # só pode ser criada depois da carta do centro estar ligada

## O baralho de poder TEM que ser o desta mesa (se o campo estiver vazio ou apontar para o da mesa
## principal, o clique não funcionaria). Procura dentro do tutorial e recria o poder.
func _religar_poder_do_jogador() -> void:
	var proprio: Node3D = baralho_poder
	if proprio == null or not is_ancestor_of(proprio):
		proprio = null
		for n in find_children("*", "Node3D", true, false):
			var nome: String = String(n.name).to_lower().replace("_", "").replace(" ", "")
			if nome.begins_with("baralhopoder"):
				proprio = n
				break
	if proprio == null:
		push_error("[Tutorial] Não achei o 'baralho_poder' DENTRO do tutorial: sem ele o poder não funciona. Coloque um (copie o da mesa) e arraste para 'Baralho Poder'.")
		return
	baralho_poder = proprio
	poder = PoderBaralho.new(self)

func _filho_do_deus(nome: String) -> Node:
	return null if no_deus == null else no_deus.find_child(nome, true, false)

func _achar_animador() -> AnimationPlayer:
	if animador_deus != null or no_deus == null:
		return animador_deus
	for no in no_deus.find_children("*", "AnimationPlayer", true, false):
		var player := no as AnimationPlayer
		if AnimUtil.resolver(player, "JOGAR_CARTA") != "":
			return player
	return null

func _criar_jogadores() -> void:
	jogadores.clear()
	jogadores.append(Jogador.new("Humano", true))
	jogadores.append(Jogador.new(nome_deus, false))
	for j in jogadores:
		if not vitorias_jogadores.has(j.nome):
			vitorias_jogadores[j.nome] = 0

## Chamado pela cadeira_tutorial.gd (no lugar do iniciar_jogo_por_interacao do jogo principal).
func iniciar_jogo_por_interacao() -> void:
	if em_andamento:
		return
	em_andamento = true
	_sessao += 1
	_explicados.clear()
	ultimo_vencedor_nome = ""
	vitorias_jogadores.clear()
	numero_turno_atual = 1
	regras.resetar_ronda()
	regras.sentido = 1
	habilidade.resetar_ronda()
	poder_odin.resetar_ronda()
	acoes_humano.ocupado = false
	_avisou_poder = false
	_avisou_deus = false
	_bloqueio_texto = false
	_preparar_jogador()
	hud.mostrar(true)
	await super.iniciar_jogo_por_interacao()   # anda até a cadeira, senta e chama iniciar_jogo()

func iniciar_jogo() -> void:
	super.iniciar_jogo()
	poder.recarga_restante = maxi(recarga_inicial_poder, 1)   # o poder carrega no próximo turno e aí o jogo avisa
	visual.atualizar_indicador_turno()
	_mostrar_textos()

## Pega do jogo principal o personagem que anda e a mira (o tutorial não tem os seus).
func _preparar_jogador() -> void:
	for no in get_tree().get_nodes_in_group("controlador_jogo"):
		var principal := no as ControladorJogo
		if principal != null and principal != self:
			jogador_andando = principal.jogador_andando
			if principal.dot_mira != null:
				dot_mira = principal.dot_mira
			break
	_camera_andar = null
	if jogador_andando != null:
		var cameras: Array[Node] = jogador_andando.find_children("*", "Camera3D", true, false)
		if not cameras.is_empty():
			_camera_andar = cameras[0] as Camera3D


#========================================================================
#--- FIM DA PARTIDA ---
#========================================================================

## Fim da rodada: mostra o resultado, levanta e devolve o jogador ao mapa.
func verificar_fim_partida(vencedor: Jogador) -> void:
	uno.limpar()
	jogo_ativo = false
	var venceu: bool = vencedor.eh_o_player
	_texto_id += 1
	Som.sfx("vitoria_serie" if venceu else "derrota")
	if venceu:
		hud.mostrar_info("VITÓRIA", "Você derrotou %s! Tutorial concluído." % nome_deus)
		Configuracoes.definir("tutorial_feito", true)
	else:
		hud.mostrar_info("DERROTA", "%s venceu. Sente de novo para tentar outra vez." % nome_deus)
	await get_tree().create_timer(pausa_ao_fim, false).timeout
	await _levantar(venceu)

func _levantar(venceu: bool) -> void:
	_sessao += 1   # cancela qualquer texto pendente
	await hud.fade(1.0, 0.5)

	for j in jogadores:   # limpa a mesa para a próxima vez
		j.mao.clear()
	visual.atualizar_mao_humano(jogadores[0], 0)
	visual.atualizar_maos_ia()
	pilha.limpar()
	poder.resetar()
	mira.carta_em_foco = -1
	hud.esconder_info()

	if jogador_andando != null:
		jogador_andando.process_mode = Node.PROCESS_MODE_INHERIT
	if _camera_andar != null:
		_camera_andar.make_current()
	else:
		push_warning("[Tutorial] Câmera do jogador que anda não encontrada: ela precisa ser filha do nó 'Jogador'.")
	Som.pagode_passeio()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	em_andamento = false
	await hud.fade(0.0, 0.5)
	hud.mostrar(false)
	tutorial_terminou.emit(venceu)


#========================================================================
#--- TEXTOS (comandos no início; cartas especiais só quando aparecem) ---
#========================================================================

## Os comandos ficam na tela sempre que nenhuma explicação está sendo mostrada.
func _mostrar_textos() -> void:
	_texto_id += 1
	hud.mostrar_info(titulo_comandos, texto_comandos)

## O poder do jogador carregou (chamado pelo PoderBaralho): explica só na primeira vez.
func ao_poder_carregado() -> void:
	if not em_andamento or _avisou_poder or _bloqueio_texto:
		return
	_avisou_poder = true
	_mostrar(titulo_poder, texto_poder + "\n\n" + texto_poder_pronto, tempo_explicacao)

## O jogador clicou no poder ainda recarregando: repete a explicação e mostra quantos turnos faltam.
func ao_poder_em_recarga(restante: int) -> void:
	if not em_andamento or _bloqueio_texto:
		return
	_mostrar(titulo_poder, texto_poder + "\n\n" + texto_poder_recarga.format({"restante": restante}), tempo_explicacao)

## A habilidade do deus vai começar: explica só na primeira vez e espera um pouco para dar tempo de ler.
func avisar_poder_do_deus() -> void:
	if not em_andamento or _avisou_deus:
		return
	_avisou_deus = true
	_bloqueio_texto = true   # cartas jogadas e outros avisos não trocam este texto
	var sessao: int = _sessao
	_mostrar(titulo_deus, texto_deus.format({"deus": nome_deus}), tempo_aviso_deus)
	get_tree().create_timer(tempo_aviso_deus, false).timeout.connect(func(): if sessao == _sessao: _bloqueio_texto = false)
	await get_tree().create_timer(pausa_antes_habilidade_deus, false).timeout

func _ao_carta_jogada(carta: Carta) -> void:
	if not em_andamento or _bloqueio_texto or _explicados.has(carta.valor) or not EXPLICACOES.has(carta.valor):
		return
	_explicados.append(carta.valor)
	var e: Array = EXPLICACOES[carta.valor]
	_mostrar(e[0], e[1], tempo_explicacao)

## Mostra uma explicação no bloco e, depois de `tempo`, devolve os comandos (se nenhum outro texto tomou o lugar).
func _mostrar(titulo: String, texto: String, tempo: float) -> void:
	_texto_id += 1
	var id: int = _texto_id
	var sessao: int = _sessao
	hud.mostrar_info(titulo, texto)
	await get_tree().create_timer(tempo, false).timeout
	if id == _texto_id and sessao == _sessao and jogo_ativo:
		_mostrar_textos()
