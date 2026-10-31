module main

// A digitação acontece na própria janela, mas o que ela faz com o texto e com a cena não
// depende de janela nenhuma: precisa só de uma superfície onde medir a fonte. Estes testes
// montam essa superfície e conduzem a digitação do começo ao fim.

// text_editor monta um editor sobre uma imagem pequena, com a ferramenta de texto na mão.
fn text_editor() !Editor {
	screen := C.GetDC(unsafe { nil })
	source := new_surface(screen, 400, 300)!
	C.ReleaseDC(unsafe { nil }, screen)
	mut editor := Editor{
		source: source
		tool: .text
		color: annotation_color
		thickness: text_thickness
		canvas_width: 400
		canvas_height: 300
		scene: Scene{
			crop: Rect{
				width: 400
				height: 300
			}
		}
		selected: -1
	}
	editor.apply()!
	return editor
}

// A caixa de partida e o texto escrito viram uma marcação selecionada.
fn test_o_que_foi_escrito_vira_marcacao() ! {
	mut editor := text_editor()!
	editor.start_text(Rect{
		x: 40
		y: 50
		width: 200
		height: 0
	})
	assert editor.typing
	for letter in 'olá'.runes() {
		editor.type_letter(letter)
	}
	assert editor.finish_text() == 'Texto escrito'
	assert !editor.typing
	assert editor.scene.shapes.len == 1
	assert editor.scene.shapes[0].tool == .text
	assert editor.scene.shapes[0].text == 'olá'
	assert editor.scene.shapes[0].area.x == 40
	assert editor.scene.shapes[0].area.width == 200
	// A marcação nasce selecionada, como as outras.
	assert editor.selected == 0
	// E o passo entra no histórico.
	assert editor.past.len == 1
}

// Um clique sem arrasto ainda dá uma caixa em que se possa escrever.
fn test_um_clique_seco_ganha_caixa_de_partida() ! {
	mut editor := text_editor()!
	editor.start_text(Rect{
		x: 10
		y: 40
	})
	assert editor.typed_area.width == text_height(f32(text_thickness)) * text_min_columns
	assert editor.typed_area.height > 0
	// O texto nasce à direita do ponteiro e centrado nele, e não abaixo.
	box := editor.typed_area
	assert box.x == 10
	assert abs(box.y + box.height / 2 - 40) <= 1
	// Uma linha a mais cresce para baixo: o topo, e com ele a primeira linha, fica parado.
	editor.type_letter(`a`)
	editor.type_letter(`\r`)
	editor.type_letter(`b`)
	assert editor.typed_area.y == box.y
	assert editor.typed_area.height > box.height
	assert editor.finish_text() == 'Texto escrito'
	assert editor.scene.shapes[0].area.y == box.y
}

// Um arrasto de verdade põe a caixa onde ele foi feito, sem centrar nada.
fn test_o_arrasto_fica_onde_foi_feito() ! {
	mut editor := text_editor()!
	editor.start_text(Rect{
		x: 10
		y: 40
		width: 150
	})
	assert editor.typed_area.x == 10
	assert editor.typed_area.y == 40
}

// A caixa cresce com o texto: a largura é a do arrasto, e a altura acompanha as linhas.
fn test_a_caixa_cresce_para_baixo() ! {
	mut editor := text_editor()!
	editor.start_text(Rect{
		x: 0
		y: 0
		width: 120
		height: 0
	})
	first := editor.typed_area.height
	for letter in 'primeira'.runes() {
		editor.type_letter(letter)
	}
	editor.type_letter(`\r`)
	for letter in 'segunda'.runes() {
		editor.type_letter(letter)
	}
	assert editor.typed_area.height > first
	assert editor.typed_area.width == 120
}

// Desistir não deixa nada para trás.
fn test_esc_desiste_sem_deixar_marcacao() ! {
	mut editor := text_editor()!
	editor.start_text(Rect{
		x: 10
		y: 10
		width: 150
	})
	editor.type_letter(`a`)
	editor.cancel_text()
	assert !editor.typing
	assert editor.scene.shapes.len == 0
	assert editor.past.len == 0
}

