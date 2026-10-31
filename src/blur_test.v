module main

// Borrar é a primeira ferramenta que lê a imagem em vez de só escrever nela, e o que ela
// faz não se vê na geometria: se as duas passadas de redução saíssem trocadas, ou se a
// volta interpolasse, o resultado continuaria sendo um retângulo do tamanho certo. Estes
// testes desenham cores conhecidas numa superfície e conferem os pixels que saem.

// canvas monta uma superfície branca do tamanho pedido.
fn canvas(width int, height int) !Frozen {
	screen := C.GetDC(unsafe { nil })
	surface := new_surface(screen, width, height)!
	C.ReleaseDC(unsafe { nil }, screen)
	paint_rect(surface.dc, Rect{
		width: width
		height: height
	}, 0x00ffffff)
	return surface
}

// channels reparte um COLORREF, que é 0x00bbggrr, nos três canais.
fn channels(color u32) (int, int, int) {
	return int(color & 0xff), int((color >> 8) & 0xff), int((color >> 16) & 0xff)
}

// Um quadrado preto num quarto do bloco tem de virar um bloco inteiro de cinza claro, e o
// bloco vizinho tem de continuar branco: é isso, e não o tamanho da área, que distingue um
// mosaico de um retângulo pintado.
fn test_borrar_espalha_a_cor_pelo_bloco_inteiro() ! {
	surface := canvas(40, 40)!
	defer {
		surface.release()
	}
	paint_rect(surface.dc, Rect{
		width: 10
		height: 10
	}, 0x00000000)
	area := Rect{
		width: 40
		height: 40
	}
	// Espessura dez dá blocos de vinte, ou seja, quatro blocos nesta área.
	assert blur_block(10) == 20
	draw_blur(surface.dc, Shape{
		tool: .blur
		area: area
		thickness: 10
	}, area)

	corner := C.GetPixel(surface.dc, 0, 0)
	// O bloco é chapado: o canto oposto dele tem de ter exatamente a mesma cor.
	assert C.GetPixel(surface.dc, 19, 19) == corner
	assert C.GetPixel(surface.dc, 5, 15) == corner
	red, green, blue := channels(corner)
	// Um quarto de preto em branco dá um cinza claro, e não preto nem branco.
	assert red > 150 && red < 230
	assert red == green && green == blue
	// O bloco onde não havia nada continua branco.
	assert C.GetPixel(surface.dc, 39, 39) == 0x00ffffff
}

// A prévia, com a imagem reduzida, tem os blocos do resultado: eles são contados pela caixa da marcação, em pixels da captura, e não pela espessura reduzida da prévia, que truncada e com piso dava um grão mais fino.
fn test_a_previa_tem_os_blocos_do_resultado() ! {
	surface := canvas(48, 48)!
	defer {
		surface.release()
	}
	paint_rect(surface.dc, Rect{
		width: 4
		height: 48
	}, 0x00000000)
	// Uma caixa de 120 pixels da captura exibida a 0,4 ocupa 48 da janela. A espessura 6 dá blocos de 12 pixels da captura, ou seja, dez blocos de 4,8 pixels na prévia, e a coluna 4 ainda é do primeiro, o da faixa preta.
	draw_blur(surface.dc, Shape{
		tool: .blur
		area: Rect{
			width: 120
			height: 120
		}
		thickness: 6
	}, Rect{
		width: 48
		height: 48
	})
	assert C.GetPixel(surface.dc, 4, 10) == C.GetPixel(surface.dc, 0, 10)
}

// Apagar cobre a área inteira com uma cor só, tirada da média do que havia ali.
fn test_apagar_cobre_com_a_media_das_cores() ! {
	surface := canvas(40, 20)!
	defer {
		surface.release()
	}
	paint_rect(surface.dc, Rect{
		width: 20
		height: 20
	}, 0x000000ff) // vermelho
	paint_rect(surface.dc, Rect{
		x: 20
		width: 20
		height: 20
	}, 0x00ff0000) // azul
	area := Rect{
		width: 40
		height: 20
	}
	draw_blur(surface.dc, Shape{
		tool: .blur
		style: Style{
			erase: true
		}
	}, area)

	corner := C.GetPixel(surface.dc, 0, 0)
	assert C.GetPixel(surface.dc, 39, 19) == corner
	assert C.GetPixel(surface.dc, 20, 10) == corner
	red, green, blue := channels(corner)
	// Meio vermelho e meio azul dão os dois canais pela metade, e nada de verde.
	assert red > 90 && red < 170
	assert blue > 90 && blue < 170
	assert green < 20
}

// Uma área sem lado não é área: borrar nela não faz nada, e não quebra.
fn test_area_vazia_nao_borra_nada() ! {
	surface := canvas(10, 10)!
	defer {
		surface.release()
	}
	draw_blur(surface.dc, Shape{
		tool: .blur
	}, Rect{
		width: 0
		height: 10
	})
	assert C.GetPixel(surface.dc, 0, 0) == 0x00ffffff
}

// O bloco cresce com a espessura e nunca chega a um pixel, que seria não borrar nada.
fn test_o_bloco_acompanha_a_espessura() {
	assert blur_block(f32(min_thickness)) >= 2
	assert blur_block(0.1) == 2
	assert blur_block(f32(max_thickness)) == max_thickness * blur_grain
	assert blur_block(f32(max_thickness)) > blur_block(f32(min_thickness))
}

// O painel de borrar não tem disco de cor, e por isso é mais estreito e o controle começa
// logo na margem.
fn test_o_painel_de_borrar_nao_tem_disco_de_cor() {
	assert !has_swatch(.blur)
	assert has_swatch(.rectangle)
	assert options_width(.blur) == options_width(.rectangle) - swatch_size - swatch_gap -
		style_group_width(.rectangle) + style_group_width(.blur)

	panel := Rect{
		x: 100
		y: 50
		width: options_width(.blur)
		height: options_height
	}
	track := slider_track(panel, .blur)
	assert track.x == panel.x + options_padding
	// E os botões de estilo continuam cabendo dentro do painel.
	last := style_button_rect(panel, .blur, style_slots_blur.len - 1)
	assert last.x + last.width == panel.x + panel.width - options_padding
	assert last.x > track.x + track.width
}

// Sem disco não há paleta: ela pende dele.
fn test_sem_disco_a_paleta_nao_abre() {
	mut editor := Editor{
		canvas_width: 800
		canvas_height: 600
		tool: .blur
		selected: -1
		palette_open: true
	}
	assert editor.options_panel() != none
	assert editor.palette_rect() == none
	// Com uma ferramenta que tem cor, a mesma paleta aberta aparece.
	editor.tool = .rectangle
	assert editor.palette_rect() != none
}

// Os dois botões são borrar e apagar, e um exclui o outro.
fn test_borrar_escolhe_entre_blocos_e_media() {
	assert style_slots(.blur) == style_slots_blur
	blocks := style_pressed(Style{}, style_slots_blur[0])
	average := style_pressed(Style{}, style_slots_blur[1])
	assert !blocks.erase
	assert average.erase
	assert style_is_active(blocks, style_slots_blur[0])
	assert !style_is_active(blocks, style_slots_blur[1])
	assert style_is_active(average, style_slots_blur[1])
	assert style_name(style_slots_blur[0]) == 'Borrar em blocos'
	assert style_name(style_slots_blur[1]) == 'Apagar com a média'
	// Trocar o modo não mexe no que as outras ferramentas guardam.
	rich := Style{
		rounded: true
		filled: true
		head: .double
	}
	changed := style_pressed(rich, style_slots_blur[1])
	assert changed.rounded && changed.filled && changed.head == .double
}
