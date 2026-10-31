module main

// panel_editor monta um editor sem janela, só com o que o painel consulta: onde a imagem
// aparece, quanto espaço há, e o que está selecionado.
fn panel_editor(shape_y int, selected int, tool Tool) Editor {
	return Editor{
		canvas_width: 800
		canvas_height: 600
		view: Rect{
			x: 100
			y: toolbar_height
			width: 600
			height: 400
		}
		scale: 0.5
		scene: Scene{
			crop: Rect{
				x: 10
				y: 20
				width: 1600
				height: 2400
			}
			shapes: [
				Shape{
					tool: .rectangle
					area: Rect{
						x: 210
						y: shape_y
						width: 200
						height: 100
					}
					color: annotation_color
					thickness: 6
				},
			]
		}
		selected: selected
		tool: tool
	}
}

// drawn_panel_editor é o panel_editor com uma captura de verdade por baixo, para os testes em que a marcação muda e a imagem de trabalho tem de ser refeita: sem captura o apply falha, e a mudança é desfeita.
fn drawn_panel_editor(selected int, tool Tool) !Editor {
	screen := C.GetDC(unsafe { nil })
	source := new_surface(screen, 640, 480)!
	C.ReleaseDC(unsafe { nil }, screen)
	bare := panel_editor(220, selected, tool)
	mut editor := Editor{
		...bare
		source: source
		scene: Scene{
			...bare.scene
			crop: Rect{
				width: 640
				height: 480
			}
		}
	}
	editor.apply()!
	return editor
}

// O painel fica parado no canto superior direito, logo abaixo da barra, como na
// referência: ele não persegue a marcação nem cobre o que está sendo editado.
fn test_painel_fica_no_canto_superior_direito() {
	editor := panel_editor(220, 0, .select)
	panel := editor.options_panel() or { panic('o painel deveria aparecer') }
	assert panel.width == options_width(.rectangle)
	assert panel.height == options_height
	assert panel.x + panel.width == editor.canvas_width - options_margin
	assert panel.y == toolbar_height + options_margin
}

// Onde a marcação está não muda nada: uma rente ao pé da imagem tem o painel no mesmo
// lugar de uma rente ao topo.
fn test_posicao_nao_depende_da_marcacao() {
	high := panel_editor(220, 0, .select)
	low := panel_editor(1112, 0, .select)
	assert high.options_panel() or { panic('') } == low.options_panel() or { panic('') }
}

// Sem nada selecionado ele continua lá, desde que a ferramenta desenhe alguma coisa: é o
// que permite escolher a espessura antes de traçar.
fn test_painel_aparece_para_a_ferramenta_sem_selecao() {
	editor := panel_editor(220, -1, .rectangle)
	panel := editor.options_panel() or { panic('o painel deveria aparecer') }
	assert panel.x + panel.width == editor.canvas_width - options_margin
	assert panel.y == toolbar_height + options_margin
}

// Sem nada selecionado, o painel aparece para quem tem o que oferecer — as ferramentas que desenham — e para mais ninguém: a moldura só tem painel escolhida, e o editor de teste não tem moldura. O teste percorre a barra inteira em vez de nomear ferramentas, porque a lista muda a cada entrega.
fn test_o_painel_aparece_so_para_quem_tem_o_que_oferecer() {
	mut quiet := 0
	for tool in toolbar_tools {
		offers := tool in drawing_tools
		assert (panel_editor(220, -1, tool).options_panel() != none) == offers, tool_name(tool)
		if !offers {
			quiet++
		}
	}
	assert quiet > 0
}

// Durante o arrasto o painel some: ele atrapalharia justamente onde o traço está sendo
// feito.
fn test_painel_some_durante_o_arrasto() {
	mut editor := panel_editor(220, 0, .select)
	editor.dragging = true
	assert editor.options_panel() == none
}

fn test_o_botao_percorre_a_faixa_toda() {
	editor := panel_editor(220, 0, .select)
	panel := editor.options_panel() or { panic('o painel deveria aparecer') }
	track := slider_track(panel, .rectangle)
	// Nas pontas o botão para com o raio dele para dentro, senão sairia da faixa.
	assert knob_center(track, min_thickness) == track.x + int(knob_radius)
	assert knob_center(track, max_thickness) == track.x + track.width - int(knob_radius)
	// E a espessura do meio cai no meio.
	middle := knob_center(track, (min_thickness + max_thickness) / 2)
	assert middle > track.x + track.width / 3 && middle < track.x + 2 * track.width / 3
}

