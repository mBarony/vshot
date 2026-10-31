module main

fn C.SetPixel(hdc voidptr, x int, y int, color u32) u32

// sample_image monta uma imagem onde cada pixel carrega a própria coordenada nas
// componentes de cor, para dar para conferir de onde cada pixel veio depois de um
// recorte, e não apenas que o tamanho bateu.
fn sample_image(size int) !Frozen {
	screen_dc := C.GetDC(unsafe { nil })
	defer {
		C.ReleaseDC(unsafe { nil }, screen_dc)
	}
	surface := new_surface(screen_dc, size, size)!
	for y := 0; y < size; y++ {
		for x := 0; x < size; x++ {
			// COLORREF é 0x00bbggrr, então x vai no vermelho e y no verde.
			C.SetPixel(surface.dc, x, y, u32(x * 5) | (u32(y * 5) << 8))
		}
	}
	return surface
}

// pixel_of lê um pixel da imagem, já em RGBA.
fn pixel_of(image Frozen, x int, y int) ![]u8 {
	shot := image.region(Rect{
		width: image.width
		height: image.height
	})!
	defer {
		shot.release()
	}
	index := (y * image.width + x) * 4
	unsafe {
		return [shot.pixels[index], shot.pixels[index + 1], shot.pixels[index + 2],
			shot.pixels[index + 3]]
	}
}

fn whole_of(image Frozen) Rect {
	return Rect{
		width: image.width
		height: image.height
	}
}

// Um desfazer ou refazer cuja imagem não pode ser montada não troca a cena: ela continua a da imagem na tela, e a que não pôde ser montada volta para a pilha dela, para a próxima tentativa. Sem isso o fator e a moldura passavam a ser os de outra imagem, e as alças e os traços novos saíam deslocados.
fn test_desfazer_que_falha_nao_desencontra_cena_e_imagem() ! {
	source := sample_image(40)!
	defer {
		source.release()
	}
	mut editor := Editor{
		source: source
		canvas_width: 400
		canvas_height: 300
		scene: Scene{
			crop: whole_of(source)
		}
		selected: -1
	}
	editor.apply()!
	defer {
		editor.current.release()
	}
	editor.record()
	editor.scene.crop = Rect{
		x: 5
		y: 5
		width: 20
		height: 20
	}
	editor.apply()!
	// A cena guardada pede um fator de tamanho que nenhuma memória comporta: a imagem dela não pode ser montada, como a de uma captura grande ampliada com a memória já apertada.
	editor.past[0].factor = 100000.0
	assert editor.undo().starts_with('Falha ao desfazer')
	assert editor.scene.crop.width == 20, 'a cena continua a da imagem na tela'
	assert editor.scene.factor == 1.0
	assert editor.past.len == 1 && editor.future.len == 0
	editor.past[0].factor = 1.0
	assert editor.undo() == 'Desfeito'
	assert editor.scene.crop == whole_of(source)
	editor.future[0].factor = 100000.0
	assert editor.redo().starts_with('Falha ao refazer')
	assert editor.scene.crop == whole_of(source)
	assert editor.past.len == 0 && editor.future.len == 1
	editor.future[0].factor = 1.0
	assert editor.redo() == 'Refeito'
	assert editor.scene.crop.width == 20
}

// Mover uma marcação cuja imagem nova não pode ser montada não deixa na cena uma marcação que a imagem não mostra: ela sai da cena, que volta a ser a da imagem na tela — montada sem ela ao pegá-la —, e desfazer a traz de volta no lugar de antes.
fn test_mover_que_falha_nao_desencontra_cena_e_imagem() ! {
	source := sample_image(40)!
	defer {
		source.release()
	}
	mut editor := Editor{
		source: source
		canvas_width: 400
		canvas_height: 300
		scene: Scene{
			crop: whole_of(source)
			shapes: [
				Shape{
					tool: .rectangle
					area: Rect{
						x: 5
						y: 5
						width: 10
						height: 10
					}
					color: annotation_color
					thickness: 2
				},
			]
		}
		selected: 0
	}
	editor.apply()!
	defer {
		editor.current.release()
	}
	editor.start_grab(.body, false)
	assert editor.grab == .body
	editor.cursor_x = 40
	// Um fator de tamanho que nenhuma memória comporta: a imagem nova não pode ser montada, como a de uma captura grande ampliada com a memória apertada.
	editor.scene.factor = 100000.0
	assert editor.finish_grab().starts_with('Falha ao mover')
	assert editor.scene.shapes.len == 0
	assert editor.selected == -1
	assert editor.past.len == 1
	editor.scene.factor = 1.0
	assert editor.undo() == 'Desfeito'
	assert editor.scene.shapes.len == 1
	assert editor.scene.shapes[0].area.x == 5
}

