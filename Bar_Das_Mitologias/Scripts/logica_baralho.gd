class_name Baralho
extends RefCounted
 
var cartas_baralho: Array[Carta] = []
var pilha_descarte: Array[Carta] = []
 
func _init():
	reiniciar_jogo()
 
 
func reiniciar_jogo():
	# Limpando o vetor de cartas do baralho e da pilha de descarte 
	cartas_baralho.clear()
	pilha_descarte.clear()
	
	cria_baralho()
	# Distribui aleatóriamente as cartas
	cartas_baralho.shuffle()
 
 
func cria_baralho():
	# Adicionando as cartas coloridas no baralho
	for c in [Carta.Cor.VERMELHA, Carta.Cor.AZUL, Carta.Cor.VERDE, Carta.Cor.AMARELA]:
		for v in range(Carta.Valor.ZERO, Carta.Valor.BLOQUEIO + 1):
			cartas_baralho.append(Carta.new(c,v))  
			
	# Adicionando as cartas coringa ao baralho
	for i in range(4):
		cartas_baralho.append(Carta.new(Carta.Cor.PRETA, Carta.Valor.MAIS_QUATRO))
		cartas_baralho.append(Carta.new(Carta.Cor.PRETA, Carta.Valor.MUDAR_COR))
 
 
func puxar() -> Carta:
	if cartas_baralho.size() == 0:
		reembaralhar_pilha_descarte()
	if cartas_baralho.size() > 0:
		# Retorna a ultima carta da pilha, a do topo
		return cartas_baralho.pop_back()
	return null
 
 
# Move a carta da sua mão ou do baralho pro descarte 
func descartar(carta: Carta):
	pilha_descarte.append(carta)
 
 
# Retorna a carta do topo do baralho, a que ta na mesa 
func obter_topo() -> Carta:
	if pilha_descarte.size() > 0:
		return pilha_descarte.back()
	return null
 
 
func reembaralhar_pilha_descarte():
	if pilha_descarte.size() <= 1:
		return
	else:
		var topo = pilha_descarte.pop_back()
		for c in pilha_descarte:
			# Se for coringa (Mais Quatro ou Mudar Cor), reseta a cor para PRETA
			if c.valor == Carta.Valor.MAIS_QUATRO or c.valor == Carta.Valor.MUDAR_COR:
				c.cor = Carta.Cor.PRETA
		cartas_baralho = pilha_descarte.duplicate()
		pilha_descarte.clear()
		pilha_descarte.append(topo)
		cartas_baralho.shuffle()
 