fn test_ponto_na_faixa_vira_espessura() {
	editor := panel_editor(220, 0, .select)
	panel := editor.options_panel() or { panic('o painel deveria aparecer') }
	track := slider_track(panel, .rectangle)
	assert thickness_at(track, knob_center(track, min_thickness)) == min_thickness
	assert thickness_at(track, knob_center(track, max_thickness)) == max_thickness
	assert thickness_at(track, knob_center(track, 7)) == 7
	// Fora das pontas o valor é preso ao limite, em vez de sair da faixa.
	assert thickness_at(track, track.x - 500) == min_thickness
	assert thickness_at(track, track.x + track.width + 500) == max_thickness
}

// Arrastar o controle guarda o estado uma vez só: sem isso desfazer teria de ser apertado
// uma vez por movimento do mouse.
fn test_arrasto_do_controle_guarda_uma_entrada_de_historico() {
	mut editor := panel_editor(220, -1, .rectangle)
	assert editor.current_thickness() == annotation_width
	panel := editor.options_panel() or { panic('o painel deveria aparecer') }
	track := slider_track(panel, .rectangle)
	editor.start_slide()
	for thickness in [4, 9, 11] {
		assert editor.slide_to(knob_center(track, thickness)) == 'Espessura ${thickness}'
	}
	assert editor.current_thickness() == 11
	// Sem marcação selecionada não há o que desfazer: só o padrão mudou.
	assert editor.past.len == 0
}

// Os botões do retângulo são dois grupos exclusivos: o canto e o preenchimento. Trocar um
// não mexe no outro.
fn test_pares_de_estilo_sao_independentes() {
	start := Style{}
	rounded := style_pressed(start, 0)
	assert rounded.rounded && !rounded.filled
	filled := style_pressed(rounded, 3)
	assert filled.rounded && filled.filled, 'preencher não deveria endireitar o canto'
	square := style_pressed(filled, 1)
	assert !square.rounded && square.filled, 'endireitar o canto não deveria tirar o preenchimento'
	assert !style_pressed(square, 2).filled
}

// O botão aceso é o que representa o estado atual, um por par.
fn test_um_botao_aceso_por_par() {
	style := Style{
		rounded: true
		filled: false
	}
	assert style_is_active(style, 0) && !style_is_active(style, 1)
	assert style_is_active(style, 2) && !style_is_active(style, 3)
}

// O preenchimento tem três escolhas — só o contorno, translúcido e opaco —, e exatamente
// uma fica acesa, venha de onde vier; o canto não muda com elas.
fn test_o_preenchimento_tem_tres_escolhas_exclusivas() {
	assert style_slots(.rectangle) == [0, 1, 2, 3, 18]
	fills := [2, 3, 18]
	for start in [Style{}, Style{
		rounded: true
		filled: true
		opaque: true
	}] {
		for index in fills {
			style := style_pressed(start, index)
			assert style.rounded == start.rounded
			for other in fills {
				assert style_is_active(style, other) == (other == index), 'botão ${index}, aceso ${other}'
			}
		}
	}
}

// O pixel do meio da marcação sobre fundo branco: só o contorno deixa o branco, o
// translúcido mistura a cor com ele, e o opaco cobre com a cor da marcação — no retângulo e
// na elipse.
fn test_os_tres_preenchimentos_no_pixel() ! {
	token := start_gdiplus()!
	defer {
		stop_gdiplus(token)
	}
	screen := C.GetDC(unsafe { nil })
	surface := new_surface(screen, 60, 60)!
	C.ReleaseDC(unsafe { nil }, screen)
	defer {
		surface.release()
	}
	area := Rect{
		x: 10
		y: 10
		width: 40
		height: 40
	}
	red := u32(0x000000ff)
	white := u32(0x00ffffff)
	for tool in [Tool.rectangle, .oval] {
		mut middle := []u32{}
		for index in [2, 3, 18] {
			paint_rect(surface.dc, Rect{
				width: 60
				height: 60
			}, white)
			style := style_pressed(Style{}, index)
			if tool == .oval {
				draw_oval(surface.dc, area, style, red, 2)
			} else {
				draw_outline(surface.dc, area, style, red, 2, corner_radius)
			}
			middle << C.GetPixel(surface.dc, 30, 30)
		}
		assert middle[0] == white, '${tool}: só o contorno'
		assert middle[1] != white && middle[1] != red, '${tool}: translúcido'
		assert middle[2] == red, '${tool}: opaco'
	}
}

