module main

// A régua desenha como a linha, e o que ela tem de próprio é a medida: o número que ela
// escreve e a faixa que ela acha sozinha. É isso que estes testes olham, sobre superfícies
// pintadas com cores conhecidas.

// painted monta uma superfície branca com uma faixa preta de x0 a x1 (exclusivo) em todas
// as linhas de y0 a y1 (exclusivo).
fn painted(width int, height int, bar Rect) !Frozen {
	screen := C.GetDC(unsafe { nil })
	surface := new_surface(screen, width, height)!
	C.ReleaseDC(unsafe { nil }, screen)
	paint_rect(surface.dc, Rect{
		width: width
		height: height
	}, 0x00ffffff)
	paint_rect(surface.dc, bar, 0x00000000)
	return surface
}

// O comprimento é o do traço, e não o da caixa: numa diagonal é a hipotenusa.
fn test_o_comprimento_e_o_do_traco() {
	assert ruler_length(Rect{
		width: 120
	}) == 120
	assert ruler_length(Rect{
		height: 45
	}) == 45
	assert ruler_length(Rect{
		width: 30
		height: 40
	}) == 50
	assert ruler_label(Rect{
		width: 30
		height: 40
	}) == '50px'
}

// Clicar no meio de uma faixa acha as duas bordas dela, e o fim é exclusivo: a diferença
// é a largura da faixa.
fn test_acha_as_bordas_da_faixa() ! {
	surface := painted(100, 40, Rect{
		x: 20
		y: 10
		width: 50
		height: 20
	})!
	defer {
		surface.release()
	}
	start, end := measure_run(surface.dc, 100, 40, 40, 15, false)
	assert start == 20
	assert end == 70
	top, bottom := measure_run(surface.dc, 100, 40, 40, 15, true)
	assert top == 10
	assert bottom == 30
}

// Na própria borda a medida é a mesma: a faixa inteira, e não só o que fica de um lado.
fn test_clicar_na_borda_mede_a_faixa_inteira() ! {
	surface := painted(100, 40, Rect{
		x: 20
		y: 10
		width: 50
		height: 20
	})!
	defer {
		surface.release()
	}
	first, last := measure_run(surface.dc, 100, 40, 20, 15, false)
	assert first == 20 && last == 70
	first2, last2 := measure_run(surface.dc, 100, 40, 69, 15, false)
	assert first2 == 20 && last2 == 70
}

// Uma faixa que vai até a borda da imagem para na borda, sem sair dela.
fn test_a_faixa_para_na_borda_da_imagem() ! {
	surface := painted(100, 40, Rect{
		x: 0
		y: 0
		width: 30
		height: 40
	})!
	defer {
		surface.release()
	}
	start, end := measure_run(surface.dc, 100, 40, 10, 5, false)
	assert start == 0 && end == 30
	top, bottom := measure_run(surface.dc, 100, 40, 10, 5, true)
	assert top == 0 && bottom == 40
}

// Um tom vizinho dentro da folga conta como a mesma cor; um tom de fora corta a faixa.
fn test_a_folga_aceita_o_tom_vizinho() ! {
	surface := painted(100, 10, Rect{
		x: 10
		y: 0
		width: 40
		height: 10
	})!
	defer {
		surface.release()
	}
	// Um trecho quase preto no meio da faixa, dentro da folga.
	paint_rect(surface.dc, Rect{
		x: 25
		y: 0
		width: 5
		height: 10
	}, 0x00080808)
	start, end := measure_run(surface.dc, 100, 10, 12, 5, false)
	assert start == 10 && end == 50
	// Um cinza escuro de verdade, fora da folga, corta a faixa.
	paint_rect(surface.dc, Rect{
		x: 25
		y: 0
		width: 5
		height: 10
	}, 0x00404040)
	start2, end2 := measure_run(surface.dc, 100, 10, 12, 5, false)
	assert start2 == 10 && end2 == 25
	assert same_color(0x00000000, 0x000c0c0c)
	assert !same_color(0x00000000, 0x000d0000)
}

// ruler_editor monta um editor sobre uma captura com uma faixa preta de sessenta pixels.
fn ruler_editor() !Editor {
	source := painted(200, 100, Rect{
		x: 50
		y: 20
		width: 60
		height: 40
	})!
	mut editor := Editor{
		source: source
		tool: .ruler
		color: annotation_color
		thickness: ruler_thickness
		canvas_width: 900
		canvas_height: 700
		scene: Scene{
			crop: Rect{
				width: 200
				height: 100
			}
		}
		selected: -1
	}
	editor.apply()!
	return editor
}