// O recorte é uma janela sobre a captura, e não uma destruição dela: é isso que permite
// desfazer sem reconstruir nada.
fn test_recorte_desloca_a_origem_e_pode_ser_desfeito() {
	source := sample_image(20)!
	defer {
		source.release()
	}

	whole := render_scene(source, Scene{ crop: whole_of(source) })!
	assert whole.width == 20 && whole.height == 20
	whole.release()

	cut := render_scene(source, Scene{
		crop: Rect{
			x: 5
			y: 4
			width: 8
			height: 6
		}
	})!
	assert cut.width == 8 && cut.height == 6
	assert pixel_of(cut, 0, 0)! == pixel_of(source, 5, 4)!, 'o canto do recorte deveria vir de (5,4)'
	assert pixel_of(cut, 7, 5)! == pixel_of(source, 12, 9)!, 'o canto oposto deveria vir de (12,9)'
	cut.release()

	// Desfazer é só voltar a cena anterior: a captura nunca foi tocada.
	undone := render_scene(source, Scene{ crop: whole_of(source) })!
	defer {
		undone.release()
	}
	assert undone.width == 20 && undone.height == 20
	assert pixel_of(undone, 5, 4)! == pixel_of(source, 5, 4)!
}

// A marcação é guardada em coordenadas da captura, e não da imagem visível. Um recorte
// posterior tem de encontrá-la no lugar certo sem que ninguém reescreva a geometria dela.
fn test_marcacao_acompanha_o_recorte() {
	// As marcações são desenhadas pelo GDI+, que só existe entre ligar e desligar. No
	// programa isso acontece na abertura e no fechamento do editor; aqui, no teste.
	token := start_gdiplus()!
	defer {
		stop_gdiplus(token)
	}
	source := sample_image(40)!
	defer {
		source.release()
	}

	mark := Shape{
		tool: .rectangle
		area: Rect{
			x: 10
			y: 10
			width: 20
			height: 20
		}
		color: annotation_color
		thickness: annotation_width
	}

	// Sem recorte, o traço está onde foi desenhado.
	full := render_scene(source, Scene{ crop: whole_of(source), shapes: [mark] })!
	assert pixel_of(full, 20, 10)! == [u8(255), 0, 0, 255], 'o traço deveria estar em (20,10)'
	full.release()

	// Com recorte de origem (8,8), o mesmo traço passa a estar em (12,2).
	cropped := render_scene(source, Scene{
		crop: Rect{
			x: 8
			y: 8
			width: 24
			height: 24
		}
		shapes: [mark]
	})!
	defer {
		cropped.release()
	}
	assert cropped.width == 24 && cropped.height == 24
	assert pixel_of(cropped, 12, 2)! == [u8(255), 0, 0, 255], 'a marcação deveria ter acompanhado o recorte'
	// No centro da moldura a cor original continua lá: a marcação é vazada.
	assert pixel_of(cropped, 12, 12)! == pixel_of(source, 20, 20)!, 'o miolo não deveria ter sido tocado'
}

// O que o GDI não sabia fazer: espessura fracionária e borda suavizada. Com uma caneta de
// dois pixels centrada na borda, cada lado do traço cobre meio pixel, e esse meio pixel
// tem de sair como mistura entre o traço e o fundo. No GDI ele sairia de uma cor só.
fn test_traco_tem_borda_suavizada() {
	token := start_gdiplus()!
	defer {
		stop_gdiplus(token)
	}
	source := sample_image(40)!
	defer {
		source.release()
	}
	background := pixel_of(source, 20, 9)!
	draw_outline(source.dc, Rect{ x: 10, y: 10, width: 20, height: 20 }, Style{}, annotation_color, 2.0, corner_radius)

	// O miolo do traço é vermelho puro.
	assert pixel_of(source, 20, 10)! == [u8(255), 0, 0, 255]

	// A borda não: está entre o fundo e o vermelho, nos dois canais.
	edge := pixel_of(source, 20, 9)!
	assert edge[0] > background[0] && edge[0] < 255, 'o vermelho da borda deveria estar entre o fundo e o traço'
	assert edge[1] > 0 && edge[1] < background[1], 'o verde da borda deveria estar entre o traço e o fundo'
}

