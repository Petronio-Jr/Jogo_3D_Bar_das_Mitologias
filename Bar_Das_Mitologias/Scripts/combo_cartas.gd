class_name ComboCartas
extends RefCounted
## Regras do combo: jogar 2+ cartas de MESMO VALOR juntas (ex.: 2 azul + 2 verde + 2 vermelho).
## - Só cartas coloridas (pretas não entram).
## - Pelo menos uma das cartas tem que combinar com a mesa (cor ou valor).
## - O combo nunca pode deixar menos de `minimo_restante` cartas na mão (padrão 2):
##   ou seja, não dá para zerar a mão nem ficar com UNO usando combo.
## - Com compra acumulada ativa, só combo de +2.
## A ÚLTIMA carta da lista fica no topo da mesa e define a cor.

static func eh_preta(c: Carta) -> bool:
	return c.cor == Carta.Cor.PRETA or c.valor == Carta.Valor.MAIS_QUATRO or c.valor == Carta.Valor.MUDAR_COR

## "" = combo válido; senão devolve o motivo (texto para mostrar ao jogador).
static func validar(mao: Array[Carta], indices: Array[int], topo: Carta, compras_acumuladas: int, minimo_restante: int) -> String:
	if indices.size() < 2:
		return "Combo: escolha 2 ou mais cartas de mesmo valor."
	var valor: Carta.Valor = mao[indices[0]].valor
	var alguma_combina: bool = false
	for i in indices:
		var c: Carta = mao[i]
		if eh_preta(c):
			return "Cartas pretas não entram em combo."
		if c.valor != valor:
			return "Combo: só cartas com o mesmo valor."
		if topo == null or c.cor == topo.cor or c.valor == topo.valor:
			alguma_combina = true
	if compras_acumuladas > 0 and valor != Carta.Valor.MAIS_DOIS:
		return "Com compra acumulada só vale combo de +2."
	if mao.size() - indices.size() < minimo_restante:
		return "Combo não pode deixar menos de %d cartas na mão." % minimo_restante
	if not alguma_combina:
		return "Nenhuma carta do combo combina com a mesa."
	return ""

static func _combina_com_mesa(c: Carta, topo: Carta) -> bool:
	return topo == null or c.cor == topo.cor or c.valor == topo.valor

## Índices em ordem de jogada. A PRIMEIRA carta jogada tem que combinar com a mesa (cor ou valor);
## as seguintes têm o mesmo valor, então sempre encaixam.
## `final` (a carta clicada) fica no topo sempre que possível. Se ela é a única que combina com a
## mesa, ela é obrigada a ir primeiro e uma das outras fica no topo.
static func ordenar_com_final(mao: Array[Carta], indices: Array[int], final: int, topo: Carta) -> Array[int]:
	var outros: Array[int] = []
	for i in indices:
		if i != final:
			outros.append(i)
	outros.sort()
	var ordem: Array[int] = []
	# as que combinam com a mesa vêm antes das que não combinam
	var combinam: Array[int] = []
	var demais: Array[int] = []
	for i in outros:
		if _combina_com_mesa(mao[i], topo):
			combinam.append(i)
		else:
			demais.append(i)
	if combinam.is_empty():
		# só a clicada combina com a mesa: ela abre o combo
		ordem.append(final)
		ordem.append_array(demais)
	else:
		ordem.append_array(combinam)
		ordem.append_array(demais)
		ordem.append(final)
	return ordem

## IA: devolve os índices de um combo (última = fica no topo), ou [] se não vai combar.
## Nunca zera a mão 
static func escolher_para_ia(mao: Array[Carta], topo: Carta, compras_acumuladas: int, minimo_restante: int, chance: float) -> Array[int]:
	var vazio: Array[int] = []
	if mao.size() - minimo_restante < 2 or randf() >= chance:
		return vazio
	var max_k: int = mao.size() - minimo_restante

	# Agrupa as cartas coloridas por valor
	var grupos: Dictionary = {}
	for i in range(mao.size()):
		if eh_preta(mao[i]):
			continue
		var v: int = mao[i].valor
		if not grupos.has(v):
			grupos[v] = []
		grupos[v].append(i)

	var melhor: Array[int] = []
	for v in grupos.keys():
		var g: Array = grupos[v]
		if g.size() < 2:
			continue
		# as que combinam com a mesa vêm primeiro (garante que o combo seja válido)
		var jogaveis: Array[int] = []
		var outras: Array[int] = []
		for i in g:
			if topo == null or mao[i].cor == topo.cor or mao[i].valor == topo.valor:
				jogaveis.append(i)
			else:
				outras.append(i)
		var ordenadas: Array[int] = jogaveis + outras
		var k: int = mini(ordenadas.size(), max_k)
		var cand: Array[int] = []
		for n in range(k):
			cand.append(ordenadas[n])
		if validar(mao, cand, topo, compras_acumuladas, minimo_restante) == "" and cand.size() > melhor.size():
			melhor = cand
	if melhor.is_empty():
		return vazio

	# A carta que fica no topo (define a cor): a da cor mais comum na mão
	var contagem: Dictionary = {}
	for c in mao:
		contagem[c.cor] = int(contagem.get(c.cor, 0)) + 1
	var final: int = melhor[0]
	for i in melhor:
		if int(contagem.get(mao[i].cor, 0)) > int(contagem.get(mao[final].cor, 0)):
			final = i
	return ordenar_com_final(mao, melhor, final, topo)
