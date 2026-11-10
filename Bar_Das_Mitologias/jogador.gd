class_name Jogador
extends RefCounted
 
var nome: String
var eh_o_player: bool = false
var mao: Array[Carta] = []
 
# Construtor
func _init(nome: String, eh_o_player: bool):
	self.nome = nome
	self.eh_o_player = eh_o_player
 
# Adicionar uma carta no vetor da mao do jogador
func adicionar_carta(carta: Carta):
	if carta != null:
		mao.append(carta)
 
func remover_carta(indice: int) -> Carta:
	if indice >= 0 and indice < mao.size():
		return mao.pop_at(indice)
	return null
 
func pode_jogar_carta(carta: Carta, topo: Carta) -> bool:
	if carta.cor == Carta.Cor.PRETA:
		return true
	if carta.cor == topo.cor or carta.valor == topo.valor:
		return true
	return false
 