// A elipse é inscrita no retângulo do arrasto: o meio de cada lado é tocado, mas o canto
// da caixa fica de fora. É o que distingue o traço dela do do retângulo.
fn test_elipse_toca_os_lados_e_poupa_os_cantos() {
	token := start_gdiplus()!
	defer {
		stop_gdiplus(token)
	}
	source := sample_image(40)!
	defer {
		source.release()
	}
	mark := Shape{
		tool: .oval
		area: Rect{
			x: 10
			y: 10
			width: 20
			height: 20
		}
		color: annotation_color
		thickness: annotation_width
	}
	corner_before := pixel_of(source, 10, 10)!
	drawn := render_scene(source, Scene{ crop: whole_of(source), shapes: [mark] })!
	defer {
		drawn.release()
	}
	assert pixel_of(drawn, 20, 10)! == [u8(255), 0, 0, 255], 'o topo da elipse deveria ser traço'
	assert pixel_of(drawn, 10, 20)! == [u8(255), 0, 0, 255], 'a lateral também'
	assert pixel_of(drawn, 10, 10)! == corner_before, 'o canto da caixa não é da elipse'
	assert pixel_of(drawn, 20, 20)! == pixel_of(source, 20, 20)!, 'o miolo é vazado'
}

// O marca-texto destaca sem esconder: o traço dele deixa o fundo passar, e o traço livre
// no mesmo lugar cobre.
fn test_marca_texto_deixa_o_fundo_passar() {
	token := start_gdiplus()!
	defer {
		stop_gdiplus(token)
	}
	source := sample_image(40)!
	defer {
		source.release()
	}
	path := [Point{5, 20}, Point{20, 20}, Point{35, 20}]
	background := pixel_of(source, 20, 20)!

	mark := Shape{
		tool: .highlighter
		area: bounds(path)
		color: highlight_color
		thickness: 10
		points: path
	}
	marked := render_scene(source, Scene{ crop: whole_of(source), shapes: [mark] })!
	defer {
		marked.release()
	}
	blended := pixel_of(marked, 20, 20)!
	// Amarelo é 255 de vermelho e 215 de verde; o fundo ali tem 100 nos dois.
	assert blended[0] > background[0] && blended[0] < 255, 'o vermelho deveria ficar entre o fundo e o traço'
	assert blended[1] > background[1] && blended[1] < 215, 'e o verde também'

	// O mesmo caminho com o traço livre cobre o fundo por inteiro.
	opaque := render_scene(source, Scene{
		crop: whole_of(source)
		shapes: [Shape{
			...mark
			tool: .freehand
		}]
	})!
	defer {
		opaque.release()
	}
	assert pixel_of(opaque, 20, 20)! == [u8(255), 215, 0, 255], 'o traço livre é opaco'
}

// Um clique sem arrasto deixa um traço de um ponto só. O do marca-texto também deixa o fundo passar, e o do traço livre continua opaco.
fn test_ponto_do_marca_texto_deixa_o_fundo_passar() ! {
	token := start_gdiplus()!
	defer {
		stop_gdiplus(token)
	}
	source := sample_image(40)!
	defer {
		source.release()
	}
	background := pixel_of(source, 20, 20)!
	mark := Shape{
		tool: .highlighter
		area: bounds([Point{20, 20}])
		color: highlight_color
		thickness: 10
		points: [Point{20, 20}]
	}
	marked := render_scene(source, Scene{ crop: whole_of(source), shapes: [mark] })!
	defer {
		marked.release()
	}
	blended := pixel_of(marked, 20, 20)!
	assert blended[0] > background[0] && blended[0] < 255, 'o vermelho deveria ficar entre o fundo e o traço'
	assert blended[1] > background[1] && blended[1] < 215, 'e o verde também'

	opaque := render_scene(source, Scene{
		crop: whole_of(source)
		shapes: [Shape{
			...mark
			tool: .freehand
		}]
	})!
	defer {
		opaque.release()
	}
	assert pixel_of(opaque, 20, 20)! == [u8(255), 215, 0, 255], 'o ponto do traço livre é opaco'
}

// Um arrasto que não saiu do lugar deixa vários pontos iguais: o traço sai como um ponto só, em vez de sumir e deixar uma marcação invisível na cena.
fn test_traco_de_pontos_iguais_nao_some() ! {
	token := start_gdiplus()!
	defer {
		stop_gdiplus(token)
	}
	source := sample_image(40)!
	defer {
		source.release()
	}
	background := pixel_of(source, 20, 20)!
	path := [Point{20, 20}, Point{20, 20}, Point{20, 20}]
	marked := render_scene(source, Scene{
		crop: whole_of(source)
		shapes: [
			Shape{
				tool: .highlighter
				area: bounds(path)
				color: highlight_color
				thickness: 10
				points: path
			},
		]
	})!
	defer {
		marked.release()
	}
	assert pixel_of(marked, 20, 20)! != background
}