// Um retângulo arredondado de 2 px de altura não tem raio que caiba nele: sai reto, em vez de sumir — no contorno e no preenchimento. Com a caneta de meio pixel, só o preenchimento chega à segunda linha dele.
fn test_retangulo_arredondado_fino_aparece() ! {
	token := start_gdiplus()!
	defer {
		stop_gdiplus(token)
	}
	screen := C.GetDC(unsafe { nil })
	surface := new_surface(screen, 60, 60)!
	C.ReleaseDC(unsafe { nil }, screen)
	defer {
		surface.release()
	}
	thin := Rect{
		x: 10
		y: 30
		width: 40
		height: 2
	}
	red := u32(0x000000ff)
	white := u32(0x00ffffff)
	paint_rect(surface.dc, Rect{
		width: 60
		height: 60
	}, white)
	draw_outline(surface.dc, thin, Style{ rounded: true }, red, 2, corner_radius)
	assert C.GetPixel(surface.dc, 30, 31) != white, 'o contorno'

	paint_rect(surface.dc, Rect{
		width: 60
		height: 60
	}, white)
	draw_outline(surface.dc, thin, Style{ rounded: true, filled: true, opaque: true }, red, 0.5, corner_radius)
	assert C.GetPixel(surface.dc, 30, 31) == red, 'o preenchimento'
}

// O canto arredondado acompanha a escala da vista: com zoom de quatro vezes, a prévia do retângulo tem o raio do resultado ampliado, e não os mesmos doze pixels da janela, que na imagem eram três e deixavam o canto quase reto até a soltura.
fn test_o_canto_arredondado_acompanha_a_escala() ! {
	token := start_gdiplus()!
	defer {
		stop_gdiplus(token)
	}
	screen := C.GetDC(unsafe { nil })
	surface := new_surface(screen, 240, 240)!
	C.ReleaseDC(unsafe { nil }, screen)
	defer {
		surface.release()
	}
	paint_rect(surface.dc, Rect{
		width: 240
		height: 240
	}, u32(0x00ffffff))
	mark := Shape{
		tool: .rectangle
		style: Style{
			rounded: true
		}
		color: u32(0x000000ff)
		thickness: 2
	}
	assert mark_corner(mark, 2.0) == corner_radius
	assert mark_corner(mark, 8.0) == 4 * corner_radius
	draw_mark(surface.dc, mark, Rect{
		x: 20
		y: 20
		width: 200
		height: 200
	}, 8.0, 0)
	// Na borda esquerda, vinte pixels abaixo do topo: com raio de doze a borda já é reta ali, e com o de quarenta e oito o arco ainda passa bem para dentro.
	assert (C.GetPixel(surface.dc, 21, 40) >> 8) & 0xff > 200
}

// A espessura da prévia não tem piso: com a captura reduzida à metade, a espessura 1 vira meio pixel, e o canto do retângulo sai com o raio que vai ter no resultado exibido, e não com o dobro. O traço fino continua à vista: a caneta do GDI+ nunca desenha menos de um pixel, e o ponto de um clique no traço livre, que é um disco, tem piso próprio — sem ele, com 0,25 de diâmetro, o pixel ficava quase branco.
fn test_a_previa_fina_tem_o_canto_do_resultado() ! {
	assert preview_thickness(1, 0.5) == f32(0.5)
	assert mark_corner(Shape{
		tool: .rectangle
		thickness: 1
	}, preview_thickness(1, 0.5)) == 6
	token := start_gdiplus()!
	defer {
		stop_gdiplus(token)
	}
	screen := C.GetDC(unsafe { nil })
	surface := new_surface(screen, 80, 60)!
	C.ReleaseDC(unsafe { nil }, screen)
	defer {
		surface.release()
	}
	paint_rect(surface.dc, Rect{
		width: 80
		height: 60
	}, u32(0x00ffffff))
	draw_stroke(surface.dc, [point(40, 30)], u32(0x000000ff), 0.25, 255)
	assert (C.GetPixel(surface.dc, 40, 30) >> 8) & 0xff < 200
}

