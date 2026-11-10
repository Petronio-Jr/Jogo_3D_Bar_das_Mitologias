class_name CartaUI
extends Control

signal carta_clicada(indice)

@onready var fundo: ColorRect = $Fundo
@onready var texto_valor: Label = $TextoValor
@onready var texto_valor2: Label = $TextoValor2
@onready var texto_valor3: Label = $TextoValor3

@onready var botao: Button = $Botao

var indice_na_mao: int = -1

func _ready() -> void:
	# Conecta os sinais do botão via código para facilitar
	botao.pressed.connect(_on_botao_pressed)
	botao.mouse_entered.connect(_on_mouse_entered)
	botao.mouse_exited.connect(_on_mouse_exited)

# Preenche o visual com base na carta lógica recebida
func setup(carta: Carta, index: int):
	indice_na_mao = index
	
	var texto_formatado = carta.para_texto()
	texto_valor.text = texto_formatado
	texto_valor2.text = texto_formatado
	texto_valor3.text = texto_formatado
	
	# Mapeando cores do enum para cores reais
	match carta.cor:
		Carta.Cor.VERMELHA: fundo.color = Color(0.629, 0.111, 0.111, 1.0)
		Carta.Cor.AZUL:     fundo.color = Color(0.115, 0.346, 0.652, 1.0)
		Carta.Cor.VERDE:    fundo.color = Color(0.133, 0.664, 0.222, 1.0)
		Carta.Cor.AMARELA:  fundo.color = Color(0.723, 0.57, 0.076, 1.0)
		Carta.Cor.PRETA:    fundo.color = Color(0.148, 0.148, 0.148, 1.0)

func _on_botao_pressed():
	emit_signal("carta_clicada", indice_na_mao)

func _on_mouse_entered():
	# Efeito visual: Sobe a carta levemente ao passar o mouse
	position.y -= 15

func _on_mouse_exited():
	# Retorna à posição original
	position.y += 15