// Recortar move a janela da cena: a imagem de trabalho encolhe, a marcação feita antes
// sobrevive na posição certa, e nada da captura é perdido. Vale também para o traço livre,
// que guarda pontos e não uma caixa.
fn test_recorte_no_editor_move_a_janela_e_preserva_o_traco() {
	token := start_gdiplus()!
	defer {
		stop_gdiplus(token)
	}
	source := sample_image(40)!
	defer {
		source.release()
	}
	path := [Point{10, 20}, Point{20, 20}, Point{30, 20}]
	scene := Scene{
		crop: whole_of(source)
		shapes: [
			Shape{
				tool: .freehand
				area: bounds(path)
				color: annotation_color
				thickness: 3
				points: path
			},
		]
	}
	whole := render_scene(source, scene)!
	assert whole.width == 40
	// O traço passa por (20,20) na captura inteira.
	assert pixel_of(whole, 20, 20)! == [u8(255), 0, 0, 255]
	whole.release()

	// Recortado a partir de (8,8), o mesmo traço passa a estar em (12,12).
	mut cropped_scene := scene
	cropped_scene.crop = Rect{
		x: 8
		y: 8
		width: 24
		height: 24
	}
	cropped := render_scene(source, cropped_scene)!
	defer {
		cropped.release()
	}
	assert cropped.width == 24 && cropped.height == 24
	assert pixel_of(cropped, 12, 12)! == [u8(255), 0, 0, 255], 'o traço deveria ter acompanhado o recorte'
	// E o canto do recorte veio de (8,8) da captura.
	assert pixel_of(cropped, 0, 0)! == pixel_of(source, 8, 8)!
}

// Terminar de desenhar deixa a marcação selecionada: o painel passa a governar o que
// acabou de ser feito, e as alças dela aparecem sem precisar trocar de ferramenta.
fn test_marcacao_nasce_selecionada() {
	token := start_gdiplus()!
	defer {
		stop_gdiplus(token)
	}
	source := sample_image(60)!
	defer {
		source.release()
	}
	mut editor := Editor{
		source: source
		canvas_width: 60
		canvas_height: 60
		scene: Scene{
			crop: whole_of(source)
		}
		tool: .rectangle
	}
	defer {
		editor.current.release()
	}
	editor.apply()!
	assert editor.selected == -1

	// A imagem começa abaixo da barra de ferramentas, e o arrasto é preso a ela.
	assert editor.view.y == toolbar_height
	editor.origin_x = 10
	editor.origin_y = toolbar_height + 5
	editor.cursor_x = 40
	editor.cursor_y = toolbar_height + 25
	assert editor.finish_drag() == 'Retângulo desenhado'
	assert editor.scene.shapes.len == 1
	assert editor.selected == 0

	// A segunda passa a ser a selecionada, e não a primeira.
	editor.origin_y = toolbar_height + 30
	editor.cursor_y = toolbar_height + 50
	assert editor.finish_drag() == 'Retângulo desenhado'
	assert editor.scene.shapes.len == 2
	assert editor.selected == 1

	// E o painel passa a mostrar o que a marcação nova tem, não o padrão da ferramenta.
	assert editor.current_thickness() == editor.scene.shapes[1].thickness
	assert editor.options_tool() == .rectangle
}

// Com uma ferramenta de desenho na mão, um clique sobre uma marcação a escolhe, sem
// desenhar nada; um arrasto que comece sobre ela desenha outra por cima; e o numerador,
// que cria com um clique, põe o balão mesmo dentro de um retângulo.
fn test_clique_sobre_a_marcacao_a_escolhe_com_qualquer_ferramenta() ! {
	token := start_gdiplus()!
	defer {
		stop_gdiplus(token)
	}
	source := sample_image(60)!
	defer {
		source.release()
	}
	mut editor := Editor{
		source: source
		canvas_width: 60
		canvas_height: 60
		scene: Scene{
			crop: whole_of(source)
			shapes: [
				Shape{
					tool: .rectangle
					area: Rect{
						x: 10
						y: 10
						width: 30
						height: 30
					}
					thickness: 2
				},
			]
		}
		tool: .oval
		selected: -1
	}
	defer {
		editor.current.release()
	}
	editor.apply()!
	top := toolbar_height

	// Um clique de mão trêmula, um pixel ao lado, dentro do retângulo: escolhe.
	editor.origin_x = 25
	editor.origin_y = top + 25
	editor.cursor_x = 26
	editor.cursor_y = top + 26
	assert editor.finish_drag() == 'Marcação selecionada'
	assert editor.selected == 0
	assert editor.scene.shapes.len == 1
	assert editor.past.len == 0

	// Um arrasto que começa no mesmo lugar desenha uma elipse por cima.
	editor.cursor_x = 50
	editor.cursor_y = top + 50
	assert editor.finish_drag() == 'Elipse desenhado'
	assert editor.scene.shapes.len == 2

	// O numerador não cede o clique: o balão nasce dentro do retângulo.
	editor.tool = .counter
	editor.origin_x = 15
	editor.origin_y = top + 15
	editor.cursor_x = 15
	editor.cursor_y = top + 15
	editor.finish_drag()
	assert editor.scene.shapes.len == 3
	assert editor.scene.shapes.last().tool == .counter
}