// Terminar sem escrever nada também não: uma caixa vazia não é marcação.
fn test_texto_em_branco_nao_vira_marcacao() ! {
	mut editor := text_editor()!
	editor.start_text(Rect{
		x: 10
		y: 10
		width: 150
	})
	editor.type_letter(` `)
	editor.finish_text()
	assert editor.scene.shapes.len == 0
	assert editor.past.len == 0
}

// Reabrir uma marcação devolve o que estava escrito e a repõe no mesmo lugar da pilha, para
// o que estava por cima dela continuar por cima.
fn test_reabrir_reescreve_no_mesmo_lugar() ! {
	mut editor := text_editor()!
	editor.scene.shapes = [
		Shape{
			tool: .text
			area: Rect{
				x: 10
				y: 10
				width: 150
				height: 30
			}
			color: annotation_color
			thickness: text_thickness
			text: 'antes'
		},
		Shape{
			tool: .rectangle
			area: Rect{
				x: 200
				y: 200
				width: 50
				height: 50
			}
		},
	]
	editor.edit_text(0)
	assert editor.typing
	assert editor.typed == 'antes'
	// Enquanto é reescrita ela não está na cena, senão apareceria duas vezes.
	assert editor.scene.shapes.len == 1
	editor.type_letter(`\b`)
	editor.type_letter(`s`)
	editor.finish_text()
	assert editor.scene.shapes.len == 2
	assert editor.scene.shapes[0].text == 'antes'.substr(0, 4) + 's'
	assert editor.scene.shapes[1].tool == .rectangle
}

// Desistir de uma reescrita devolve a marcação como ela estava.
fn test_desistir_da_reescrita_devolve_o_texto() ! {
	mut editor := text_editor()!
	editor.scene.shapes = [
		Shape{
			tool: .text
			area: Rect{
				x: 10
				y: 10
				width: 150
				height: 30
			}
			color: annotation_color
			thickness: text_thickness
			text: 'antes'
		},
	]
	editor.edit_text(0)
	editor.type_letter(`x`)
	editor.cancel_text()
	assert editor.scene.shapes.len == 1
	assert editor.scene.shapes[0].text == 'antes'
}

// rewriting monta um editor com Selecionar na mão e um texto sendo reescrito: o "antes" reaberto, com um "x" acrescentado.
fn rewriting() !Editor {
	mut editor := text_editor()!
	editor.scene.shapes = [
		Shape{
			tool: .text
			area: Rect{
				x: 10
				y: 10
				width: 150
				height: 30
			}
			color: annotation_color
			thickness: text_thickness
			text: 'antes'
		},
	]
	editor.tool = .select
	editor.edit_text(0)
	editor.type_letter(`x`)
	return editor
}

// Desfazer no meio de uma reescrita fecha o texto antes: a reescrita entra na cena, e o desfazer volta ao texto de antes, sem deixar dois. Refazer traz a reescrita de volta.
fn test_desfazer_no_meio_da_reescrita_fecha_o_texto() ! {
	mut editor := rewriting()!
	editor.undo()
	assert !editor.typing
	assert editor.scene.shapes.len == 1
	assert editor.scene.shapes[0].text == 'antes'
	editor.redo()
	assert editor.scene.shapes.len == 1
	assert editor.scene.shapes[0].text == 'antesx'
}

// Terminar uma reescrita cuja imagem não pode ser montada não deixa na cena o texto de antes, que a imagem na tela — montada sem ele ao reabri-lo — não mostra: a cena volta a ser a da imagem, e desfazer traz o texto de antes.
fn test_reescrita_que_falha_nao_desencontra_cena_e_imagem() ! {
	mut editor := rewriting()!
	// Um fator de tamanho que nenhuma memória comporta: a imagem nova não pode ser montada, como a de uma captura grande ampliada com a memória apertada.
	editor.scene.factor = 100000.0
	assert editor.finish_text().starts_with('Falha ao aplicar')
	assert !editor.typing
	assert editor.scene.shapes.len == 0
	assert editor.past.len == 1
	editor.scene.factor = 1.0
	assert editor.undo() == 'Desfeito'
	assert editor.scene.shapes.len == 1
	assert editor.scene.shapes[0].text == 'antes'
}