// probe_at põe o ponteiro sobre um ponto da captura e aperta a tecla, como o teclado faria.
fn probe_at(mut editor Editor, x int, y int, key u32) {
	client := editor.to_client(Rect{
		x: x
		y: y
	})
	editor.cursor_x = client.x
	editor.cursor_y = client.y
	assert editor.start_probe(key)
}

// Segurar 2 sobre a faixa só mostra a prévia; o clique guarda a régua selecionada no histórico.
fn test_a_tecla_2_mede_a_faixa_na_horizontal() ! {
	mut editor := ruler_editor()!
	probe_at(mut editor, 70, 30, 0x32)
	assert editor.probe_shape() != none
	assert editor.scene.shapes.len == 0
	editor_grab_or_draw(mut editor, editor.cursor_x, editor.cursor_y)
	assert editor.status == 'Medido: 60px'
	assert !editor.dragging
	assert editor.probe == .none
	assert editor.scene.shapes.len == 1
	ruler := editor.scene.shapes[0]
	assert ruler.tool == .ruler
	assert ruler.area.x == 50
	assert ruler.area.width == 60
	assert ruler.area.height == 0
	assert editor.selected == 0
	assert editor.past.len == 1
}

fn test_soltar_a_tecla_da_regua_nao_adiciona_marcacao() ! {
	mut editor := ruler_editor()!
	defer {
		editor.source.release()
		editor.current.release()
	}
	probe_at(mut editor, 70, 30, 0x32)
	assert !editor_key_up(unsafe { nil }, mut editor, 0x31)
	assert editor.probe == .horizontal
	assert editor_key_up(unsafe { nil }, mut editor, 0x32)
	assert editor.probe == .none
	assert editor.scene.shapes.len == 0
	assert editor.past.len == 0
}

fn test_clique_confirma_regua_uma_vez_e_permite_desfazer() ! {
	mut editor := ruler_editor()!
	defer {
		editor.source.release()
		editor.current.release()
	}
	probe_at(mut editor, 70, 30, 0x31)
	editor_press(unsafe { nil }, mut editor, editor.cursor_x, editor.cursor_y)
	assert editor.scene.shapes.len == 1
	assert !editor.dragging
	assert !editor_key_up(unsafe { nil }, mut editor, 0x31)
	assert editor.scene.shapes.len == 1
	editor.undo()
	assert editor.scene.shapes.len == 0
	editor.redo()
	assert editor.scene.shapes.len == 1
}

// Segurar 1 mede a mesma faixa na vertical, que é a altura dela.
fn test_a_tecla_1_mede_na_vertical() ! {
	mut editor := ruler_editor()!
	probe_at(mut editor, 70, 30, 0x31)
	assert editor.finish_probe() == 'Medido: 40px'
	ruler := editor.scene.shapes[0]
	assert ruler.area.y == 20
	assert ruler.area.height == 40
	assert ruler.area.width == 0
}

// Cada seta mede do ponteiro até a borda da faixa naquela direção.
fn test_as_setas_medem_do_ponteiro_ate_a_borda() ! {
	mut editor := ruler_editor()!
	expected := {
		vk_left:  Rect{
			x: 50
			y: 30
			width: 20
		}
		vk_right: Rect{
			x: 70
			y: 30
			width: 40
		}
		vk_up:    Rect{
			x: 70
			y: 20
			height: 10
		}
		vk_down:  Rect{
			x: 70
			y: 30
			height: 30
		}
	}
	for key, area in expected {
		probe_at(mut editor, 70, 30, key)
		shape := editor.probe_shape() or { panic('a seta ${key} deveria medir') }
		assert shape.area == area, 'seta ${key}'
	}
}

// A medida é da régua: com outra ferramenta na mão, as teclas não são dela. Escolher a
// régua abre a ajuda, e a primeira medida a tira da frente.
fn test_so_a_regua_mede_e_a_ajuda_sai_da_frente() ! {
	mut editor := ruler_editor()!
	editor.choose(.rectangle)
	assert !editor.start_probe(0x31)
	assert editor.ruler_help_left() == none
	editor.choose(.ruler)
	assert editor.popover == .ruler_help
	left := editor.ruler_help_left() or { panic('a ajuda deveria abrir') }
	assert left >= options_margin
	assert left + ruler_help_width <= editor.canvas_width - options_margin
	assert editor.start_probe(0x31)
	assert editor.popover == .none
	// Uma tecla que não é de medida continua sendo de quem era.
	assert !editor.start_probe(0x41)
}

