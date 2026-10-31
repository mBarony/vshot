module main

// A moldura é a única coisa que muda o tamanho do resultado, e é isso que estes testes
// olham: quanto a imagem cresceu, onde a original foi parar dentro dela, e que as contas
// que levam um ponto da captura até a janela continuam certas depois disso.

// framed_editor monta um editor sobre uma captura pequena, sem janela.
fn framed_editor() !Editor {
	screen := C.GetDC(unsafe { nil })
	source := new_surface(screen, 200, 100)!
	C.ReleaseDC(unsafe { nil }, screen)
	paint_rect(source.dc, Rect{
		width: 200
		height: 100
	}, 0x00ffffff)
	mut editor := Editor{
		source: source
		tool: .rectangle
		color: annotation_color
		thickness: annotation_width
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

// Escolher a ferramenta já põe a moldura: ela não nasce de arrasto. Escolher de novo apenas
// devolve a que existe, sem empilhar uma segunda.
fn test_escolher_a_ferramenta_poe_uma_moldura_so() ! {
	mut editor := framed_editor()!
	editor.choose(.backdrop)
	assert editor.scene.shapes.len == 1
	assert editor.scene.shapes[0].tool == .backdrop
	assert editor.selected == 0
	assert editor.past.len == 1

	editor.choose(.rectangle)
	editor.choose(.backdrop)
	assert editor.scene.shapes.len == 1
	assert editor.selected == 0
	// Escolher de novo não é uma edição, então não entra no histórico.
	assert editor.past.len == 1
}

// A imagem de trabalho cresce a folga de cada lado, e o painel governa essa folga.
fn test_a_moldura_faz_a_imagem_crescer() ! {
	mut editor := framed_editor()!
	editor.choose(.backdrop)
	margin := backdrop_margin(backdrop_thickness)
	assert editor.current.width == 200 + 2 * margin
	assert editor.current.height == 100 + 2 * margin
	assert editor.margin() == margin

	// Engrossar pelo controle do painel engrossa a folga.
	panel := editor.options_panel() or { panic('a moldura tem painel') }
	editor.slide_to(knob_center(slider_track(panel, .backdrop), max_thickness))
	assert editor.margin() == backdrop_margin(max_thickness)
	assert editor.current.width == 200 + 2 * backdrop_margin(max_thickness)
}

// Sem moldura a folga é zero, e as conversões ficam como eram.
fn test_sem_moldura_nao_ha_folga() ! {
	mut editor := framed_editor()!
	assert editor.margin() == 0
	assert scene_margin(editor.scene) == 0
	assert editor.current.width == 200
}

// A folga desloca a origem da imagem, então um ponto da captura tem de continuar caindo no
// mesmo lugar da imagem depois de a moldura entrar — e a volta tem de desfazer a ida.
fn test_a_folga_entra_nas_duas_pontas_da_conversao() ! {
	mut editor := framed_editor()!
	editor.choose(.backdrop)
	editor.selected = -1

	spot := Rect{
		x: 40
		y: 30
		width: 20
		height: 10
	}
	client := editor.to_client(spot)
	back := editor.to_source(editor.to_image(client))
	assert back.x == spot.x
	assert back.y == spot.y

	point := editor.to_source_point(client.x, client.y)
	assert point.x == spot.x
	assert point.y == spot.y
}

// A imagem original fica no meio da moldura, e o que sobra em volta é a cor escolhida.
fn test_a_imagem_fica_no_meio_e_a_cor_em_volta() ! {
	screen := C.GetDC(unsafe { nil })
	inner := new_surface(screen, 60, 40)!
	C.ReleaseDC(unsafe { nil }, screen)
	defer {
		inner.release()
	}
	paint_rect(inner.dc, Rect{
		width: 60
		height: 40
	}, 0x0000ff00) // verde
	mark := Shape{
		tool: .backdrop
		color: 0x000000ff // vermelho
		thickness: 2
	}
	framed := wrap_backdrop(inner, mark)!
	defer {
		framed.release()
	}
	margin := backdrop_margin(2)
	assert framed.width == 60 + 2 * margin
	assert framed.height == 40 + 2 * margin
	// O canto da moldura é a cor dela, e o meio é a imagem.
	assert C.GetPixel(framed.dc, 1, 1) == 0x000000ff
	assert C.GetPixel(framed.dc, margin + 30, margin + 20) == 0x0000ff00
	// A imagem começa exatamente na folga.
	assert C.GetPixel(framed.dc, margin, margin) == 0x0000ff00
	assert C.GetPixel(framed.dc, margin - 1, margin - 1) == 0x000000ff
}

// Com o canto arredondado, o canto da imagem some e aparece a cor da moldura no lugar; sem
// ele, a imagem vai até o canto.
fn test_o_canto_arredondado_come_a_quina_da_imagem() ! {
	screen := C.GetDC(unsafe { nil })
	inner := new_surface(screen, 60, 60)!
	C.ReleaseDC(unsafe { nil }, screen)
	defer {
		inner.release()
	}
	paint_rect(inner.dc, Rect{
		width: 60
		height: 60
	}, 0x0000ff00)
	margin := backdrop_margin(3)

	square := wrap_backdrop(inner, Shape{
		tool: .backdrop
		color: 0x000000ff
		thickness: 3
	})!
	defer {
		square.release()
	}
	assert C.GetPixel(square.dc, margin, margin) == 0x0000ff00

	round := wrap_backdrop(inner, Shape{
		tool: .backdrop
		color: 0x000000ff
		thickness: 3
		style: Style{
			rounded: true
		}
	})!
	defer {
		round.release()
	}
	assert C.GetPixel(round.dc, margin, margin) != 0x0000ff00
	// O meio de cada lado continua sendo a imagem: só a quina é comida.
	assert C.GetPixel(round.dc, margin + 30, margin) == 0x0000ff00
	assert C.GetPixel(round.dc, margin, margin + 30) == 0x0000ff00
}

// A sombra escurece a moldura logo abaixo da imagem, e deixa o canto de cima intacto. É a
// única parte da moldura que passa pelo GDI+, que fora do editor precisa ser ligado à mão.
fn test_a_sombra_escurece_sob_a_imagem() ! {
	token := start_gdiplus()!
	defer {
		stop_gdiplus(token)
	}
	screen := C.GetDC(unsafe { nil })
	inner := new_surface(screen, 60, 60)!
	C.ReleaseDC(unsafe { nil }, screen)
	defer {
		inner.release()
	}
	paint_rect(inner.dc, Rect{
		width: 60
		height: 60
	}, 0x0000ff00)
	margin := backdrop_margin(4)
	base := Shape{
		tool: .backdrop
		color: 0x00ffffff
		thickness: 4
	}
	plain := wrap_backdrop(inner, base)!
	defer {
		plain.release()
	}
	shaded := wrap_backdrop(inner, Shape{
		...base
		style: Style{
			shadow: true
		}
	})!
	defer {
		shaded.release()
	}
	below := margin + 60 + 3
	assert C.GetPixel(plain.dc, margin + 30, below) == 0x00ffffff
	assert C.GetPixel(shaded.dc, margin + 30, below) != 0x00ffffff
	// Longe da imagem a moldura continua limpa nos dois casos.
	assert C.GetPixel(shaded.dc, 0, 0) == 0x00ffffff
}

// Numa imagem menor que o canto da moldura, a sombra continua um degradê: descendo pela coluna do meio, abaixo da imagem, ela só clareia. Com os arcos do canto cruzados, saía em lóbulos claros e escuros.
fn test_sombra_de_imagem_pequena_e_um_degrade() ! {
	token := start_gdiplus()!
	defer {
		stop_gdiplus(token)
	}
	screen := C.GetDC(unsafe { nil })
	inner := new_surface(screen, 20, 20)!
	C.ReleaseDC(unsafe { nil }, screen)
	defer {
		inner.release()
	}
	paint_rect(inner.dc, Rect{
		width: 20
		height: 20
	}, 0x0000ff00)
	framed := wrap_backdrop(inner, Shape{
		tool: .backdrop
		color: 0x00ffffff
		thickness: 12
		style: Style{
			rounded: true
			shadow: true
		}
	})!
	defer {
		framed.release()
	}
	margin := backdrop_margin(12)
	x := margin + 10
	mut previous := -1
	for y in margin + 21 .. margin + 40 {
		pixel := C.GetPixel(framed.dc, x, y)
		light := int(pixel & 0xff) + int((pixel >> 8) & 0xff) + int((pixel >> 16) & 0xff)
		assert light >= previous, 'y ${y}: ${light} depois de ${previous}'
		previous = light
	}
}

// A folga e a cor mexidas na moldura são dela: não viram o traço nem a cor das ferramentas seguintes, que continuam com os que estavam.
fn test_a_moldura_nao_passa_folga_nem_cor_adiante() ! {
	mut editor := framed_editor()!
	editor.thickness = 8
	editor.choose(.backdrop)
	panel := editor.options_panel() or { panic('o painel deveria existir') }
	editor.slide_to(knob_center(slider_track(panel, .backdrop), max_thickness))
	editor.apply_color(quick_colors[3])
	assert editor.scene.shapes[0].thickness == max_thickness
	assert editor.scene.shapes[0].color == quick_colors[3]
	editor.choose(.rectangle)
	assert editor.thickness == 8
	assert editor.color == annotation_color
}

// Um botão de estilo com a marcação de outra ferramenta selecionada muda só a marcação: a sombra e o canto da moldura, ou o balão de um texto, não viram o padrão do próximo retângulo. Com a marcação da ferramenta na mão, a troca vale também para as próximas.
fn test_estilo_de_outra_ferramenta_nao_vira_padrao() ! {
	mut editor := framed_editor()!
	editor.choose(.backdrop)
	editor.choose_style(style_slots_backdrop[3])
	assert !editor.scene.shapes[0].style.shadow
	editor.choose(.rectangle)
	assert !editor.style.rounded

	editor.scene.shapes << Shape{
		tool: .rectangle
		area: Rect{
			x: 10
			y: 10
			width: 40
			height: 30
		}
		color: annotation_color
		thickness: annotation_width
	}
	editor.selected = editor.scene.shapes.len - 1
	editor.choose_style(0)
	assert editor.scene.shapes[editor.selected].style.rounded
	assert editor.style.rounded

	editor.scene.shapes << Shape{
		tool: .text
		area: Rect{
			x: 60
			y: 10
			width: 80
			height: 30
		}
		color: annotation_color
		thickness: text_thickness
		text: 'a'
	}
	editor.choose(.select)
	editor.selected = editor.scene.shapes.len - 1
	before := editor.style
	editor.choose_style(10)
	assert editor.style == before
}

// A sombra só é pintada nas faixas em volta do miolo que a imagem cobre: as quatro não se sobrepõem, e somadas cobrem a sombra inteira menos o miolo. Numa imagem menor que dois cantos não há miolo, e a faixa é uma só.
fn test_faixas_da_sombra_cobrem_o_que_aparece() {
	seat := Rect{
		x: 100
		y: 100
		width: 200
		height: 120
	}
	strips := shadow_strips(seat, 20)
	assert strips.len == 4
	mut painted := 0
	for index, strip in strips {
		painted += strip.width * strip.height
		for other in strips[index + 1..] {
			common := overlap(strip, other)
			assert common.width == 0 || common.height == 0
		}
	}
	pad := shadow_layers + 2
	whole := (seat.width + 2 * pad) * (seat.height + 2 * pad + shadow_drop)
	core := (seat.width - 40) * (seat.height - 40)
	assert painted == whole - core
	assert shadow_strips(Rect{ x: 10, y: 10, width: 30, height: 30 }, 20).len == 1
}

// A moldura só tem painel enquanto está escolhida: sem ela selecionada — depois de um Esc, de um desfazer ou de um Delete —, o painel mostraria e mudaria valores que moldura nenhuma usa. Apertar K de novo a escolhe, e o painel volta.
fn test_a_moldura_so_tem_painel_escolhida() ! {
	mut editor := framed_editor()!
	editor.choose(.backdrop)
	assert editor.options_panel() != none
	editor.selected = -1
	assert editor.options_panel() == none
	editor.choose(.backdrop)
	assert editor.options_panel() != none
}

// A moldura não se pega por clique: quem a escolhe é o botão da barra.
fn test_a_moldura_nao_e_pega_por_clique() ! {
	mut editor := framed_editor()!
	editor.choose(.backdrop)
	editor.tool = .select
	// Um clique no meio da imagem não escolhe a moldura, mesmo com ela ocupando tudo.
	assert editor.shape_at(editor.view.x + editor.view.width / 2, editor.view.y +
		editor.view.height / 2) == -1
}

// A moldura escolhida não tem alças: a caixa dela é zerada, e as alças cairiam todas no canto de dentro da moldura, onde um arrasto a estragaria.
fn test_a_moldura_nao_tem_alcas() ! {
	mut editor := framed_editor()!
	editor.choose(.backdrop)
	corner := editor.to_client(Rect{})
	assert editor.grab_at(corner.x, corner.y) == .none
}

// Aproximar da moldura escolhida mostra a imagem inteira: a caixa zerada dela levava o zoom ao máximo, no canto de dentro da moldura.
fn test_aproximar_da_moldura_mostra_a_imagem_inteira() ! {
	mut editor := framed_editor()!
	editor.choose(.backdrop)
	assert editor.zoom_selection().ends_with('a imagem inteira')
	assert editor.zoom == 1.0
}

// Numa captura baixa o canto é preso a um terço do lado menor, como nas marcações: com o raio da folga larga, as pontas da imagem viravam semicírculos, e ela perdia bem mais que a quina.
fn test_o_canto_da_moldura_respeita_a_imagem_baixa() ! {
	screen := C.GetDC(unsafe { nil })
	inner := new_surface(screen, 200, 40)!
	C.ReleaseDC(unsafe { nil }, screen)
	defer {
		inner.release()
	}
	paint_rect(inner.dc, Rect{
		width: 200
		height: 40
	}, 0x0000ff00)
	margin := backdrop_margin(6)
	framed := wrap_backdrop(inner, Shape{
		tool: .backdrop
		color: 0x000000ff
		thickness: 6
		style: Style{
			rounded: true
		}
	})!
	defer {
		framed.release()
	}
	assert C.GetPixel(framed.dc, margin + 5, margin + 5) == 0x0000ff00
	assert C.GetPixel(framed.dc, margin, margin) != 0x0000ff00
}

// Na largura 1 a sombra cabe na folga: as doze camadas passavam da borda, e em vez de sumir na cor da moldura ela terminava numa faixa cinza cortada.
fn test_a_sombra_cabe_na_folga_estreita() ! {
	token := start_gdiplus()!
	defer {
		stop_gdiplus(token)
	}
	screen := C.GetDC(unsafe { nil })
	inner := new_surface(screen, 60, 60)!
	C.ReleaseDC(unsafe { nil }, screen)
	defer {
		inner.release()
	}
	paint_rect(inner.dc, Rect{
		width: 60
		height: 60
	}, 0x0000ff00)
	margin := backdrop_margin(1)
	framed := wrap_backdrop(inner, Shape{
		tool: .backdrop
		color: 0x00ffffff
		thickness: 1
		style: Style{
			rounded: true
			shadow: true
		}
	})!
	defer {
		framed.release()
	}
	assert C.GetPixel(framed.dc, margin + 30, framed.height - 1) == 0x00ffffff
	assert C.GetPixel(framed.dc, framed.width - 1, margin + 30) == 0x00ffffff
	// A sombra continua existindo logo abaixo da imagem.
	assert C.GetPixel(framed.dc, margin + 30, margin + 62) != 0x00ffffff
}

// A prévia do traço livre é recortada pela imagem, como as das outras ferramentas: o que passava para a folga da moldura aparecia no arrasto e sumia ao soltar.
fn test_a_previa_do_traco_nao_passa_da_imagem() ! {
	token := start_gdiplus()!
	defer {
		stop_gdiplus(token)
	}
	mut editor := framed_editor()!
	editor.choose(.backdrop)
	editor.selected = -1
	editor.tool = .freehand
	screen := C.GetDC(unsafe { nil })
	window := new_surface(screen, editor.canvas_width, toolbar_height + editor.canvas_height)!
	C.ReleaseDC(unsafe { nil }, screen)
	defer {
		window.release()
	}
	paint_rect(window.dc, Rect{
		width: window.width
		height: window.height
	}, 0x00ffffff)
	image := editor.to_client(editor.scene.crop)
	// O traço desce da imagem até 30 pixels dentro da folga, que tem 60.
	editor.stroke = [Point{image.x + 100, image.y + 50}, Point{image.x + 100, image.y + image.height + 30}]
	draw_preview(window.dc, editor.area(), &editor)
	assert C.GetPixel(window.dc, image.x + 100, image.y + 60) == annotation_color
	assert C.GetPixel(window.dc, image.x + 100, image.y + image.height + 20) == 0x00ffffff
}

// Os quatro botões do painel são o canto da imagem e a sombra, em dois pares exclusivos.
fn test_a_moldura_escolhe_canto_e_sombra() {
	assert style_slots(.backdrop) == style_slots_backdrop
	rounded := style_pressed(Style{}, style_slots_backdrop[0])
	square := style_pressed(Style{}, style_slots_backdrop[1])
	shaded := style_pressed(Style{}, style_slots_backdrop[2])
	plain := style_pressed(Style{}, style_slots_backdrop[3])
	assert rounded.rounded && !square.rounded
	assert shaded.shadow && !plain.shadow
	assert style_is_active(shaded, style_slots_backdrop[2])
	assert !style_is_active(shaded, style_slots_backdrop[3])
	assert style_name(style_slots_backdrop[2]) == 'Com sombra'
	assert style_name(style_slots_backdrop[3]) == 'Sem sombra'
	// Escolher a sombra não mexe no canto, nem o contrário.
	both := style_pressed(rounded, style_slots_backdrop[2])
	assert both.rounded && both.shadow
}