// Com uma ferramenta de desenho na mão, arrastar a marcação selecionada a move e entra no
// histórico; apertar e soltar sem mexer não entra; e sobre uma marcação que não está
// selecionada o arrasto não pega nada — ele desenha.
fn test_arrastar_a_selecionada_a_move_com_qualquer_ferramenta() ! {
	token := start_gdiplus()!
	defer {
		stop_gdiplus(token)
	}
	source := sample_image(60)!
	defer {
		source.release()
	}
	mut editor := Editor{
		source: source
		canvas_width: 60
		canvas_height: 60
		scene: Scene{
			crop: whole_of(source)
			shapes: [
				Shape{
					tool: .rectangle
					area: Rect{
						x: 10
						y: 10
						width: 30
						height: 30
					}
					thickness: 2
				},
			]
		}
		tool: .oval
		selected: 0
	}
	defer {
		editor.current.release()
	}
	editor.apply()!
	top := toolbar_height

	press(mut editor, 25, top + 25)
	assert editor.grab == .body
	assert editor.finish_grab() == 'Marcação selecionada'
	assert editor.past.len == 0
	assert editor.scene.shapes.len == 1
	assert editor.selected == 0

	press(mut editor, 25, top + 25)
	editor.cursor_x = 35
	editor.cursor_y = top + 30
	assert editor.finish_grab() == 'Marcação movida'
	assert editor.scene.shapes[0].area == Rect{
		x: 20
		y: 15
		width: 30
		height: 30
	}
	assert editor.past.len == 1
	assert editor.scene.shapes.len == 1

	editor.selected = -1
	press(mut editor, 30, top + 30)
	assert editor.grab == .none
	assert editor.dragging
}

// press faz o que o clique sobre a imagem faz, sem janela: guarda onde ele caiu e decide o
// que ele começa.
fn press(mut editor Editor, x int, y int) {
	editor.origin_x = x
	editor.origin_y = y
	editor.cursor_x = x
	editor.cursor_y = y
	editor_grab_or_draw(mut editor, x, y)
}

// Selecionar e recortar dividem o botão: sobre uma marcação o clique a escolhe e não
// recorta, sobre a imagem vazia um clique que tremeu não recorta, e um arrasto de verdade
// recorta.
fn test_selecionar_recorta_arrastando_na_imagem_vazia() ! {
	token := start_gdiplus()!
	defer {
		stop_gdiplus(token)
	}
	source := sample_image(60)!
	defer {
		source.release()
	}
	mut editor := Editor{
		source: source
		canvas_width: 60
		canvas_height: 60
		scene: Scene{
			crop: whole_of(source)
			shapes: [
				Shape{
					tool: .rectangle
					area: Rect{
						x: 5
						y: 5
						width: 20
						height: 20
					}
					thickness: 2
				},
			]
		}
		tool: .select
		selected: -1
	}
	defer {
		editor.current.release()
	}
	editor.apply()!
	top := toolbar_height

	press(mut editor, 5, top + 15)
	assert editor.selected == 0
	assert !editor.dragging

	press(mut editor, 40, top + 40)
	assert editor.selected == -1
	assert editor.dragging
	editor.cursor_x = 42
	editor.cursor_y = top + 43
	editor.finish_drag()
	assert editor.scene.crop == whole_of(source)

	press(mut editor, 30, top + 30)
	editor.cursor_x = 55
	editor.cursor_y = top + 50
	assert editor.finish_drag().starts_with('Recortado')
	assert editor.scene.crop == Rect{
		x: 30
		y: 30
		width: 25
		height: 20
	}
	editor.undo()
	assert editor.scene.crop == whole_of(source)
}

// square_editor monta um editor sobre a imagem, numa janela do tamanho dado, em Selecionar, com um quadrado cheio de (5, 5) a (45, 45) já selecionado. Pede o GDI+ iniciado.
fn square_editor(source Frozen, width int, height int) !Editor {
	mut editor := Editor{
		source: source
		canvas_width: width
		canvas_height: height
		scene: Scene{
			crop: whole_of(source)
			shapes: [
				Shape{
					tool: .rectangle
					area: Rect{
						x: 5
						y: 5
						width: 40
						height: 40
					}
					thickness: 2
					style: Style{
						filled: true
					}
				},
			]
		}
		tool: .select
		selected: 0
	}
	editor.apply()!
	return editor
}