// Com moldura, a leitura acontece numa imagem maior, e a régua tem de voltar para as
// coordenadas da captura descontando a folga — senão ela nasce deslocada.
fn test_com_moldura_a_regua_nasce_no_lugar() ! {
	mut editor := ruler_editor()!
	editor.choose(.backdrop)
	editor.choose(.ruler)
	margin := editor.margin()
	assert margin > 0
	// O mesmo ponto da captura, agora deslocado pela folga na janela.
	probe_at(mut editor, 70, 30, 0x32)
	editor.finish_probe()
	ruler := editor.scene.shapes.last()
	assert ruler.tool == .ruler
	assert ruler.area.x == 50
	assert ruler.area.width == 60
}

// Na folga da moldura não há o que medir: ela não é captura, e a medida da faixa chapada da cor dela gravava uma régua fora do recorte, com a etiqueta presa na borda da imagem.
fn test_na_folga_da_moldura_nao_ha_medida() ! {
	mut editor := ruler_editor()!
	editor.choose(.backdrop)
	editor.choose(.ruler)
	probe_at(mut editor, 70, -editor.margin() / 2, 0x32)
	assert editor.probe_shape() == none
	editor.finish_probe()
	assert editor.scene.shapes.len == 1
	assert editor.past.len == 1
}

// Rente à borda, uma faixa da cor da moldura na imagem emenda com a folga, e a medida somava a folga: a régua fica no recorte.
fn test_a_medida_rente_a_moldura_fica_no_recorte() ! {
	mut editor := ruler_editor()!
	paint_rect(editor.source.dc, Rect{
		width: 20
		height: 100
	}, backdrop_color)
	editor.choose(.backdrop)
	// Sem sombra, que escureceria a folga junto da imagem e cortaria a faixa.
	editor.scene.shapes[0] = Shape{
		...editor.scene.shapes[0]
		style: Style{
			rounded: true
		}
	}
	editor.apply()!
	editor.choose(.ruler)
	probe_at(mut editor, 10, 50, 0x32)
	shape := editor.probe_shape() or { panic('a medida deveria existir') }
	assert shape.area.x == 0
	assert shape.area.width == 20
}

// A altura da ajuda é fixa, porque o conta-gotas precisa dela sem contexto em que medir o texto: ela tem de ser a do texto quebrado na largura da caixa, na fonte do editor. Menor, a última linha sairia cortada; maior, sobraria uma faixa vazia embaixo do texto.
fn test_o_texto_da_ajuda_cabe_na_altura_fixa() ! {
	screen := C.GetDC(unsafe { nil })
	surface := new_surface(screen, 400, 200)!
	C.ReleaseDC(unsafe { nil }, screen)
	defer {
		surface.release()
	}
	font := C.CreateFontW(-15, 0, 0, 0, 400, 0, 0, 0, default_charset, 0, 0, antialiased_quality,
		0, 'Segoe UI'.to_wide())
	defer {
		C.DeleteObject(font)
	}
	old_font := C.SelectObject(surface.dc, font)
	defer {
		C.SelectObject(surface.dc, old_font)
	}
	mut measured := C.RECT{
		right: ruler_help_width - 2 * ruler_help_padding
	}
	C.DrawTextW(surface.dc, ruler_help_text.to_wide(), -1, &measured, dt_wordbreak | dt_noprefix | dt_calcrect)
	assert measured.bottom == ruler_help_text_height
}

// Confirmar por clique encerra a prévia: a tecla solta depois não repete a inserção.
fn test_o_clique_encerra_a_medida() ! {
	mut editor := ruler_editor()!
	probe_at(mut editor, 70, 30, 0x32)
	editor_grab_or_draw(mut editor, editor.cursor_x, editor.cursor_y)
	assert editor.probe == .none
	assert !editor_key_up(unsafe { nil }, mut editor, 0x32)
	assert editor.past.len == 1
	assert editor.scene.shapes.len == 1
}