// O pontilhado sai em pontos redondos: na linha do meio o ponto tem a largura da espessura, mas duas linhas acima a quina do quadrado já não é da cor do traço.
fn test_pontilhado_sai_em_pontos_redondos() ! {
	token := start_gdiplus()!
	defer {
		stop_gdiplus(token)
	}
	screen := C.GetDC(unsafe { nil })
	surface := new_surface(screen, 80, 60)!
	C.ReleaseDC(unsafe { nil }, screen)
	defer {
		surface.release()
	}
	red := u32(0x000000ff)
	paint_rect(surface.dc, Rect{
		width: 80
		height: 60
	}, u32(0x00ffffff))
	draw_line(surface.dc, 5, 30, 75, 30, Style{ dashed: true }, red, 6)
	// A borda esquerda do segundo ponto, na linha do meio. O primeiro fica de fora, porque a ponta da linha já é redonda por conta própria.
	mut x := 0
	for x < 80 && C.GetPixel(surface.dc, x, 30) != red {
		x++
	}
	for x < 80 && C.GetPixel(surface.dc, x, 30) == red {
		x++
	}
	for x < 80 && C.GetPixel(surface.dc, x, 30) != red {
		x++
	}
	assert x < 80, 'a linha deveria ter um segundo ponto'
	assert C.GetPixel(surface.dc, x, 28) != red, 'a quina do ponto deveria ser redonda'
}

// Um clique na folga do painel, fora do disco, dos botões e da faixa do controle, é do painel mas não faz nada: não começa arrasto, não muda a espessura e não entra no histórico. Na faixa, o clique ainda começa o arrasto.
fn test_clique_na_folga_do_painel_nao_mexe_na_espessura() {
	mut editor := panel_editor(220, 0, .select)
	panel := editor.options_panel() or { panic('o painel deveria existir') }
	middle := panel.y + panel.height / 2
	editor_option(unsafe { nil }, mut editor, panel.x + panel.width - 2, middle)
	assert !editor.sliding
	assert editor.scene.shapes[0].thickness == 6
	assert editor.past.len == 0

	track := slider_track(panel, editor.options_tool())
	editor_option(unsafe { nil }, mut editor, knob_center(track, 9), middle)
	assert editor.sliding
}

// Arrastar o controle só manda refazer a composição fixa quando o botão muda de passo: um movimento dentro do mesmo passo não muda nada na tela.
// Sem marcação selecionada nada é remontado, e é o próprio arrasto que tem de pedir a composição nova: com uma selecionada, a remontagem da imagem já a pediria, e o teste passaria sem olhar o arrasto.
fn test_controle_so_refaz_a_composicao_no_passo_novo() {
	mut editor := panel_editor(220, -1, .rectangle)
	panel := editor.options_panel() or { panic('o painel deveria existir') }
	track := slider_track(panel, editor.options_tool())
	middle := panel.y + panel.height / 2
	editor.start_slide()
	editor.background_ready = true
	same := knob_center(track, editor.current_thickness())
	dispatch_editor(unsafe { nil }, mut editor, wm_mousemove, 0, isize(same | (middle << 16)))
	assert editor.background_ready, 'o mesmo passo não refaz nada'
	next := knob_center(track, 9)
	dispatch_editor(unsafe { nil }, mut editor, wm_mousemove, 0, isize(next | (middle << 16)))
	assert !editor.background_ready, 'o passo novo refaz'
	assert editor.current_thickness() == 9
}

// Um passo do controle que não pega — a imagem de trabalho não pôde ser refeita — deixa a espessura como estava e nada no histórico, mas a barra tem de dizer que falhou: a mensagem é da composição fixa, e só uma composição nova a mostra. O passo seguinte que pega é o que entra no histórico.
fn test_passo_do_controle_que_falha_avisa_e_nao_entra_no_historico() ! {
	mut editor := drawn_panel_editor(0, .select)!
	panel := editor.options_panel() or { panic('o painel deveria existir') }
	track := slider_track(panel, editor.options_tool())
	middle := panel.y + panel.height / 2
	editor.start_slide()
	editor.background_ready = true
	// Um fator de tamanho que nenhuma memória comporta: a imagem de trabalho não pode ser montada, e o apply falha como falharia numa captura grande ampliada.
	editor.scene.factor = 100000.0
	dispatch_editor(unsafe { nil }, mut editor, wm_mousemove, 0, isize(knob_center(track, 9) | (middle << 16)))
	assert editor.status.starts_with('Falha ao trocar a espessura')
	assert !editor.background_ready, 'a mensagem de falha aparece'
	assert editor.scene.shapes[0].thickness == 6
	assert editor.past.len == 0
	editor.scene.factor = 1.0
	dispatch_editor(unsafe { nil }, mut editor, wm_mousemove, 0, isize(knob_center(track, 10) | (middle << 16)))
	assert editor.scene.shapes[0].thickness == 10
	assert editor.past.len == 1
}