// Desistir de uma reescrita cuja cena de antes não pode ser montada deixa valendo a cena da imagem na tela, sem o texto, e a de antes volta ao histórico: desfazer a devolve quando der.
fn test_desistir_da_reescrita_que_falha_nao_desencontra_cena_e_imagem() ! {
	mut editor := rewriting()!
	editor.past[0].factor = 100000.0
	assert editor.cancel_text().starts_with('Falha ao devolver o texto')
	assert editor.scene.shapes.len == 0
	assert editor.past.len == 1
	editor.past[0].factor = 1.0
	assert editor.undo() == 'Desfeito'
	assert editor.scene.shapes.len == 1
	assert editor.scene.shapes[0].text == 'antes'
}

// Redimensionar no meio de uma reescrita também fecha o texto antes, e o desfazer seguinte volta só o tamanho.
fn test_redimensionar_no_meio_da_reescrita_fecha_o_texto() ! {
	mut editor := rewriting()!
	factor := editor.scene.factor
	editor.apply_resize(0)
	assert !editor.typing
	assert editor.scene.shapes.len == 1
	assert editor.scene.shapes[0].text == 'antesx'
	editor.undo()
	assert editor.scene.factor == factor
	assert editor.scene.shapes[0].text == 'antesx'
}

// Trocar de ferramenta no meio de uma reescrita fecha o texto com a aparência dele, antes de a ferramenta nova trocar a cor e a espessura.
fn test_trocar_de_ferramenta_no_meio_da_reescrita_fecha_o_texto() ! {
	mut editor := rewriting()!
	editor.choose(.highlighter)
	assert !editor.typing
	assert editor.scene.shapes[0].text == 'antesx'
	assert editor.scene.shapes[0].color == annotation_color
	assert editor.scene.shapes[0].thickness == text_thickness
}

// Reabrir um texto usa a cor, a espessura e o estilo dele durante a reescrita, mas não os deixa como padrão: depois de terminar ou de desistir, as próximas marcações saem como sairiam antes.
fn test_reescrever_nao_troca_o_padrao() ! {
	for finish in [true, false] {
		mut editor := text_editor()!
		editor.scene.shapes = [
			Shape{
				tool: .text
				area: Rect{
					x: 10
					y: 10
					width: 150
					height: 30
				}
				color: quick_colors[3]
				thickness: 9
				style: Style{
					filled: true
				}
				text: 'antes'
			},
		]
		editor.tool = .select
		editor.color = annotation_color
		editor.thickness = annotation_width
		editor.style = Style{}
		editor.edit_text(0)
		assert editor.color == quick_colors[3]
		if finish {
			editor.finish_text()
		} else {
			editor.cancel_text()
		}
		assert editor.color == annotation_color
		assert editor.thickness == annotation_width
		assert editor.style == Style{}
		assert editor.scene.shapes[0].style.filled
		assert editor.scene.shapes[0].thickness == 9
	}
}

// Mudar a espessura de um texto escolhido refaz a caixa para o corpo novo: a altura acompanha a letra, e a largura, que decide onde as linhas quebram, fica.
fn test_espessura_do_texto_refaz_a_caixa() ! {
	mut editor := text_editor()!
	editor.scene.shapes = [
		Shape{
			tool: .text
			area: Rect{
				x: 10
				y: 10
				width: 150
				height: 30
			}
			color: annotation_color
			thickness: text_thickness
			style: Style{
				filled: true
			}
			text: 'antes'
		},
	]
	editor.tool = .select
	editor.selected = 0
	before := editor.scene.shapes[0].area
	editor.size_by(4)
	after := editor.scene.shapes[0].area
	assert editor.scene.shapes[0].thickness == text_thickness + 4
	assert after.height > before.height
	assert after.x == before.x && after.y == before.y && after.width == before.width
	assert after == text_fit(editor.current.dc, before, 'antes', text_thickness + 4)
}

// Estreitar um texto pela alça quebra as linhas de novo, e a caixa cresce para baixo com elas: a alça decide a largura, e a altura vem das linhas, como na troca de espessura. Antes, as linhas a mais saíam por baixo do balão.
fn test_estreitar_o_texto_pela_alca_refaz_a_caixa() ! {
	mut editor := text_editor()!
	editor.scene.shapes = [
		Shape{
			tool: .text
			area: Rect{
				x: 10
				y: 10
				width: 300
				height: 30
			}
			color: annotation_color
			thickness: text_thickness
			style: Style{
				filled: true
			}
			text: 'uma frase longa que quebra em várias linhas'
		},
	]
	editor.tool = .select
	editor.selected = 0
	editor.start_grab(.right, false)
	editor.cursor_x = editor.origin_x - 150
	after := editor.grabbed_shape().area
	assert after.width == 150
	assert after.height > 30
	assert after == text_fit(editor.current.dc, Rect{
		x: 10
		y: 10
		width: 150
		height: 30
	}, editor.grabbed.text, text_thickness)
}