// Com o ponteiro fora da imagem não há o que medir, nem prévia nem régua.
fn test_fora_da_imagem_nao_mede() ! {
	mut editor := ruler_editor()!
	editor.cursor_x = editor.view.x - 5
	editor.cursor_y = editor.view.y + 30
	assert editor.start_probe(0x32)
	assert editor.probe_shape() == none
	editor.finish_probe()
	assert editor.probe == .none
	assert editor.scene.shapes.len == 0
	assert editor.past.len == 0
}

// Com zoom, o ponteiro a poucos pixels da borda, sobre o fundo cinza, também fica fora: a conversão para a imagem truncaria o ponto para dentro dela, e a régua mediria a primeira coluna.
fn test_com_zoom_junto_da_borda_nao_mede() ! {
	mut editor := ruler_editor()!
	editor.scale = 8.0
	editor.cursor_x = editor.view.x - 5
	editor.cursor_y = editor.view.y + 30
	assert editor.start_probe(0x32)
	assert editor.probe_shape() == none
	editor.finish_probe()
	assert editor.scene.shapes.len == 0
}

// top_ruler é uma régua deitada rente à borda de cima de uma captura de 200 por 100.
fn top_ruler() Shape {
	return Shape{
		tool: .ruler
		area: Rect{
			x: 50
			y: 2
			width: 100
		}
		color: 0x000000ff
		thickness: ruler_thickness
	}
}

// labelled conta os pixels da cor da régua na faixa logo abaixo do traço, onde a etiqueta de uma régua rente ao topo tem de estar.
fn labelled(hdc voidptr, left int, top int) int {
	mut count := 0
	for y in top + 12 .. top + 28 {
		for x in left + 60 .. left + 140 {
			if C.GetPixel(hdc, x, y) == 0x000000ff {
				count++
			}
		}
	}
	return count
}

// Rente à borda de cima, a etiqueta da régua deitada desce para baixo do traço em vez de sair cortada da imagem.
fn test_rente_ao_topo_a_etiqueta_desce() ! {
	token := start_gdiplus()!
	defer {
		stop_gdiplus(token)
	}
	source := painted(200, 100, Rect{})!
	defer {
		source.release()
	}
	drawn := render_scene(source, Scene{
		crop: Rect{
			width: 200
			height: 100
		}
		shapes: [top_ruler()]
	})!
	defer {
		drawn.release()
	}
	assert labelled(drawn.dc, 0, 0) > 100
}

// Na prévia, a etiqueta procura lugar dentro da imagem, e não da janela inteira: sem o recorte ela ia para cima da imagem, sobre o fundo, onde o resultado não a teria.
fn test_na_previa_a_etiqueta_fica_na_imagem() ! {
	token := start_gdiplus()!
	defer {
		stop_gdiplus(token)
	}
	editor := ruler_editor()!
	screen := C.GetDC(unsafe { nil })
	window := new_surface(screen, editor.canvas_width, toolbar_height + editor.canvas_height)!
	C.ReleaseDC(unsafe { nil }, screen)
	defer {
		window.release()
	}
	mark := top_ruler()
	editor.draw_mark_on_image(window.dc, mark, editor.to_client(mark.area), f32(ruler_thickness), 0)
	assert labelled(window.dc, editor.view.x, editor.view.y) > 100
}

// Em pé e rente à borda direita, a etiqueta passa para a esquerda do traço; a que nem assim cabe fica presa dentro da imagem; e longe das bordas nada muda.
fn test_a_etiqueta_procura_lugar_dentro_da_imagem() ! {
	surface := painted(200, 100, Rect{})!
	defer {
		surface.release()
	}
	standing := label_box(surface.dc, 190, 50, false, 5, 40, 16)
	assert standing.x == 190 - 5 - 40
	assert standing.y == 50 - 8
	// Deitada e rente ao topo, ela desce para baixo do traço, e não fica espremida em cima dele.
	top := label_box(surface.dc, 100, 3, true, 5, 40, 16)
	assert top.y == 3 + 5
	corner := label_box(surface.dc, 10, 60, true, 5, 40, 16)
	assert corner.x == 0
	assert corner.y == 60 - 5 - 16
	middle := label_box(surface.dc, 100, 50, false, 5, 40, 16)
	assert middle.x == 105
}

// A régua desenha e atravessa a caixa como a linha, e não tem botões de estilo.
fn test_a_regua_e_uma_linha_com_rotulo() {
	assert Tool.ruler in drawing_tools
	assert Tool.ruler in diagonal_tools
	assert style_slots(.ruler).len == 0
	assert default_thickness(.ruler) == ruler_thickness
}