// Durante o arrasto de uma marcação ela está fora da cena: as teclas, os atalhos e a roda que chegam nesse meio-tempo são engolidos, e soltar o botão a devolve ao lugar dela, com uma entrada só no histórico. Se outra janela tomar o mouse no meio do arrasto, o botão solto nunca chega, e o arrasto termina ali mesmo.
fn test_arrasto_de_marcacao_resiste_ao_teclado_e_a_perda_do_mouse() ! {
	token := start_gdiplus()!
	defer {
		stop_gdiplus(token)
	}
	source := sample_image(60)!
	defer {
		source.release()
	}
	mut editor := square_editor(source, 60, 60)!
	defer {
		editor.current.release()
	}
	top := toolbar_height

	press(mut editor, 25, top + 25)
	assert editor.grab == .body
	assert editor.scene.shapes.len == 0
	for key in [vk_escape, vk_delete, u32(`R`)] {
		dispatch_editor(unsafe { nil }, mut editor, wm_keydown, usize(key), 0)
	}
	dispatch_editor(unsafe { nil }, mut editor, wm_command, usize(id_undo), 0)
	dispatch_editor(unsafe { nil }, mut editor, wm_mousewheel, usize(120) << 16, 0)
	assert editor.selected == 0
	assert editor.tool == .select
	assert editor.past.len == 1
	assert editor.scene.shapes.len == 0

	dispatch_editor(unsafe { nil }, mut editor, wm_lbuttonup, 0, isize(35 | ((top + 30) << 16)))
	assert editor.grab == .none
	assert editor.scene.shapes.len == 1
	assert editor.scene.shapes[0].area.x == 15
	assert editor.past.len == 1

	// O aviso de que o mouse foi para a própria janela não interrompe nada; o de que ele foi para outra termina o arrasto.
	press(mut editor, 35, top + 35)
	assert editor.grab == .body
	editor.cursor_x = 40
	editor.cursor_y = top + 35
	dispatch_editor(unsafe { nil }, mut editor, wm_capturechanged, 0, 0)
	assert editor.grab == .body
	other := isize(1)
	dispatch_editor(unsafe { nil }, mut editor, wm_capturechanged, 0, other)
	assert editor.grab == .none
	assert !editor.dragging
	assert editor.scene.shapes.len == 1
	assert editor.scene.shapes[0].area.x == 20
	assert editor.past.len == 2

	// O controle de espessura e a imagem arrastada pelo botão direito também param.
	editor.sliding = true
	editor.panning = true
	dispatch_editor(unsafe { nil }, mut editor, wm_capturechanged, 0, other)
	assert !editor.sliding && !editor.panning
}

// O segundo aperto rápido sobre a marcação que o primeiro escolheu chega como duplo clique, e tem de pegá-la como um clique comum: engolido, ele não fazia nada, e a marcação não saía do lugar.
fn test_duplo_clique_rapido_pega_a_marcacao() ! {
	token := start_gdiplus()!
	defer {
		stop_gdiplus(token)
	}
	source := sample_image(60)!
	defer {
		source.release()
	}
	// Numa janela maior, para o painel de opções, no canto de cima, não cobrir a imagem.
	mut editor := square_editor(source, 600, 400)!
	defer {
		editor.current.release()
	}
	down :=editor.to_client(Rect{
		x: 25
		y: 25
	})
	up := editor.to_client(Rect{
		x: 35
		y: 30
	})
	dispatch_editor(unsafe { nil }, mut editor, wm_lbuttondblclk, 0, isize(down.x | (down.y << 16)))
	assert editor.grab == .body
	assert editor.dragging
	dispatch_editor(unsafe { nil }, mut editor, wm_lbuttonup, 0, isize(up.x | (up.y << 16)))
	assert editor.scene.shapes.len == 1
	assert editor.scene.shapes[0].area.x == 15
}