// Escolher a cor que a marcação selecionada já tem não é edição: nada entra no histórico, e o refazer continua valendo.
fn test_a_mesma_cor_nao_apaga_o_refazer() ! {
	mut editor := drawn_panel_editor(0, .select)!
	editor.size_by(1)
	editor.undo()
	assert editor.past.len == 0 && editor.future.len == 1
	editor.apply_color(editor.scene.shapes[0].color)
	assert editor.past.len == 0
	assert editor.future.len == 1
}

// A ajuda da régua pende do botão dela, à esquerda, e não disputa o canto do painel de opções: com ela aberta, o painel e a paleta continuam à vista.
fn test_ajuda_da_regua_nao_esconde_o_painel() {
	mut editor := panel_editor(220, -1, .rectangle)
	editor.palette_open = true
	editor.choose(.ruler)
	assert editor.popover == .ruler_help
	assert editor.options_panel() != none
	assert editor.palette_rect() != none
}

// Tocar no controle sem mudar o valor não é edição: nada entra no histórico, e o refazer continua valendo. Só o primeiro passo de verdade guarda a cena, uma vez para o arrasto inteiro.
fn test_tocar_no_controle_sem_mudar_nao_apaga_o_refazer() ! {
	mut editor := drawn_panel_editor(0, .select)!
	editor.future = [editor.scene.clone()]
	panel := editor.options_panel() or { panic('o painel deveria existir') }
	track := slider_track(panel, editor.options_tool())
	editor.start_slide()
	editor.slide_to(knob_center(track, 6))
	assert editor.past.len == 0
	assert editor.future.len == 1
	editor.slide_to(knob_center(track, 9))
	editor.slide_to(knob_center(track, 11))
	assert editor.past.len == 1
	assert editor.future.len == 0
}

// Com um texto em digitação — inclusive numa reescrita, com Selecionar na mão —, o painel continua à vista e governa o texto.
fn test_texto_em_digitacao_tem_painel() {
	mut editor := panel_editor(220, -1, .select)
	assert !editor.has_options()
	editor.typing = true
	assert editor.has_options()
	assert editor.options_tool() == .text
	assert editor.options_panel() != none
}

// Todo botão de estilo acende depois de apertado, a partir de qualquer estilo, a miniatura dele o acende também, e cada um tem nome próprio: uma linha fora do lugar na tabela dos botões trocaria a ação, o nome ou a miniatura de um botão sem erro nenhum.
fn test_todo_botao_de_estilo_acende_depois_de_apertado() {
	starts := [
		Style{},
		Style{
			tip: .thick
			rounded: true
			filled: true
			opaque: true
			dashed: true
			head: .double
			erase: true
			shadow: true
		},
		Style{
			opaque: true
		},
	]
	mut names := []string{}
	for index in 0 .. style_buttons.len {
		for start in starts {
			assert style_is_active(style_pressed(start, index), index), '${index}'
		}
		assert style_is_active(style_sample(index), index), '${index}'
		names << style_name(index)
	}
	for index, name in names {
		assert names.index(name) == index, name
	}
}

fn test_clique_acha_o_botao_de_estilo() {
	editor := panel_editor(220, 0, .select)
	panel := editor.options_panel() or { panic('o painel deveria aparecer') }
	slots := style_slots(.rectangle)
	last := style_button_rect(panel, .rectangle, slots.len - 1)
	assert editor.style_at(last.x + 15, last.y + 15)? == slots.last()
	// O último botão termina dentro do painel, e não passando dele.
	assert last.x + last.width <= panel.x + panel.width - options_padding
	// A faixa do controle não encosta no primeiro botão.
	first := style_button_rect(panel, .rectangle, 0)
	track := slider_track(panel, .rectangle)
	assert first.x > track.x + track.width
	assert editor.style_at(track.x + 10, track.y + 20) == none
}