// Com o retângulo na mão, engrossar ou pintar um texto escolhido não muda o padrão do próximo retângulo: o texto é de outra família, e o número dele é o corpo da letra.
fn test_texto_de_outra_familia_nao_vira_padrao() ! {
	mut editor := text_editor()!
	editor.scene.shapes = [
		Shape{
			tool: .text
			area: Rect{
				x: 10
				y: 10
				width: 150
				height: 30
			}
			color: annotation_color
			thickness: text_thickness
			style: Style{
				filled: true
			}
			text: 'antes'
		},
	]
	editor.tool = .rectangle
	editor.thickness = annotation_width
	editor.selected = 0
	editor.size_by(4)
	assert editor.scene.shapes[0].thickness == text_thickness + 4
	assert editor.thickness == annotation_width
	editor.apply_color(quick_colors[3])
	assert editor.scene.shapes[0].color == quick_colors[3]
	assert editor.color == annotation_color
}

// Ctrl+Backspace manda o caractere DEL, que não é texto: antes ele entrava como um quadradinho no fim do que foi escrito.
fn test_ctrl_backspace_nao_escreve_um_quadradinho() ! {
	mut editor := text_editor()!
	editor.start_text(Rect{
		x: 20
		y: 20
		width: 200
		height: 40
	})
	editor_char(unsafe { nil }, mut editor, `a`)
	editor_char(unsafe { nil }, mut editor, rune(0x7f))
	assert editor.typed == 'a'
}

// Só o fim do texto é cortado ao terminar: as linhas em branco e os espaços do começo são parte dele, e a prévia os mostrava — cortá-los fazia o texto saltar ao confirmar.
fn test_o_comeco_em_branco_fica() ! {
	mut editor := text_editor()!
	editor.start_text(Rect{
		x: 10
		y: 10
		width: 150
	})
	for letter in [`\r`, ` `, `a`, `\r`] {
		editor.type_letter(letter)
	}
	assert editor.finish_text() == 'Texto escrito'
	assert editor.scene.shapes[0].text == '\n a'
}

// Um clique rente à borda direita e ao topo abre a caixa de partida dentro da imagem: fora dela, o que se escrevesse sumiria.
fn test_a_caixa_de_partida_cabe_no_recorte() ! {
	mut editor := text_editor()!
	editor.start_text(Rect{
		x: 390
		y: 5
	})
	assert editor.typed_area.width == text_height(f32(text_thickness)) * text_min_columns
	assert editor.typed_area.x + editor.typed_area.width <= 400
	assert editor.typed_area.y >= 0
}

// Salvar ou copiar com um texto em digitação o põe na imagem antes, como um Ctrl+Enter. Se ele não entra, o comando não segue e a barra diz a falha: antes o editor salvava a imagem sem o texto e fechava.
fn test_salvar_com_texto_que_nao_entra_nao_segue() ! {
	mut editor := text_editor()!
	editor.start_text(Rect{
		x: 40
		y: 50
		width: 200
	})
	editor.type_letter(`o`)
	editor.scene.factor = 100000.0
	assert !editor.text_entered(id_save)
	assert editor.status.starts_with('Falha')
	editor.scene.factor = 1.0
	editor.start_text(Rect{
		x: 40
		y: 50
		width: 200
	})
	editor.type_letter(`o`)
	assert editor.text_entered(id_copy)
	assert editor.scene.shapes.len == 1
}

// Apagar tudo numa reescrita apaga a marcação.
fn test_apagar_tudo_apaga_a_marcacao() ! {
	mut editor := text_editor()!
	editor.scene.shapes = [
		Shape{
			tool: .text
			area: Rect{
				x: 10
				y: 10
				width: 150
				height: 30
			}
			color: annotation_color
			thickness: text_thickness
			text: 'ai'
		},
	]
	editor.edit_text(0)
	editor.type_letter(`\b`)
	editor.type_letter(`\b`)
	assert editor.finish_text() == 'Texto apagado'
	assert editor.scene.shapes.len == 0
}