// Desenhando, o teclado e os atalhos também esperam a soltura: V trocava o retângulo em curso por um recorte, e desfazer apagava a marcação anterior debaixo do traço.
fn test_teclas_esperam_o_desenho() ! {
	token := start_gdiplus()!
	defer {
		stop_gdiplus(token)
	}
	source := sample_image(60)!
	defer {
		source.release()
	}
	mut editor := Editor{
		source: source
		canvas_width: 60
		canvas_height: 60
		scene: Scene{
			crop: whole_of(source)
		}
		tool: .rectangle
		color: annotation_color
		thickness: 2
		selected: -1
		config: default_config()
	}
	defer {
		editor.current.release()
	}
	editor.apply()!
	top := toolbar_height
	press(mut editor, 10, top + 10)
	dispatch_editor(unsafe { nil }, mut editor, wm_lbuttonup, 0, isize(20 | ((top + 20) << 16)))
	assert editor.scene.shapes.len == 1
	press(mut editor, 30, top + 30)
	assert editor.dragging
	dispatch_editor(unsafe { nil }, mut editor, wm_keydown, usize(`V`), 0)
	dispatch_editor(unsafe { nil }, mut editor, wm_command, usize(id_undo), 0)
	assert editor.tool == .rectangle
	assert editor.dragging
	dispatch_editor(unsafe { nil }, mut editor, wm_lbuttonup, 0, isize(50 | ((top + 50) << 16)))
	assert editor.scene.shapes.len == 2
}

// counter_at monta um balão numerado de círculo com o centro no ponto dado.
fn counter_at(x int, y int) Shape {
	radius := int(counter_radius(f32(counter_thickness)))
	return Shape{
		tool: .counter
		area: Rect{
			x: x - radius
			y: y - radius
			width: 2 * radius
			height: 2 * radius
		}
		color: annotation_color
		thickness: counter_thickness
		points: [Point{x, y}, Point{x + radius, y + radius}]
	}
}

// Arrastar um balão numerado não renumera os outros enquanto dura o arrasto: a montagem sabe que falta um balão ali, e a prévia leva o número do lugar dele na lista.
fn test_arrastar_um_balao_nao_renumera_os_outros() ! {
	token := start_gdiplus()!
	defer {
		stop_gdiplus(token)
	}
	source := sample_image(200)!
	defer {
		source.release()
	}
	mut editor := Editor{
		source: source
		canvas_width: 200
		canvas_height: 200
		scene: Scene{
			crop: whole_of(source)
			shapes: [counter_at(30, 40), counter_at(100, 40), counter_at(170, 40)]
		}
		tool: .select
		selected: 0
	}
	defer {
		editor.current.release()
	}
	editor.apply()!
	top := toolbar_height
	// O quadro do algarismo do balão do meio, inteiro dentro do disco dele e longe da ponta do primeiro: um pixel só podia cair na haste que o 1 e o 2 têm em comum.
	digit := Rect{
		x: 84
		y: 24
		width: 32
		height: 32
	}
	before := editor.current.region(digit)!
	defer {
		before.release()
	}

	press(mut editor, 30, top + 40)
	assert editor.grab == .body
	during := editor.current.region(digit)!
	defer {
		during.release()
	}
	assert unsafe { during.pixels.vbytes(32 * 32 * 4) } == unsafe { before.pixels.vbytes(32 * 32 * 4) }, 'o balão do meio continua com o 2 durante o arrasto'
	assert editor.scene.shapes.len == 2
	assert editor.missing_counter() == 0
	assert number_at(editor.scene.shapes, editor.selected) == 1
	editor.cursor_x = 40
	assert editor.finish_grab() == 'Marcação movida'
	assert editor.missing_counter() == -1
	assert editor.scene.shapes.len == 3
}

// Com o botão esquerdo num arrasto a vista fica parada: a roda não aproxima e o botão direito não arrasta a imagem, porque o arrasto guarda a origem em pixels da janela e uma vista nova a poria noutro ponto da imagem. E com o direito arrastando a imagem, o esquerdo não começa nada.
fn test_arrasto_com_o_esquerdo_congela_a_vista() ! {
	token := start_gdiplus()!
	defer {
		stop_gdiplus(token)
	}
	source := sample_image(60)!
	defer {
		source.release()
	}
	mut editor := Editor{
		source: source
		canvas_width: 60
		canvas_height: 60
		scene: Scene{
			crop: whole_of(source)
		}
		tool: .rectangle
		selected: -1
	}
	defer {
		editor.current.release()
	}
	editor.apply()!
	top := toolbar_height
	spot := isize(20 | ((top + 20) << 16))

	press(mut editor, 10, top + 10)
	assert editor.dragging
	zoom := editor.zoom
	dispatch_editor(unsafe { nil }, mut editor, wm_mousewheel, usize(120) << 16, spot)
	assert editor.zoom == zoom
	dispatch_editor(unsafe { nil }, mut editor, wm_rbuttondown, 0, spot)
	assert !editor.panning

	editor.dragging = false
	dispatch_editor(unsafe { nil }, mut editor, wm_rbuttondown, 0, spot)
	assert editor.panning
	dispatch_editor(unsafe { nil }, mut editor, wm_lbuttondown, 0, spot)
	assert !editor.dragging
}