// Ctrl ou Shift com a roda muda o tamanho: sem seleção, o das próximas marcações, preso à
// faixa do controle e sem histórico; com seleção, o da marcação, uma entrada por passo.
fn test_a_roda_com_tecla_muda_o_tamanho() ! {
	mut free := panel_editor(220, -1, .rectangle)
	free.thickness = 3
	assert free.size_by(2) == 'Espessura 5'
	assert free.thickness == 5
	free.size_by(100)
	assert free.thickness == max_thickness
	free.size_by(-100)
	assert free.thickness == min_thickness
	assert free.past.len == 0

	mut chosen := drawn_panel_editor(0, .select)!
	chosen.size_by(1)
	chosen.size_by(1)
	assert chosen.scene.shapes[0].thickness == 8
	assert chosen.past.len == 2
	// No limite da faixa não há o que mudar, e nem o que desfazer.
	chosen.size_by(100)
	assert chosen.scene.shapes[0].thickness == max_thickness
	assert chosen.past.len == 3
	chosen.size_by(1)
	assert chosen.past.len == 3
}

// A roda diz na própria mensagem se Ctrl ou Shift estavam apertados, e cada dente é um
// passo — ao menos um, mesmo numa roda de giro fino.
fn test_a_roda_sabe_das_teclas_e_conta_dentes() {
	assert wheel_of(usize(120) << 16) == .plain
	assert wheel_of((usize(120) << 16) | mk_control) == .ctrl
	assert wheel_of((usize(0xff88) << 16) | mk_shift) == .shift
	assert wheel_steps(120) == 1
	assert wheel_steps(-240) == -2
	assert wheel_steps(30) == 1
	assert wheel_steps(-30) == -1
}

// Sem marcação selecionada o estilo escolhido vale para os próximos traços, e não há o que
// desfazer.
fn test_estilo_sem_selecao_vira_padrao() {
	mut editor := panel_editor(220, -1, .rectangle)
	assert editor.current_style() == Style{}
	assert editor.choose_style(0) == 'Cantos arredondados'
	assert editor.current_style().rounded
	assert editor.past.len == 0
}

// Trocar um campo da marcação não pode apagar os outros. Isto já quebrou: mudar a
// espessura devolvia o retângulo aos cantos retos e sem preenchimento.
fn test_trocar_um_campo_preserva_o_resto() ! {
	mut editor := drawn_panel_editor(0, .select)!
	editor.scene.shapes[0] = Shape{
		...editor.scene.shapes[0]
		style: Style{
			rounded: true
			filled: true
		}
	}
	panel := editor.options_panel() or { panic('o painel deveria aparecer') }
	editor.start_slide()
	editor.slide_to(knob_center(slider_track(panel, .rectangle), max_thickness))
	assert editor.scene.shapes[0].thickness == max_thickness
	assert editor.scene.shapes[0].style.rounded, 'a espessura não deveria endireitar o canto'
	assert editor.scene.shapes[0].style.filled, 'a espessura não deveria tirar o preenchimento'
	assert editor.scene.shapes[0].color == annotation_color
}

// Quando a imagem de trabalho não pode ser refeita — sem memória, numa captura grande ampliada —, a marcação volta à espessura que a imagem ainda mostra: o painel lê a cena, e sem isso ele mostrava 7 sobre uma imagem com 6, e a próxima edição aplicava o 7 de repente.
fn test_espessura_que_nao_se_aplica_volta_atras() ! {
	mut editor := drawn_panel_editor(0, .select)!
	editor.size_by(1)
	editor.undo()
	editor.thickness = 3
	// Um fator de tamanho que nenhuma memória comporta: a imagem de trabalho não pode ser montada, e o apply falha como falharia numa captura grande ampliada.
	editor.scene.factor = 100000.0
	assert editor.size_by(1).starts_with('Falha ao trocar a espessura')
	assert editor.scene.shapes[0].thickness == 6
	assert editor.current_thickness() == 6
	// O padrão das próximas marcações também fica, e o histórico não ganha entrada nem perde o refazer.
	assert editor.thickness == 3
	assert editor.past.len == 0 && editor.future.len == 1
	editor.scene.factor = 1.0
	assert editor.size_by(1) == 'Espessura 7'
	assert editor.scene.shapes[0].thickness == 7
	assert editor.past.len == 1 && editor.future.len == 0
}

