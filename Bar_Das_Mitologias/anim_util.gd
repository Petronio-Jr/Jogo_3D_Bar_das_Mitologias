class_name AnimUtil
extends RefCounted
## Funções utilitárias para tocar animações. Não guarda estado.

static func resolver(player: AnimationPlayer, nome: String) -> String:
	if player == null or nome == "":
		return ""
	if player.has_animation(nome):
		return nome
	var alvo: String = nome.to_lower()
	for a in player.get_animation_list():
		var s: String = String(a)
		var minusculo: String = s.to_lower()
		if minusculo == alvo or minusculo.ends_with("/" + alvo):
			return s
	return ""

static func tocar(arvore: SceneTree, player: AnimationPlayer, nome: String, reverso: bool = false) -> void:
	if player == null or nome == "":
		return
	var anim: String = resolver(player, nome)
	if anim == "":
		return
	if reverso:
		player.play_backwards(anim)
	else:
		player.play(anim)
	var dados: Animation = player.get_animation(anim)
	if dados.loop_mode != Animation.LOOP_NONE:
		await arvore.create_timer(dados.length).timeout
	else:
		await player.animation_finished

static func tocar_e_voltar_idle(animador: AnimationPlayer, nome_anim: String) -> void:
	if not animador:
		return
	var anim_final: String = ""
	if animador.has_animation(nome_anim):
		anim_final = nome_anim
	elif animador.has_animation("anim_deuses/" + nome_anim):
		anim_final = "anim_deuses/" + nome_anim

	if anim_final != "":
		animador.play(anim_final)
		await animador.animation_finished
		if animador.has_animation("IDLE"):
			animador.play("IDLE")
		elif animador.has_animation("anim_deuses/IDLE"):
			animador.play("anim_deuses/IDLE")