// Um clique sem mover sobre a marcação selecionada não é edição e deixa o refazer como estava; um arrasto que a move é edição e o apaga.
fn test_clique_parado_na_marcacao_guarda_o_refazer() ! {
	token := start_gdiplus()!
	defer {
		stop_gdiplus(token)
	}
	source := sample_image(60)!
	defer {
		source.release()
	}
	mut editor := Editor{
		source: source
		canvas_width: 60
		canvas_height: 60
		scene: Scene{
			crop: whole_of(source)
			shapes: [
				Shape{
					tool: .rectangle
					area: Rect{
						x: 5
						y: 5
						width: 40
						height: 40
					}
					thickness: 2
					style: Style{
						filled: true
					}
				},
			]
		}
		tool: .select
		selected: 0
	}
	defer {
		editor.current.release()
	}
	editor.apply()!
	editor.future = [editor.scene.clone()]
	top := toolbar_height

	press(mut editor, 25, top + 25)
	assert editor.finish_grab() == 'Marcação selecionada'
	assert editor.future.len == 1
	assert editor.past.len == 0

	press(mut editor, 25, top + 25)
	editor.cursor_x = 35
	assert editor.finish_grab() == 'Marcação movida'
	assert editor.future.len == 0
	assert editor.past.len == 1
}

// Com moldura, a vista inclui a folga dela, que não é captura: o recorte que começa ou termina na folga fica preso à captura, e um arrasto todo dentro da folga não recorta nada nem entra no histórico.
fn test_recorte_com_moldura_fica_dentro_da_captura() ! {
	token := start_gdiplus()!
	defer {
		stop_gdiplus(token)
	}
	source := sample_image(60)!
	defer {
		source.release()
	}
	mut editor := Editor{
		source: source
		canvas_width: 200
		canvas_height: 200
		scene: Scene{
			crop: whole_of(source)
			shapes: [
				Shape{
					tool: .backdrop
					color: 0x00ffffff
					thickness: 2
				},
			]
		}
		tool: .select
		selected: -1
	}
	defer {
		editor.current.release()
	}
	editor.apply()!
	view := editor.view
	margin := int(f64(backdrop_margin(2)) * editor.scale)

	press(mut editor, view.x, view.y)
	editor.cursor_x = view.x + margin - 1
	editor.cursor_y = view.y + view.height
	editor.finish_drag()
	assert editor.scene.crop == whole_of(source)
	assert editor.past.len == 0

	press(mut editor, view.x, view.y)
	editor.cursor_x = view.x + view.width / 2
	editor.cursor_y = view.y + view.height / 2
	assert editor.finish_drag().starts_with('Recortado')
	top_left := editor.scene.crop
	assert top_left.x == 0 && top_left.y == 0
	assert top_left.width > 0 && top_left.height > 0

	editor.undo()
	press(mut editor, view.x + view.width / 2, view.y + view.height / 2)
	editor.cursor_x = view.x + view.width
	editor.cursor_y = view.y + view.height
	assert editor.finish_drag().starts_with('Recortado')
	bottom_right := editor.scene.crop
	assert bottom_right.width > 0 && bottom_right.x + bottom_right.width == 60
	assert bottom_right.height > 0 && bottom_right.y + bottom_right.height == 60
}

// A alça de uma marcação encostada na borda da imagem fica meio para fora dela, e o ponteiro já mostra a seta de esticar ali: o clique nesse lado também pega a alça. Antes ele não fazia nada, porque a imagem era conferida primeiro.
fn test_a_alca_na_borda_pega_tambem_por_fora_da_imagem() ! {
	token := start_gdiplus()!
	defer {
		stop_gdiplus(token)
	}
	source := sample_image(60)!
	defer {
		source.release()
	}
	mut editor := square_editor(source, 200, 200)!
	defer {
		editor.current.release()
	}
	editor.scene.shapes[0] = Shape{
		...editor.scene.shapes[0]
		area: Rect{
			width: 40
			height: 40
		}
	}
	x := editor.view.x - 2
	y := editor.view.y - 2
	assert !inside_view(editor, x, y)
	assert editor.grab_at(x, y) == .top_left
	editor_press(unsafe { nil }, mut editor, x, y)
	assert editor.grab == .top_left
	assert editor.dragging
	// Longe de qualquer alça, o fundo em volta da imagem continua sem começar nada.
	editor.dragging = false
	editor.grab = .none
	editor.scene.shapes.insert(0, editor.grabbed)
	editor_press(unsafe { nil }, mut editor, 1, toolbar_height + 1)
	assert !editor.dragging
}