// A cor e o estilo que não se aplicam também não ficam como padrão, como a espessura: a barra diz que a troca falhou, e as próximas marcações saem como sairiam antes.
fn test_cor_e_estilo_que_nao_se_aplicam_nao_viram_padrao() ! {
	mut editor := drawn_panel_editor(0, .rectangle)!
	color := editor.color
	style := editor.style
	editor.scene.factor = 100000.0
	assert editor.apply_color(quick_colors[3]).starts_with('Falha ao trocar a cor')
	assert editor.color == color
	assert editor.choose_style(0).starts_with('Falha ao trocar o estilo')
	assert editor.style == style
	assert editor.past.len == 0
}

// Uma troca que não se aplica não apaga o refazer: a cena volta a ser a de antes, e o que havia à frente continua lá para refazer.
fn test_troca_que_falha_nao_apaga_o_refazer() ! {
	mut editor := drawn_panel_editor(0, .select)!
	editor.future = [editor.scene.clone()]
	editor.scene.factor = 100000.0
	assert editor.apply_color(quick_colors[3]).starts_with('Falha')
	assert editor.past.len == 0
	assert editor.future.len == 1
}

// Apertar o botão de estilo que já está aceso não é troca: nada entra no histórico, e o refazer continua valendo.
fn test_estilo_ja_aceso_nao_entra_no_historico() ! {
	mut editor := drawn_panel_editor(0, .select)!
	editor.future = [editor.scene.clone()]
	// O retângulo tem cantos retos, e o botão deles já está aceso.
	assert editor.choose_style(1) == 'Cantos retos'
	assert editor.past.len == 0
	assert editor.future.len == 1
}

// No meio de um desenho, a roda muda só a espessura da marcação que vai nascer: a selecionada fica como está, e o histórico não ganha entrada.
fn test_a_roda_no_meio_do_desenho_nao_mexe_na_selecionada() ! {
	mut editor := drawn_panel_editor(0, .rectangle)!
	editor.thickness = 3
	editor.dragging = true
	assert editor.size_by(2) == 'Espessura 5'
	assert editor.thickness == 5
	assert editor.scene.shapes[0].thickness == 6
	assert editor.past.len == 0
}

// O disco de cor é o primeiro item do painel, e o controle começa depois dele.
fn test_disco_de_cor_abre_o_painel() {
	editor := panel_editor(220, 0, .select)
	panel := editor.options_panel() or { panic('o painel deveria aparecer') }
	swatch := swatch_rect(panel)
	assert swatch.x == panel.x + options_padding
	assert swatch.width == swatch_size && swatch.height == swatch_size
	// Centrado na altura do painel.
	assert swatch.y - panel.y == panel.y + panel.height - (swatch.y + swatch.height)
	// A faixa do controle começa depois do disco, sem encostar nele.
	track := slider_track(panel, .rectangle)
	assert track.x >= swatch.x + swatch.width + swatch_gap
	// E o último botão de estilo continua cabendo.
	last := style_button_rect(panel, .rectangle, style_slots(.rectangle).len - 1)
	assert last.x + last.width <= panel.x + panel.width - options_padding
}

// A cor em vigor é a da marcação selecionada; sem seleção, a que os próximos traços vão
// usar, que começa no vermelho da marcação.
fn test_cor_em_vigor_segue_a_selecao() {
	assert panel_editor(220, -1, .rectangle).current_color() == annotation_color
	mut editor := panel_editor(220, 0, .select)
	editor.scene.shapes[0] = Shape{
		...editor.scene.shapes[0]
		color: 0x0000ff00
	}
	assert editor.current_color() == 0x0000ff00
}

// A elipse não tem canto: o painel dela oferece só o preenchimento, e por isso é mais
// estreito. Com uma marcação selecionada, quem manda é a ferramenta dela, e não a que está
// na mão.
fn test_painel_muda_com_a_ferramenta() {
	assert style_slots(.oval) == [2, 3, 18]
	assert options_width(.oval) < options_width(.rectangle)

	oval := panel_editor(220, -1, .oval)
	panel := oval.options_panel() or { panic('o painel deveria aparecer') }
	assert panel.width == options_width(.oval)
	// A fila de botões continua encostada na direita, com o último dentro do painel.
	last := style_button_rect(panel, .oval, 2)
	assert last.x + last.width == panel.x + panel.width - options_padding
	// E os três botões que sobraram são os do preenchimento, com o opaco por último.
	assert oval.style_at(last.x + 15, last.y + 15)? == 18

	mut selected := panel_editor(220, 0, .oval)
	selected.scene.shapes[0] = Shape{
		...selected.scene.shapes[0]
		tool: .rectangle
	}
	assert selected.options_tool() == .rectangle
	assert selected.options_panel()?.width == options_width(.rectangle)
}

