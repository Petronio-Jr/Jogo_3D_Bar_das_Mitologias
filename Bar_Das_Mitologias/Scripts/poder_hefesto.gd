class_name PoderHefesto
extends RefCounted
## Poder do Hefesto: a cada `rodadas_para_poder_hefesto` rodadas, na vez dele, ele joga uma
## carta COMUM (número) na mesa e ela é FORJADA: gira e vira uma carta PRETA com um símbolo.
## Com a carta da mesa preta, só cartas pretas (+4 e coringa) podem ser jogadas; as demais
## obrigam a comprar. Quem joga uma preta escolhe a cor e o jogo volta ao normal.
##
## Se na vez dele não houver carta comum jogável, o poder fica "pronto" para a próxima vez.

const VOLUME_SOM_DB: float = -10.0   # volume do som da forja (mais negativo = mais baixo)

var ctrl: ControladorJogo

var rodadas_desde_uso: int = 0
var pronto: bool = false          # carregado: usa assim que jogar uma carta comum
var em_andamento: bool = false
var _trocou: bool = false

func _init(controlador: ControladorJogo) -> void:
	ctrl = controlador

func resetar_ronda() -> void:
	rodadas_desde_uso = 0
	pronto = false
	em_andamento = false

## Uma vez por rodada completa (junto com o poder do Odin e a habilidade do Anubis).
func registrar_rodada() -> void:
	if pronto:
		return
	rodadas_desde_uso += 1
	if rodadas_desde_uso >= ctrl.rodadas_para_poder_hefesto:
		rodadas_desde_uso = 0
		pronto = randf() < ctrl.chance_poder_hefesto   # tenta forjar; se não der, tenta de novo daqui a N rodadas

## Carta comum = colorida e com número (sem efeito). Só essa pode virar a carta forjada.
func eh_comum(carta: Carta) -> bool:
	return carta != null and carta.cor != Carta.Cor.PRETA and carta.valor <= Carta.Valor.NOVE

## A carta que ele acabou de jogar (já no topo) é forjada: vira preta com o símbolo.
func ativar() -> void:
	pronto = false
	rodadas_desde_uso = 0
	em_andamento = true

	var original: Carta = ctrl.baralho.obter_topo()
	var forjada := Carta.new(Carta.Cor.PRETA, Carta.Valor.FORJA)
	# A carta original volta para o descarte (por baixo); a forjada ocupa o topo
	ctrl.baralho.pilha_descarte.pop_back()
	if original != null:
		ctrl.baralho.pilha_descarte.append(original)
	ctrl.baralho.descartar(forjada)

	ctrl.visual.mensagem("Hefesto forja a carta!\nSó cartas pretas podem ser jogadas.")
	Som.sfx("hefesto_forja", VOLUME_SOM_DB)

	var no: Node3D = null
	if not ctrl.pilha.cartas.is_empty():
		no = ctrl.pilha.cartas.back()
	if no != null and is_instance_valid(no):
		await _girar_e_trocar(no, forjada)
	await ctrl.get_tree().create_timer(1.2, false).timeout

	em_andamento = false
	ctrl.visual.atualizar_indicador_turno()

## A carta levanta um pouco e dá uma volta completa (virando como uma panqueca); quando está de
## costas, a face troca para a carta preta com o símbolo.
func _girar_e_trocar(no: Node3D, forjada: Carta) -> void:
	_trocou = false
	var t0: Transform3D = no.global_transform
	var eixo: Vector3 = ctrl.pilha._eixos_mesa()[0]   # eixo "para longe do jogador": a carta gira como uma moeda
	var tw: Tween = ctrl.create_tween()
	tw.tween_method(func(k: float): _quadro_forja(no, forjada, k, t0, eixo), 0.0, 1.0, maxf(ctrl.duracao_forja, 0.01))
	await tw.finished
	if is_instance_valid(no):
		no.global_transform = t0
		if not _trocou:
			no.call("setup", forjada, 0)

func _quadro_forja(no: Node3D, forjada: Carta, k: float, t0: Transform3D, eixo: Vector3) -> void:
	if not is_instance_valid(no):
		return
	var e: float = k * k * (3.0 - 2.0 * k)
	var ang: float = TAU * e
	if not _trocou and ang >= PI:
		_trocou = true
		no.call("setup", forjada, 0)   # de costas: a face vira a carta preta com o símbolo
	var altura: float = sin(k * PI) * ctrl.altura_forja
	no.global_transform = Transform3D(Basis(eixo, ang) * t0.basis, t0.origin + Vector3.UP * altura)
