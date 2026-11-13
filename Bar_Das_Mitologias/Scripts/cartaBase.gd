class_name Carta
extends RefCounted
 
# Definindo as possíveis cores e valores de cartas 
enum Cor {VERMELHA, AZUL, VERDE, AMARELA, PRETA}
enum Valor {ZERO, UM, DOIS, TRES, QUATRO, CINCO, SEIS, SETE, OITO, NOVE,
			MAIS_DOIS, INVERTER, BLOQUEIO, MAIS_QUATRO, MUDAR_COR}
 
var cor: Cor
var valor: Valor
 
# Construtor
func _init(cor: Cor, valor: Valor):
	self.cor = cor
	self.valor = valor
 
# Escreve a COR e VALOR da carta no terminal
func para_texto() -> String:
	match valor:
		Valor.ZERO: return "0"
		Valor.UM: return "1"
		Valor.DOIS: return "2"
		Valor.TRES: return "3"
		Valor.QUATRO: return "4"
		Valor.CINCO: return "5"
		Valor.SEIS: return "6"
		Valor.SETE: return "7"
		Valor.OITO: return "8"
		Valor.NOVE: return "9"
		Valor.MAIS_DOIS: return "+2"
		Valor.INVERTER: return "⇄"
		Valor.BLOQUEIO: return "Ø"
		Valor.MAIS_QUATRO: return "+4"
		Valor.MUDAR_COR: return "★"
		_: return "?"
 