// A paleta pende do disco de cor e só existe enquanto está aberta.
fn test_paleta_pende_do_disco_e_so_abre_quando_pedida() {
	mut editor := panel_editor(220, -1, .rectangle)
	assert editor.palette_rect() == none

	editor.palette_open = true
	palette := editor.palette_rect() or { panic('a paleta deveria aparecer') }
	panel := editor.options_panel() or { panic('o painel deveria aparecer') }
	swatch := swatch_rect(panel)
	assert palette.y == panel.y + panel.height + palette_drop
	assert palette.x + palette.width / 2 == swatch.x + swatch.width / 2
	assert palette.width == palette_width && palette.height == palette_height
	// Ela cabe inteira dentro do editor, mesmo pendurada na borda direita.
	assert palette.x >= options_margin
	assert palette.x + palette.width <= editor.canvas_width - options_margin

	// Sem painel não há paleta: ela é parte dele.
	editor.tool = .select
	assert editor.palette_rect() == none
}

// Quando a tecla leva o painel embora, a paleta fecha junto: aberta sem painel, ela voltava sozinha com a ferramenta seguinte.
fn test_a_paleta_fecha_junto_com_o_painel() {
	bare := panel_editor(220, -1, .rectangle)
	mut editor := Editor{
		...bare
		config:       default_config()
		palette_open: true
	}
	dispatch_editor(unsafe { nil }, mut editor, wm_keydown, usize(`V`), 0)
	assert editor.tool == .select
	assert !editor.palette_open
	editor.choose(.rectangle)
	assert editor.palette_rect() == none
}

// Sobre a paleta o ponteiro é a seta, como sobre o painel: ela é de clicar, e não de desenhar.
fn test_sobre_a_paleta_o_ponteiro_e_a_seta() {
	mut editor := panel_editor(220, -1, .rectangle)
	editor.palette_open = true
	palette := editor.palette_rect() or { panic('a paleta deveria aparecer') }
	assert cursor_at(&editor, palette.x + palette.width / 2, palette.y + palette.height / 2)? == idc_arrow
}

// As oito cores ocupam quatro colunas por duas linhas, e o botão do seletor fica embaixo,
// tudo dentro da paleta.
fn test_grade_de_cores_cabe_na_paleta() {
	mut editor := panel_editor(220, -1, .rectangle)
	editor.palette_open = true
	palette := editor.palette_rect() or { panic('a paleta deveria aparecer') }
	assert quick_colors.len == 8

	first := palette_cell_rect(palette, 0)
	assert first.x == palette.x + palette_padding
	assert first.y == palette.y + palette_padding
	last := palette_cell_rect(palette, quick_colors.len - 1)
	assert last.x + last.width == palette.x + palette.width - palette_padding
	assert last.y > first.y, 'a segunda fileira fica abaixo da primeira'

	custom := palette_custom_rect(palette)
	assert custom.y > last.y + last.height
	assert custom.y + custom.height <= palette.y + palette.height - palette_padding

	// Um clique em cada quadrado devolve a cor daquele lugar, e o vão entre eles não.
	assert editor.palette_color_at(first.x + 5, first.y + 5)? == quick_colors[0]
	assert editor.palette_color_at(last.x + 5, last.y + 5)? == quick_colors[7]
	assert editor.palette_color_at(first.x + palette_cell + 2, first.y + 5) == none
	assert editor.palette_color_at(custom.x + 5, custom.y + 5) == none
}

// Escolher uma cor sem marcação selecionada muda só o padrão, e não deixa nada para
// desfazer.
fn test_cor_sem_selecao_vira_padrao() {
	mut editor := panel_editor(220, -1, .rectangle)
	assert editor.apply_color(quick_colors[3]) == 'Cor trocada'
	assert editor.color == quick_colors[3]
	assert editor.current_color() == quick_colors[3]
	assert editor.past.len == 0
}