// Um emoji chega em dois WM_CHAR, as metades de um par substituto: as duas juntas viram o caractere, e o Backspace o apaga inteiro. Uma metade solta é descartada, em vez de virar um "�".
fn test_emoji_chega_em_duas_metades() ! {
	mut editor := text_editor()!
	editor.start_text(Rect{
		x: 20
		y: 20
		width: 200
		height: 40
	})
	editor.type_unit(`a`)
	editor.type_unit(rune(0xd83d))
	editor.type_unit(rune(0xde00))
	assert editor.typed == 'a' + rune(0x1f600).str()
	editor.type_unit(`\b`)
	assert editor.typed == 'a'
	editor.type_unit(rune(0xde00))
	assert editor.typed == 'a'
}

// Apagar conta letras, e não bytes: um "ã" ocupa dois bytes, e meio caractere não é texto.
fn test_apagar_tira_uma_letra_e_nao_um_byte() {
	assert drop_last('não') == 'nã'
	assert drop_last('nã') == 'n'
	assert drop_last('n') == ''
	assert drop_last('') == ''
	assert drop_last('coração') == 'coraçã'
}

// O tamanho da fonte sai da espessura, e nunca chega a zero.
fn test_o_corpo_da_fonte_sai_da_espessura() {
	assert text_height(1) == text_scale
	assert text_height(f32(max_thickness)) == max_thickness * text_scale
	assert text_height(0) == 1
	assert text_padding(text_height(f32(text_thickness))) > 0
}

// Os dois botões do painel do texto são o balão e a palavra solta, e um exclui o outro.
fn test_o_texto_escolhe_entre_balao_e_palavra_solta() {
	assert style_slots(.text) == style_slots_text
	balloon := style_pressed(Style{}, style_slots_text[0])
	loose := style_pressed(Style{}, style_slots_text[1])
	assert balloon.filled
	assert !loose.filled
	assert style_is_active(balloon, style_slots_text[0])
	assert !style_is_active(balloon, style_slots_text[1])
	assert style_is_active(loose, style_slots_text[1])
	assert style_name(style_slots_text[0]) == 'Texto em balão'
	assert style_name(style_slots_text[1]) == 'Texto solto'
	// Trocar o estilo do texto não mexe no que as outras ferramentas guardam.
	rich := Style{
		rounded: true
		dashed: true
		head: .simple
	}
	changed := style_pressed(rich, style_slots_text[0])
	assert changed.rounded && changed.dashed && changed.head == .simple
}

// Um clique fora da caixa termina o texto também no fundo em volta da imagem, que aparece depois de um recorte ou numa captura menor que a janela: ali o clique não fazia nada, e o texto continuava aberto.
fn test_clique_no_fundo_em_volta_da_imagem_termina_o_texto() ! {
	mut editor := text_editor()!
	editor.canvas_width = 900
	editor.canvas_height = 700
	editor.layout()
	editor.start_text(Rect{
		x: 10
		y: 10
		width: 150
		height: 30
	})
	editor.type_letter(`a`)
	assert !inside_view(editor, 5, toolbar_height + 5)
	editor_press(unsafe { nil }, mut editor, 5, toolbar_height + 5)
	assert !editor.typing
	assert editor.scene.shapes.len == 1
	assert editor.scene.shapes[0].text == 'a'
}

// Desistir de uma reescrita devolve tudo como estava, inclusive o refazer: reabrir o texto e apertar Esc não é edição nenhuma.
fn test_desistir_da_reescrita_nao_apaga_o_refazer() ! {
	mut editor := text_editor()!
	editor.scene.shapes = [
		Shape{
			tool: .text
			area: Rect{
				x: 10
				y: 10
				width: 150
				height: 30
			}
			color: annotation_color
			thickness: text_thickness
			text: 'antes'
		},
	]
	editor.tool = .select
	editor.future << editor.scene.clone()
	editor.edit_text(0)
	editor.type_letter(`x`)
	editor.cancel_text()
	assert editor.scene.shapes[0].text == 'antes'
	assert editor.past.len == 0
	assert editor.future.len == 1
}
